import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';
import '../models/address.dart';

/// Minimal in-memory cookie store shared by every [ApiService] instance.
///
/// The custom cart endpoint falls back to WooCommerce's native session-based
/// cart (`WC()->cart`) for guests, which is only kept alive via the
/// `woocommerce_cart_hash`/PHP session cookie set by the server. Without
/// resending that cookie on every request, each call starts a brand-new
/// anonymous session and the guest cart appears empty right after adding
/// an item.
class _CookieStore {
  static final Map<String, String> _cookies = {};

  static void saveFromHeaders(Headers headers) {
    final setCookies = headers['set-cookie'];
    if (setCookies == null) return;

    for (final raw in setCookies) {
      final firstPair = raw.split(';').first;
      final separatorIndex = firstPair.indexOf('=');
      if (separatorIndex <= 0) continue;

      final name = firstPair.substring(0, separatorIndex).trim();
      final value = firstPair.substring(separatorIndex + 1).trim();
      if (name.isNotEmpty) {
        _cookies[name] = value;
      }
    }
  }

  static String? get header {
    if (_cookies.isEmpty) return null;
    return _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  static void clear() => _cookies.clear();
}

class ApiService {
  // Every screen/provider previously did `final _api = ApiService()`,
  // each constructing its own Dio and paying a fresh TLS handshake per
  // screen instead of reusing a keep-alive connection to the same host.
  // A factory constructor makes every existing call site a singleton
  // with no changes needed anywhere else.
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  final Dio _dio = Dio();
  final Dio _wpDio = Dio();

  ApiService._internal() {
    _dio.options.baseUrl = baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);

    _wpDio.options.baseUrl = wpBaseUrl;
    _wpDio.options.connectTimeout = const Duration(seconds: 30);
    _wpDio.options.receiveTimeout = const Duration(seconds: 30);

