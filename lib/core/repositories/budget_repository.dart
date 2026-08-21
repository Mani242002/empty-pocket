import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../domain/entities/budget_entity.dart';
import 'transaction_repository.dart';

abstract class BudgetRepository {
  Future<List<BudgetEntity>> getBudgetsForMonth(DateTime month);
  Future<List<BudgetEntity>> getAllBudgets();
  Future<void> saveBudget(BudgetEntity budget);
  Future<void> deleteBudget(String id);
}

class SqliteBudgetRepository implements BudgetRepository {
  final AppDatabase _db;

  SqliteBudgetRepository(this._db);

  @override
  Future<List<BudgetEntity>> getBudgetsForMonth(DateTime month) {
    return _db.getBudgetsForMonth(month);
  }

  @override
  Future<List<BudgetEntity>> getAllBudgets() {
    return _db.getAllBudgets();
  }

  @override
  Future<void> saveBudget(BudgetEntity budget) async {
    await _db.insertBudget(budget);
  }

  @override
  Future<void> deleteBudget(String id) async {
    await _db.deleteBudget(id);
  }
}

class InMemoryBudgetRepository implements BudgetRepository {
  final List<BudgetEntity> _budgets = [];

  InMemoryBudgetRepository([List<BudgetEntity>? initial]) {
    if (initial != null) {
      _budgets.addAll(initial);
    }
  }

  @override
  Future<List<BudgetEntity>> getBudgetsForMonth(DateTime month) async {
    return _budgets.where((b) {
      return b.month.year == month.year && b.month.month == month.month;
    }).toList();
  }

  @override
  Future<List<BudgetEntity>> getAllBudgets() async {
    return List<BudgetEntity>.from(_budgets);
  }

  @override
  Future<void> saveBudget(BudgetEntity budget) async {
    _budgets.removeWhere((b) =>
        b.id == budget.id ||
        (b.category.toLowerCase() == budget.category.toLowerCase() &&
            b.month.year == budget.month.year &&
            b.month.month == budget.month.month));
    _budgets.add(budget);
  }

  @override
  Future<void> deleteBudget(String id) async {
    _budgets.removeWhere((b) => b.id == id);
  }
}

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return SqliteBudgetRepository(db);
});
