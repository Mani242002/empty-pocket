import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/calculation/financial_calculator.dart';
import '../../../../core/domain/entities/financial_health_entity.dart';
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

  return FinancialCalculator.calculateNetWorthComposition(
    cashBalance: financialSummary.netBalance,
    savingsGoalsAmount: savingsSummary.totalSaved,
    investmentsAmount: portfolioSummary.totalCurrentValue,
    totalLiabilities: liabilitiesSummary.totalOutstanding,
  );
});

/// Holistic 4-Pillar Financial Health Score (0 - 100) and Analysis Provider
final financialHealthSummaryProvider = Provider<FinancialHealthSummary>((ref) {
  final financialSummary = ref.watch(monthlyFinancialSummaryProvider);
  final savingsSummary = ref.watch(overallSavingsSummaryProvider);
  final portfolioSummary = ref.watch(overallPortfolioSummaryProvider);
  final liabilitiesSummary = ref.watch(overallLiabilitiesSummaryProvider);

  return FinancialCalculator.calculateFinancialHealthSummary(
    cashBalance: financialSummary.netBalance,
    monthlyIncome: financialSummary.totalIncome,
    monthlyExpense: financialSummary.totalExpense,
    savingsGoalsAmount: savingsSummary.totalSaved,
    emergencyFundSaved: savingsSummary.emergencyFundSaved,
    investmentsAmount: portfolioSummary.totalCurrentValue,
    distinctAssetClassesCount: portfolioSummary.assetAllocations.length,
    totalLiabilities: liabilitiesSummary.totalOutstanding,
    totalMonthlyEmi: liabilitiesSummary.totalMonthlyEmi,
  );
});
