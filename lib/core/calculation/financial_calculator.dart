import 'dart:math';
import 'package:flutter/material.dart';
import '../domain/entities/budget_entity.dart';
import '../domain/entities/debt_entity.dart';
import '../domain/entities/financial_health_entity.dart';
import '../domain/entities/investment_entity.dart';
import '../domain/entities/recurring_expense_entity.dart';
import '../domain/entities/reports_entity.dart';
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
  }) {
    final net = healthSummary.netWorth;
    return '''
- Monthly Income: ₹${monthlyIncome.toStringAsFixed(2)}
- Monthly Expenses: ₹${monthlyExpense.toStringAsFixed(2)}
- Monthly Net Savings: ₹${monthlyNetBalance.toStringAsFixed(2)} (${savingsRate.toStringAsFixed(1)}% savings rate)
- Liquid Cash / Accounts: ₹${net.cashBalance.toStringAsFixed(2)}
- Savings Goals Total: ₹${savingsSummary.totalSaved.toStringAsFixed(2)} across ${savingsSummary.activeGoalsCount} active goals (Emergency Fund: ₹${savingsSummary.emergencyFundSaved.toStringAsFixed(2)})
- Investments Portfolio: ₹${portfolioSummary.totalCurrentValue.toStringAsFixed(2)} (Invested: ₹${portfolioSummary.totalInvested.toStringAsFixed(2)}, Returns: ₹${portfolioSummary.totalProfitLoss.toStringAsFixed(2)} / ${portfolioSummary.overallReturnPercentage.toStringAsFixed(1)}%)
- Outstanding Liabilities / Debts: ₹${liabilitiesSummary.totalOutstanding.toStringAsFixed(2)} (Total Monthly EMI: ₹${liabilitiesSummary.totalMonthlyEmi.toStringAsFixed(2)})
- Consolidated Net Worth: ₹${net.netWorth.toStringAsFixed(2)}
- Financial Health Score: ${healthSummary.overallScore}/100 (${healthSummary.grade.displayName})
''';
  }
}
