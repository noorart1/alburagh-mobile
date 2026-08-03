import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manual IQD/USD switch. The website's Multi Currency plugin picks this
/// automatically via GeoIP, which the app has no equivalent for — so this is
/// a persisted, user-controlled choice instead (see Profile screen).
class CurrencyProvider with ChangeNotifier {
  static const _prefKey = 'selected_currency';

  String _currency;

  CurrencyProvider({String initialCurrency = 'USD'})
    : _currency = initialCurrency;

  String get currency => _currency;
  bool get isIqd => _currency == 'IQD';
  String get symbol => _currency == 'IQD' ? 'د.ع' : '\$';

  static Future<String> loadInitial() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKey) ?? 'USD';
  }

  Future<void> setCurrency(String currency) async {
    if (_currency == currency) return;
    _currency = currency;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, currency);
  }
}
