import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/calculation/financial_calculator.dart';
import '../../../../core/domain/entities/savings_goal_entity.dart';
import '../../../../core/domain/entities/transaction_entity.dart';
import '../../../../core/repositories/savings_goal_repository.dart';
import '../../../../core/repositories/transaction_repository.dart';
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
    final currentGoals =
        state.valueOrNull ??
        await ref.read(savingsGoalRepositoryProvider).getAllGoals();
    final accounts = ref.read(bankAccountListProvider).valueOrNull ?? [];
    final account = accounts.where((a) => a.id == accountId).firstOrNull;
    if (account == null) return;

    final repository = ref.read(savingsGoalRepositoryProvider);
    bool anyChanged = false;
    final now = DateTime.now();

    for (final goal in currentGoals) {
      if (goal.linkedAccountId == accountId && goal.autoSyncAccount) {
        final syncedAmount =
            (account.currentBalance * (goal.allocationPercentage / 100.0))
                .clamp(0.0, double.infinity);
        if ((syncedAmount - goal.currentAmount).abs() > 0.01) {
          final isCompleted = syncedAmount >= goal.targetAmount;
          final updated = goal.copyWith(
            currentAmount: syncedAmount,
            status: isCompleted
                ? GoalStatus.completed
                : (goal.status == GoalStatus.completed
                      ? GoalStatus.active
                      : goal.status),
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

  /// Applies customized smart inflow distribution slider percentages to goals linked to an account
  Future<void> applyInflowDistribution({
    required String accountId,
    required double primaryPercent,
    required double secondaryPercent,
    String? primaryGoalId,
    String? secondaryGoalId,
    double? customBalance,
  }) async {
    final repository = ref.read(savingsGoalRepositoryProvider);
    final currentGoals = state.valueOrNull ?? await repository.getAllGoals();
    final accounts = ref.read(bankAccountListProvider).valueOrNull ?? [];
    final account = accounts.where((a) => a.id == accountId).firstOrNull;
    if (account == null) return;

    final balanceToDistribute = customBalance ?? account.currentBalance;
    final now = DateTime.now();
    final linkedGoals = currentGoals
        .where((g) => g.linkedAccountId == accountId)
        .toList();

    SavingsGoalEntity? pGoal;
    SavingsGoalEntity? sGoal;

    if (primaryGoalId != null) {
      pGoal = linkedGoals.where((g) => g.id == primaryGoalId).firstOrNull;
    } else if (linkedGoals.isNotEmpty) {
      pGoal = linkedGoals.first;
    }

    if (secondaryGoalId != null) {
      sGoal = linkedGoals.where((g) => g.id == secondaryGoalId).firstOrNull;
    } else if (linkedGoals.length > 1) {
      sGoal = linkedGoals[1];
    }

    bool anyChanged = false;
    if (pGoal != null) {
      final pAmount = (balanceToDistribute * (primaryPercent / 100.0)).clamp(
        0.0,
        double.infinity,
      );
      final isCompleted = pAmount >= pGoal.targetAmount;
      final updatedP = pGoal.copyWith(
        allocationPercentage: primaryPercent,
        autoSyncAccount: true,
        currentAmount: pAmount,
        status: isCompleted
            ? GoalStatus.completed
            : (pGoal.status == GoalStatus.completed
                  ? GoalStatus.active
                  : pGoal.status),
        updatedAt: now,
      );
      await repository.saveGoal(updatedP);
      anyChanged = true;
    }

    if (sGoal != null && sGoal.id != pGoal?.id) {
      final sAmount = (balanceToDistribute * (secondaryPercent / 100.0)).clamp(
        0.0,
        double.infinity,
      );
      final isCompleted = sAmount >= sGoal.targetAmount;
      final updatedS = sGoal.copyWith(
        allocationPercentage: secondaryPercent,
        autoSyncAccount: true,
        currentAmount: sAmount,
        status: isCompleted
            ? GoalStatus.completed
            : (sGoal.status == GoalStatus.completed
                  ? GoalStatus.active
                  : sGoal.status),
        updatedAt: now,
      );
      await repository.saveGoal(updatedS);
      anyChanged = true;
    }

    if (anyChanged) {
      state = AsyncValue.data(await repository.getAllGoals());
    }
  }

  Future<void> syncAllLinkedGoals() async {
    try {
      final currentGoals =
          state.valueOrNull ??
          await ref.read(savingsGoalRepositoryProvider).getAllGoals();
      final accounts = ref.read(bankAccountListProvider).valueOrNull ?? [];
      if (accounts.isEmpty) return;

      final repository = ref.read(savingsGoalRepositoryProvider);
      bool anyChanged = false;
      final now = DateTime.now();

      for (final goal in currentGoals) {
        if (goal.linkedAccountId != null && goal.autoSyncAccount) {
          final account = accounts
              .where((a) => a.id == goal.linkedAccountId)
              .firstOrNull;
          if (account != null) {
            final syncedAmount =
                (account.currentBalance * (goal.allocationPercentage / 100.0))
                    .clamp(0.0, double.infinity);
            if ((syncedAmount - goal.currentAmount).abs() > 0.01) {
              final isCompleted = syncedAmount >= goal.targetAmount;
              final updated = goal.copyWith(
                currentAmount: syncedAmount,
                status: isCompleted
                    ? GoalStatus.completed
                    : (goal.status == GoalStatus.completed
                          ? GoalStatus.active
                          : goal.status),
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
    } catch (e) {
      if (e.toString().contains('disposed')) return;
      rethrow;
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
    final now = DateTime.now();
    final isSameAccount =
        goal.linkedAccountId != null && goal.linkedAccountId == accountId;
    final txId = const Uuid().v4();
    final tx = logAsTransaction
        ? TransactionEntity(
            id: txId,
            title: 'Goal: ${goal.title}',
            amount: amount,
            type: TransactionType.transfer,
            category: 'Savings & Investments',
            date: now,
            paymentSource: paymentSource,
            accountId: isSameAccount ? null : accountId,
            toAccountId: (accountId != null && !isSameAccount)
                ? goal.linkedAccountId
                : null,
            linkedEntityId: goal.id,
            notes: notes ?? 'Savings contribution towards "${goal.title}"',
            createdAt: now,
            updatedAt: now,
          )
        : null;

    final txRepo = ref.read(transactionRepositoryProvider);
    if (txRepo is SqliteTransactionRepository) {
      await txRepo.addSavingsGoalContributionAtomic(
        goal: goal,
        amount: amount,
        notes: notes,
        logAsTransaction: logAsTransaction,
        paymentSource: paymentSource,
        accountId: accountId,
        transaction: tx,
      );
    } else {
      final repository = ref.read(savingsGoalRepositoryProvider);
      final contribution = GoalContributionEntity(
        id: const Uuid().v4(),
        goalId: goal.id,
        amount: amount,
        date: now,
        notes: notes,
        sourceAccountId: accountId,
        transactionId: tx?.id,
        createdAt: now,
      );
      await repository.addContribution(contribution);

      final updatedAmount = goal.currentAmount + amount;
      final newStatus = goal.status == GoalStatus.paused
          ? GoalStatus.paused
          : (updatedAmount >= goal.targetAmount
                ? GoalStatus.completed
                : goal.status);
      final updatedGoal = goal.copyWith(
        currentAmount: updatedAmount,
        status: newStatus,
        updatedAt: now,
      );
      await saveGoal(updatedGoal);

      if (logAsTransaction && tx != null) {
        if (accountId != null && !isSameAccount) {
          await ref
              .read(bankAccountListProvider.notifier)
              .adjustAccountBalance(accountId, -amount);
          if (goal.linkedAccountId != null) {
            await ref
                .read(bankAccountListProvider.notifier)
                .adjustAccountBalance(goal.linkedAccountId!, amount);
          }
        }
        await ref
            .read(transactionListNotifierProvider.notifier)
            .addTransaction(tx);
      }
    }

    state = AsyncValue.data(
      await ref.read(savingsGoalRepositoryProvider).getAllGoals(),
    );
    ref.invalidate(bankAccountListProvider);
    ref.invalidate(transactionListNotifierProvider);
  }

  /// Records a savings contribution and updates goal progress without creating
  /// an expense or deducting from bank balance, since funds were already moved
  /// via an account transfer or deposit.
  Future<void> recordAllocation({
    required SavingsGoalEntity goal,
    required double amount,
    required String sourceAccountId,
    String? transactionTitle,
    DateTime? date,
  }) async {
    if (amount <= 0) return;
    final repository = ref.read(savingsGoalRepositoryProvider);
    final now = date ?? DateTime.now();

    // 1. Create contribution record (without any expense transaction)
    final contribution = GoalContributionEntity(
      id: const Uuid().v4(),
      goalId: goal.id,
      amount: amount,
      date: now,
      notes: transactionTitle != null
          ? 'Allocated from: $transactionTitle'
          : 'Allocated from linked account transfer',
      sourceAccountId: sourceAccountId,
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
  }

  /// Automatically or interactively splits transferred/deposited money
  /// across multiple linked savings goals without double-counting as an expense.
  Future<void> allocateToMultipleGoals({
    required Map<String, double> goalAllocations,
    required String sourceAccountId,
    String? transactionTitle,
    DateTime? date,
    double? newTotalAccountBalance,
  }) async {
    final repository = ref.read(savingsGoalRepositoryProvider);
    final currentGoals = state.valueOrNull ?? await repository.getAllGoals();
    final now = date ?? DateTime.now();

    for (final entry in goalAllocations.entries) {
      final goalId = entry.key;
      final amount = entry.value;
      if (amount <= 0) continue;

      final goal = currentGoals.where((g) => g.id == goalId).firstOrNull;
      if (goal == null) continue;

      final contribution = GoalContributionEntity(
        id: const Uuid().v4(),
        goalId: goal.id,
        amount: amount,
        date: now,
        notes: transactionTitle != null
            ? 'Allocated from: $transactionTitle'
            : 'Allocated from linked account transfer',
        sourceAccountId: sourceAccountId,
        createdAt: now,
      );
      await repository.addContribution(contribution);

      final updatedAmount = goal.currentAmount + amount;
      final isCompleted = updatedAmount >= goal.targetAmount;
      double? newAllocPct;
      if (newTotalAccountBalance != null && newTotalAccountBalance > 0) {
        newAllocPct = (updatedAmount / newTotalAccountBalance) * 100.0;
      }

      final updatedGoal = goal.copyWith(
        currentAmount: updatedAmount,
        allocationPercentage: newAllocPct ?? goal.allocationPercentage,
        status: isCompleted ? GoalStatus.completed : goal.status,
        updatedAt: now,
      );
      await repository.saveGoal(updatedGoal);
    }

    state = AsyncValue.data(await repository.getAllGoals());
  }

  Future<void> createGoalWithInitialDeposit({
    required SavingsGoalEntity goal,
    required double initialAmount,
    bool deductFromAccount = true,
    String? accountId,
    String paymentSource = 'Bank Account',
  }) async {
    final repository = ref.read(savingsGoalRepositoryProvider);
    final now = DateTime.now();
    final tx = (initialAmount > 0 && deductFromAccount && accountId != null)
        ? TransactionEntity(
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
          )
        : null;

    await repository.createSavingsGoalAtomic(
      goal: goal,
      initialAmount: initialAmount,
      deductFromAccount: deductFromAccount,
      accountId: accountId,
      paymentSource: paymentSource,
      transaction: tx,
    );

    if (repository is! SqliteSavingsGoalRepository) {
      if (deductFromAccount && accountId != null && initialAmount > 0) {
        await ref
            .read(bankAccountListProvider.notifier)
            .adjustAccountBalance(accountId, -initialAmount);
        if (tx != null) {
          await ref
              .read(transactionListNotifierProvider.notifier)
              .addTransaction(tx);
        }
      }
    }

    state = AsyncValue.data(await repository.getAllGoals());
    if (deductFromAccount && accountId != null && initialAmount > 0) {
      ref.invalidate(bankAccountListProvider);
      ref.invalidate(transactionListNotifierProvider);
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
final goalProgressMetricsListProvider = Provider<List<GoalProgressMetrics>>((
  ref,
) {
  final goalsAsync = ref.watch(savingsGoalsListNotifierProvider);

  return goalsAsync.maybeWhen(
    data: (goals) =>
        goals.map((g) => FinancialCalculator.calculateGoalProgress(g)).toList(),
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
    FutureProvider.family<List<GoalContributionEntity>, String>((
      ref,
      goalId,
    ) async {
      final repository = ref.watch(savingsGoalRepositoryProvider);
      return await repository.getContributionsForGoal(goalId);
    });
