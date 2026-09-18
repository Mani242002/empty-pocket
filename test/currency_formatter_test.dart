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

    test('safely handles NaN and Infinite amounts without throwing', () {
      expect(CurrencyFormatter.format(double.nan), '₹0.00');
      expect(CurrencyFormatter.format(double.infinity), '₹0.00');
      expect(CurrencyFormatter.format(double.negativeInfinity), '₹0.00');
      expect(CurrencyFormatter.formatCompact(double.nan), '₹0');
      expect(CurrencyFormatter.formatCompact(double.infinity), '₹0');
      expect(CurrencyFormatter.formatCompact(double.negativeInfinity), '₹0');
    });

    test('supports global currencies with Western numbering', () {
      CurrencyFormatter.setCurrencyByCode('USD');
      expect(CurrencyFormatter.format(1250.50), '\$1,250.50');
      expect(CurrencyFormatter.formatCompact(45000), '\$45.0 k');
      expect(CurrencyFormatter.formatCompact(2500000), '\$2.50 M');
      expect(CurrencyFormatter.formatCompact(1500000000), '\$1.50 B');

      CurrencyFormatter.setCurrencyByCode('EUR');
      expect(CurrencyFormatter.format(850.00), '€850.00');

      CurrencyFormatter.setCurrencyByCode('GBP');
      expect(CurrencyFormatter.format(120.75), '£120.75');
      expect(CurrencyFormatter.currentSymbol, '£');

      CurrencyFormatter.setCurrencyByCode('USD');
      expect(CurrencyFormatter.currentSymbol, '\$');
      expect(CurrencyFormatter.format(-50.25), '-\$50.25');

      CurrencyFormatter.setCurrencyByCode('CAD');
      expect(CurrencyFormatter.currentSymbol, 'CA\$');
      expect(CurrencyFormatter.format(-100.0), '-CA\$100.00');

      // Reset to INR
      CurrencyFormatter.setCurrencyByCode('INR');
      expect(CurrencyFormatter.currentSymbol, '₹');
      expect(CurrencyFormatter.format(1250.50), '₹1,250.50');
    });
  });
}
