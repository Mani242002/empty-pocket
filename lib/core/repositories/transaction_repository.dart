import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../domain/entities/transaction_entity.dart';

abstract class TransactionRepository {
  Future<List<TransactionEntity>> getAllTransactions();
  Future<List<TransactionEntity>> getTransactionsPaginated({
    int limit = 50,
    int offset = 0,
  });
  Future<void> addTransaction(TransactionEntity transaction);
  Future<void> updateTransaction(TransactionEntity transaction);
  Future<void> deleteTransaction(String id);
  Future<void> clearAllTransactions();
}

class SqliteTransactionRepository implements TransactionRepository {
  final AppDatabase _db;

  SqliteTransactionRepository(this._db);

  @override
  Future<List<TransactionEntity>> getAllTransactions() {
    return _db.getAllTransactions();
  }

  @override
  Future<List<TransactionEntity>> getTransactionsPaginated({
    int limit = 50,
    int offset = 0,
  }) {
    return _db.getTransactionsPaginated(limit: limit, offset: offset);
  }

  @override
  Future<void> addTransaction(TransactionEntity transaction) async {
    await _db.insertTransaction(transaction);
  }

  @override
  Future<void> updateTransaction(TransactionEntity transaction) async {
    await _db.updateTransaction(transaction);
  }

  @override
  Future<void> deleteTransaction(String id) async {
    await _db.deleteTransaction(id);
  }

  @override
  Future<void> clearAllTransactions() async {
    await _db.clearAllTransactions();
  }
}

class InMemoryTransactionRepository implements TransactionRepository {
  final List<TransactionEntity> _transactions = [];

  InMemoryTransactionRepository([List<TransactionEntity>? initial]) {
    if (initial != null) {
      _transactions.addAll(initial);
    }
  }

  @override
  Future<List<TransactionEntity>> getAllTransactions() async {
    return List<TransactionEntity>.from(_transactions)
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  @override
  Future<List<TransactionEntity>> getTransactionsPaginated({
    int limit = 50,
    int offset = 0,
  }) async {
    final sorted = List<TransactionEntity>.from(_transactions)
      ..sort((a, b) => b.date.compareTo(a.date));
    if (offset >= sorted.length) return [];
    final end = (offset + limit < sorted.length) ? offset + limit : sorted.length;
    return sorted.sublist(offset, end);
  }

  @override
  Future<void> addTransaction(TransactionEntity transaction) async {
    _transactions.removeWhere((t) => t.id == transaction.id);
    _transactions.add(transaction);
  }

  @override
  Future<void> updateTransaction(TransactionEntity transaction) async {
    final index = _transactions.indexWhere((t) => t.id == transaction.id);
    if (index != -1) {
      _transactions[index] = transaction;
    } else {
      _transactions.add(transaction);
    }
  }

  @override
  Future<void> deleteTransaction(String id) async {
    _transactions.removeWhere((t) => t.id == id);
  }

  @override
  Future<void> clearAllTransactions() async {
    _transactions.clear();
  }
}

/// App Database Provider - Always returns the shared singleton instance
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase.instance;
});

/// Transaction Repository Provider
final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return SqliteTransactionRepository(db);
});
