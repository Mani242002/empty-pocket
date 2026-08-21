import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/calculation/financial_calculator.dart';
import '../../../../core/domain/entities/investment_entity.dart';
import '../../../../core/domain/entities/transaction_entity.dart';
import '../../../../core/repositories/investment_repository.dart';
import '../../../transactions/presentation/state/transactions_provider.dart';

class InvestmentListNotifier extends AsyncNotifier<List<InvestmentEntity>> {
  @override
  FutureOr<List<InvestmentEntity>> build() async {
    final repository = ref.watch(investmentRepositoryProvider);
    return await repository.getAllInvestments();
  }

  Future<void> saveInvestment(
    InvestmentEntity investment, {
    bool logAsTransaction = false,
    String paymentSource = 'Bank Account',
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(investmentRepositoryProvider);
      await repository.saveInvestment(investment);

      if (logAsTransaction) {
        final now = DateTime.now();
        final tx = TransactionEntity(
          id: const Uuid().v4(),
          title: 'Investment: ${investment.name}',
          amount: investment.investedAmount,
          type: TransactionType.expense,
          category: 'Investment & Savings',
          date: now,
          paymentSource: paymentSource,
          notes: 'Asset allocation in ${investment.assetClass.displayName}',
          createdAt: now,
          updatedAt: now,
        );
        await ref.read(transactionListNotifierProvider.notifier).addTransaction(tx);
      }

      return await repository.getAllInvestments();
    });
  }

  Future<void> updateValuation({
    required InvestmentEntity investment,
    required double newCurrentValue,
    double? newCurrentPrice,
  }) async {
    final now = DateTime.now();
    final updated = investment.copyWith(
      currentValue: newCurrentValue,
      currentPrice: newCurrentPrice ?? investment.currentPrice,
      updatedAt: now,
    );

    await saveInvestment(updated, logAsTransaction: false);
  }

  Future<void> deleteInvestment(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(investmentRepositoryProvider);
      await repository.deleteInvestment(id);
      return await repository.getAllInvestments();
    });
  }
}

final investmentListNotifierProvider =
    AsyncNotifierProvider<InvestmentListNotifier, List<InvestmentEntity>>(
  InvestmentListNotifier.new,
);

/// Aggregated portfolio summary
final overallPortfolioSummaryProvider = Provider<OverallPortfolioSummary>((ref) {
  final investmentsAsync = ref.watch(investmentListNotifierProvider);

  return investmentsAsync.maybeWhen(
    data: (investments) => FinancialCalculator.calculateOverallPortfolioSummary(investments),
    orElse: () => OverallPortfolioSummary.empty,
  );
});

/// Metrics for all investments
final investmentMetricsListProvider = Provider<List<InvestmentMetrics>>((ref) {
  final investmentsAsync = ref.watch(investmentListNotifierProvider);

  return investmentsAsync.maybeWhen(
    data: (investments) => investments.map((i) => FinancialCalculator.calculateInvestmentMetrics(i)).toList(),
    orElse: () => [],
  );
});

/// Asset allocations breakdown
final assetAllocationListProvider = Provider<List<AssetAllocationItem>>((ref) {
  final investmentsAsync = ref.watch(investmentListNotifierProvider);

  return investmentsAsync.maybeWhen(
    data: (investments) => FinancialCalculator.calculateAssetAllocation(investments),
    orElse: () => [],
  );
});

/// Grouped holdings by asset class
final investmentsByAssetClassProvider = Provider<Map<AssetClass, List<InvestmentEntity>>>((ref) {
  final investmentsAsync = ref.watch(investmentListNotifierProvider);

  return investmentsAsync.maybeWhen(
    data: (investments) {
      final Map<AssetClass, List<InvestmentEntity>> grouped = {};
      for (final inv in investments) {
        grouped.putIfAbsent(inv.assetClass, () => []).add(inv);
      }
      return grouped;
    },
    orElse: () => {},
  );
});
