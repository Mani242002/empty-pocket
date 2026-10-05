import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../domain/entities/transaction_entity.dart';
import '../domain/entities/bank_account_entity.dart';
import '../domain/entities/credit_card_entity.dart';
import '../domain/entities/savings_goal_entity.dart';
import '../domain/entities/debt_entity.dart';

abstract class TransactionRepository {
  Future<List<TransactionEntity>> getAllTransactions();
  Future<List<TransactionEntity>> getTransactionsPaginated({
    int limit = 50,
    int offset = 0,
  });
  Future<void> addTransaction(
    TransactionEntity transaction, {
    DatabaseExecutor? executor,
  });
  Future<void> addTransactions(List<TransactionEntity> transactions);
  Future<void> updateTransaction(
    TransactionEntity transaction, {
    DatabaseExecutor? executor,
  });
  Future<void> deleteTransaction(String id, {DatabaseExecutor? executor});
  Future<void> clearAllTransactions();

  /// Atomically saves a transaction (add or edit) and syncs ledger accounts/cards, savings goals, and debts
  Future<void> saveTransactionAtomic({
    required TransactionEntity transaction,
    TransactionEntity? previousTransaction,
    Map<String, double>? multiGoalAllocations,
    String? multiGoalSourceAccountId,
    DatabaseExecutor? executor,
  });

  /// Atomically deletes a transaction and reverts its ledger balance impact
  Future<void> deleteTransactionAtomic(String id, {DatabaseExecutor? executor});

  /// Atomically settles multiple shared expenses
  Future<void> settleSharedExpensesAtomic({
    required List<TransactionEntity> updatedOriginals,
    required TransactionEntity settlementTransaction,
    List<TransactionEntity>? additionalTransactions,
    DatabaseExecutor? executor,
  });

  /// Atomically deletes a settlement transaction and updates original transactions
  Future<void> deleteSettlementTransactionAtomic({
    required String settlementTransactionId,
    required List<TransactionEntity> updatedOriginals,
    DatabaseExecutor? executor,
  });

  /// Atomically transfers funds between accounts
  Future<void> performTransferAtomic({
    required BankAccountEntity fromAccount,
    required BankAccountEntity toAccount,
    required double amount,
    required TransactionEntity transaction,
    DatabaseExecutor? executor,
  });

  /// Atomically pays a credit card bill
  Future<void> payCreditCardBillAtomic({
    required BankAccountEntity fromAccount,
    required CreditCardEntity creditCard,
    required double amount,
    required TransactionEntity transaction,
    DatabaseExecutor? executor,
  });

  /// Atomically contributes to a savings goal
  Future<void> addSavingsGoalContributionAtomic({
    required SavingsGoalEntity goal,
    required double amount,
    String? notes,
    bool logAsTransaction = true,
    String paymentSource = 'Bank Account',
    String? accountId,
    TransactionEntity? transaction,
    DatabaseExecutor? executor,
  });

  /// Atomically records a debt payment
  Future<void> recordDebtPaymentAtomic({
    required DebtEntity debt,
    required double amount,
    double principalPortion = 0.0,
    double interestPortion = 0.0,
    String? notes,
    bool logAsTransaction = true,
    String paymentSource = 'Bank Account',
    String? accountId,
    TransactionEntity? transaction,
    DatabaseExecutor? executor,
  });
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
  Future<void> addTransaction(
    TransactionEntity transaction, {
    DatabaseExecutor? executor,
  }) async {
    await _db.insertTransaction(transaction, executor: executor);
  }

  @override
  Future<void> addTransactions(List<TransactionEntity> transactions) async {
    await _db.batchInsertTransactions(transactions);
  }

  @override
  Future<void> updateTransaction(
    TransactionEntity transaction, {
    DatabaseExecutor? executor,
  }) async {
    await _db.updateTransaction(transaction, executor: executor);
  }

  @override
  Future<void> deleteTransaction(
    String id, {
    DatabaseExecutor? executor,
  }) async {
    await _db.deleteTransaction(id, executor: executor);
  }

