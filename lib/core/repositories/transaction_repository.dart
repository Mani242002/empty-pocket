import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../domain/entities/transaction_entity.dart';

abstract class TransactionRepository {
  Future<List<TransactionEntity>> getAllTransactions();
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

/// App Database Provider
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

/// Transaction Repository Provider
final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return SqliteTransactionRepository(db);
});
