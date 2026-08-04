import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';

/// Tracks products the user has opened recently, purely on-device (no
/// account or server round trip needed) so the home screen can offer a
/// quick way back to something they were looking at. Capped at
/// [_maxItems], most-recently-viewed first.
class RecentlyViewedProvider extends ChangeNotifier {
  static const _prefsKey = 'recently_viewed_products';
  static const _maxItems = 15;

  List<Product> _items = [];
  List<Product> get items => List.unmodifiable(_items);

  // Resolves once the persisted list has been restored. recordView() awaits
  // this before touching _items, otherwise a product viewed right after app
  // start could race _load() -- if _load() finishes after recordView() adds
  // an item, it would overwrite _items with the older persisted snapshot
  // and silently erase the item just viewed.
  late final Future<void> _ready;

  RecentlyViewedProvider() {
    _ready = _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? [];
    _items = raw
        .map((entry) {
          try {
            return Product.fromJson(
              jsonDecode(entry) as Map<String, dynamic>,
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<Product>()
        .toList();
    notifyListeners();
  }

  Future<void> recordView(Product product) async {
    await _ready;
    _items.removeWhere((p) => p.id == product.id);
    _items.insert(0, product);
    if (_items.length > _maxItems) {
      _items = _items.sublist(0, _maxItems);
    }
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _prefsKey,
      _items.map((p) => jsonEncode(p.toJson())).toList(),
    );
  }
}
