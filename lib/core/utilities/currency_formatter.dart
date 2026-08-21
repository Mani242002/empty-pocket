import 'package:intl/intl.dart';

/// Formatter for currency and financial metrics
class CurrencyFormatter {
  static String format(
    double amount, {
    String symbol = '₹',
    bool showDecimals = true,
  }) {
    final format = NumberFormat.currency(
      symbol: symbol,
      decimalDigits: showDecimals ? 2 : 0,
      customPattern: '$symbol#,##,##0.00',
    );
    return format.format(amount);
  }

  static String formatCompact(
    double amount, {
    String symbol = '₹',
  }) {
    if (amount.abs() >= 10000000) {
      return '$symbol${(amount / 10000000).toStringAsFixed(2)} Cr';
    } else if (amount.abs() >= 100000) {
      return '$symbol${(amount / 100000).toStringAsFixed(2)} L';
    } else if (amount.abs() >= 1000) {
      return '$symbol${(amount / 1000).toStringAsFixed(1)} k';
    }
    return format(amount, symbol: symbol, showDecimals: false);
  }
}
