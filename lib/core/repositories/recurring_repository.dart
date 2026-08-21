import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../domain/entities/recurring_expense_entity.dart';
import 'transaction_repository.dart';

abstract class RecurringRepository {
  Future<List<RecurringExpenseEntity>> getAllRecurringExpenses();
  Future<void> saveRecurringExpense(RecurringExpenseEntity item);
  Future<void> deleteRecurringExpense(String id);
}

class SqliteRecurringRepository implements RecurringRepository {
  final AppDatabase _db;

  SqliteRecurringRepository(this._db);

  @override
  Future<List<RecurringExpenseEntity>> getAllRecurringExpenses() {
    return _db.getAllRecurringExpenses();
  }

  @override
  Future<void> saveRecurringExpense(RecurringExpenseEntity item) async {
    await _db.insertRecurringExpense(item);
  }

  @override
  Future<void> deleteRecurringExpense(String id) async {
    await _db.deleteRecurringExpense(id);
  }
}

class InMemoryRecurringRepository implements RecurringRepository {
  final List<RecurringExpenseEntity> _items = [];

  InMemoryRecurringRepository([List<RecurringExpenseEntity>? initial]) {
    if (initial != null) {
      _items.addAll(initial);
    }
  }

  @override
  Future<List<RecurringExpenseEntity>> getAllRecurringExpenses() async {
    return List<RecurringExpenseEntity>.from(_items)
      ..sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));
  }

  @override
  Future<void> saveRecurringExpense(RecurringExpenseEntity item) async {
    _items.removeWhere((i) => i.id == item.id);
    _items.add(item);
  }

  @override
  Future<void> deleteRecurringExpense(String id) async {
    _items.removeWhere((i) => i.id == id);
  }
}

final recurringRepositoryProvider = Provider<RecurringRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return SqliteRecurringRepository(db);
});
