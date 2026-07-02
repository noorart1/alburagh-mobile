import 'package:dio/dio.dart';
import 'constants.dart';

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

  Future<Map<String, dynamic>?> getCustomerByEmail(String email) async {
    return null;
  }

  Future<Map<String, dynamic>> getCustomer(int customerId) async {
    return {'id': customerId, 'first_name': '', 'last_name': ''};
  }
}
