import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../domain/entities/savings_goal_entity.dart';
import '../domain/entities/transaction_entity.dart';
import 'transaction_repository.dart';

abstract class SavingsGoalRepository {
  Future<List<SavingsGoalEntity>> getAllGoals();
  Future<void> saveGoal(SavingsGoalEntity goal, {DatabaseExecutor? executor});
  Future<void> deleteGoal(String id, {DatabaseExecutor? executor});
  Future<void> addContribution(
    GoalContributionEntity contribution, {
    DatabaseExecutor? executor,
  });
  Future<void> deleteContribution(String id, {DatabaseExecutor? executor});
  Future<List<GoalContributionEntity>> getContributionsForGoal(String goalId);

  /// Atomically creates a savings goal with an optional initial deposit
  Future<void> createSavingsGoalAtomic({
    required SavingsGoalEntity goal,
    required double initialAmount,
    bool deductFromAccount = true,
    String? accountId,
    String paymentSource = 'Bank Account',
    TransactionEntity? transaction,
    DatabaseExecutor? executor,
  });
}

class SqliteSavingsGoalRepository implements SavingsGoalRepository {
  final AppDatabase _db;

  SqliteSavingsGoalRepository(this._db);

  @override
  Future<List<SavingsGoalEntity>> getAllGoals() {
    return _db.getAllSavingsGoals();
  }

  @override
  Future<void> saveGoal(
    SavingsGoalEntity goal, {
    DatabaseExecutor? executor,
  }) async {
    await _db.insertSavingsGoal(goal, executor: executor);
  }

  @override
  Future<void> deleteGoal(String id, {DatabaseExecutor? executor}) async {
    await _db.deleteSavingsGoal(id, executor: executor);
  }

  @override
  Future<void> addContribution(
    GoalContributionEntity contribution, {
    DatabaseExecutor? executor,
  }) async {
    await _db.insertGoalContribution(contribution, executor: executor);
  }

  @override
  Future<void> deleteContribution(
    String id, {
    DatabaseExecutor? executor,
  }) async {
    await _db.deleteGoalContribution(id, executor: executor);
  }

  @override
  Future<List<GoalContributionEntity>> getContributionsForGoal(String goalId) {
    return _db.getContributionsForGoal(goalId);
  }

  @override
  Future<void> createSavingsGoalAtomic({
    required SavingsGoalEntity goal,
    required double initialAmount,
    bool deductFromAccount = true,
    String? accountId,
    String paymentSource = 'Bank Account',
    TransactionEntity? transaction,
    DatabaseExecutor? executor,
  }) async {
    await _db.createSavingsGoalAtomic(
      goal: goal,
      initialAmount: initialAmount,
      deductFromAccount: deductFromAccount,
      accountId: accountId,
      paymentSource: paymentSource,
      transaction: transaction,
      executor: executor,
    );
  }
}

class InMemorySavingsGoalRepository implements SavingsGoalRepository {
  final List<SavingsGoalEntity> _goals = [];
  final List<GoalContributionEntity> _contributions = [];

  InMemorySavingsGoalRepository([
    List<SavingsGoalEntity>? initialGoals,
    List<GoalContributionEntity>? initialContributions,
  ]) {
    if (initialGoals != null) _goals.addAll(initialGoals);
    if (initialContributions != null) {
      _contributions.addAll(initialContributions);
    }
  }

  @override
  Future<List<SavingsGoalEntity>> getAllGoals() async {
    return List<SavingsGoalEntity>.from(_goals);
  }

  @override
  Future<void> saveGoal(
    SavingsGoalEntity goal, {
    DatabaseExecutor? executor,
  }) async {
    _goals.removeWhere((g) => g.id == goal.id);
    _goals.add(goal);
  }

  @override
  Future<void> deleteGoal(String id, {DatabaseExecutor? executor}) async {
    _goals.removeWhere((g) => g.id == id);
    _contributions.removeWhere((c) => c.goalId == id);
  }

  @override
  Future<void> addContribution(
    GoalContributionEntity contribution, {
    DatabaseExecutor? executor,
  }) async {
    _contributions.add(contribution);
  }

  @override
  Future<void> deleteContribution(
    String id, {
    DatabaseExecutor? executor,
  }) async {
    _contributions.removeWhere((c) => c.id == id);
  }

  @override
  Future<List<GoalContributionEntity>> getContributionsForGoal(
    String goalId,
  ) async {
    return _contributions.where((c) => c.goalId == goalId).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  @override
  Future<void> createSavingsGoalAtomic({
    required SavingsGoalEntity goal,
    required double initialAmount,
    bool deductFromAccount = true,
    String? accountId,
    String paymentSource = 'Bank Account',
    TransactionEntity? transaction,
    DatabaseExecutor? executor,
  }) async {
    final effectiveAmount = initialAmount > 0 ? initialAmount : 0.0;
    final newCurrentAmount = goal.currentAmount + effectiveAmount;
    final newStatus =
        (newCurrentAmount >= goal.targetAmount && goal.targetAmount > 0)
        ? GoalStatus.completed
        : goal.status;
    final finalGoal = goal.copyWith(
      currentAmount: newCurrentAmount,
      status: newStatus,
      updatedAt: DateTime.now(),
    );
    await saveGoal(finalGoal);

    if (effectiveAmount > 0) {
      final now = DateTime.now();
      final contribution = GoalContributionEntity(
        id: const Uuid().v4(),
        goalId: goal.id,
        amount: effectiveAmount,
        date: now,
        notes: 'Initial savings deposit for "${goal.title}"',
        sourceAccountId: deductFromAccount ? accountId : null,
        transactionId: transaction?.id,
        createdAt: now,
      );
      await addContribution(contribution);
    }
  }
}

final savingsGoalRepositoryProvider = Provider<SavingsGoalRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return SqliteSavingsGoalRepository(db);
});
