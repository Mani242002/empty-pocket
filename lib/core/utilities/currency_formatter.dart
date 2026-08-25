import 'package:intl/intl.dart';

/// Formatter for currency and financial metrics
class CurrencyFormatter {
  static String format(
    double amount, {
    String symbol = '₹',
    bool showDecimals = true,
  }) {
    final sign = amount < 0 ? '-' : '';
    final absAmount = amount.abs();
    final pattern = showDecimals ? '$symbol#,##,##0.00' : '$symbol#,##,##0';
    final format = NumberFormat.currency(
      symbol: symbol,
      decimalDigits: showDecimals ? 2 : 0,
      customPattern: pattern,
    );
    return '$sign${format.format(absAmount)}';
  }

  static String formatCompact(
    double amount, {
    String symbol = '₹',
  }) {
    final sign = amount < 0 ? '-' : '';
    final absAmount = amount.abs();
    if (absAmount >= 10000000) {
      return '$sign$symbol${(absAmount / 10000000).toStringAsFixed(2)} Cr';
    } else if (absAmount >= 100000) {
      return '$sign$symbol${(absAmount / 100000).toStringAsFixed(2)} L';
    } else if (absAmount >= 1000) {
      return '$sign$symbol${(absAmount / 1000).toStringAsFixed(1)} k';
    }
    return format(amount, symbol: symbol, showDecimals: false);
  }
}
