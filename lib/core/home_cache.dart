import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// On-device cache for HomeScreen's own sections (categories, banners, and
/// each product row), so a reopened app can show the last-known content
/// immediately instead of a blank/loading screen while the network catches
/// up. Stores the raw JSON lists exactly as ApiService returns them (no
/// model round-trip needed -- HomeScreen already parses them via
/// Category.fromJson/Product.fromJson the same way whether the list came
/// from cache or a fresh network response).
class HomeCache {
  HomeCache._();

  static const categoriesKey = 'home_cache_categories';
  static const bannersKey = 'home_cache_banners';

  static String productsKey(String section) => 'home_cache_products_$section';

  static Future<List<dynamic>?> readList(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return null;

    try {
      final decoded = jsonDecode(raw);
      return decoded is List ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> writeList(String key, List<dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(data));
  }
}
