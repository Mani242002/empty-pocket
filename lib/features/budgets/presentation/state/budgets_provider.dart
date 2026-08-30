import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/calculation/financial_calculator.dart';
import '../../../../core/domain/entities/budget_entity.dart';
import '../../../../core/repositories/budget_repository.dart';
import '../../../transactions/presentation/state/transactions_provider.dart';

class BudgetListNotifier extends AsyncNotifier<List<BudgetEntity>> {
  @override
  FutureOr<List<BudgetEntity>> build() async {
    final repository = ref.watch(budgetRepositoryProvider);
    return await repository.getAllBudgets();
  }

  Future<void> saveBudget(BudgetEntity budget) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(budgetRepositoryProvider);
      await repository.saveBudget(budget);
      return await repository.getAllBudgets();
    });
  }

  Future<void> deleteBudget(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(budgetRepositoryProvider);
      await repository.deleteBudget(id);
      return await repository.getAllBudgets();
    });
  }
}

final budgetListNotifierProvider =
    AsyncNotifierProvider<BudgetListNotifier, List<BudgetEntity>>(
  BudgetListNotifier.new,
);

/// Budgets for the currently active/selected month
final monthlyBudgetsProvider = Provider<List<BudgetEntity>>((ref) {
  final allBudgetsAsync = ref.watch(budgetListNotifierProvider);
  final selectedMonth = ref.watch(selectedMonthProvider);

  return allBudgetsAsync.maybeWhen(
    data: (budgets) => budgets.where((b) {
      return b.month.year == selectedMonth.year && b.month.month == selectedMonth.month;
    }).toList(),
    orElse: () => [],
  );
});

/// Category Budget Statuses for the active month
final monthlyCategoryBudgetStatusesProvider = Provider<List<CategoryBudgetStatus>>((ref) {
  final budgets = ref.watch(monthlyBudgetsProvider);
  final monthlyTransactions = ref.watch(monthlyTransactionsProvider);

  return FinancialCalculator.calculateAllCategoryBudgetStatuses(budgets, monthlyTransactions);
});

/// Overall Aggregated Budget Summary for the active month
final overallMonthlyBudgetSummaryProvider = Provider<OverallBudgetSummary>((ref) {
  final budgets = ref.watch(monthlyBudgetsProvider);
  final monthlyTransactions = ref.watch(monthlyTransactionsProvider);

  return FinancialCalculator.calculateOverallBudgetSummary(budgets, monthlyTransactions);
});

/// Daily Safe-to-Spend limit for the active month
final dailySafeToSpendProvider = Provider<double>((ref) {
  final budgetSummary = ref.watch(overallMonthlyBudgetSummaryProvider);
  return FinancialCalculator.calculateDailySafeToSpend(
    budgetSummary.totalLimit,
    budgetSummary.totalSpent,
  );
});
