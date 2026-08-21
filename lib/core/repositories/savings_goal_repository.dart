import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../domain/entities/savings_goal_entity.dart';
import 'transaction_repository.dart';

abstract class SavingsGoalRepository {
  Future<List<SavingsGoalEntity>> getAllGoals();
  Future<void> saveGoal(SavingsGoalEntity goal);
  Future<void> deleteGoal(String id);
  Future<void> addContribution(GoalContributionEntity contribution);
  Future<List<GoalContributionEntity>> getContributionsForGoal(String goalId);
}

class SqliteSavingsGoalRepository implements SavingsGoalRepository {
  final AppDatabase _db;

  SqliteSavingsGoalRepository(this._db);

  @override
  Future<List<SavingsGoalEntity>> getAllGoals() {
    return _db.getAllSavingsGoals();
  }

  @override
  Future<void> saveGoal(SavingsGoalEntity goal) async {
    await _db.insertSavingsGoal(goal);
  }

  @override
  Future<void> deleteGoal(String id) async {
    await _db.deleteSavingsGoal(id);
  }

  @override
  Future<void> addContribution(GoalContributionEntity contribution) async {
    await _db.insertGoalContribution(contribution);
  }

  @override
  Future<List<GoalContributionEntity>> getContributionsForGoal(String goalId) {
    return _db.getContributionsForGoal(goalId);
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
    if (initialContributions != null) _contributions.addAll(initialContributions);
  }

  @override
  Future<List<SavingsGoalEntity>> getAllGoals() async {
    return List<SavingsGoalEntity>.from(_goals);
  }

  @override
  Future<void> saveGoal(SavingsGoalEntity goal) async {
    _goals.removeWhere((g) => g.id == goal.id);
    _goals.add(goal);
  }

  @override
  Future<void> deleteGoal(String id) async {
    _goals.removeWhere((g) => g.id == id);
    _contributions.removeWhere((c) => c.goalId == id);
  }

  @override
  Future<void> addContribution(GoalContributionEntity contribution) async {
    _contributions.add(contribution);
  }

  @override
  Future<List<GoalContributionEntity>> getContributionsForGoal(String goalId) async {
    return _contributions.where((c) => c.goalId == goalId).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }
}

final savingsGoalRepositoryProvider = Provider<SavingsGoalRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return SqliteSavingsGoalRepository(db);
});
