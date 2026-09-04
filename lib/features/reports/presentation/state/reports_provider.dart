import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/calculation/financial_calculator.dart';
import '../../../../core/domain/entities/reports_entity.dart';
import '../../../accounts/presentation/state/accounts_cards_provider.dart';
import '../../../budgets/presentation/state/recurring_provider.dart';
import '../../../debts/presentation/state/debts_provider.dart';
import '../../../transactions/presentation/state/transactions_provider.dart';

/// Historical 6-month Month-over-Month (MoM) cash flow trends
final monthlyTrendsProvider = Provider<List<MonthlyTrendData>>((ref) {
  final transactionsAsync = ref.watch(transactionListNotifierProvider);

  return transactionsAsync.maybeWhen(
    data: (transactions) => FinancialCalculator.calculateMonthlyTrends(transactions, monthsCount: 6),
    orElse: () => [],
  );
});

/// 3-Month Forward Cash-Flow Forecast based on recurring subscriptions and debt EMIs
final cashFlowForecastProvider = Provider<List<CashFlowForecastItem>>((ref) {
  final financialSummary = ref.watch(monthlyFinancialSummaryProvider);
  final recurringSummary = ref.watch(upcomingRecurringExpensesProvider);
  final liabilitiesSummary = ref.watch(overallLiabilitiesSummaryProvider);

  // Total fixed recurring monthly bills
  final totalRecurring = recurringSummary.fold(0.0, (sum, r) => sum + r.amount);

  return FinancialCalculator.calculateCashFlowForecast(
    currentCashBalance: financialSummary.netBalance,
    estimatedMonthlyIncome: financialSummary.totalIncome,
    totalMonthlyRecurringExpenses: totalRecurring,
    totalMonthlyDebtEmi: liabilitiesSummary.totalMonthlyEmi,
    forecastMonths: 3,
  );
});

/// Spending breakdown by payment method
final paymentSourceBreakdownProvider = Provider<List<PaymentSourceBreakdown>>((ref) {
  final transactionsAsync = ref.watch(transactionListNotifierProvider);

  return transactionsAsync.maybeWhen(
    data: (transactions) => FinancialCalculator.calculatePaymentSourceBreakdown(transactions),
    orElse: () => [],
  );
});

/// Account-wise outflow breakdown with purpose mapping (Kotak, ICICI, SBI, AU, IDFC, etc.)
final accountOutflowBreakdownProvider = Provider<List<AccountOutflowBreakdown>>((ref) {
  final transactions = ref.watch(monthlyTransactionsProvider);
  final accounts = ref.watch(activeBankAccountsProvider);
  final cards = ref.watch(activeCreditCardsProvider);
  return FinancialCalculator.calculateAccountOutflowBreakdown(transactions, accounts, cards);
});

/// True personal spend vs shared reimbursements impact
final sharedExpenseImpactProvider = Provider<SharedExpenseImpact>((ref) {
  final transactions = ref.watch(monthlyTransactionsProvider);
  return FinancialCalculator.calculateSharedExpenseImpact(transactions);
});

/// Wealth building rate (Investments + Goals vs living expenses)
final wealthBuildingSummaryProvider = Provider<WealthBuildingSummary>((ref) {
  final transactions = ref.watch(monthlyTransactionsProvider);
  return FinancialCalculator.calculateWealthBuildingSummary(transactions);
});

/// Month-over-month category spending changes
final categoryMomChangesProvider = Provider<List<CategoryMomChange>>((ref) {
  final allTransactions = ref.watch(transactionListNotifierProvider).valueOrNull ?? [];
  final currentMonth = ref.watch(selectedMonthProvider);
  return FinancialCalculator.calculateCategoryMomChanges(allTransactions, currentMonth);
});

