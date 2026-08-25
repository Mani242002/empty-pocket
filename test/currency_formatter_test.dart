import 'package:flutter_test/flutter_test.dart';
import 'package:empty_pocket/core/utilities/currency_formatter.dart';

void main() {
  group('CurrencyFormatter', () {
    test('formats basic amount with symbol and decimals', () {
      final formatted = CurrencyFormatter.format(1250.50);
      expect(formatted, contains('1,250.50'));
      expect(formatted, contains('₹'));
    });

    test('formats zero amount', () {
      final formatted = CurrencyFormatter.format(0);
      expect(formatted, contains('0.00'));
    });

    test('formats compact thousands', () {
      final formatted = CurrencyFormatter.formatCompact(45000);
      expect(formatted, '₹45.0 k');
    });

    test('formats compact lakhs', () {
      final formatted = CurrencyFormatter.formatCompact(250000);
      expect(formatted, '₹2.50 L');
    });

    test('formats compact crores', () {
      final formatted = CurrencyFormatter.formatCompact(15000000);
      expect(formatted, '₹1.50 Cr');
    });

    test('formats negative amount correctly', () {
      final formatted = CurrencyFormatter.format(-1250.50);
      expect(formatted, contains('-₹1,250.50'));
    });

    test('formats negative compact numbers correctly', () {
      expect(CurrencyFormatter.formatCompact(-45000), '-₹45.0 k');
      expect(CurrencyFormatter.formatCompact(-250000), '-₹2.50 L');
      expect(CurrencyFormatter.formatCompact(-15000000), '-₹1.50 Cr');
    });
  });
}
