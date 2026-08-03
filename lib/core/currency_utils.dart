class CurrencyUtils {
  CurrencyUtils._();

  static String formatAmount(num rawAmount) {
    if (rawAmount == rawAmount.roundToDouble()) {
      return rawAmount.toInt().toString();
    }
    return rawAmount.toStringAsFixed(2);
  }

  /// Formats [rawAmount] with [symbol] using the right convention for each
  /// currency: "$8.13" for USD (symbol first), "12000 د.ع" for IQD (symbol
  /// last, matching how the amount is normally written in Arabic).
  static String format(num rawAmount, String symbol) {
    final amount = formatAmount(rawAmount);
    return symbol == '\$' ? '\$$amount' : '$amount $symbol';
  }

  static String formatString(String rawAmount, String symbol) {
    return format(double.tryParse(rawAmount) ?? 0, symbol);
  }
}
