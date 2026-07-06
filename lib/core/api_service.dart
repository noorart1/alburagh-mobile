import 'package:dio/dio.dart';
import 'constants.dart';
import '../models/address.dart';

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
  }

  Future<List<dynamic>> getProducts({
    int page = 1,
    int perPage = 20,
    String? category,
  }) async {
    final response = await _dio.get(
      'products',
      queryParameters: {
        'page': page,
        'per_page': perPage,
        ...?category == null ? null : {'category': category},
      },
    );
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

  Future<Map<String, dynamic>> checkoutOrder({
    required List<Map<String, dynamic>> cartItems,
    required Map<String, dynamic> billingAddress,
    required Map<String, dynamic> shippingAddress,
    required String paymentMethod,
    required String paymentMethodTitle,
  }) async {
    final response = await _dio.post(
      'checkout',
      data: {
        'billing_address': billingAddress,
        'shipping_address': shippingAddress,
        'cart_items': cartItems,
        'payment_method': paymentMethod,
        'payment_method_title': paymentMethodTitle,
      },
    );
    return response.data is Map
        ? Map<String, dynamic>.from(response.data)
        : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getCart() async {
    final response = await _dio.get('cart');
    return response.data is Map
        ? Map<String, dynamic>.from(response.data)
        : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> addToCart({
    required int productId,
    int quantity = 1,
  }) async {
    final response = await _dio.post(
      'cart',
      data: {'product_id': productId, 'quantity': quantity},
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
    );
    return response.data is Map
        ? Map<String, dynamic>.from(response.data)
        : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> clearCart() async {
    final response = await _dio.delete('cart');
    return response.data is Map
        ? Map<String, dynamic>.from(response.data)
        : <String, dynamic>{};
  }

  Future<List<dynamic>> getReviews({required int productId}) async {
    final response = await _dio.get('reviews', queryParameters: {'product_id': productId});
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

  Future<Map<String, dynamic>> getOrderDetails(String token, int orderId) async {
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