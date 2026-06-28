import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_service.dart';
import '../models/user.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  User? _user;
  bool _isLoggedIn = false;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String? get error => _error;

  AuthProvider() {
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
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.loginWithJwt(
        username: email,
        password: password,
      );

      final token = response['token'] as String?;
      final userId = response['user_id'] as int?;

      if (token == null || userId == null) {
        _error = 'فشل تسجيل الدخول';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final customer = await _api.getCustomer(userId);
      final name = (customer['first_name'] ?? '').toString().isNotEmpty
          ? customer['first_name']
          : response['user_display_name'] ?? email.split('@')[0];

      _user = User(
        id: userId,
        email: email,
        name: name,
        token: token,
      );
      _isLoggedIn = true;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      await prefs.setInt('user_id', userId);
      await prefs.setString('user_email', email);
      await prefs.setString('user_name', name);

      _isLoading = false;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        _error = 'اسم المستخدم أو كلمة المرور غير صحيحة';
      } else if (e.response?.statusCode == 404) {
        _error = 'خدمة تسجيل الدخول غير متاحة. تأكد من تفعيل إضافة JWT Authentication';
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

      return await login(email, password);
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
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
