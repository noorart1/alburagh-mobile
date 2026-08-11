import 'package:flutter/material.dart';
import '../core/api_service.dart';
import '../core/error_messages.dart';
import '../models/product.dart';

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

  // Bumped on every loadWishlist() call so a slow, stale request (e.g. one
  // still in flight for the previous account at logout/login time) can tell
  // it's no longer the latest and skip applying its response -- otherwise an
  // out-of-order response can land after a newer account's own (correct)
  // load and silently overwrite it with the wrong account's items.
  int _requestId = 0;

  void setCurrency(String currency) {
    if (_currency == currency) return;
    _currency = currency;
    loadWishlist();
  }

  Future<void> loadWishlist() async {
    final requestId = ++_requestId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _apiService.getWishlist(currency: _currency);
      if (requestId != _requestId) return;

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
      if (requestId != _requestId) return;
      _isLoading = false;
      _error = friendlyErrorMessage(e, fallback: 'تعذر تحميل المفضلة، حاول مرة أخرى');
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
    final requestId = _requestId;

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
      // If logout/loadWishlist has moved on to a new account since this
      // call started, this rollback belongs to the account that's no
      // longer current -- applying it would mutate the new account's list.
      if (requestId != _requestId) return false;
      _items.removeWhere((p) => p.id == product.id);
      _error = friendlyErrorMessage(
        e,
        fallback: 'تعذر إضافة المنتج إلى المفضلة، حاول مرة أخرى',
      );
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeFromWishlist(Product product) async {
    final requestId = _requestId;
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
      // See addToWishlist -- don't re-add items removed for an account
      // that's no longer the current one.
      if (requestId != _requestId) return false;
      _items.addAll(removed);
      _error = friendlyErrorMessage(
        e,
        fallback: 'تعذر إزالة المنتج من المفضلة، حاول مرة أخرى',
      );
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
    _requestId++;
    _items.clear();
    _error = null;
    notifyListeners();
  }
}
