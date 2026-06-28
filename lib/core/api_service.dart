import 'package:dio/dio.dart';
import 'constants.dart';

class ApiService {
  final Dio _dio = Dio();
  final Dio _wpDio = Dio();

  ApiService() {
    _dio.options.baseUrl = baseUrl;
    _dio.options.queryParameters = {
      'consumer_key': consumerKey,
      'consumer_secret': consumerSecret,
    };

    _wpDio.options.baseUrl = wpBaseUrl;
  }

  Future<List<dynamic>> getProducts({int page = 1, int perPage = 20, String? category}) async {
    final response = await _dio.get('products', queryParameters: {
      'page': page,
      'per_page': perPage,
      if (category != null) 'category': category,
    });
    return response.data;
  }

  Future<List<dynamic>> getCategories() async {
    final response = await _dio.get('products/categories');
    return response.data;
  }

  Future<Map<String, dynamic>> registerCustomer({
    required String email,
    required String password,
    required String firstName,
    String? lastName,
    String? phone,
  }) async {
    final response = await _dio.post(
      'customers',
      data: {
        'email': email,
        'password': password,
        'first_name': firstName,
        if (lastName != null) 'last_name': lastName,
        if (phone != null)
          'billing': {
            'phone': phone,
          },
      },
    );
    return response.data;
  }

  Future<Map<String, dynamic>> loginWithJwt({
    required String username,
    required String password,
  }) async {
    final response = await _wpDio.post(
      'jwt-auth/v1/token',
      data: {
        'username': username,
        'password': password,
      },
    );
    return response.data;
  }

  Future<Map<String, dynamic>?> getCustomerByEmail(String email) async {
    final response = await _dio.get(
      'customers',
      queryParameters: {'email': email},
    );
    final list = response.data as List;
    if (list.isNotEmpty) {
      return list.first as Map<String, dynamic>;
    }
    return null;
  }

  Future<Map<String, dynamic>> getCustomer(int customerId) async {
    final response = await _dio.get('customers/$customerId');
    return response.data;
  }
}
