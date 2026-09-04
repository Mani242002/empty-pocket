import 'dart:math';
import 'package:flutter/material.dart';
import '../domain/entities/bank_account_entity.dart';
import '../domain/entities/budget_entity.dart';
import '../domain/entities/credit_card_entity.dart';
import '../domain/entities/debt_entity.dart';
import '../domain/entities/financial_health_entity.dart';
import '../domain/entities/investment_entity.dart';
import '../domain/entities/recurring_expense_entity.dart';
import '../domain/entities/reports_entity.dart';
import '../domain/entities/savings_goal_entity.dart';
import '../domain/entities/transaction_entity.dart';

class CombinedCreditSummary {
  final double totalLimit;
  final double totalUsed;
  final double totalAvailable;
  final double overallUtilizationRatio;
  final CreditUtilizationHealth overallHealth;
  final int activeCardsCount;
  final CreditCardEntity? nextDueCard;
  final int? daysUntilNextDue;

  const CombinedCreditSummary({
    required this.totalLimit,
    required this.totalUsed,
    required this.totalAvailable,
    required this.overallUtilizationRatio,
    required this.overallHealth,
    required this.activeCardsCount,
    this.nextDueCard,
    this.daysUntilNextDue,
  });

  static const empty = CombinedCreditSummary(
    totalLimit: 0.0,
    totalUsed: 0.0,
    totalAvailable: 0.0,
    overallUtilizationRatio: 0.0,
    overallHealth: CreditUtilizationHealth.optimal,
    activeCardsCount: 0,
    nextDueCard: null,
    daysUntilNextDue: null,
  );
}

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

class MonthlySpendingComparison {
  final double currentMonthExpense;
  final double previousMonthExpense;
  final double differenceAmount;
  final double percentageChange;
  final bool isLower;
  final bool hasPreviousMonthData;

  const MonthlySpendingComparison({
    required this.currentMonthExpense,
    required this.previousMonthExpense,
    required this.differenceAmount,
    required this.percentageChange,
    required this.isLower,
    required this.hasPreviousMonthData,
  });

  static const empty = MonthlySpendingComparison(
    currentMonthExpense: 0.0,
    previousMonthExpense: 0.0,
    differenceAmount: 0.0,
    percentageChange: 0.0,
    isLower: false,
    hasPreviousMonthData: false,
  );
}

/// Pure financial calculation engine for EmptyPocket
abstract class FinancialCalculator {
  /// Safely rounds a monetary value to 2 decimal places to eliminate IEEE-754 floating point inaccuracies.
  static double roundMoney(double value) {
    if (value.isNaN || value.isInfinite) return 0.0;
    return (value * 100).roundToDouble() / 100.0;
  }

  /// Safely divides numerator by denominator, returning [fallback] (default 0.0) if denominator is zero, NaN, or infinite.
  static double safeDivide(double numerator, double denominator, [double fallback = 0.0]) {
    if (denominator == 0.0 || denominator.isNaN || denominator.isInfinite) {
      return fallback;
    }
    final res = numerator / denominator;
    return (res.isNaN || res.isInfinite) ? fallback : roundMoney(res);
  }

  /// Calculate month-over-month spending comparison.
  /// Compares spending in [targetMonth] against the immediately preceding month.
  static MonthlySpendingComparison calculateMonthOverMonthComparison(
    List<TransactionEntity> allTransactions,
    DateTime targetMonth,
  ) {
    final currentMonthTxs = filterByMonth(allTransactions, targetMonth);
    final currentExpense = calculateTotalExpense(currentMonthTxs);

    final prevMonthDate = DateTime(targetMonth.year, targetMonth.month - 1, 1);
    final prevMonthTxs = filterByMonth(allTransactions, prevMonthDate);
    final prevExpense = calculateTotalExpense(prevMonthTxs);

    if (prevExpense <= 0) {
      return MonthlySpendingComparison(
        currentMonthExpense: currentExpense,
        previousMonthExpense: 0.0,
        differenceAmount: currentExpense,
        percentageChange: 0.0,
        isLower: false,
        hasPreviousMonthData: false,
      );
    }

    final diff = roundMoney(currentExpense - prevExpense);
    final pctChange = roundMoney(((currentExpense - prevExpense).abs() / prevExpense) * 100);
    final isLower = currentExpense < prevExpense;

    return MonthlySpendingComparison(
      currentMonthExpense: currentExpense,
      previousMonthExpense: prevExpense,
      differenceAmount: diff,
      percentageChange: pctChange,
      isLower: isLower,
      hasPreviousMonthData: true,
    );
  }

  /// Calculate total income from list of transactions.
  ///
  /// Note: Transfer transactions ([TransactionType.transfer]) are intentionally
  /// excluded from income/expense calculations as they represent internal account
  /// fund movements rather than external cash flow events.
  ///
  /// Shared expense reimbursements ([category == 'Shared Expense Reimbursement'])
  /// are excluded by default so that friend repayments do not falsely inflate earned income.
  static double calculateTotalIncome(
    List<TransactionEntity> transactions, {
    bool excludeReimbursements = true,
  }) {
    final total = transactions
        .where((t) =>
            t.type == TransactionType.income &&
            (!excludeReimbursements || t.category != 'Shared Expense Reimbursement'))
        .fold(0.0, (sum, t) => sum + t.amount);
    return roundMoney(total);
  }

