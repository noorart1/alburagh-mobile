class CurrencyUtils {
  CurrencyUtils._();

  static String formatAmount(num rawAmount) {
    if (rawAmount == rawAmount.roundToDouble()) {
      return rawAmount.toInt().toString();
    }
    return rawAmount.toStringAsFixed(2);
  }

  /// IQD amounts are always whole numbers in everyday use (no fils in
  /// practice) and are conventionally grouped by thousands, e.g. "10,000".
  static String _formatDinarAmount(num rawAmount) {
    final digits = rawAmount.round().abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return rawAmount < 0 ? '-$buffer' : buffer.toString();
  }

  /// Formats [rawAmount] with [symbol] using the right convention for each
  /// currency: "$8.13" for USD (symbol first), "10,000 د.ع" for IQD (symbol
  /// last and thousands-grouped with no decimals, matching how the amount is
  /// normally written in Arabic).
  static String format(num rawAmount, String symbol) {
    if (symbol == '\$') return '\$${formatAmount(rawAmount)}';
    return '${_formatDinarAmount(rawAmount)} $symbol';
  }

  static String formatString(String rawAmount, String symbol) {
    return format(double.tryParse(rawAmount) ?? 0, symbol);
  }

  /// Maps a WooCommerce currency code (e.g. from an order's own
  /// get_currency(), which may differ from the app's currently selected
  /// display currency) to the symbol format() expects.
  static String symbolForCode(String code) {
    return code.toUpperCase() == 'IQD' ? 'د.ع' : '\$';
  }
}
