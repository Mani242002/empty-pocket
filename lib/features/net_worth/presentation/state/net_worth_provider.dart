import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/calculation/financial_calculator.dart';
import '../../../../core/domain/entities/financial_health_entity.dart';
import '../../../accounts/presentation/state/accounts_cards_provider.dart';
import '../../../debts/presentation/state/debts_provider.dart';
import '../../../investments/presentation/state/investments_provider.dart';
import '../../../savings/presentation/state/savings_goals_provider.dart';
import '../../../transactions/presentation/state/transactions_provider.dart';

/// Consolidated Net Worth composition Provider
final netWorthCompositionProvider = Provider<NetWorthComposition>((ref) {
  final financialSummary = ref.watch(monthlyFinancialSummaryProvider);
  final savingsSummary = ref.watch(overallSavingsSummaryProvider);
  final portfolioSummary = ref.watch(overallPortfolioSummaryProvider);
  final liabilitiesSummary = ref.watch(overallLiabilitiesSummaryProvider);
  final bankAccounts = ref.watch(activeBankAccountsProvider);
  final combinedLiquidCash = ref.watch(combinedLiquidCashProvider);
  final creditSummary = ref.watch(combinedCreditSummaryProvider);

  // Use real combined bank account liquid cash if accounts configured, otherwise monthly net
  final effectiveCash = bankAccounts.isNotEmpty ? combinedLiquidCash : financialSummary.netBalance;
  final totalLiabilities = liabilitiesSummary.totalOutstanding + creditSummary.totalUsed;

  return FinancialCalculator.calculateNetWorthComposition(
    cashBalance: effectiveCash,
    savingsGoalsAmount: savingsSummary.totalSaved,
    investmentsAmount: portfolioSummary.totalCurrentValue,
    totalLiabilities: totalLiabilities,
  );
});

/// Holistic 4-Pillar Financial Health Score (0 - 100) and Analysis Provider
final financialHealthSummaryProvider = Provider<FinancialHealthSummary>((ref) {
  final financialSummary = ref.watch(monthlyFinancialSummaryProvider);
  final savingsSummary = ref.watch(overallSavingsSummaryProvider);
  final portfolioSummary = ref.watch(overallPortfolioSummaryProvider);
  final liabilitiesSummary = ref.watch(overallLiabilitiesSummaryProvider);
  final bankAccounts = ref.watch(activeBankAccountsProvider);
  final combinedLiquidCash = ref.watch(combinedLiquidCashProvider);
  final creditSummary = ref.watch(combinedCreditSummaryProvider);

  final effectiveCash = bankAccounts.isNotEmpty ? combinedLiquidCash : financialSummary.netBalance;
  final totalLiabilities = liabilitiesSummary.totalOutstanding + creditSummary.totalUsed;

  return FinancialCalculator.calculateFinancialHealthSummary(
    cashBalance: effectiveCash,
    monthlyIncome: financialSummary.totalIncome,
    monthlyExpense: financialSummary.totalExpense,
    savingsGoalsAmount: savingsSummary.totalSaved,
    emergencyFundSaved: savingsSummary.emergencyFundSaved,
    investmentsAmount: portfolioSummary.totalCurrentValue,
    distinctAssetClassesCount: portfolioSummary.assetAllocations.length,
    totalLiabilities: totalLiabilities,
    totalMonthlyEmi: liabilitiesSummary.totalMonthlyEmi,
  );
});
