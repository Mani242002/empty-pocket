import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Supported global currency definition
class CurrencyOption {
  final String
  code; // e.g. 'INR', 'USD', 'EUR', 'GBP', 'CAD', 'AUD', 'AED', 'JPY', 'SGD'
  final String name; // e.g. 'Indian Rupee', 'US Dollar'
  final String symbol; // '₹', '$', '€', '£', etc.
  final bool isIndianNumbering; // true for INR (Lakhs/Crores), false for Western (Thousands/Millions/Billions)
  final int decimalDigits;

  const CurrencyOption({
    required this.code,
    required this.name,
    required this.symbol,
    required this.isIndianNumbering,
    this.decimalDigits = 2,
  });
}

/// Formatter for currency and financial metrics
class CurrencyFormatter {
  static const List<CurrencyOption> supportedCurrencies = [
    CurrencyOption(
      code: 'INR',
      name: 'Indian Rupee',
      symbol: '₹',
      isIndianNumbering: true,
    ),
    CurrencyOption(
      code: 'USD',
      name: 'US Dollar',
      symbol: r'$',
      isIndianNumbering: false,
    ),
    CurrencyOption(
      code: 'EUR',
      name: 'Euro',
      symbol: '€',
      isIndianNumbering: false,
    ),
    CurrencyOption(
      code: 'GBP',
      name: 'British Pound',
      symbol: '£',
      isIndianNumbering: false,
    ),
    CurrencyOption(
      code: 'CAD',
      name: 'Canadian Dollar',
      symbol: r'CA$',
      isIndianNumbering: false,
    ),
    CurrencyOption(
      code: 'AUD',
      name: 'Australian Dollar',
      symbol: r'A$',
      isIndianNumbering: false,
    ),
    CurrencyOption(
      code: 'AED',
      name: 'UAE Dirham',
      symbol: 'AED ',
      isIndianNumbering: false,
    ),
    CurrencyOption(
      code: 'JPY',
      name: 'Japanese Yen',
      symbol: '¥',
      isIndianNumbering: false,
      decimalDigits: 0,
    ),
    CurrencyOption(
      code: 'SGD',
      name: 'Singapore Dollar',
      symbol: r'S$',
      isIndianNumbering: false,
    ),
  ];

  static CurrencyOption activeCurrency = supportedCurrencies.first;

  /// Initializes active currency from persistent preferences (reloading to avoid stale cache)
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final code = prefs.getString('app_currency_code');
      if (code != null && code.isNotEmpty) {
        setCurrencyByCode(code);
      }
    } catch (_) {}
  }

  /// Returns the symbol of the currently active currency
  static String get currentSymbol => activeCurrency.symbol;

  static void setCurrency(CurrencyOption option) {
    activeCurrency = option;
  }

  static void setCurrencyByCode(String code) {
    activeCurrency = supportedCurrencies.firstWhere(
      (c) => c.code.toUpperCase() == code.toUpperCase(),
      orElse: () => supportedCurrencies.first,
    );
  }

  static String format(
    double amount, {
    String? symbol,
    bool showDecimals = true,
  }) {
    final curSymbol = symbol ?? activeCurrency.symbol;
    final isIndian = (symbol != null && symbol != activeCurrency.symbol)
        ? (symbol == '₹')
        : activeCurrency.isIndianNumbering;

    final int digits = showDecimals ? activeCurrency.decimalDigits : 0;
    final decimalZeros = digits > 0 ? '.${'0' * digits}' : '';

    if (amount.isNaN || amount.isInfinite) {
      return '$curSymbol${digits > 0 ? "0.00" : "0"}';
    }
    final sign = amount < 0 ? '-' : '';
    final absAmount = amount.abs();
    final pattern = isIndian
        ? (digits > 0
              ? '$curSymbol#,##,##0$decimalZeros'
              : '$curSymbol#,##,##0')
        : (digits > 0 ? '$curSymbol#,##0$decimalZeros' : '$curSymbol#,##0');
    final format = NumberFormat.currency(
      symbol: curSymbol,
      decimalDigits: digits,
      customPattern: pattern,
    );
    return '$sign${format.format(absAmount)}';
  }

  static String formatCompact(double amount, {String? symbol}) {
    final curSymbol = symbol ?? activeCurrency.symbol;
    final isIndian = (symbol != null && symbol != activeCurrency.symbol)
        ? (symbol == '₹')
        : activeCurrency.isIndianNumbering;

    if (amount.isNaN || amount.isInfinite) {
      return '${curSymbol}0';
    }
    final sign = amount < 0 ? '-' : '';
    final absAmount = amount.abs();

    if (isIndian) {
      if (absAmount >= 10000000) {
        return '$sign$curSymbol${(absAmount / 10000000).toStringAsFixed(2)} Cr';
      } else if (absAmount >= 100000) {
        return '$sign$curSymbol${(absAmount / 100000).toStringAsFixed(2)} L';
      } else if (absAmount >= 1000) {
        return '$sign$curSymbol${(absAmount / 1000).toStringAsFixed(1)} k';
      }
    } else {
      if (absAmount >= 1000000000) {
        return '$sign$curSymbol${(absAmount / 1000000000).toStringAsFixed(2)} B';
      } else if (absAmount >= 1000000) {
        return '$sign$curSymbol${(absAmount / 1000000).toStringAsFixed(2)} M';
      } else if (absAmount >= 1000) {
        return '$sign$curSymbol${(absAmount / 1000).toStringAsFixed(1)} k';
      }
    }
    return format(amount, symbol: curSymbol, showDecimals: false);
  }
}
