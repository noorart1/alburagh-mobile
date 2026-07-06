import 'package:flutter/material.dart';
import '../models/product.dart';
import '../core/api_service.dart';

class CartProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final List<Product> _items = [];
  bool _isLoading = false;
  String? _error;

  List<Product> get items => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;

  double get totalPrice {
    return _items.fold(0, (sum, item) => sum + double.parse(item.price));
  }

  Future<void> loadCart() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final cartData = await _apiService.getCart();
      final items = cartData['items'] as List<dynamic>? ?? [];
      _items.clear();
      for (final item in items) {
        final productData = item['product'] ?? item;
        final qty = int.tryParse(item['quantity']?.toString() ?? '') ?? 1;
        if (productData is Map<String, dynamic>) {
          final product = Product.fromJson(productData);
          for (int i = 0; i < qty; i++) {
            _items.add(product);
          }
        }
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = 'فشل تحميل السلة: $e';
      notifyListeners();
    }
  }

  Future<bool> addToCart(Product product, {int quantity = 1}) async {
    try {
      await _apiService.addToCart(productId: product.id, quantity: quantity);
      await loadCart();
      return true;
    } catch (e) {
      _error = 'فشل إضافة المنتج للسلة: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeFromCart(Product product) async {
    try {
      await loadCart();
      final cartData = await _apiService.getCart();
      final items = cartData['items'] as List<dynamic>? ?? [];
      for (final item in items) {
        if (item['product_id'] == product.id) {
          await _apiService.updateCart(cartItemKey: item['key'], quantity: 0);
          await loadCart();
          return true;
        }
      }
      return false;
    } catch (e) {
      _error = 'فشل إزالة المنتج من السلة: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateQuantity(Product product, int quantity) async {
    try {
      await loadCart();
      final cartData = await _apiService.getCart();
      final items = cartData['items'] as List<dynamic>? ?? [];
      for (final item in items) {
        if (item['product_id'] == product.id) {
          await _apiService.updateCart(cartItemKey: item['key'], quantity: quantity);
          await loadCart();
          return true;
        }
      }
      return false;
    } catch (e) {
      _error = 'فشل تحديث الكمية: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> clearCart() async {
    try {
      await _apiService.clearCart();
      _items.clear();
      notifyListeners();
    } catch (e) {
      _error = 'فشل تفريغ السلة: $e';
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}