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

    test('Mid-cycle: statement generated yesterday (Sept 15), today is Sept 16, grace 20 days -> due date is Oct 5, NOT Nov 4', () {
      final card = CreditCardEntity(
        id: 'card-5',
        cardName: 'HDFC Regalia',
        bankName: 'HDFC',
        creditLimit: 200000.0,
        statementDateDay: 15,
        gracePeriodDays: 20,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final now = DateTime(2026, 9, 16, 10, 0, 0);

      // Statement for next cycle is Oct 15
      final nextStatement = card.getNextStatementDate(now);
      expect(nextStatement, DateTime(2026, 10, 15));

      // Due date MUST be for the bill generated on Sept 15 -> Oct 5
      final nextDue = card.getNextDueDate(now);
      expect(nextDue, DateTime(2026, 10, 5), reason: 'Due date must not skip to November');

      final daysUntilDue = card.daysUntilDue(now);
      expect(daysUntilDue, 19, reason: 'From Sept 16 to Oct 5 is 19 days');
    });

    test('Mid-cycle: Today is the due date itself -> due date is today, daysUntilDue is 0', () {
      final card = CreditCardEntity(
        id: 'card-6',
        cardName: 'Axis Magnus',
        bankName: 'Axis Bank',
        creditLimit: 300000.0,
        statementDateDay: 15,
        gracePeriodDays: 20,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final now = DateTime(2026, 10, 5, 23, 59, 0);
      final nextDue = card.getNextDueDate(now);
      expect(nextDue, DateTime(2026, 10, 5));
      expect(card.daysUntilDue(now), 0);
    });

    test('Post-due: Today is the day after due date (Oct 6) -> next due date is for October statement (Nov 4)', () {
      final card = CreditCardEntity(
        id: 'card-7',
        cardName: 'ICICI Sapphiro',
        bankName: 'ICICI Bank',
        creditLimit: 150000.0,
        statementDateDay: 15,
        gracePeriodDays: 20,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final now = DateTime(2026, 10, 6, 8, 0, 0);
      final nextDue = card.getNextDueDate(now);
      expect(nextDue, DateTime(2026, 11, 4));
      expect(card.daysUntilDue(now), 29);
    });

    test('initialUsedAmount is properly mapped and preserved', () {
      final card = CreditCardEntity(
        id: 'card-initial',
        cardName: 'OneCard',
        bankName: 'Federal Bank',
        creditLimit: 100000.0,
        usedAmount: 15000.0,
        initialUsedAmount: 15000.0,
        statementDateDay: 10,
        gracePeriodDays: 20,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final map = card.toMap();
      expect(map['initial_used_amount'], 15000.0);

      final restored = CreditCardEntity.fromMap(map);
      expect(restored.initialUsedAmount, 15000.0);

      // Fallback test for legacy maps lacking initial_used_amount
      final legacyMap = Map<String, dynamic>.from(map)..remove('initial_used_amount');
      final legacyRestored = CreditCardEntity.fromMap(legacyMap);
      expect(legacyRestored.initialUsedAmount, 15000.0);
    });
  });
}
