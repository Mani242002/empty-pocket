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
