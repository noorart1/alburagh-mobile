import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_service.dart';
import '../core/secure_token_storage.dart';
import '../models/user.dart';
import 'cart_provider.dart'; // Import CartProvider
import 'wishlist_provider.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final CartProvider _cartProvider; // Add CartProvider dependency
  final WishlistProvider _wishlistProvider;

  User? _user;
  bool _isLoggedIn = false;
  bool _isLoading = false;
  String? _error;

  // Full profile (name/phone/billing/shipping) fetched once in the
  // background right after login/auto-login, ahead of the user ever opening
  // ProfileScreen, so that screen can render instantly from cache instead of
  // making its own GET /profile round trip and showing a spinner every time
  // it's opened.
  Map<String, dynamic>? _profile;
  Future<void>? _profileFuture;

  User? get user => _user;
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, dynamic>? get profile => _profile;

  // Resolves once the saved-session restore below has finished (whether or
  // not there was one to restore). Screens built eagerly at app start (e.g.
  // ProfileScreen, sitting in MainScreen's IndexedStack) must await this
  // before trusting isLoggedIn — otherwise they can read it before
  // _loadSavedAuth() has had a chance to set it, and wrongly treat a logged
  // in user as a guest right after the app is reopened.
  late final Future<void> initialized;

  AuthProvider(this._cartProvider, this._wishlistProvider) {
    // Lets ApiService's AuthInterceptor drop the session locally once the
    // refresh token is confirmed dead (expired/revoked/rejected) -- never
    // called for a plain network failure, see AuthInterceptor's doc comment.
    _api.onSessionExpired = forceLogout;
    initialized = _loadSavedAuth();
  }

  Future<void> _loadSavedAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final token = await SecureTokenStorage.readAccessToken();
    final userId = prefs.getInt('user_id');
    final email = prefs.getString('user_email') ?? '';
    final name = prefs.getString('user_name') ?? '';

    if (token != null && userId != null && email.isNotEmpty) {
      _user = User(id: userId, email: email, name: name, token: token);
      _isLoggedIn = true;
      notifyListeners();
      // Load cart after successful auto-login
      await _cartProvider.loadCart();
      // Not awaited: runs in the background while the user is on whatever
      // screen they land on first, so it's ready by the time they open theirs.
      ensureProfileLoaded();
      // WishlistScreen only loads once, the first time it's built (it's kept
      // alive in MainScreen's IndexedStack) — so if that already happened
      // before this restore finished (e.g. it ran as a logged-out guest),
      // it would otherwise keep showing an empty/stale list forever. Refresh
      // it now that we know who's actually logged in.
      _wishlistProvider.loadWishlist();
    }
  }

  Future<bool> login(String identifier, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      Map<String, dynamic> response;

      try {
        response = await _api.loginWithAlburaghApi(
          username: identifier,
          password: password,
        );
      } on DioException catch (e) {
        if (e.response?.statusCode != 404) {
          rethrow;
        }
        response = await _loginWithJwtFallback(identifier, password);
      }

      final authData = response['data'] is Map
          ? Map<String, dynamic>.from(response['data'])
          : response;
      final token = authData['token']?.toString();
      final alburaghUser = authData['user'] is Map
          ? Map<String, dynamic>.from(authData['user'])
          : null;
      var userId = _parseUserId(alburaghUser?['id']);

      if (token != null) {
        userId ??= _userIdFromJwt(token);
      }

      if (token == null || userId == null) {
        _error = 'فشل تسجيل الدخول';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final responseEmail =
          authData['user_email']?.toString() ??
          alburaghUser?['email']?.toString() ??
          identifier;
      final displayName =
          authData['user_display_name']?.toString() ??
          [alburaghUser?['first_name'], alburaghUser?['last_name']]
              .whereType<String>()
              .where((value) => value.isNotEmpty)
              .join(' ')
              .trim();
      final name = displayName.isNotEmpty
          ? displayName
          : identifier.split('@')[0];
      final userEmail = responseEmail.isNotEmpty ? responseEmail : identifier;

      _user = User(id: userId, email: userEmail, name: name, token: token);
      _isLoggedIn = true;

      // The wp-json JWT-plugin login fallback doesn't issue a refresh token
      // (it's a third-party plugin, not this app's own backend) -- only the
      // primary /login endpoint's response has one. Clearing first (instead
      // of just not overwriting) stops a fallback login from silently
      // inheriting whatever refresh token a previous session happened to
      // leave behind -- a fallback-started session just won't silently
      // refresh at all.
      final refreshToken = authData['refresh_token']?.toString();
      await SecureTokenStorage.clear();
      await SecureTokenStorage.saveTokens(
        accessToken: token,
        refreshToken: refreshToken,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('user_id', userId);
      await prefs.setString('user_email', userEmail);
      await prefs.setString('user_name', name);

      _isLoading = false;
      notifyListeners();

      // Snapshot the guest cart, then drop the session cookie before the
      // first authenticated cart call: without that reset, WooCommerce's
      // own cookie-based session migration (in init_wc_cart()) would
      // silently overwrite the account's own saved cart with whatever
      // this cookie's guest session held, permanently losing anything
      // saved there before this login. Resetting first makes the
      // authenticated session load the account's real cart untouched, and
      // mergeCart() then additively re-adds the guest items on top of it.
      final guestItems = List<CartItem>.from(_cartProvider.items);
      _api.resetSession();
      await _cartProvider.mergeCart(guestItems);
      // Not awaited — see _loadSavedAuth() for why.
      ensureProfileLoaded();
      // Refresh with this account's wishlist — see _loadSavedAuth() for why
      // WishlistScreen's own one-time load isn't enough on its own.
      _wishlistProvider.loadWishlist();
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        _error = 'اسم المستخدم أو كلمة المرور غير صحيحة';
      } else if (e.response?.statusCode == 404) {
        _error =
            'خدمة تسجيل الدخول غير متاحة. تأكد من تفعيل إضافة JWT Authentication';
      } else {
        _error = e.response?.data?['message'] ?? 'خطأ في الاتصال بالخادم';
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'خطأ غير متوقع: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>> _loginWithJwtFallback(
    String identifier,
    String password,
  ) async {
    try {
      return await _api.loginWithJwt(username: identifier, password: password);
    } on DioException catch (e) {
      if (e.response?.statusCode != 403) {
        rethrow;
      }

      if (!identifier.contains('@')) {
        rethrow;
      }

      final customer = await _api.getCustomerByEmail(identifier);
      final username = customer?['username']?.toString();

      if (username == null || username.isEmpty || username == identifier) {
        rethrow;
      }

      return _api.loginWithJwt(username: username, password: password);
    }
  }

  int? _parseUserId(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  int? _userIdFromJwt(String token) {
    final parts = token.split('.');

    if (parts.length != 3) {
      return null;
    }

    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );

      if (payload is! Map<String, dynamic>) {
        return null;
      }

      final id = payload['sub'] ?? payload['data']?['user']?['id'];

      if (id is int) {
        return id;
      }

      if (id is String) {
        return int.tryParse(id);
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  Future<bool> register({
    required String email,
    required String password,
    required String firstName,
    String? lastName,
    String? phone,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _api.registerCustomer(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
      );

      // login() already merges the guest cart after it stores the new token.
      // Merging again here would add every guest item twice.
      return login(email, password);
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        _error = data['message'];
      } else if (e.response?.statusCode == 400) {
        _error = 'البريد الإلكتروني مسجل مسبقاً أو البيانات غير صحيحة';
      } else if (e.response?.statusCode == 500) {
        _error = 'خطأ في الخادم. تأكد من تفعيل REST API في WooCommerce';
      } else {
        _error = 'خطأ في إنشاء الحساب';
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'خطأ غير متوقع: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Returns the in-flight or already-completed profile fetch, starting one
  /// if neither exists yet. Safe to call from multiple places (e.g. a screen
  /// opened before the background preload finished) without triggering
  /// duplicate GET /profile requests.
  Future<void> ensureProfileLoaded() {
    if (_profile != null) return Future.value();
    return _profileFuture ??= _fetchProfile();
  }

  /// Updates the cached profile directly from data already fetched elsewhere
  /// (e.g. the response of a PUT /profile save), instead of invalidating the
  /// cache and forcing a redundant re-fetch.
  void setProfile(Map<String, dynamic> profile) {
    _profile = profile;
    notifyListeners();
  }

  Future<void> _fetchProfile() async {
    final token = _user?.token;
    if (token == null) return;

    try {
      _profile = await _api.getProfile(token);
      notifyListeners();
    } catch (_) {
      // Leave _profile null; the next ensureProfileLoaded() call (e.g. a
      // manual retry) will simply try again.
    } finally {
      _profileFuture = null;
    }
  }

  Future<void> logout() async {
    // Best-effort server-side revoke, using the token while it's still
    // around -- fire-and-forget so a slow/offline revoke call never blocks
    // the user leaving their account, and a failure here is harmless (the
    // refresh token just lingers server-side until it expires on its own).
    final token = _user?.token;
    if (token != null) {
      unawaited(_api.revokeRefreshToken(token).catchError((_) {}));
    }

    await _clearLocalSession();
  }

  /// Drops the local session only -- no server revoke call. Used when
  /// ApiService's AuthInterceptor has already confirmed server-side that the
  /// refresh token is dead, so there's nothing left to revoke.
  Future<void> forceLogout() => _clearLocalSession();

  Future<void> _clearLocalSession() async {
    _user = null;
    _isLoggedIn = false;
    _error = null;
    _profile = null;
    _profileFuture = null;

    await SecureTokenStorage.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('user_email');
    await prefs.remove('user_name');

    notifyListeners();
    // Local-only reset -- see CartProvider.resetLocal's doc comment for
    // why logout must not call the server clearCart API here.
    _cartProvider.resetLocal();
    // Also drop the session cookie so guest browsing after logout starts a
    // fresh anonymous WooCommerce session instead of continuing to read/
    // write this account's own cart via its still-linked cookie.
    _api.resetSession();
    // Drop the cached wishlist too (local only — see WishlistProvider.reset)
    // so its bottom-bar badge doesn't keep showing the previous account's
    // count while logged out.
    _wishlistProvider.reset();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
