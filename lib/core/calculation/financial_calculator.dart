import 'dart:math';
import '../domain/entities/budget_entity.dart';
import '../domain/entities/recurring_expense_entity.dart';
import '../domain/entities/savings_goal_entity.dart';
import '../domain/entities/transaction_entity.dart';

class CategorySpendingSummary {
  final String category;
  final double amount;
  final double percentage;
  final int count;

  const CategorySpendingSummary({
    required this.category,
    required this.amount,
    required this.percentage,
    required this.count,
  });
}

/// Pure financial calculation engine for EmptyPocket
abstract class FinancialCalculator {
  /// Calculate total income from list of transactions
  static double calculateTotalIncome(List<TransactionEntity> transactions) {
    return transactions
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  /// Calculate total expense from list of transactions
  static double calculateTotalExpense(List<TransactionEntity> transactions) {
    return transactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  /// Calculate net balance (Total Income - Total Expense)
  static double calculateNetBalance(List<TransactionEntity> transactions) {
    return calculateTotalIncome(transactions) - calculateTotalExpense(transactions);
  }

  /// Calculate savings rate as a percentage: ((income - expense) / income) * 100
  /// Clamped between 0% and 100% for standard financial representation.
  static double calculateSavingsRate(double income, double expense) {
    if (income <= 0) return 0.0;
    final rate = ((income - expense) / income) * 100;
    return rate < 0 ? 0.0 : (rate > 100 ? 100.0 : rate);
  }

  /// Filter transactions for a given month and year
  static List<TransactionEntity> filterByMonth(
    List<TransactionEntity> transactions,
    DateTime month,
  ) {
    return transactions.where((t) {
      return t.date.year == month.year && t.date.month == month.month;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date)); // newest first
  }

  /// Filter transactions by TransactionType (null returns all)
  static List<TransactionEntity> filterByType(
    List<TransactionEntity> transactions,
    TransactionType? type,
  ) {
    if (type == null) return transactions;
    return transactions.where((t) => t.type == type).toList();
  }

  /// Search transactions by query (matches title, category, notes, or amount string)
  static List<TransactionEntity> searchTransactions(
    List<TransactionEntity> transactions,
    String query,
  ) {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) return transactions;

    return transactions.where((t) {
      final matchesTitle = t.title.toLowerCase().contains(cleanQuery);
      final matchesCategory = t.category.toLowerCase().contains(cleanQuery);
      final matchesNotes = t.notes?.toLowerCase().contains(cleanQuery) ?? false;
      final matchesSource = t.paymentSource.toLowerCase().contains(cleanQuery);
      final matchesAmount = t.amount.toString().contains(cleanQuery);

      return matchesTitle || matchesCategory || matchesNotes || matchesSource || matchesAmount;
    }).toList();
  }

  /// Group transactions by Date for categorized list views (e.g. today, yesterday, earlier)
  static Map<DateTime, List<TransactionEntity>> groupTransactionsByDate(
    List<TransactionEntity> transactions,
  ) {
    final sorted = List<TransactionEntity>.from(transactions)
      ..sort((a, b) => b.date.compareTo(a.date));

    final Map<DateTime, List<TransactionEntity>> grouped = {};

    for (final transaction in sorted) {
      // Normalize date to midnight (00:00:00)
      final dateKey = DateTime(
        transaction.date.year,
        transaction.date.month,
        transaction.date.day,
      );

      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(transaction);
    }

    return grouped;
  }

  /// Calculate breakdown of expenses grouped by category
  static List<CategorySpendingSummary> calculateCategoryBreakdown(
    List<TransactionEntity> transactions,
  ) {
    final expenses = transactions.where((t) => t.type == TransactionType.expense).toList();
    final totalExpense = expenses.fold(0.0, (sum, t) => sum + t.amount);

    if (totalExpense == 0) return [];

    final Map<String, List<TransactionEntity>> groupedByCategory = {};
    for (final item in expenses) {
      groupedByCategory.putIfAbsent(item.category, () => []).add(item);
    }

    final List<CategorySpendingSummary> summary = [];
    groupedByCategory.forEach((category, items) {
      final catAmount = items.fold(0.0, (sum, t) => sum + t.amount);
      final percentage = (catAmount / totalExpense) * 100;
      summary.add(
        CategorySpendingSummary(
          category: category,
          amount: catAmount,
          percentage: percentage,
          count: items.length,
        ),
      );
    });

    summary.sort((a, b) => b.amount.compareTo(a.amount));
    return summary;
  }

  // --- Milestone 3: Budgeting Calculations ---

  /// Calculate single category budget status against actual expense transactions
  static CategoryBudgetStatus calculateCategoryBudgetStatus(
    BudgetEntity budget,
    List<TransactionEntity> monthlyTransactions,
  ) {
    final categoryExpenses = monthlyTransactions.where((t) {
      return t.type == TransactionType.expense &&
          t.category.toLowerCase() == budget.category.toLowerCase();
    });

    final spent = categoryExpenses.fold(0.0, (sum, t) => sum + t.amount);
    final limit = budget.limitAmount;
    final remaining = max(0.0, limit - spent);
    final overspent = max(0.0, spent - limit);
    final percentage = limit > 0 ? (spent / limit) * 100 : 0.0;

    BudgetHealth health;
    if (percentage >= 100.0) {
      health = BudgetHealth.exceeded;
    } else if (percentage >= 80.0) {
      health = BudgetHealth.warning;
    } else {
      health = BudgetHealth.safe;
    }

    return CategoryBudgetStatus(
      budget: budget,
      spentAmount: spent,
      remainingAmount: remaining,
      overspentAmount: overspent,
      spentPercentage: percentage,
      health: health,
    );
  }

  /// Calculate all category budget statuses
  static List<CategoryBudgetStatus> calculateAllCategoryBudgetStatuses(
    List<BudgetEntity> budgets,
    List<TransactionEntity> monthlyTransactions,
  ) {
    return budgets
        .map((b) => calculateCategoryBudgetStatus(b, monthlyTransactions))
        .toList()
      ..sort((a, b) => b.spentPercentage.compareTo(a.spentPercentage)); // highest utilization first
  }

  /// Calculate overall aggregated budget summary for the active month
  static OverallBudgetSummary calculateOverallBudgetSummary(
    List<BudgetEntity> budgets,
    List<TransactionEntity> monthlyTransactions,
  ) {
    if (budgets.isEmpty) {
      final totalSpent = calculateTotalExpense(monthlyTransactions);
      return OverallBudgetSummary(
        totalLimit: 0.0,
        totalSpent: totalSpent,
        totalRemaining: 0.0,
        totalOverspent: 0.0,
        overallPercentage: 0.0,
        health: BudgetHealth.safe,
        budgetedCategoriesCount: 0,
      );
    }

    final statuses = calculateAllCategoryBudgetStatuses(budgets, monthlyTransactions);

    final totalLimit = statuses.fold(0.0, (sum, s) => sum + s.limitAmount);
    final totalSpent = statuses.fold(0.0, (sum, s) => sum + s.spentAmount);
    final totalRemaining = max(0.0, totalLimit - totalSpent);
    final totalOverspent = statuses.fold(0.0, (sum, s) => sum + s.overspentAmount);
    final overallPercentage = totalLimit > 0 ? (totalSpent / totalLimit) * 100 : 0.0;

    BudgetHealth health;
    if (overallPercentage >= 100.0 || totalOverspent > 0) {
      health = BudgetHealth.exceeded;
    } else if (overallPercentage >= 80.0) {
      health = BudgetHealth.warning;
    } else {
      health = BudgetHealth.safe;
    }

    return OverallBudgetSummary(
      totalLimit: totalLimit,
      totalSpent: totalSpent,
      totalRemaining: totalRemaining,
      totalOverspent: totalOverspent,
      overallPercentage: overallPercentage,
      health: health,
      budgetedCategoriesCount: budgets.length,
    );
  }

  // --- Milestone 3: Recurring Expense Calculations ---

  /// Calculate next due date based on frequency
  static DateTime calculateNextDueDate(DateTime fromDate, RecurringFrequency frequency) {
    switch (frequency) {
      case RecurringFrequency.daily:
        return fromDate.add(const Duration(days: 1));
      case RecurringFrequency.weekly:
        return fromDate.add(const Duration(days: 7));
      case RecurringFrequency.monthly:
        return DateTime(fromDate.year, fromDate.month + 1, fromDate.day);
      case RecurringFrequency.yearly:
        return DateTime(fromDate.year + 1, fromDate.month, fromDate.day);
    }
  }

  /// Filter upcoming active recurring expenses within daysAhead window
  static List<RecurringExpenseEntity> getUpcomingRecurringExpenses(
    List<RecurringExpenseEntity> expenses, {
    int daysAhead = 30,
  }) {
    final active = expenses.where((e) => e.isActive).toList();
    final filtered = active.where((e) {
      final days = e.daysUntilDue;
      return days >= -1 && days <= daysAhead;
    }).toList();

    filtered.sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));
    return filtered;
  }

  // --- Milestone 4: Savings Goals Calculations ---

  /// Calculate progress metrics for a savings goal
  static GoalProgressMetrics calculateGoalProgress(SavingsGoalEntity goal) {
    final target = goal.targetAmount;
    final current = goal.currentAmount;
    final percentage = target > 0 ? min(100.0, (current / target) * 100) : 0.0;
    final remaining = max(0.0, target - current);
    final isCompleted = current >= target;

    final now = DateTime.now();
    int monthsRemaining = ((goal.targetDate.year - now.year) * 12) + (goal.targetDate.month - now.month);
    if (monthsRemaining <= 0) monthsRemaining = 1;

    final recommendedMonthly = isCompleted ? 0.0 : (remaining / monthsRemaining);

    return GoalProgressMetrics(
      goal: goal,
      percentage: percentage,
      remainingAmount: remaining,
      isCompleted: isCompleted,
      monthsRemaining: monthsRemaining,
      recommendedMonthlySavings: recommendedMonthly,
    );
  }

  /// Calculate overall savings summary across all goals
  static OverallSavingsSummary calculateOverallSavingsSummary(List<SavingsGoalEntity> goals) {
    if (goals.isEmpty) return OverallSavingsSummary.empty;

    final totalTarget = goals.fold(0.0, (sum, g) => sum + g.targetAmount);
    final totalSaved = goals.fold(0.0, (sum, g) => sum + g.currentAmount);
    final totalRemaining = max(0.0, totalTarget - totalSaved);
    final overallPercentage = totalTarget > 0 ? min(100.0, (totalSaved / totalTarget) * 100) : 0.0;

    final activeCount = goals.where((g) => g.status == GoalStatus.active && g.currentAmount < g.targetAmount).length;
    final completedCount = goals.where((g) => g.status == GoalStatus.completed || g.currentAmount >= g.targetAmount).length;

    return OverallSavingsSummary(
      totalTarget: totalTarget,
      totalSaved: totalSaved,
      totalRemaining: totalRemaining,
      overallPercentage: overallPercentage,
      activeGoalsCount: activeCount,
      completedGoalsCount: completedCount,
    );
  }

  /// Calculate recommended emergency fund amount based on monthly expenses
  static double calculateRecommendedEmergencyFund(double averageMonthlyExpense, {int months = 6}) {
    return max(0.0, averageMonthlyExpense * months);
  }
}
