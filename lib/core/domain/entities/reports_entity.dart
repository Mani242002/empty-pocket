class MonthlyTrendData {
  final DateTime month;
  final double totalIncome;
  final double totalExpense;
  final double netSavings;
  final double savingsRate; // percentage

  const MonthlyTrendData({
    required this.month,
    required this.totalIncome,
    required this.totalExpense,
    required this.netSavings,
    required this.savingsRate,
  });

  bool get isPositive => netSavings >= 0;
}

class CashFlowForecastItem {
  final DateTime month;
  final double projectedIncome;
  final double projectedFixedExpenses; // Recurring expenses + active debt EMIs
  final double projectedNetCash;
  final double projectedCumulativeBalance;

  const CashFlowForecastItem({
    required this.month,
    required this.projectedIncome,
    required this.projectedFixedExpenses,
    required this.projectedNetCash,
    required this.projectedCumulativeBalance,
  });
}

class PaymentSourceBreakdown {
  final String source;
  final double amount;
  final double percentage;
  final int count;

  const PaymentSourceBreakdown({
    required this.source,
    required this.amount,
    required this.percentage,
    required this.count,
  });
}

class AccountOutflowBreakdown {
  final String accountId;
  final String accountName;
  final String purpose;
  final double totalOutflow;
  final double percentage;
  final int transactionCount;

  const AccountOutflowBreakdown({
    required this.accountId,
    required this.accountName,
    required this.purpose,
    required this.totalOutflow,
    required this.percentage,
    required this.transactionCount,
  });
}

class SharedExpenseImpact {
  final double grossExpense;
  final double truePersonalSpend;
  final double pendingReimbursement;
  final double settledReimbursement;

  const SharedExpenseImpact({
    required this.grossExpense,
    required this.truePersonalSpend,
    required this.pendingReimbursement,
    required this.settledReimbursement,
  });

  double get reimbursementRate => grossExpense > 0 ? (settledReimbursement / grossExpense * 100).clamp(0.0, 100.0) : 0.0;
}

class WealthBuildingSummary {
  final double totalInflow;
  final double investmentOutflow;
  final double savingsTransfer;
  final double pureExpense;
  final double wealthBuildingRate; // (investment + savings) / totalInflow * 100

  const WealthBuildingSummary({
    required this.totalInflow,
    required this.investmentOutflow,
    required this.savingsTransfer,
    required this.pureExpense,
    required this.wealthBuildingRate,
  });
}

class CategoryMomChange {
  final String category;
  final double currentMonthAmount;
  final double previousMonthAmount;
  final double diffAmount;
  final double percentChange;

  const CategoryMomChange({
    required this.category,
    required this.currentMonthAmount,
    required this.previousMonthAmount,
    required this.diffAmount,
    required this.percentChange,
  });

  bool get isIncrease => diffAmount > 0;
}