  @override
  Future<void> clearAllTransactions() async {
    await _db.clearAllTransactions();
  }

  @override
  Future<void> saveTransactionAtomic({
    required TransactionEntity transaction,
    TransactionEntity? previousTransaction,
    Map<String, double>? multiGoalAllocations,
    String? multiGoalSourceAccountId,
    DatabaseExecutor? executor,
  }) async {
    await _db.saveTransactionAtomic(
      transaction: transaction,
      previousTransaction: previousTransaction,
      multiGoalAllocations: multiGoalAllocations,
      multiGoalSourceAccountId: multiGoalSourceAccountId,
      executor: executor,
    );
  }

  @override
  Future<void> deleteTransactionAtomic(
    String id, {
    DatabaseExecutor? executor,
  }) async {
    await _db.deleteTransactionAtomic(id, executor: executor);
  }

  @override
  Future<void> settleSharedExpensesAtomic({
    required List<TransactionEntity> updatedOriginals,
    required TransactionEntity settlementTransaction,
    List<TransactionEntity>? additionalTransactions,
    DatabaseExecutor? executor,
  }) async {
    await _db.settleSharedExpensesAtomic(
      updatedOriginals: updatedOriginals,
      settlementTransaction: settlementTransaction,
      additionalTransactions: additionalTransactions,
      executor: executor,
    );
  }

  @override
  Future<void> deleteSettlementTransactionAtomic({
    required String settlementTransactionId,
    required List<TransactionEntity> updatedOriginals,
    DatabaseExecutor? executor,
  }) async {
    await _db.deleteSettlementTransactionAtomic(
      settlementTransactionId: settlementTransactionId,
      updatedOriginals: updatedOriginals,
      executor: executor,
    );
  }

  @override
  Future<void> performTransferAtomic({
    required BankAccountEntity fromAccount,
    required BankAccountEntity toAccount,
    required double amount,
    required TransactionEntity transaction,
    DatabaseExecutor? executor,
  }) async {
    await _db.performTransferAtomic(
      fromAccount: fromAccount,
      toAccount: toAccount,
      amount: amount,
      transaction: transaction,
      executor: executor,
    );
  }

  @override
  Future<void> payCreditCardBillAtomic({
    required BankAccountEntity fromAccount,
    required CreditCardEntity creditCard,
    required double amount,
    required TransactionEntity transaction,
    DatabaseExecutor? executor,
  }) async {
    await _db.payCreditCardBillAtomic(
      fromAccount: fromAccount,
      creditCard: creditCard,
      amount: amount,
      transaction: transaction,
      executor: executor,
    );
  }

  @override
  Future<void> addSavingsGoalContributionAtomic({
    required SavingsGoalEntity goal,
    required double amount,
    String? notes,
    bool logAsTransaction = true,
    String paymentSource = 'Bank Account',
    String? accountId,
    TransactionEntity? transaction,
    DatabaseExecutor? executor,
  }) async {
    await _db.addSavingsGoalContributionAtomic(
      goal: goal,
      amount: amount,
      notes: notes,
      logAsTransaction: logAsTransaction,
      paymentSource: paymentSource,
      accountId: accountId,
      transaction: transaction,
      executor: executor,
    );
  }

  @override
  Future<void> recordDebtPaymentAtomic({
    required DebtEntity debt,
    required double amount,
    double principalPortion = 0.0,
    double interestPortion = 0.0,
    String? notes,
    bool logAsTransaction = true,
    String paymentSource = 'Bank Account',
    String? accountId,
    TransactionEntity? transaction,
    DatabaseExecutor? executor,
  }) async {
    await _db.recordDebtPaymentAtomic(
      debt: debt,
      amount: amount,
      principalPortion: principalPortion,
      interestPortion: interestPortion,
      notes: notes,
      logAsTransaction: logAsTransaction,
      paymentSource: paymentSource,
      accountId: accountId,
      transaction: transaction,
      executor: executor,
    );
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
    final end = (offset + limit < sorted.length)
        ? offset + limit
        : sorted.length;
    return sorted.sublist(offset, end);
  }

