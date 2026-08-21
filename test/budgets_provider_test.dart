import 'package:flutter_test/flutter_test.dart';
import 'package:empty_pocket/core/domain/entities/budget_entity.dart';
import 'package:empty_pocket/core/domain/entities/recurring_expense_entity.dart';
import 'package:empty_pocket/core/repositories/budget_repository.dart';
import 'package:empty_pocket/core/repositories/recurring_repository.dart';

void main() {
  group('BudgetRepository (In-Memory)', () {
    late InMemoryBudgetRepository repository;
    final now = DateTime(2026, 8, 1);

    setUp(() {
      repository = InMemoryBudgetRepository();
    });

    test('saveBudget and getBudgetsForMonth works properly', () async {
      final budget = BudgetEntity(
        id: 'b1',
        category: 'Food & Dining',
        limitAmount: 8000,
        month: now,
        createdAt: now,
        updatedAt: now,
      );

      await repository.saveBudget(budget);
      final list = await repository.getBudgetsForMonth(now);

      expect(list.length, 1);
      expect(list.first.category, 'Food & Dining');
      expect(list.first.limitAmount, 8000);
    });

    test('deleteBudget removes budget', () async {
      final budget = BudgetEntity(
        id: 'b1',
        category: 'Food & Dining',
        limitAmount: 8000,
        month: now,
        createdAt: now,
        updatedAt: now,
      );

      await repository.saveBudget(budget);
      expect((await repository.getAllBudgets()).length, 1);

      await repository.deleteBudget('b1');
      expect((await repository.getAllBudgets()).isEmpty, isTrue);
    });
  });

  group('RecurringRepository (In-Memory)', () {
    late InMemoryRecurringRepository repository;
    final now = DateTime(2026, 8, 21);

    setUp(() {
      repository = InMemoryRecurringRepository();
    });

    test('saveRecurringExpense and getAllRecurringExpenses works properly', () async {
      final item = RecurringExpenseEntity(
        id: 'r1',
        title: 'Spotify Premium',
        amount: 119,
        category: 'Entertainment',
        frequency: RecurringFrequency.monthly,
        paymentSource: 'UPI',
        startDate: now,
        nextDueDate: now.add(const Duration(days: 10)),
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      await repository.saveRecurringExpense(item);
      final list = await repository.getAllRecurringExpenses();

      expect(list.length, 1);
      expect(list.first.title, 'Spotify Premium');
      expect(list.first.amount, 119);
    });

    test('deleteRecurringExpense removes item', () async {
      final item = RecurringExpenseEntity(
        id: 'r1',
        title: 'Spotify Premium',
        amount: 119,
        category: 'Entertainment',
        frequency: RecurringFrequency.monthly,
        paymentSource: 'UPI',
        startDate: now,
        nextDueDate: now.add(const Duration(days: 10)),
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      await repository.saveRecurringExpense(item);
      expect((await repository.getAllRecurringExpenses()).length, 1);

      await repository.deleteRecurringExpense('r1');
      expect((await repository.getAllRecurringExpenses()).isEmpty, isTrue);
    });
  });
}