  /// Calculate total expense from list of transactions.
  ///
  /// When [netPersonalOnly] is true (default), shared expenses contribute only the user's
  /// personal portion ([t.netPersonalAmount]) rather than the gross bill amount, preventing
  /// budget and spending inflation for money that was paid on behalf of others.
  static double calculateTotalExpense(
    List<TransactionEntity> transactions, {
    bool netPersonalOnly = true,
  }) {
    final total = transactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + (netPersonalOnly ? t.netPersonalAmount : t.amount));
    return roundMoney(total);
  }

  /// Calculate gross out-of-pocket expense before any reimbursements
  static double calculateGrossExpense(List<TransactionEntity> transactions) {
    return calculateTotalExpense(transactions, netPersonalOnly: false);
  }

  /// Calculate total reimbursement funds received back from friends/roommates
  static double calculateTotalReimbursements(List<TransactionEntity> transactions) {
    final total = transactions
        .where((t) => t.type == TransactionType.income && t.category == 'Shared Expense Reimbursement')
        .fold(0.0, (sum, t) => sum + t.amount);
    return roundMoney(total);
  }

  /// Calculate total pending reimbursements yet to be collected across all active shared expenses
  static double calculatePendingReimbursements(List<TransactionEntity> transactions) {
    final total = transactions
        .where((t) => t.isShared && !t.isSettled)
        .fold(0.0, (sum, t) => sum + t.pendingReimbursement);
    return roundMoney(total);
  }

  /// Calculate credit card funds earmarked in bank accounts from roommate reimbursements.
  /// These are reimbursement funds collected for expenses originally paid via credit card.
  static double calculateCreditCardEarmarkedReserve(List<TransactionEntity> transactions) {
    final total = transactions
        .where((t) => t.isShared && t.creditCardId != null && t.reimbursedAmount > 0)
        .fold(0.0, (sum, t) => sum + t.reimbursedAmount);
    return roundMoney(total);
  }

  /// Calculate net balance (Total Income - Total Expense)
  static double calculateNetBalance(List<TransactionEntity> transactions) {
    return roundMoney(calculateTotalIncome(transactions) - calculateTotalExpense(transactions));
  }

  /// Calculate daily safe-to-spend limit based on remaining monthly budget and days left in the month
  static double calculateDailySafeToSpend(
    double monthlyBudget,
    double totalSpentThisMonth, [
    DateTime? currentDate,
  ]) {
    if (monthlyBudget <= 0) return 0.0;
    final now = currentDate ?? DateTime.now();
    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    final daysRemaining = max(1, lastDay - now.day + 1);
    final remainingBudget = max(0.0, monthlyBudget - totalSpentThisMonth);
    return roundMoney(remainingBudget / daysRemaining);
  }

  /// Calculate savings rate as a percentage: ((income - expense) / income) * 100
  /// Clamped between 0% and 100% for standard financial representation.
  static double calculateSavingsRate(double income, double expense) {
    if (income <= 0) return 0.0;
    final rate = ((income - expense) / income) * 100;
    final clamped = rate < 0 ? 0.0 : (rate > 100 ? 100.0 : rate);
    return roundMoney(clamped);
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
    final totalExpense = expenses.fold(
      0.0,
      (sum, t) => sum + (t.isShared ? t.netPersonalAmount : t.amount),
    );

    if (totalExpense == 0) return [];

    final Map<String, List<TransactionEntity>> groupedByCategory = {};
    for (final item in expenses) {
      groupedByCategory.putIfAbsent(item.category, () => []).add(item);
    }

    final List<CategorySpendingSummary> summary = [];
    groupedByCategory.forEach((category, items) {
      final catAmount = items.fold(
        0.0,
        (sum, t) => sum + (t.isShared ? t.netPersonalAmount : t.amount),
      );
      final percentage = totalExpense > 0 ? (catAmount / totalExpense) * 100 : 0.0;
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

    final spent = categoryExpenses.fold(
      0.0,
      (sum, t) => sum + (t.isShared ? t.netPersonalAmount : t.amount),
    );
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

  /// Calculate next due date based on frequency with robust month-end clamping
  static DateTime calculateNextDueDate(DateTime fromDate, RecurringFrequency frequency) {
    switch (frequency) {
      case RecurringFrequency.daily:
        return fromDate.add(const Duration(days: 1));
      case RecurringFrequency.weekly:
        return fromDate.add(const Duration(days: 7));
      case RecurringFrequency.monthly:
        final nextMonth = DateTime(fromDate.year, fromDate.month + 1, 1);
        final lastDayOfNextMonth = DateTime(nextMonth.year, nextMonth.month + 1, 0).day;
        final day = fromDate.day.clamp(1, lastDayOfNextMonth);
        return DateTime(nextMonth.year, nextMonth.month, day, fromDate.hour, fromDate.minute, fromDate.second);
      case RecurringFrequency.yearly:
        final nextYear = fromDate.year + 1;
        final lastDayOfTargetMonth = DateTime(nextYear, fromDate.month + 1, 0).day;
        final day = fromDate.day.clamp(1, lastDayOfTargetMonth);
        return DateTime(nextYear, fromDate.month, day, fromDate.hour, fromDate.minute, fromDate.second);
    }
  }

  /// Filter upcoming active recurring expenses within daysAhead window
  static List<RecurringExpenseEntity> getUpcomingRecurringExpenses(
    List<RecurringExpenseEntity> expenses, {
    int daysAhead = 30,
    DateTime? fromDate,
  }) {
    final active = expenses.where((e) => e.isActive).toList();
    final filtered = active.where((e) {
      final days = fromDate != null ? e.daysUntilDueFrom(fromDate) : e.daysUntilDue;
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
    final emergencySaved = goals.where((g) => g.isEmergencyFund).fold(0.0, (sum, g) => sum + g.currentAmount);

    return OverallSavingsSummary(
      totalTarget: totalTarget,
      totalSaved: totalSaved,
      totalRemaining: totalRemaining,
      overallPercentage: overallPercentage,
      activeGoalsCount: activeCount,
      completedGoalsCount: completedCount,
      emergencyFundSaved: emergencySaved,
    );
  }

  /// Calculate recommended emergency fund amount based on monthly expenses
  static double calculateRecommendedEmergencyFund(double averageMonthlyExpense, {int months = 6}) {
    return max(0.0, averageMonthlyExpense * months);
  }

  // --- Milestone 5: Loans & Debts Calculations ---

  /// Calculate standard monthly EMI: E = P * r * (1+r)^n / ((1+r)^n - 1)
  static double calculateStandardEmi(
    double principal,
    double annualInterestRate,
    int tenureMonths,
  ) {
    if (principal <= 0 || tenureMonths <= 0) return 0.0;

    if (annualInterestRate <= 0) {
      return principal / tenureMonths;
    }

    final monthlyRate = (annualInterestRate / 12) / 100;
    final factor = pow(1 + monthlyRate, tenureMonths).toDouble();
    final emi = principal * monthlyRate * (factor / (factor - 1));

    return emi;
  }

  /// Calculate total interest payable over the loan duration
  static double calculateTotalInterest(
    double principal,
    double monthlyEmi,
    int tenureMonths,
  ) {
    final totalPayment = monthlyEmi * tenureMonths;
    return max(0.0, totalPayment - principal);
  }

  /// Calculate progress metrics for a single debt/loan
  static DebtRepaymentMetrics calculateDebtProgress(DebtEntity debt) {
    final principal = debt.principalAmount;
    final remaining = debt.remainingAmount;
    final paid = max(0.0, principal - remaining);
    final paidPercentage = principal > 0 ? min(100.0, (paid / principal) * 100) : 0.0;
    final isPaidOff = remaining <= 0 || debt.status == DebtStatus.paidOff;

    final monthsRemaining = (debt.monthlyEmi > 0 && !isPaidOff)
        ? (remaining / debt.monthlyEmi).ceil()
        : 0;

    return DebtRepaymentMetrics(
      debt: debt,
      paidAmount: paid,
      paidPercentage: paidPercentage,
      isPaidOff: isPaidOff,
      estimatedMonthsRemaining: monthsRemaining,
    );
  }

  /// Calculate overall liabilities summary across all debts
  static OverallLiabilitiesSummary calculateOverallLiabilitiesSummary(List<DebtEntity> debts) {
    if (debts.isEmpty) return OverallLiabilitiesSummary.empty;

    final activeDebts = debts.where((d) => d.status == DebtStatus.active && d.remainingAmount > 0).toList();
    final paidOffDebts = debts.where((d) => d.status == DebtStatus.paidOff || d.remainingAmount <= 0).toList();

    final totalOutstanding = activeDebts.fold(0.0, (sum, d) => sum + d.remainingAmount);
    final totalMonthlyEmi = activeDebts.fold(0.0, (sum, d) => sum + d.monthlyEmi);
    final totalOriginalPrincipal = debts.fold(0.0, (sum, d) => sum + d.principalAmount);
    final totalPaidOff = max(0.0, totalOriginalPrincipal - totalOutstanding);

    return OverallLiabilitiesSummary(
      totalOutstanding: totalOutstanding,
      totalMonthlyEmi: totalMonthlyEmi,
      totalOriginalPrincipal: totalOriginalPrincipal,
      totalPaidOff: totalPaidOff,
      activeDebtsCount: activeDebts.length,
      paidOffDebtsCount: paidOffDebts.length,
    );
  }

  /// Calculate Debt-to-Income (DTI) ratio percentage: (Total Monthly EMI / Monthly Income) * 100
  static double calculateDebtToIncomeRatio(double totalMonthlyEmi, double monthlyIncome) {
    if (monthlyIncome <= 0) return 0.0;
    return (totalMonthlyEmi / monthlyIncome) * 100;
  }

  // --- Milestone 6: Investments & Asset Allocation Calculations ---

  /// Calculate metrics for a single investment holding
  static InvestmentMetrics calculateInvestmentMetrics(InvestmentEntity investment) {
    final invested = investment.investedAmount;
    final current = investment.currentValue;
    final pnl = current - invested;
    final returnPct = invested > 0 ? (pnl / invested) * 100 : 0.0;
    final isProfit = current >= invested;

    return InvestmentMetrics(
      investment: investment,
      unrealizedProfitLoss: pnl,
      returnPercentage: returnPct,
      isProfit: isProfit,
    );
  }

  /// Calculate asset allocation distribution across all asset classes
  static List<AssetAllocationItem> calculateAssetAllocation(List<InvestmentEntity> investments) {
    if (investments.isEmpty) return [];

    final totalPortfolioValue = investments.fold(0.0, (sum, i) => sum + i.currentValue);

    final Map<AssetClass, List<InvestmentEntity>> grouped = {};
    for (final inv in investments) {
      grouped.putIfAbsent(inv.assetClass, () => []).add(inv);
    }

    final List<AssetAllocationItem> allocations = [];
    grouped.forEach((assetClass, items) {
      final classInvested = items.fold(0.0, (sum, i) => sum + i.investedAmount);
      final classCurrent = items.fold(0.0, (sum, i) => sum + i.currentValue);
      final percentage = totalPortfolioValue > 0 ? (classCurrent / totalPortfolioValue) * 100 : 0.0;

      allocations.add(
        AssetAllocationItem(
          assetClass: assetClass,
          investedAmount: classInvested,
          currentValue: classCurrent,
          percentageOfPortfolio: percentage,
          itemsCount: items.length,
        ),
      );
    });

    allocations.sort((a, b) => b.currentValue.compareTo(a.currentValue));
    return allocations;
  }

  /// Calculate aggregated portfolio summary
  static OverallPortfolioSummary calculateOverallPortfolioSummary(List<InvestmentEntity> investments) {
    if (investments.isEmpty) return OverallPortfolioSummary.empty;

    final totalInvested = investments.fold(0.0, (sum, i) => sum + i.investedAmount);
    final totalCurrentValue = investments.fold(0.0, (sum, i) => sum + i.currentValue);
    final totalProfitLoss = totalCurrentValue - totalInvested;
    final overallReturn = totalInvested > 0 ? (totalProfitLoss / totalInvested) * 100 : 0.0;
    final isProfit = totalCurrentValue >= totalInvested;
    final allocations = calculateAssetAllocation(investments);

    return OverallPortfolioSummary(
      totalInvested: totalInvested,
      totalCurrentValue: totalCurrentValue,
      totalProfitLoss: totalProfitLoss,
      overallReturnPercentage: overallReturn,
      isProfit: isProfit,
      assetAllocations: allocations,
      totalHoldingsCount: investments.length,
    );
  }

  // --- Milestone 7: Net Worth & Financial Health Calculations ---

  /// Calculate consolidated Net Worth composition from all financial pillars
  static NetWorthComposition calculateNetWorthComposition({
    required double cashBalance,
    required double savingsGoalsAmount,
    required double investmentsAmount,
    required double totalLiabilities,
  }) {
    final effectiveCash = cashBalance > 0 ? cashBalance : 0.0;
    final totalAssets = effectiveCash + savingsGoalsAmount + investmentsAmount;
    final netWorth = totalAssets - totalLiabilities;
    final debtRatio = totalAssets > 0 ? (totalLiabilities / totalAssets) * 100 : (totalLiabilities > 0 ? 100.0 : 0.0);

    return NetWorthComposition(
      cashBalance: cashBalance,
      savingsGoalsAmount: savingsGoalsAmount,
      investmentsAmount: investmentsAmount,
      totalAssets: totalAssets,
      totalLiabilities: totalLiabilities,
      netWorth: netWorth,
      debtToAssetRatio: debtRatio,
    );
  }

  /// Calculate holistic 4-pillar Financial Health Summary (0 - 100 Score)
  static FinancialHealthSummary calculateFinancialHealthSummary({
    required double cashBalance,
    required double monthlyIncome,
    required double monthlyExpense,
    required double savingsGoalsAmount,
    required double emergencyFundSaved,
    required double investmentsAmount,
    required int distinctAssetClassesCount,
    required double totalLiabilities,
    required double totalMonthlyEmi,
  }) {
    final netWorthComp = calculateNetWorthComposition(
      cashBalance: cashBalance,
      savingsGoalsAmount: savingsGoalsAmount,
      investmentsAmount: investmentsAmount,
      totalLiabilities: totalLiabilities,
    );

    // 1. Emergency Buffer Pillar (0 - 25 pts)
    int emergencyScore = 10;
    String emergencyStatus = 'Underfunded';
    String emergencyTip = 'Build at least 3-6 months of expenses in an emergency fund.';

    if (monthlyExpense <= 0) {
      emergencyScore = 15;
      emergencyStatus = 'No expenses logged';
      emergencyTip = 'Log your monthly expenses to calculate your safety runway.';
    } else {
      final totalLiquid = emergencyFundSaved + (cashBalance > 0 ? cashBalance : 0.0);
      final monthsCovered = totalLiquid / monthlyExpense;

      if (monthsCovered >= 6.0) {
        emergencyScore = 25;
        emergencyStatus = 'Fully funded (${monthsCovered.toStringAsFixed(1)} months)';
        emergencyTip = 'Excellent! You have a 6+ month emergency safety shield.';
      } else if (monthsCovered >= 3.0) {
        emergencyScore = 20;
        emergencyStatus = 'Healthy (${monthsCovered.toStringAsFixed(1)} months)';
        emergencyTip = 'Good buffer. Consider expanding to 6 months for complete safety.';
      } else if (monthsCovered >= 1.0) {
        emergencyScore = 12;
        emergencyStatus = 'Basic (${monthsCovered.toStringAsFixed(1)} months)';
        emergencyTip = 'Increase liquid reserves to reach the minimum 3-month target.';
      } else {
        emergencyScore = 5;
        emergencyStatus = 'Critical (< 1 month)';
        emergencyTip = 'Prioritize allocating funds to an Emergency Fund immediately.';
      }
    }

    final emergencyPillar = HealthPillarScore(
      name: 'Emergency Buffer',
      score: emergencyScore,
      statusText: emergencyStatus,
      tip: emergencyTip,
      color: const Color(0xFFF59E0B),
      icon: Icons.shield_rounded,
    );

    // 2. Savings Rate Pillar (0 - 25 pts)
    int savingsScore = 10;
    String savingsStatus = 'Moderate';
    String savingsTip = 'Target saving 20%+ of monthly income.';

    if (monthlyIncome <= 0) {
      savingsScore = 10;
      savingsStatus = 'No income recorded';
      savingsTip = 'Record your monthly income to assess cash flow retention.';
    } else {
      final savingsRate = calculateSavingsRate(monthlyIncome, monthlyExpense);

      if (savingsRate >= 35.0) {
        savingsScore = 25;
        savingsStatus = 'High (${savingsRate.toStringAsFixed(1)}%)';
        savingsTip = 'Superb cash retention! Direct surplus into compound investments.';
      } else if (savingsRate >= 20.0) {
        savingsScore = 20;
        savingsStatus = 'Healthy (${savingsRate.toStringAsFixed(1)}%)';
        savingsTip = 'Healthy savings rate meeting standard financial guidelines.';
      } else if (savingsRate >= 10.0) {
        savingsScore = 12;
        savingsStatus = 'Moderate (${savingsRate.toStringAsFixed(1)}%)';
        savingsTip = 'Try to cut non-essential expenses to push savings above 20%.';
      } else {
        savingsScore = 5;
        savingsStatus = 'Low (${savingsRate.toStringAsFixed(1)}%)';
        savingsTip = 'Expenses are consuming most income. Review your monthly budget limits.';
      }
    }

    final savingsRatePillar = HealthPillarScore(
      name: 'Savings Rate',
      score: savingsScore,
      statusText: savingsStatus,
      tip: savingsTip,
      color: const Color(0xFF10B981),
      icon: Icons.savings_rounded,
    );

    // 3. Debt Burden Pillar (0 - 25 pts)
    int debtScore = 25;
    String debtStatus = '0% Debt-Free';
    String debtTip = 'Outstanding! You carry zero debt burden.';

    if (totalLiabilities > 0) {
      final dti = calculateDebtToIncomeRatio(totalMonthlyEmi, monthlyIncome);

      if (dti <= 15.0) {
        debtScore = 22;
        debtStatus = 'Low Burden (${dti.toStringAsFixed(1)}% DTI)';
        debtTip = 'Your monthly debt obligations are very safe and manageable.';
      } else if (dti <= 35.0) {
        debtScore = 17;
        debtStatus = 'Manageable (${dti.toStringAsFixed(1)}% DTI)';
        debtTip = 'Debt is under control. Avoid taking additional high-interest loans.';
      } else if (dti <= 50.0) {
        debtScore = 10;
        debtStatus = 'High Burden (${dti.toStringAsFixed(1)}% DTI)';
        debtTip = 'EMIs consume over a third of income. Consider loan prepayments.';
      } else {
        debtScore = 4;
        debtStatus = 'Critical Burden (${dti.toStringAsFixed(1)}% DTI)';
        debtTip = 'High debt exposure. Focus aggressively on paying off high-interest debts.';
      }
    }

    final debtPillar = HealthPillarScore(
      name: 'Debt Burden',
      score: debtScore,
      statusText: debtStatus,
      tip: debtTip,
      color: const Color(0xFF06B6D4),
      icon: Icons.credit_score_rounded,
    );

    // 4. Asset Diversification Pillar (0 - 25 pts)
    int diversificationScore = 8;
    String diversificationStatus = 'Cash Only';
    String diversificationTip = 'Start investing in mutual funds, stocks, gold, or FDs.';

    if (investmentsAmount > 0 && distinctAssetClassesCount >= 3) {
      diversificationScore = 25;
      diversificationStatus = 'Well-Diversified ($distinctAssetClassesCount Asset Classes)';
      diversificationTip = 'Excellent asset allocation across varied risk profiles.';
    } else if (investmentsAmount > 0 && distinctAssetClassesCount == 2) {
      diversificationScore = 20;
      diversificationStatus = 'Moderate Spread ($distinctAssetClassesCount Asset Classes)';
      diversificationTip = 'Consider adding a non-correlated asset like Gold or Fixed Deposits.';
    } else if (investmentsAmount > 0) {
      diversificationScore = 14;
      diversificationStatus = 'Basic Spread ($distinctAssetClassesCount Asset Class)';
      diversificationTip = 'Spread your portfolio across multiple asset categories.';
    } else if (savingsGoalsAmount > 0) {
      diversificationScore = 10;
      diversificationStatus = 'Savings Only';
      diversificationTip = 'Move surplus savings above your emergency fund into investments.';
    }

    final diversificationPillar = HealthPillarScore(
      name: 'Asset Spread',
      score: diversificationScore,
      statusText: diversificationStatus,
      tip: diversificationTip,
      color: const Color(0xFF8B5CF6),
      icon: Icons.pie_chart_rounded,
    );

    // Overall Score & Grade
    final overallScore = (emergencyScore + savingsScore + debtScore + diversificationScore).clamp(0, 100);

    HealthGrade grade;
    if (overallScore >= 85) {
      grade = HealthGrade.excellent;
    } else if (overallScore >= 70) {
      grade = HealthGrade.strong;
    } else if (overallScore >= 50) {
      grade = HealthGrade.moderate;
    } else {
      grade = HealthGrade.needsAttention;
    }

    // Generate prioritized actionable tips
    final List<String> actionableTips = [];
    final pillars = [emergencyPillar, savingsRatePillar, debtPillar, diversificationPillar]
      ..sort((a, b) => a.score.compareTo(b.score));

    for (final p in pillars) {
      if (p.score < 22) {
        actionableTips.add(p.tip);
      }
    }

    if (actionableTips.isEmpty) {
      actionableTips.add('Your financial health is in top shape! Maintain your disciplined habits.');
    }

    return FinancialHealthSummary(
      netWorth: netWorthComp,
      overallScore: overallScore,
      grade: grade,
      emergencyBufferPillar: emergencyPillar,
      savingsRatePillar: savingsRatePillar,
      debtBurdenPillar: debtPillar,
      diversificationPillar: diversificationPillar,
      actionableTips: actionableTips,
    );
  }

  // --- Milestone 8: Reports, Analytics & AI Context ---

  /// Calculate historical Month-over-Month (MoM) cash flow trends for the past N months
  static List<MonthlyTrendData> calculateMonthlyTrends(
    List<TransactionEntity> transactions, {
    int monthsCount = 6,
  }) {
    final now = DateTime.now();
    final List<MonthlyTrendData> trends = [];

    for (int i = monthsCount - 1; i >= 0; i--) {
      final monthDate = DateTime(now.year, now.month - i, 1);
      final monthTxs = filterByMonth(transactions, monthDate);
      final income = calculateTotalIncome(monthTxs);
      final expense = calculateTotalExpense(monthTxs);
      final netSavings = income - expense;
      final savingsRate = calculateSavingsRate(income, expense);

      trends.add(
        MonthlyTrendData(
          month: monthDate,
          totalIncome: income,
          totalExpense: expense,
          netSavings: netSavings,
          savingsRate: savingsRate,
        ),
      );
    }

    return trends;
  }

  /// Calculate 3-Month forward cash-flow forecast based on recurring obligations and EMIs
  static List<CashFlowForecastItem> calculateCashFlowForecast({
    required double currentCashBalance,
    required double estimatedMonthlyIncome,
    required double totalMonthlyRecurringExpenses,
    required double totalMonthlyDebtEmi,
    int forecastMonths = 3,
  }) {
    final now = DateTime.now();
    final List<CashFlowForecastItem> forecast = [];
    double cumulative = currentCashBalance;

    final fixedExpenses = totalMonthlyRecurringExpenses + totalMonthlyDebtEmi;
    final netCash = estimatedMonthlyIncome - fixedExpenses;

    for (int i = 1; i <= forecastMonths; i++) {
      final forecastDate = DateTime(now.year, now.month + i, 1);
      cumulative += netCash;

      forecast.add(
        CashFlowForecastItem(
          month: forecastDate,
          projectedIncome: estimatedMonthlyIncome,
          projectedFixedExpenses: fixedExpenses,
          projectedNetCash: netCash,
          projectedCumulativeBalance: cumulative,
        ),
      );
    }

    return forecast;
  }

  /// Calculate payment source breakdown across all expense transactions
  static List<PaymentSourceBreakdown> calculatePaymentSourceBreakdown(List<TransactionEntity> transactions) {
    final expenses = transactions.where((t) => t.type == TransactionType.expense).toList();
    if (expenses.isEmpty) return [];

    final totalExpense = expenses.fold(0.0, (sum, t) => sum + t.amount);
    final Map<String, List<TransactionEntity>> grouped = {};

    for (final tx in expenses) {
      grouped.putIfAbsent(tx.paymentSource, () => []).add(tx);
    }

    final List<PaymentSourceBreakdown> breakdown = [];
    grouped.forEach((source, items) {
      final amount = items.fold(0.0, (sum, t) => sum + t.amount);
      final percentage = totalExpense > 0 ? (amount / totalExpense) * 100 : 0.0;

      breakdown.add(
        PaymentSourceBreakdown(
          source: source,
          amount: amount,
          percentage: percentage,
          count: items.length,
        ),
      );
    });

    breakdown.sort((a, b) => b.amount.compareTo(a.amount));
    return breakdown;
  }

  /// Calculate account-wise outflow breakdown with purpose mapping
  static List<AccountOutflowBreakdown> calculateAccountOutflowBreakdown(
    List<TransactionEntity> transactions,
    List<BankAccountEntity> bankAccounts,
    List<CreditCardEntity> creditCards,
  ) {
    final outflows = transactions.where((t) => t.type == TransactionType.expense || (t.type == TransactionType.transfer && t.accountId != null)).toList();
    if (outflows.isEmpty) return [];

    final totalOutflow = outflows.fold(0.0, (sum, t) => sum + t.amount);
    if (totalOutflow <= 0) return [];

    final Map<String, List<TransactionEntity>> grouped = {};

    for (final tx in outflows) {
      final key = tx.accountId ?? (tx.creditCardId ?? tx.paymentSource);
      grouped.putIfAbsent(key, () => []).add(tx);
    }

    final List<AccountOutflowBreakdown> list = [];
    grouped.forEach((key, items) {
      final amount = items.fold(0.0, (sum, t) => sum + t.amount);
      final percentage = (amount / totalOutflow) * 100;

      String name = items.first.paymentSource;
      String purpose = 'General Outflow';

      final acc = bankAccounts.where((a) => a.id == key || a.accountName.toLowerCase() == key.toLowerCase()).firstOrNull;
      if (acc != null) {
        name = acc.accountName;
        purpose = acc.usedFor;
      } else {
        final card = creditCards.where((c) => c.id == key || c.cardName.toLowerCase() == key.toLowerCase()).firstOrNull;
        if (card != null) {
          name = card.cardName;
          purpose = 'Credit Card (${card.bankName})';
        }
      }

      list.add(
        AccountOutflowBreakdown(
          accountId: key,
          accountName: name,
          purpose: purpose,
          totalOutflow: roundMoney(amount),
          percentage: roundMoney(percentage),
          transactionCount: items.length,
        ),
      );
    });

    list.sort((a, b) => b.totalOutflow.compareTo(a.totalOutflow));
    return list;
  }

  /// Calculate true personal spend vs shared reimbursements
  static SharedExpenseImpact calculateSharedExpenseImpact(List<TransactionEntity> transactions) {
    final expenses = transactions.where((t) => t.type == TransactionType.expense).toList();
    final gross = expenses.fold(0.0, (sum, t) => sum + t.amount);

    double truePersonal = 0.0;
    double pendingReimbursements = 0.0;
    double settledReimbursements = 0.0;

    for (final tx in expenses) {
      if (tx.isShared) {
        final myShare = tx.myShareAmount ?? (tx.amount - tx.reimbursedAmount);
        truePersonal += myShare;
        settledReimbursements += tx.reimbursedAmount;
        if (!tx.isSettled) {
          final pending = max(0.0, tx.amount - (tx.myShareAmount ?? 0.0) - tx.reimbursedAmount);
          pendingReimbursements += pending;
        }
      } else {
        truePersonal += tx.amount;
      }
    }

    return SharedExpenseImpact(
      grossExpense: roundMoney(gross),
      truePersonalSpend: roundMoney(truePersonal),
      pendingReimbursement: roundMoney(pendingReimbursements),
      settledReimbursement: roundMoney(settledReimbursements),
    );
  }

  /// Calculate wealth building & savings rate (investments + goals vs pure expenses)
  static WealthBuildingSummary calculateWealthBuildingSummary(List<TransactionEntity> transactions) {
    final totalInflow = calculateTotalIncome(transactions);
    final expenses = transactions.where((t) => t.type == TransactionType.expense).toList();

    double investmentOutflow = 0.0;
    double savingsTransfer = 0.0;
    double pureExpense = 0.0;

    for (final tx in expenses) {
      final catLower = tx.category.toLowerCase();
      if (catLower.contains('investment') ||
          catLower.contains('mutual') ||
          catLower.contains('sip') ||
          catLower.contains('stock') ||
          catLower.contains('gold')) {
        investmentOutflow += tx.amount;
      } else if (catLower.contains('saving') || tx.linkedEntityId != null) {
        savingsTransfer += tx.amount;
      } else {
        pureExpense += tx.amount;
      }
    }

    final totalWealthAllocated = investmentOutflow + savingsTransfer;
    final rate = totalInflow > 0 ? (totalWealthAllocated / totalInflow * 100).clamp(0.0, 100.0) : 0.0;

    return WealthBuildingSummary(
      totalInflow: roundMoney(totalInflow),
      investmentOutflow: roundMoney(investmentOutflow),
      savingsTransfer: roundMoney(savingsTransfer),
      pureExpense: roundMoney(pureExpense),
      wealthBuildingRate: roundMoney(rate),
    );
  }

  /// Calculate month-over-month category spending changes
  static List<CategoryMomChange> calculateCategoryMomChanges(
    List<TransactionEntity> allTransactions,
    DateTime currentMonth,
  ) {
    final currentTxs = allTransactions.where((t) =>
        t.type == TransactionType.expense &&
        t.date.year == currentMonth.year &&
        t.date.month == currentMonth.month).toList();

    final prevMonthDate = DateTime(currentMonth.year, currentMonth.month - 1);
    final prevTxs = allTransactions.where((t) =>
        t.type == TransactionType.expense &&
        t.date.year == prevMonthDate.year &&
        t.date.month == prevMonthDate.month).toList();

    final Map<String, double> currentMap = {};
    for (final t in currentTxs) {
      currentMap[t.category] = (currentMap[t.category] ?? 0.0) + t.amount;
    }

    final Map<String, double> prevMap = {};
    for (final t in prevTxs) {
      prevMap[t.category] = (prevMap[t.category] ?? 0.0) + t.amount;
    }

    final allCategories = {...currentMap.keys, ...prevMap.keys};
    final List<CategoryMomChange> changes = [];

    for (final cat in allCategories) {
      final curr = currentMap[cat] ?? 0.0;
      final prev = prevMap[cat] ?? 0.0;
      final diff = curr - prev;
      final pct = prev > 0 ? ((curr - prev) / prev * 100) : (curr > 0 ? 100.0 : 0.0);

      changes.add(
        CategoryMomChange(
          category: cat,
          currentMonthAmount: roundMoney(curr),
          previousMonthAmount: roundMoney(prev),
          diffAmount: roundMoney(diff),
          percentChange: roundMoney(pct),
        ),
      );
    }

    changes.sort((a, b) => b.diffAmount.abs().compareTo(a.diffAmount.abs()));
    return changes;
  }

  /// Calculate combined liquid cash across all non-archived bank accounts
  static double calculateCombinedLiquidCash(List<BankAccountEntity> accounts) {
    return accounts
        .where((a) => !a.isArchived)
        .fold(0.0, (sum, a) => sum + a.currentBalance);
  }

  /// Calculate combined credit cards summary across all non-archived cards
  static CombinedCreditSummary calculateCombinedCreditSummary(List<CreditCardEntity> cards) {
    final activeCards = cards.where((c) => !c.isArchived).toList();
    if (activeCards.isEmpty) return CombinedCreditSummary.empty;

    final totalLimit = activeCards.fold(0.0, (sum, c) => sum + c.creditLimit);
    final totalUsed = activeCards.fold(0.0, (sum, c) => sum + c.usedAmount);
    final totalAvailable = max(0.0, totalLimit - totalUsed);
    final overallRatio = totalLimit > 0 ? (totalUsed / totalLimit) * 100 : 0.0;

    CreditUtilizationHealth health;
    if (overallRatio <= 30.0) {
      health = CreditUtilizationHealth.optimal;
    } else if (overallRatio <= 50.0) {
      health = CreditUtilizationHealth.moderate;
    } else {
      health = CreditUtilizationHealth.highRisk;
    }

    // Find card with nearest upcoming payment due date with non-zero used amount
    CreditCardEntity? nextDueCard;
    int? daysUntilNextDue;

    final cardsWithBalance = activeCards.where((c) => c.usedAmount > 0).toList();
    if (cardsWithBalance.isNotEmpty) {
      cardsWithBalance.sort((a, b) => a.daysUntilDue().compareTo(b.daysUntilDue()));
      nextDueCard = cardsWithBalance.first;
      daysUntilNextDue = nextDueCard.daysUntilDue();
    }

    return CombinedCreditSummary(
      totalLimit: totalLimit,
      totalUsed: totalUsed,
      totalAvailable: totalAvailable,
      overallUtilizationRatio: overallRatio,
      overallHealth: health,
      activeCardsCount: activeCards.length,
      nextDueCard: nextDueCard,
      daysUntilNextDue: daysUntilNextDue,
    );
  }

  /// Format an executive financial context string to provide as context to PocketAI
  static String generateFinancialContextSummary({
    required double monthlyIncome,
    required double monthlyExpense,
    required double monthlyNetBalance,
    required double savingsRate,
    required OverallSavingsSummary savingsSummary,
    required OverallPortfolioSummary portfolioSummary,
    required OverallLiabilitiesSummary liabilitiesSummary,
    required FinancialHealthSummary healthSummary,
    List<CategorySpendingSummary>? topExpenseCategories,
    List<BankAccountEntity>? bankAccounts,
    List<CreditCardEntity>? creditCards,
    CombinedCreditSummary? creditSummary,
    List<RecurringExpenseEntity>? recurringExpenses,
  }) {
    final net = healthSummary.netWorth;
    final buffer = StringBuffer();

    buffer.writeln('### Executive Financial Summary:');
    buffer.writeln('- Monthly Income: ₹${monthlyIncome.toStringAsFixed(2)}');
    buffer.writeln('- Monthly Expenses: ₹${monthlyExpense.toStringAsFixed(2)}');
    buffer.writeln('- Monthly Net Savings: ₹${monthlyNetBalance.toStringAsFixed(2)} (${savingsRate.toStringAsFixed(1)}% savings rate)');
    buffer.writeln('- Liquid Cash / Accounts: ₹${net.cashBalance.toStringAsFixed(2)}');
    buffer.writeln('- Savings Goals Total: ₹${savingsSummary.totalSaved.toStringAsFixed(2)} across ${savingsSummary.activeGoalsCount} active goals (Emergency Fund: ₹${savingsSummary.emergencyFundSaved.toStringAsFixed(2)})');
    buffer.writeln('- Investments Portfolio: ₹${portfolioSummary.totalCurrentValue.toStringAsFixed(2)} (Invested: ₹${portfolioSummary.totalInvested.toStringAsFixed(2)}, Returns: ₹${portfolioSummary.totalProfitLoss.toStringAsFixed(2)} / ${portfolioSummary.overallReturnPercentage.toStringAsFixed(1)}%)');
    buffer.writeln('- Outstanding Liabilities / Debts: ₹${liabilitiesSummary.totalOutstanding.toStringAsFixed(2)} (Total Monthly EMI: ₹${liabilitiesSummary.totalMonthlyEmi.toStringAsFixed(2)})');
    buffer.writeln('- Consolidated Net Worth: ₹${net.netWorth.toStringAsFixed(2)}');
    buffer.writeln('- Financial Health Score: ${healthSummary.overallScore}/100 (${healthSummary.grade.displayName})');

    if (topExpenseCategories != null && topExpenseCategories.isNotEmpty) {
      buffer.writeln('\n### Top Expense Categories (This Month):');
      for (final cat in topExpenseCategories.take(5)) {
        buffer.writeln('- ${cat.category}: ₹${cat.amount.toStringAsFixed(2)} (${cat.percentage.toStringAsFixed(1)}% of total)');
      }
    }

    if (bankAccounts != null && bankAccounts.isNotEmpty) {
      final active = bankAccounts.where((a) => !a.isArchived).toList();
      if (active.isNotEmpty) {
        buffer.writeln('\n### Bank & Cash Accounts:');
        for (final acc in active) {
          buffer.writeln('- ${acc.accountName} (${acc.bankName}, ${acc.accountType.displayName}) [Used for: ${acc.usedFor}]: ₹${acc.currentBalance.toStringAsFixed(2)}');
        }
      }
    }

    if (creditCards != null && creditCards.isNotEmpty) {
      final activeCards = creditCards.where((c) => !c.isArchived).toList();
      if (activeCards.isNotEmpty) {
        buffer.writeln('\n### Credit Cards & Utilization:');
        for (final card in activeCards) {
          final util = card.creditLimit > 0 ? (card.usedAmount / card.creditLimit) * 100 : 0.0;
          buffer.writeln('- ${card.cardName} (${card.bankName}): Used ₹${card.usedAmount.toStringAsFixed(2)} / ₹${card.creditLimit.toStringAsFixed(2)} (${util.toStringAsFixed(1)}% util, due in ${card.daysUntilDue()} days)');
        }
      }
    }

    if (recurringExpenses != null && recurringExpenses.isNotEmpty) {
      final activeRec = recurringExpenses.where((r) => r.isActive).toList();
      if (activeRec.isNotEmpty) {
        buffer.writeln('\n### Recurring Bills & Fixed Expenses:');
        for (final r in activeRec.take(6)) {
          buffer.writeln('- ${r.title}: ₹${r.amount.toStringAsFixed(2)} / ${r.frequency.displayName} (Next due: ${r.nextDueDate.day}/${r.nextDueDate.month})');
        }
      }
    }

    return buffer.toString();
  }
}