    for (final dio in [_dio, _wpDio]) {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final cookieHeader = _CookieStore.header;
            if (cookieHeader != null) {
              options.headers['Cookie'] = cookieHeader;
            }
            handler.next(options);
          },
          onResponse: (response, handler) {
            _CookieStore.saveFromHeaders(response.headers);
            handler.next(response);
          },
          onError: (error, handler) {
            final headers = error.response?.headers;
            if (headers != null) {
              _CookieStore.saveFromHeaders(headers);
            }
            handler.next(error);
          },
        ),
      );
    }
  }

  Future<List<dynamic>> getProducts({
    int page = 1,
    int perPage = 20,
    String? category,
    String? currency,
  }) async {
    final Map<String, dynamic> queryParams = {
      'page': page,
      'per_page': perPage,
      'currency': ?currency,
    };
    if (category != null && category.isNotEmpty) {
      queryParams['category'] = int.tryParse(category) ?? category;
    }
    final response = await _dio.get('products', queryParameters: queryParams);
    return response.data is List ? List.from(response.data) : <dynamic>[];
  }

  Future<List<dynamic>> getFeaturedProducts({String? currency}) async {
    final response = await _dio.get(
      'featured-products',
      queryParameters: {'currency': ?currency},
    );
    return response.data is List ? List.from(response.data) : <dynamic>[];
  }

  Future<List<dynamic>> getNewArrivals({String? currency}) async {
    final response = await _dio.get(
      'new-arrivals',
      queryParameters: {'currency': ?currency},
    );
    return response.data is List ? List.from(response.data) : <dynamic>[];
  }

  Future<List<dynamic>> getSaleProducts({String? currency}) async {
    final response = await _dio.get(
      'sale-products',
      queryParameters: {'currency': ?currency},
    );
    return response.data is List ? List.from(response.data) : <dynamic>[];
  }

  Future<List<dynamic>> getBestSellers({String? currency}) async {
    final response = await _dio.get(
      'best-sellers',
      queryParameters: {'currency': ?currency},
    );
    return response.data is List ? List.from(response.data) : <dynamic>[];
  }

  Future<List<dynamic>> searchProducts(
    String query, {
    String? currency,
    String? category,
  }) async {
    final response = await _dio.get(
      'search',
      queryParameters: {
        'q': query,
        'currency': ?currency,
        if (category != null && category.isNotEmpty) 'category': category,
      },
    );
    return response.data is List ? List.from(response.data) : <dynamic>[];
  }

  // "uncategorized"/"غير مصنف" is WooCommerce's default catch-all category,
  // not a real merchandising category. The rest are hidden from the app for
  // now too. Matched by slug where the site gives one; "بطاقات اشتراك تطبيق
  // البراق" only has a percent-encoded Arabic slug, so it's matched by name
  // instead.
  static const _hiddenCategorySlugs = {'uncategorized', 'english-books', 'pdf','all-books',};
  static const _hiddenCategoryNames = {'بطاقات اشتراك تطبيق البراق','العروض والمفاجآت'};

  // Fixed display order for the app's real merchandising categories.
  // Anything not listed here (none currently, but a new WooCommerce
  // category would fall in this bucket) sorts after these, in whatever
  // order the API returned it.
  static const _categoryOrder = [
    'collections',
    'picture-books',
    'educational',
    'religious',
    'heritage-books',
    'skills-development',
    'intellectual-game',
  ];

  // The site's own category thumbnails (get_categories()'s "image" field)
  // are unset for all of these -- every one comes back null -- so the app
  // supplies its own curated image per category instead of showing the
  // fallback icon everywhere.
  static const _categoryImages = {
    'collections':
        'https://alburagh.com/wp-content/uploads/2026/08/catagory1.png',
    'picture-books':
        'https://alburagh.com/wp-content/uploads/2026/08/catagory2.png',
    'educational':
        'https://alburagh.com/wp-content/uploads/2026/08/catagory3.png',
    'religious':
        'https://alburagh.com/wp-content/uploads/2026/08/catagory4.png',
    'heritage-books':
        'https://alburagh.com/wp-content/uploads/2026/08/catagory5.png',
    'skills-development':
        'https://alburagh.com/wp-content/uploads/2026/08/catagory6.png',
    'intellectual-game':
        'https://alburagh.com/wp-content/uploads/2026/08/catagory7.png',
  };

  Future<List<dynamic>> getCategories() async {
    final response = await _dio.get('categories');
    final categories = response.data is List
        ? List<dynamic>.from(response.data)
        : <dynamic>[];

    final visible = categories
        .where((c) {
          final map = c as Map;
          final slug = map['slug']?.toString().toLowerCase();
          final name = map['name']?.toString();
          return !_hiddenCategorySlugs.contains(slug) &&
              !_hiddenCategoryNames.contains(name);
        })
        .map((c) {
          final map = Map<String, dynamic>.from(c as Map);
          final image = _categoryImages[map['slug']?.toString().toLowerCase()];
          if (image != null) {
            map['image'] = image;
          }
          return map;
        })
        .toList();

    visible.sort((a, b) {
      final aRank = _categoryOrder.indexOf(
        a['slug']?.toString().toLowerCase() ?? '',
      );
      final bRank = _categoryOrder.indexOf(
        b['slug']?.toString().toLowerCase() ?? '',
      );
      return (aRank == -1 ? _categoryOrder.length : aRank).compareTo(
        bRank == -1 ? _categoryOrder.length : bRank,
      );
    });

    return visible;
  }

  Future<Map<String, dynamic>> registerCustomer({
    required String email,
    required String password,
    required String firstName,
    String? lastName,
    String? phone,
  }) async {
    final response = await _dio.post(
      'register',
      data: {
        'username': email,
        'email': email,
        'password': password,
        'first_name': firstName,
        ...?lastName == null ? null : {'last_name': lastName},
        ...?phone == null ? null : {'phone': phone},
      },
    );
    return response.data is Map
        ? Map<String, dynamic>.from(response.data)
        : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    final response = await _dio.post('forgot-password', data: {'email': email});
    return response.data is Map
        ? Map<String, dynamic>.from(response.data)
        : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> loginWithJwt({
    required String username,
    required String password,
  }) async {
    final response = await _wpDio.post(
      'jwt-auth/v1/token',
      data: {'username': username, 'password': password},
    );
    return response.data is Map
        ? Map<String, dynamic>.from(response.data)
        : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> loginWithAlburaghApi({
    required String username,
    required String password,
  }) async {
    final response = await _dio.post(
      'login',
      data: {'username': username, 'password': password},
    );
    return response.data is Map
        ? Map<String, dynamic>.from(response.data)
        : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getProfile(String token) async {
    final response = await _dio.get(
      'profile',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return response.data is Map
        ? Map<String, dynamic>.from(response.data)
        : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> updateProfile(
    String token,
    Map<String, dynamic> data,
  ) async {
    final response = await _dio.put(
      'profile',
      data: data,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return response.data is Map
        ? Map<String, dynamic>.from(response.data)
        : <String, dynamic>{};
  }

  /// Requests a short-lived, single-use login link so the customer can be
  /// sent to [redirectTo] on the real website already logged in there,
  /// instead of having to sign in a second time in the browser.
  Future<String?> createAutoLoginLink({
    required String token,
    required String redirectTo,
  }) async {
    final response = await _dio.post(
      'auto-login-link',
      data: {'redirect_to': redirectTo},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return response.data is Map ? response.data['url'] as String? : null;
  }

  /// Drops the WooCommerce session cookie so the next request starts a
  /// brand-new anonymous session instead of reusing whatever account the
  /// cookie's customer_id was last tied to. Call this around login/logout
  /// so a stale cookie can't leak one account's cart into another
  /// session -- see _CookieStore's doc comment for why the cookie exists
  /// and gets tied to a specific customer_id in the first place.
  void resetSession() => _CookieStore.clear();

  Future<Options?> _authOptions() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null || token.isEmpty) {
      return null;
    }

    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<Map<String, dynamic>> getCart({String? currency}) async {
    try {
      final response = await _dio.get(
        'cart',
        queryParameters: {'currency': ?currency},
        options: await _authOptions(),
      );
      return response.data is Map
          ? Map<String, dynamic>.from(response.data)
          : <String, dynamic>{};
    } on DioException catch (e) {
      // The custom cart endpoint can return HTTP 500 when there is no valid
      // server-side cart/session yet. Treat that case as an empty cart so the
      // app remains usable instead of showing Dio's raw technical error.
      if (e.response?.statusCode == 500) {
        return {'items': <dynamic>[]};
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> addToCart({
    required int productId,
    int quantity = 1,
    String? currency,
  }) async {
    final response = await _dio.post(
      'cart',
      data: {'product_id': productId, 'quantity': quantity},
      queryParameters: {'currency': ?currency},
      options: await _authOptions(),
    );
    return response.data is Map
        ? Map<String, dynamic>.from(response.data)
        : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> updateCart({
    required String cartItemKey,
    required int quantity,
    String? currency,
  }) async {
    final response = await _dio.put(
      'cart',
      data: {'cart_item_key': cartItemKey, 'quantity': quantity},
      queryParameters: {'currency': ?currency},
      options: await _authOptions(),
    );
    return response.data is Map
        ? Map<String, dynamic>.from(response.data)
        : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> clearCart({String? currency}) async {
    final response = await _dio.delete(
      'cart',
      queryParameters: {'currency': ?currency},
      options: await _authOptions(),
    );
    return response.data is Map
        ? Map<String, dynamic>.from(response.data)
        : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getWishlist({String? currency}) async {
    try {
      final response = await _dio.get(
        'wishlist',
        queryParameters: {'currency': ?currency},
        options: await _authOptions(),
      );
      return response.data is Map
          ? Map<String, dynamic>.from(response.data)
          : <String, dynamic>{};
    } on DioException catch (e) {
      if (e.response?.statusCode == 500) {
        return {'items': <dynamic>[]};
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> addToWishlist({
    required int productId,
    String? currency,
  }) async {
    final response = await _dio.post(
      'wishlist',
      data: {'product_id': productId},
      queryParameters: {'currency': ?currency},
      options: await _authOptions(),
    );
    return response.data is Map
        ? Map<String, dynamic>.from(response.data)
        : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> removeFromWishlist({
    required int productId,
    String? currency,
  }) async {
    final response = await _dio.delete(
      'wishlist',
      data: {'product_id': productId},
      queryParameters: {'currency': ?currency},
      options: await _authOptions(),
    );
    return response.data is Map
        ? Map<String, dynamic>.from(response.data)
        : <String, dynamic>{};
  }

  Future<List<dynamic>> getReviews({required int productId}) async {
    final response = await _dio.get(
      'reviews',
      queryParameters: {'product_id': productId},
    );
    return response.data is List ? List.from(response.data) : <dynamic>[];
  }

  Future<Map<String, dynamic>> addReview({
    required int productId,
    required int rating,
    required String review,
    String? author,
    String? email,
  }) async {
    final response = await _dio.post(
      'reviews',
      data: {
        'product_id': productId,
        'rating': rating,
        'review': review,
        if (author != null && author.isNotEmpty) 'author': author,
        if (email != null && email.isNotEmpty) 'email': email,
      },
    );
    return response.data is Map
        ? Map<String, dynamic>.from(response.data)
        : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> validateCoupon(String couponCode) async {
    final response = await _dio.post(
      'validate-coupon',
      data: {'coupon_code': couponCode},
    );
    return response.data is Map
        ? Map<String, dynamic>.from(response.data)
        : <String, dynamic>{};
  }

  Future<List<Address>> getAddresses(String token) async {
    final response = await _dio.get(
      'addresses',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return (response.data as List).map((e) => Address.fromJson(e)).toList();
  }

  Future<void> saveAddress(String token, Address address) async {
    await _dio.post(
      'addresses',
      data: address.toJson(),
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  Future<List<dynamic>> getOrders(String token) async {
    final response = await _dio.get(
      'orders',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return response.data is List ? List.from(response.data) : <dynamic>[];
  }

  Future<Map<String, dynamic>> getOrderDetails(
    String token,
    int orderId,
  ) async {
    final response = await _dio.get(
      'orders/$orderId',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return response.data is Map
        ? Map<String, dynamic>.from(response.data)
        : <String, dynamic>{};
  }

  Future<Map<String, dynamic>?> getCustomerByEmail(String email) async {
    return null;
  }

  Future<Map<String, dynamic>> getCustomer(int customerId) async {
    return {'id': customerId, 'first_name': '', 'last_name': ''};
  }
}