  @override
  Future<void> addTransaction(
    TransactionEntity transaction, {
    DatabaseExecutor? executor,
  }) async {
    _transactions.removeWhere((t) => t.id == transaction.id);
    _transactions.add(transaction);
  }

  @override
  Future<void> addTransactions(List<TransactionEntity> transactions) async {
    final ids = transactions.map((t) => t.id).toSet();
    _transactions.removeWhere((t) => ids.contains(t.id));
    _transactions.addAll(transactions);
  }

  @override
  Future<void> updateTransaction(
    TransactionEntity transaction, {
    DatabaseExecutor? executor,
  }) async {
    final index = _transactions.indexWhere((t) => t.id == transaction.id);
    if (index != -1) {
      _transactions[index] = transaction;
    } else {
      _transactions.add(transaction);
    }
  }

  @override
  Future<void> deleteTransaction(
    String id, {
    DatabaseExecutor? executor,
  }) async {
    _transactions.removeWhere((t) => t.id == id);
  }

  @override
  Future<void> clearAllTransactions() async {
    _transactions.clear();
  }

  @override
  Future<void> saveTransactionAtomic({
    required TransactionEntity transaction,
    TransactionEntity? previousTransaction,
    Map<String, double>? multiGoalAllocations,
    String? multiGoalSourceAccountId,
    DatabaseExecutor? executor,
  }) async {
    if (previousTransaction != null) {
      await updateTransaction(transaction);
    } else {
      await addTransaction(transaction);
    }
  }

  @override
  Future<void> deleteTransactionAtomic(
    String id, {
    DatabaseExecutor? executor,
  }) async {
    await deleteTransaction(id);
  }

  @override
  Future<void> settleSharedExpensesAtomic({
    required List<TransactionEntity> updatedOriginals,
    required TransactionEntity settlementTransaction,
    List<TransactionEntity>? additionalTransactions,
    DatabaseExecutor? executor,
  }) async {
    for (final orig in updatedOriginals) {
      await updateTransaction(orig);
    }
    await addTransaction(settlementTransaction);
    if (additionalTransactions != null) {
      for (final addTx in additionalTransactions) {
        await addTransaction(addTx);
      }
    }
  }

  @override
  Future<void> deleteSettlementTransactionAtomic({
    required String settlementTransactionId,
    required List<TransactionEntity> updatedOriginals,
    DatabaseExecutor? executor,
  }) async {
    for (final orig in updatedOriginals) {
      await updateTransaction(orig);
    }
    await deleteTransaction(settlementTransactionId);
  }

  @override
  Future<void> performTransferAtomic({
    required BankAccountEntity fromAccount,
    required BankAccountEntity toAccount,
    required double amount,
    required TransactionEntity transaction,
    DatabaseExecutor? executor,
  }) async {
    await addTransaction(transaction);
  }

  @override
  Future<void> payCreditCardBillAtomic({
    required BankAccountEntity fromAccount,
    required CreditCardEntity creditCard,
    required double amount,
    required TransactionEntity transaction,
    DatabaseExecutor? executor,
  }) async {
    await addTransaction(transaction);
  }

  @override
  Future<void> addSavingsGoalContributionAtomic({
    required SavingsGoalEntity goal,
    required double amount,
    String? notes,
    bool logAsTransaction = true,
    String paymentSource = 'Bank Account',
    String? accountId,
    TransactionEntity? transaction,
    DatabaseExecutor? executor,
  }) async {
    if (transaction != null) {
      await addTransaction(transaction);
    }
  }

  @override
  Future<void> recordDebtPaymentAtomic({
    required DebtEntity debt,
    required double amount,
    double principalPortion = 0.0,
    double interestPortion = 0.0,
    String? notes,
    bool logAsTransaction = true,
    String paymentSource = 'Bank Account',
    String? accountId,
    TransactionEntity? transaction,
    DatabaseExecutor? executor,
  }) async {
    if (transaction != null) {
      await addTransaction(transaction);
    }
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
