import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../core/api_service.dart';
import '../models/product.dart';

String _describe(Object e) {
  if (e is DioException) {
    final status = e.response?.statusCode;
    if (status != null) return 'خطأ من الخادم ($status)';
    return 'تعذر الاتصال بالخادم';
  }
  return e.toString();
}

class WishlistProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final List<Product> _items = [];
  bool _isLoading = false;
  String? _error;
  String _currency = 'USD';

  List<Product> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get itemCount => _items.length;

  bool isWishlisted(int productId) => _items.any((p) => p.id == productId);

  void setCurrency(String currency) {
    if (_currency == currency) return;
    _currency = currency;
    loadWishlist();
  }

  Future<void> loadWishlist() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _apiService.getWishlist(currency: _currency);
      final rawItems = data['items'] as List<dynamic>? ?? [];
      _items.clear();

      for (final item in rawItems) {
        final rawProduct = item is Map ? (item['product'] ?? item) : item;
        if (rawProduct is Map<String, dynamic>) {
          _items.add(Product.fromJson(rawProduct));
        }
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = 'فشل تحميل المفضلة: ${_describe(e)}';
      notifyListeners();
    }
  }

  Future<bool> toggle(Product product) {
    if (isWishlisted(product.id)) {
      return removeFromWishlist(product);
    }
    return addToWishlist(product);
  }

  Future<bool> addToWishlist(Product product) async {
    try {
      _error = null;
      _items.add(product);
      notifyListeners();
      await _apiService.addToWishlist(
        productId: product.id,
        currency: _currency,
      );
      return true;
    } catch (e) {
      _items.removeWhere((p) => p.id == product.id);
      _error = 'فشل إضافة المنتج إلى المفضلة: ${_describe(e)}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeFromWishlist(Product product) async {
    final removed = _items.where((p) => p.id == product.id).toList();

    try {
      _error = null;
      _items.removeWhere((p) => p.id == product.id);
      notifyListeners();
      await _apiService.removeFromWishlist(
        productId: product.id,
        currency: _currency,
      );
      return true;
    } catch (e) {
      _items.addAll(removed);
      _error = 'فشل إزالة المنتج من المفضلة: ${_describe(e)}';
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Drops the locally cached wishlist without touching the server copy.
  /// Called on logout so the previous account's items (and the bottom bar
  /// badge count) don't keep showing while logged out or after switching
  /// accounts — unlike the cart, the wishlist itself is never deleted.
  void reset() {
    _items.clear();
    _error = null;
    notifyListeners();
  }
}
