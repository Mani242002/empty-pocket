import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/calculation/financial_calculator.dart';
import '../../../../core/domain/entities/savings_goal_entity.dart';
import '../../../../core/domain/entities/transaction_entity.dart';
import '../../../../core/repositories/savings_goal_repository.dart';
import '../../../accounts/presentation/state/accounts_cards_provider.dart';
import '../../../transactions/presentation/state/transactions_provider.dart';

class SavingsGoalsListNotifier extends AsyncNotifier<List<SavingsGoalEntity>> {
  @override
  FutureOr<List<SavingsGoalEntity>> build() async {
    final repository = ref.watch(savingsGoalRepositoryProvider);
    final goals = await repository.getAllGoals();

    // Automatically sync linked goal progress whenever bank account balances change
    ref.listen(bankAccountListProvider, (previous, next) {
      next.whenData((_) {
        syncAllLinkedGoals();
      });
    });

    return goals;
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

  Future<void> syncGoalsForAccount(String accountId) async {
    final currentGoals = state.valueOrNull ?? await ref.read(savingsGoalRepositoryProvider).getAllGoals();
    final accounts = ref.read(bankAccountListProvider).valueOrNull ?? [];
    final account = accounts.where((a) => a.id == accountId).firstOrNull;
    if (account == null) return;

    final repository = ref.read(savingsGoalRepositoryProvider);
    bool anyChanged = false;
    final now = DateTime.now();

    for (final goal in currentGoals) {
      if (goal.linkedAccountId == accountId && goal.autoSyncAccount) {
        final syncedAmount = (account.currentBalance * (goal.allocationPercentage / 100.0)).clamp(0.0, double.infinity);
        if ((syncedAmount - goal.currentAmount).abs() > 0.01) {
          final isCompleted = syncedAmount >= goal.targetAmount;
          final updated = goal.copyWith(
            currentAmount: syncedAmount,
            status: isCompleted
                ? GoalStatus.completed
                : (goal.status == GoalStatus.completed ? GoalStatus.active : goal.status),
            updatedAt: now,
          );
          await repository.saveGoal(updated);
          anyChanged = true;
        }
      }
    }
    if (anyChanged) {
      state = AsyncValue.data(await repository.getAllGoals());
    }
  }

  Future<void> syncAllLinkedGoals() async {
    final currentGoals = state.valueOrNull ?? await ref.read(savingsGoalRepositoryProvider).getAllGoals();
    final accounts = ref.read(bankAccountListProvider).valueOrNull ?? [];
    if (accounts.isEmpty) return;

    final repository = ref.read(savingsGoalRepositoryProvider);
    bool anyChanged = false;
    final now = DateTime.now();

    for (final goal in currentGoals) {
      if (goal.linkedAccountId != null && goal.autoSyncAccount) {
        final account = accounts.where((a) => a.id == goal.linkedAccountId).firstOrNull;
        if (account != null) {
          final syncedAmount = (account.currentBalance * (goal.allocationPercentage / 100.0)).clamp(0.0, double.infinity);
          if ((syncedAmount - goal.currentAmount).abs() > 0.01) {
            final isCompleted = syncedAmount >= goal.targetAmount;
            final updated = goal.copyWith(
              currentAmount: syncedAmount,
              status: isCompleted
                  ? GoalStatus.completed
                  : (goal.status == GoalStatus.completed ? GoalStatus.active : goal.status),
              updatedAt: now,
            );
            await repository.saveGoal(updated);
            anyChanged = true;
          }
        }
      }
    }
    if (anyChanged) {
      state = AsyncValue.data(await repository.getAllGoals());
    }
  }

  Future<void> addFunds({
    required SavingsGoalEntity goal,
    required double amount,
    String? notes,
    bool logAsTransaction = true,
    String paymentSource = 'Bank Account',
    String? accountId,
  }) async {
    final repository = ref.read(savingsGoalRepositoryProvider);
    final now = DateTime.now();

    // 1. Create contribution record
    final contribution = GoalContributionEntity(
      id: const Uuid().v4(),
      goalId: goal.id,
      amount: amount,
      date: now,
      notes: notes,
      sourceAccountId: accountId,
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

    // 3. Optionally record transaction in offline ledger & adjust account balance
    if (logAsTransaction) {
      if (accountId != null) {
        await ref.read(bankAccountListProvider.notifier).adjustAccountBalance(accountId, -amount);
      }
      final tx = TransactionEntity(
        id: const Uuid().v4(),
        title: 'Goal: ${goal.title}',
        amount: amount,
        type: TransactionType.expense,
        category: 'Savings & Investments',
        date: now,
        paymentSource: paymentSource,
        accountId: accountId,
        linkedEntityId: goal.id,
        notes: notes ?? 'Savings contribution towards "${goal.title}"',
        createdAt: now,
        updatedAt: now,
      );
      await ref.read(transactionListNotifierProvider.notifier).addTransaction(tx);
    }
  }

  Future<void> createGoalWithInitialDeposit({
    required SavingsGoalEntity goal,
    required double initialAmount,
    bool deductFromAccount = true,
    String? accountId,
    String paymentSource = 'Bank Account',
  }) async {
    final updatedGoal = initialAmount > 0
        ? goal.copyWith(
            currentAmount: goal.currentAmount + initialAmount,
            status: (goal.currentAmount + initialAmount) >= goal.targetAmount
                ? GoalStatus.completed
                : goal.status,
          )
        : goal;
    await saveGoal(updatedGoal);

    if (initialAmount > 0) {
      final now = DateTime.now();
      final repository = ref.read(savingsGoalRepositoryProvider);
      final contribution = GoalContributionEntity(
        id: const Uuid().v4(),
        goalId: goal.id,
        amount: initialAmount,
        date: now,
        notes: 'Initial savings deposit for "${goal.title}"',
        sourceAccountId: deductFromAccount ? accountId : null,
        createdAt: now,
      );
      await repository.addContribution(contribution);

      if (deductFromAccount && accountId != null) {
        await ref.read(bankAccountListProvider.notifier).adjustAccountBalance(accountId, -initialAmount);
        final tx = TransactionEntity(
          id: const Uuid().v4(),
          title: 'Goal: ${goal.title}',
          amount: initialAmount,
          type: TransactionType.expense,
          category: 'Savings & Investments',
          date: now,
          paymentSource: paymentSource,
          accountId: accountId,
          linkedEntityId: goal.id,
          notes: 'Initial deposit for goal "${goal.title}"',
          createdAt: now,
          updatedAt: now,
        );
        await ref.read(transactionListNotifierProvider.notifier).addTransaction(tx);
      }
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
