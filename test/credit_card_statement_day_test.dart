import 'package:flutter_test/flutter_test.dart';
import 'package:empty_pocket/core/domain/entities/credit_card_entity.dart';

void main() {
  group('CreditCardEntity Statement & Due Day Edge Case Tests', () {
    test('Statement day is today at non-zero time: does not roll over to next month', () {
      final card = CreditCardEntity(
        id: 'card-1',
        cardName: 'Amazon Pay ICICI',
        bankName: 'ICICI Bank',
        creditLimit: 100000.0,
        statementDateDay: 15,
        gracePeriodDays: 20,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      // Current time is 2:30 PM on the 15th
      final now = DateTime(2026, 9, 15, 14, 30, 0);

      final nextStatement = card.getNextStatementDate(now);
      expect(nextStatement.year, 2026);
      expect(nextStatement.month, 9);
      expect(nextStatement.day, 15);

      final daysUntilStmt = card.daysUntilStatement(now);
      expect(daysUntilStmt, 0, reason: 'Days until statement on statement day must be 0');

      final nextDue = card.getNextDueDate(now);
      expect(nextDue, DateTime(2026, 9, 15).add(const Duration(days: 20)));

      final daysUntilDue = card.daysUntilDue(now);
      expect(daysUntilDue, 20);
    });

    test('Statement day later in current month', () {
      final card = CreditCardEntity(
        id: 'card-3',
        cardName: 'SBI SimplyCLICK',
        bankName: 'SBI',
        creditLimit: 50000.0,
        statementDateDay: 20,
        gracePeriodDays: 20,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final now = DateTime(2026, 9, 15, 9, 0, 0);
      final daysUntilStmt = card.daysUntilStatement(now);
      expect(daysUntilStmt, 5);

      final nextStatement = card.getNextStatementDate(now);
      expect(nextStatement, DateTime(2026, 9, 20));
    });

    test('Statement day clamping for short months (e.g. Feb 31 -> Feb 28 in non-leap year)', () {
      final card = CreditCardEntity(
        id: 'card-4',
        cardName: 'Axis Bank Ace',
        bankName: 'Axis Bank',
        creditLimit: 75000.0,
        statementDateDay: 31,
        gracePeriodDays: 20,
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );

      // In Feb 2025 (non-leap year), last day is 28
      final now = DateTime(2025, 2, 10);
      final nextStatement = card.getNextStatementDate(now);
      expect(nextStatement.year, 2025);
      expect(nextStatement.month, 2);
      expect(nextStatement.day, 28);
    });
  });
}
