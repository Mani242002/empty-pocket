import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/calculation/financial_calculator.dart';
import '../../../../core/domain/entities/savings_goal_entity.dart';
import '../../../../core/domain/entities/transaction_entity.dart';
import '../../../../core/repositories/savings_goal_repository.dart';
import '../../../transactions/presentation/state/transactions_provider.dart';

class SavingsGoalsListNotifier extends AsyncNotifier<List<SavingsGoalEntity>> {
  @override
  FutureOr<List<SavingsGoalEntity>> build() async {
    final repository = ref.watch(savingsGoalRepositoryProvider);
    return await repository.getAllGoals();
  }

  Future<void> saveGoal(SavingsGoalEntity goal) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(savingsGoalRepositoryProvider);
      await repository.saveGoal(goal);
      return await repository.getAllGoals();
    });
  }

  Future<void> deleteGoal(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(savingsGoalRepositoryProvider);
      await repository.deleteGoal(id);
      return await repository.getAllGoals();
    });
  }

  Future<void> addFunds({
    required SavingsGoalEntity goal,
    required double amount,
    String? notes,
    bool logAsTransaction = true,
    String paymentSource = 'Bank Account',
  }) async {
    final now = DateTime.now();
    final repository = ref.read(savingsGoalRepositoryProvider);

    // 1. Record contribution history
    final contribution = GoalContributionEntity(
      id: const Uuid().v4(),
      goalId: goal.id,
      amount: amount,
      date: now,
      notes: notes,
      createdAt: now,
    );
    await repository.addContribution(contribution);

    // 2. Update goal current amount
    final updatedAmount = goal.currentAmount + amount;
    final isCompleted = updatedAmount >= goal.targetAmount;
    final updatedGoal = goal.copyWith(
      currentAmount: updatedAmount,
      status: isCompleted ? GoalStatus.completed : goal.status,
      updatedAt: now,
    );
    await saveGoal(updatedGoal);

    // 3. Optionally record transaction in offline ledger
    if (logAsTransaction) {
      final tx = TransactionEntity(
        id: const Uuid().v4(),
        title: 'Goal: ${goal.title}',
        amount: amount,
        type: TransactionType.expense,
        category: 'Savings & Investments',
        date: now,
        paymentSource: paymentSource,
        notes: notes ?? 'Savings contribution towards "${goal.title}"',
        createdAt: now,
        updatedAt: now,
      );
      await ref.read(transactionListNotifierProvider.notifier).addTransaction(tx);
    }
  }
}

final savingsGoalsListNotifierProvider =
    AsyncNotifierProvider<SavingsGoalsListNotifier, List<SavingsGoalEntity>>(
  SavingsGoalsListNotifier.new,
);

/// Aggregated savings summary
final overallSavingsSummaryProvider = Provider<OverallSavingsSummary>((ref) {
  final goalsAsync = ref.watch(savingsGoalsListNotifierProvider);

  return goalsAsync.maybeWhen(
    data: (goals) => FinancialCalculator.calculateOverallSavingsSummary(goals),
    orElse: () => OverallSavingsSummary.empty,
  );
});

/// Metrics for all savings goals
final goalProgressMetricsListProvider = Provider<List<GoalProgressMetrics>>((ref) {
  final goalsAsync = ref.watch(savingsGoalsListNotifierProvider);

  return goalsAsync.maybeWhen(
    data: (goals) => goals.map((g) => FinancialCalculator.calculateGoalProgress(g)).toList(),
    orElse: () => [],
  );
});

/// Emergency Fund Goal Selector
final emergencyFundGoalProvider = Provider<SavingsGoalEntity?>((ref) {
  final goalsAsync = ref.watch(savingsGoalsListNotifierProvider);

  return goalsAsync.maybeWhen(
    data: (goals) {
      final matches = goals.where((g) => g.isEmergencyFund);
      return matches.isNotEmpty ? matches.first : null;
    },
    orElse: () => null,
  );
});

/// Goal Contributions Provider
final goalContributionsProvider =
    FutureProvider.family<List<GoalContributionEntity>, String>((ref, goalId) async {
  final repository = ref.watch(savingsGoalRepositoryProvider);
  return await repository.getContributionsForGoal(goalId);
});
