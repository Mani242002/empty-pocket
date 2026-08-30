import 'package:flutter_test/flutter_test.dart';
import 'package:empty_pocket/core/calculation/financial_calculator.dart';
import 'package:empty_pocket/core/domain/entities/budget_entity.dart';
import 'package:empty_pocket/core/domain/entities/recurring_expense_entity.dart';
import 'package:empty_pocket/core/domain/entities/transaction_entity.dart';

void main() {
  group('Budget & Recurring Calculations', () {
    final now = DateTime(2026, 8, 21);

    final transactions = [
      TransactionEntity(
        id: 't1',
        title: 'Supermarket Grocery',
        amount: 4000.0,
        type: TransactionType.expense,
        category: 'Groceries',
        date: now,
        paymentSource: 'UPI / Wallet',
        createdAt: now,
        updatedAt: now,
      ),
      TransactionEntity(
        id: 't2',
        title: 'Fancy Dinner',
        amount: 8500.0,
        type: TransactionType.expense,
        category: 'Food & Dining',
        date: now,
        paymentSource: 'Credit Card',
        createdAt: now,
        updatedAt: now,
      ),
      TransactionEntity(
        id: 't3',
        title: 'Monthly Rent',
        amount: 22000.0,
        type: TransactionType.expense,
        category: 'Housing & Rent',
        date: now,
        paymentSource: 'Bank Account',
        createdAt: now,
        updatedAt: now,
      ),
    ];

    test('calculateCategoryBudgetStatus computes Safe health state (< 80%)', () {
      final budget = BudgetEntity(
        id: 'b1',
        category: 'Groceries',
        limitAmount: 10000.0,
        month: now,
        createdAt: now,
        updatedAt: now,
      );

      final status = FinancialCalculator.calculateCategoryBudgetStatus(budget, transactions);

      expect(status.spentAmount, 4000.0);
      expect(status.remainingAmount, 6000.0);
      expect(status.overspentAmount, 0.0);
      expect(status.spentPercentage, 40.0);
      expect(status.health, BudgetHealth.safe);
    });

    test('calculateCategoryBudgetStatus computes Warning health state (80% - 100%)', () {
      final budget = BudgetEntity(
        id: 'b2',
        category: 'Food & Dining',
        limitAmount: 10000.0,
        month: now,
        createdAt: now,
        updatedAt: now,
      );

      final status = FinancialCalculator.calculateCategoryBudgetStatus(budget, transactions);

      expect(status.spentAmount, 8500.0);
      expect(status.remainingAmount, 1500.0);
      expect(status.overspentAmount, 0.0);
      expect(status.spentPercentage, 85.0);
      expect(status.health, BudgetHealth.warning);
    });

    test('calculateCategoryBudgetStatus computes Exceeded health state (> 100%)', () {
      final budget = BudgetEntity(
        id: 'b3',
        category: 'Housing & Rent',
        limitAmount: 20000.0,
        month: now,
        createdAt: now,
        updatedAt: now,
      );

      final status = FinancialCalculator.calculateCategoryBudgetStatus(budget, transactions);

      expect(status.spentAmount, 22000.0);
      expect(status.remainingAmount, 0.0);
      expect(status.overspentAmount, 2000.0);
      expect(status.spentPercentage, closeTo(110.0, 0.001));
      expect(status.health, BudgetHealth.exceeded);
    });

    test('calculateOverallBudgetSummary aggregates all category budgets', () {
      final budgets = [
        BudgetEntity(
          id: 'b1',
          category: 'Groceries',
          limitAmount: 10000.0, // spent: 4000
          month: now,
          createdAt: now,
          updatedAt: now,
        ),
        BudgetEntity(
          id: 'b2',
          category: 'Food & Dining',
          limitAmount: 10000.0, // spent: 8500
          month: now,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final summary = FinancialCalculator.calculateOverallBudgetSummary(budgets, transactions);

      expect(summary.totalLimit, 20000.0);
      expect(summary.totalSpent, 12500.0);
      expect(summary.totalRemaining, 7500.0);
      expect(summary.overallPercentage, 62.5);
      expect(summary.health, BudgetHealth.safe);
      expect(summary.budgetedCategoriesCount, 2);
    });

    test('calculateNextDueDate handles all recurring frequencies', () {
      final start = DateTime(2026, 8, 15);

      final daily = FinancialCalculator.calculateNextDueDate(start, RecurringFrequency.daily);
      expect(daily, DateTime(2026, 8, 16));

      final weekly = FinancialCalculator.calculateNextDueDate(start, RecurringFrequency.weekly);
      expect(weekly, DateTime(2026, 8, 22));

      final monthly = FinancialCalculator.calculateNextDueDate(start, RecurringFrequency.monthly);
      expect(monthly, DateTime(2026, 9, 15));

      final yearly = FinancialCalculator.calculateNextDueDate(start, RecurringFrequency.yearly);
      expect(yearly, DateTime(2027, 8, 15));
    });

    test('calculateNextDueDate clamps month-end dates safely (Jan 31 -> Feb 28, Feb 29 leap -> Feb 28)', () {
      // Jan 31 -> Feb 28 in non-leap year (2025)
      final jan31 = DateTime(2025, 1, 31);
      final febDue = FinancialCalculator.calculateNextDueDate(jan31, RecurringFrequency.monthly);
      expect(febDue, DateTime(2025, 2, 28));

      // Jan 31 -> Feb 29 in leap year (2024)
      final jan31Leap = DateTime(2024, 1, 31);
      final febDueLeap = FinancialCalculator.calculateNextDueDate(jan31Leap, RecurringFrequency.monthly);
      expect(febDueLeap, DateTime(2024, 2, 29));

      // Feb 29 leap year -> Feb 28 non-leap year next year
      final feb29Leap = DateTime(2024, 2, 29);
      final nextYearDue = FinancialCalculator.calculateNextDueDate(feb29Leap, RecurringFrequency.yearly);
      expect(nextYearDue, DateTime(2025, 2, 28));
    });

    test('getUpcomingRecurringExpenses returns only upcoming active items within window', () {
      final recurringList = [
        RecurringExpenseEntity(
          id: 'r1',
          title: 'Active Due Soon',
          amount: 500,
          category: 'Bills',
          frequency: RecurringFrequency.monthly,
          paymentSource: 'UPI',
          startDate: now,
          nextDueDate: now.add(const Duration(days: 3)),
          isActive: true,
          createdAt: now,
          updatedAt: now,
        ),
        RecurringExpenseEntity(
          id: 'r2',
          title: 'Paused Subscription',
          amount: 300,
          category: 'Entertainment',
          frequency: RecurringFrequency.monthly,
          paymentSource: 'Card',
          startDate: now,
          nextDueDate: now.add(const Duration(days: 2)),
          isActive: false, // Paused
          createdAt: now,
          updatedAt: now,
        ),
        RecurringExpenseEntity(
          id: 'r3',
          title: 'Far in Future',
          amount: 1000,
          category: 'Shopping',
          frequency: RecurringFrequency.yearly,
          paymentSource: 'Bank',
          startDate: now,
          nextDueDate: now.add(const Duration(days: 90)), // beyond 30 days
          isActive: true,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final upcoming = FinancialCalculator.getUpcomingRecurringExpenses(recurringList, daysAhead: 30, fromDate: now);
      expect(upcoming.length, 1);
      expect(upcoming.first.title, 'Active Due Soon');
    });
  });
}
