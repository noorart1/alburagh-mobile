import 'package:flutter/material.dart';
import '../core/api_service.dart';
import '../models/product.dart';

class CartItem {
  final String key;
  final Product product;
  final int quantity;

  const CartItem({
    required this.key,
    required this.product,
    required this.quantity,
  });

  CartItem copyWith({String? key, Product? product, int? quantity}) {
    return CartItem(
      key: key ?? this.key,
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }
}

class CartProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final List<CartItem> _items = [];
  bool _isLoading = false;
  String? _error;
  double? _serverTotal;
  double? _serverSubtotal;
  String _currency = 'USD';
  String _currencySymbol = '\$';

  List<CartItem> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get currencySymbol => _currencySymbol;

  /// Called whenever the user's manual IQD/USD choice changes, so every
  /// subsequent cart call asks the backend to convert to that currency.
  void setCurrency(String currency) {
    if (_currency == currency) return;
    _currency = currency;
    loadCart();
  }

  int get itemCount => _items.fold<int>(0, (sum, item) => sum + item.quantity);

  double get subtotalPrice {
    return _items.fold<double>(
      0,
      (sum, item) => sum + _priceOf(item.product) * item.quantity,
    );
  }

  double get totalPrice => _serverTotal ?? subtotalPrice;

  double get subtotal => _serverSubtotal ?? subtotalPrice;

  double _priceOf(Product product) {
    return double.tryParse(product.price) ??
        double.tryParse(product.regularPrice) ??
        0;
  }

  Future<void> loadCart() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final cartData = await _apiService.getCart(currency: _currency);
      final items = cartData['items'] as List<dynamic>? ?? [];
      _serverTotal = double.tryParse(cartData['total']?.toString() ?? '');
      _serverSubtotal = double.tryParse(cartData['subtotal']?.toString() ?? '');
      _currencySymbol = cartData['currency_symbol']?.toString() ?? '\$';
      _items.clear();

      for (final item in items) {
        if (item is! Map) continue;

        final rawProduct = item['product'] ?? item;
        final qty = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
        final key = item['key']?.toString() ?? '';

        if (rawProduct is Map<String, dynamic>) {
          _items.add(
            CartItem(
              key: key,
              product: Product.fromJson(rawProduct),
              quantity: qty < 1 ? 1 : qty,
            ),
          );
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

  CartItem? _findCartItemByProduct(Product product) {
    for (final item in _items) {
      if (item.product.id == product.id) return item;
    }
    return null;
  }

  Future<bool> addToCart(Product product, {int quantity = 1}) async {
    try {
      _error = null;
      await _apiService.addToCart(
        productId: product.id,
        quantity: quantity,
        currency: _currency,
      );
      await loadCart();
      return true;
    } catch (e) {
      _error = 'فشل إضافة المنتج للسلة: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> mergeCart(List<CartItem> guestItems) async {
    try {
      for (final item in guestItems) {
        await _apiService.addToCart(
          productId: item.product.id,
          quantity: item.quantity,
          currency: _currency,
        );
      }
      await loadCart();
    } catch (e) {
      debugPrint('Error merging cart: $e');
    }
  }

  Future<bool> removeFromCart(Product product) async {
    try {
      _error = null;
      final cartItem = _findCartItemByProduct(product);

      if (cartItem == null) return false;

      _isLoading = true;
      notifyListeners();

      await _apiService.updateCart(
        cartItemKey: cartItem.key,
        quantity: 0,
        currency: _currency,
      );
      await loadCart();
      return true;
    } catch (e) {
      _isLoading = false;
      _error = 'فشل إزالة المنتج من السلة: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateQuantity(Product product, int quantity) async {
    try {
      _error = null;
      final cartItem = _findCartItemByProduct(product);

      if (cartItem == null) return false;

      if (quantity <= 0) {
        return removeFromCart(product);
      }

      _isLoading = true;
      notifyListeners();

      await _apiService.updateCart(
        cartItemKey: cartItem.key,
        quantity: quantity,
        currency: _currency,
      );
      await loadCart();
      return true;
    } catch (e) {
      _isLoading = false;
      _error = 'فشل تحديث الكمية: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> clearCart() async {
    try {
      _error = null;
      _isLoading = true;
      notifyListeners();

      await _apiService.clearCart(currency: _currency);
      _items.clear();
      _serverTotal = 0;
      _serverSubtotal = 0;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = 'فشل تفريغ السلة: $e';
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
