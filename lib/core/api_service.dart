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
}

class ApiService {
  final Dio _dio = Dio();
  final Dio _wpDio = Dio();

  ApiService() {
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
  }) async {
    final Map<String, dynamic> queryParams = {
      'page': page,
      'per_page': perPage,
    };
    if (category != null && category.isNotEmpty) {
      queryParams['category'] = int.tryParse(category) ?? category;
    }
    final response = await _dio.get('products', queryParameters: queryParams);
    return response.data is List ? List.from(response.data) : <dynamic>[];
  }

  Future<List<dynamic>> getFeaturedProducts() async {
    final response = await _dio.get('featured-products');
    return response.data is List ? List.from(response.data) : <dynamic>[];
  }

  Future<List<dynamic>> getNewArrivals() async {
    final response = await _dio.get('new-arrivals');
    return response.data is List ? List.from(response.data) : <dynamic>[];
  }

  Future<List<dynamic>> getSaleProducts() async {
    final response = await _dio.get('sale-products');
    return response.data is List ? List.from(response.data) : <dynamic>[];
  }

  Future<List<dynamic>> searchProducts(String query) async {
    final response = await _dio.get('search', queryParameters: {'q': query});
    return response.data is List ? List.from(response.data) : <dynamic>[];
  }

  Future<List<dynamic>> getCategories() async {
    final response = await _dio.get('categories');
    return response.data is List ? List.from(response.data) : <dynamic>[];
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

  Future<Options?> _authOptions() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null || token.isEmpty) {
      return null;
    }

    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<Map<String, dynamic>> getCart() async {
    try {
      final response = await _dio.get('cart', options: await _authOptions());
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
  }) async {
    final response = await _dio.post(
      'cart',
      data: {'product_id': productId, 'quantity': quantity},
      options: await _authOptions(),
    );
    return response.data is Map
        ? Map<String, dynamic>.from(response.data)
        : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> updateCart({
    required String cartItemKey,
    required int quantity,
  }) async {
    final response = await _dio.put(
      'cart',
      data: {'cart_item_key': cartItemKey, 'quantity': quantity},
      options: await _authOptions(),
    );
    return response.data is Map
        ? Map<String, dynamic>.from(response.data)
        : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> clearCart() async {
    final response = await _dio.delete('cart', options: await _authOptions());
    return response.data is Map
        ? Map<String, dynamic>.from(response.data)
        : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getWishlist() async {
    try {
      final response = await _dio.get(
        'wishlist',
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

  Future<Map<String, dynamic>> addToWishlist({required int productId}) async {
    final response = await _dio.post(
      'wishlist',
      data: {'product_id': productId},
      options: await _authOptions(),
    );
    return response.data is Map
        ? Map<String, dynamic>.from(response.data)
        : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> removeFromWishlist({
    required int productId,
  }) async {
    final response = await _dio.delete(
      'wishlist',
      data: {'product_id': productId},
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
