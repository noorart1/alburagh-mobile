import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_service.dart';

/// IQD for Iraq, USD everywhere else — auto-detected server-side via IP
/// geolocation ([ApiService.detectCurrency], the same GeoIP data the
/// website's own Multi Currency plugin uses), with no user-facing switcher.
/// [initialCurrency] is only the last-known/persisted value shown for the
/// instant before that detection call resolves (or if it fails offline).
class CurrencyProvider with ChangeNotifier {
  static const _prefKey = 'selected_currency';

  String _currency;

  CurrencyProvider({String initialCurrency = 'USD'})
    : _currency = initialCurrency {
    unawaited(_autoDetect());
  }

  String get currency => _currency;
  bool get isIqd => _currency == 'IQD';
  String get symbol => _currency == 'IQD' ? 'د.ع' : '\$';

  static Future<String> loadInitial() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKey) ?? 'USD';
  }

  Future<void> _autoDetect() async {
    try {
      final detected = await ApiService().detectCurrency();
      if (detected == 'USD' || detected == 'IQD') {
        await setCurrency(detected!);
      }
    } catch (_) {
      // Offline or the endpoint failed -- keep the last-known/persisted
      // currency rather than resetting to USD.
    }
  }

  Future<void> setCurrency(String currency) async {
    if (_currency == currency) return;
    _currency = currency;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, currency);
  }
}
