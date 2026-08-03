import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_service.dart';
import '../models/user.dart';
import 'cart_provider.dart'; // Import CartProvider

class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final CartProvider _cartProvider; // Add CartProvider dependency

  User? _user;
  bool _isLoggedIn = false;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String? get error => _error;

  AuthProvider(this._cartProvider) {
    _loadSavedAuth();
  }

  Future<void> _loadSavedAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final userId = prefs.getInt('user_id');
    final email = prefs.getString('user_email') ?? '';
    final name = prefs.getString('user_name') ?? '';

    if (token != null && userId != null && email.isNotEmpty) {
      _user = User(id: userId, email: email, name: name, token: token);
      _isLoggedIn = true;
      notifyListeners();
      // Load cart after successful auto-login
      await _cartProvider.loadCart();
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

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      await prefs.setInt('user_id', userId);
      await prefs.setString('user_email', userEmail);
      await prefs.setString('user_name', name);

      _isLoading = false;
      notifyListeners();

      // Merge guest cart with user cart after successful login
      await _cartProvider.mergeCart(_cartProvider.items);
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

  Future<void> logout() async {
    _user = null;
    _isLoggedIn = false;
    _error = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_id');
    await prefs.remove('user_email');
    await prefs.remove('user_name');

    notifyListeners();
    // Clear cart after logout
    await _cartProvider.clearCart();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
