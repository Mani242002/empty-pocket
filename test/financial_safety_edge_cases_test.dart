import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:empty_pocket/core/database/app_database.dart';
import 'package:empty_pocket/core/domain/entities/bank_account_entity.dart';
import 'package:empty_pocket/core/domain/entities/savings_goal_entity.dart';
import 'package:empty_pocket/core/domain/entities/debt_entity.dart';
import 'package:empty_pocket/core/domain/entities/transaction_entity.dart';
import 'package:empty_pocket/core/domain/entities/category_constants.dart';
import 'package:empty_pocket/core/domain/entities/recurring_expense_entity.dart';
import 'package:empty_pocket/core/domain/entities/investment_entity.dart';
import 'package:empty_pocket/core/domain/entities/credit_card_entity.dart';
import 'package:empty_pocket/core/domain/entities/split_person_share.dart';
import 'package:empty_pocket/core/repositories/transaction_repository.dart';
import 'package:empty_pocket/core/utilities/split_helper.dart';
import 'package:empty_pocket/features/transactions/presentation/state/transactions_provider.dart';

class MockTestTransactionRepository implements TransactionRepository {
  final Map<String, TransactionEntity> _db = {};

  @override
  Future<List<TransactionEntity>> getAllTransactions() async =>
      _db.values.toList();

  @override
  Future<void> addTransaction(
    TransactionEntity tx, {
    DatabaseExecutor? executor,
  }) async => _db[tx.id] = tx;

  @override
  Future<void> addTransactions(List<TransactionEntity> transactions) async {
    for (final tx in transactions) {
      _db[tx.id] = tx;
    }
  }

  @override
  Future<void> updateTransaction(
    TransactionEntity tx, {
    DatabaseExecutor? executor,
  }) async => _db[tx.id] = tx;

  @override
  Future<void> deleteTransaction(
    String id, {
    DatabaseExecutor? executor,
  }) async => _db.remove(id);

  @override
  Future<void> clearAllTransactions() async => _db.clear();

  @override
  Future<List<TransactionEntity>> getTransactionsPaginated({
    int limit = 50,
    int offset = 0,
  }) async => _db.values.skip(offset).take(limit).toList();

  @override
  Future<void> saveTransactionAtomic({
    required TransactionEntity transaction,
    TransactionEntity? previousTransaction,
    Map<String, double>? multiGoalAllocations,
    String? multiGoalSourceAccountId,
    DatabaseExecutor? executor,
  }) async {
    _db[transaction.id] = transaction;
  }

  @override
  Future<void> deleteTransactionAtomic(
    String id, {
    DatabaseExecutor? executor,
  }) async => _db.remove(id);

  @override
  Future<void> settleSharedExpensesAtomic({
    required List<TransactionEntity> updatedOriginals,
    required TransactionEntity settlementTransaction,
    List<TransactionEntity>? additionalTransactions,
    DatabaseExecutor? executor,
  }) async {
    for (final orig in updatedOriginals) {
      _db[orig.id] = orig;
    }
    _db[settlementTransaction.id] = settlementTransaction;
  }

  @override
  Future<void> deleteSettlementTransactionAtomic({
    required String settlementTransactionId,
    required List<TransactionEntity> updatedOriginals,
    DatabaseExecutor? executor,
  }) async {
    _db.remove(settlementTransactionId);
    for (final orig in updatedOriginals) {
      _db[orig.id] = orig;
    }
  }

  @override
  Future<void> performTransferAtomic({
    required BankAccountEntity fromAccount,
    required BankAccountEntity toAccount,
    required double amount,
    required TransactionEntity transaction,
    DatabaseExecutor? executor,
  }) async {
    _db[transaction.id] = transaction;
  }

  @override
  Future<void> payCreditCardBillAtomic({
    required BankAccountEntity fromAccount,
    required CreditCardEntity creditCard,
    required double amount,
    required TransactionEntity transaction,
    DatabaseExecutor? executor,
  }) async {
    _db[transaction.id] = transaction;
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
    if (transaction != null) _db[transaction.id] = transaction;
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
    if (transaction != null) _db[transaction.id] = transaction;
  }
}

class TestFakeBatch implements Batch {
  final List<Future<void> Function()> _operations = [];
  final TestFakeDatabaseExecutor _executor;

  TestFakeBatch(this._executor);

  @override
  void insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    _operations.add(
      () =>
          _executor.insert(table, values, conflictAlgorithm: conflictAlgorithm),
    );
  }

  @override
  Future<List<Object?>> commit({
    bool? exclusive,
    bool? noResult,
    bool? continueOnError,
  }) async {
    for (final op in _operations) {
      await op();
    }
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestFakeTransaction extends TestFakeDatabaseExecutor
    implements Transaction {
  TestFakeTransaction(Map<String, List<Map<String, dynamic>>> sharedTables) {
    tables.clear();
    for (final entry in sharedTables.entries) {
      tables[entry.key] = entry.value;
    }
  }
}

class TestFakeDatabaseExecutor implements Database {
  final Map<String, List<Map<String, dynamic>>> tables = {
    AppDatabase.tableTransactions: [],
    AppDatabase.tableBankAccounts: [],
    AppDatabase.tableCreditCards: [],
    AppDatabase.tableSavingsGoals: [],
    AppDatabase.tableGoalContributions: [],
    AppDatabase.tableDebts: [],
    AppDatabase.tableDebtPayments: [],
    AppDatabase.tableBudgets: [],
    AppDatabase.tableInvestments: [],
    AppDatabase.tableRecurring: [],
    AppDatabase.tableChatSessions: [],
    AppDatabase.tableChatMessages: [],
    AppDatabase.tableAiReports: [],
  };

  @override
  Database get database => this;

  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction txn) action, {
    bool? exclusive,
  }) async {
    // Deep clone snapshot of all tables for rollback
    final snapshot = <String, List<Map<String, dynamic>>>{};
    for (final entry in tables.entries) {
      snapshot[entry.key] = entry.value
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    }

    final txn = TestFakeTransaction(tables);
    try {
      final result = await action(txn);
      return result;
    } catch (e) {
      // Rollback: restore all tables to pre-transaction snapshot
      tables.clear();
      for (final entry in snapshot.entries) {
        tables[entry.key] = entry.value
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
      }
      rethrow;
    }
  }

  @override
  Batch batch() => TestFakeBatch(this);

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) async {}

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    final list = tables.putIfAbsent(table, () => []);
    final mutableValues = Map<String, dynamic>.from(values);
    if (mutableValues.containsKey('id')) {
      if (conflictAlgorithm == ConflictAlgorithm.abort &&
          list.any((row) => row['id'] == mutableValues['id'])) {
        throw StateError('UNIQUE constraint failed: $table.id');
      }
      list.removeWhere((row) => row['id'] == mutableValues['id']);
    }
    list.add(mutableValues);
    return 1;
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final list = tables[table] ?? [];
    var results = list
        .where((row) {
          if (where == null) return true;
          if (where == 'id = ?' && whereArgs != null && whereArgs.isNotEmpty) {
            return row['id'] == whereArgs.first;
          }
          if (where == 'transaction_id = ?' &&
              whereArgs != null &&
              whereArgs.isNotEmpty) {
            return row['transaction_id'] == whereArgs.first;
          }
          if (where == 'goal_id = ? AND transaction_id IS NULL' &&
              whereArgs != null &&
              whereArgs.isNotEmpty) {
            return row['goal_id'] == whereArgs.first &&
                (row['transaction_id'] == null || row['transaction_id'] == '');
          }
          if (where == 'debt_id = ? AND transaction_id IS NULL' &&
              whereArgs != null &&
              whereArgs.isNotEmpty) {
            return row['debt_id'] == whereArgs.first &&
                (row['transaction_id'] == null || row['transaction_id'] == '');
          }
          if (where == 'goal_id = ?' &&
              whereArgs != null &&
              whereArgs.isNotEmpty) {
            return row['goal_id'] == whereArgs.first;
          }
          if (where == 'debt_id = ?' &&
              whereArgs != null &&
              whereArgs.isNotEmpty) {
            return row['debt_id'] == whereArgs.first;
          }
          return true;
        })
        .map((row) {
          if (columns == null) return Map<String, Object?>.from(row);
          final filtered = <String, Object?>{};
          for (final col in columns) {
            if (row.containsKey(col)) filtered[col] = row[col];
          }
          return filtered;
        })
        .toList();

    if (offset != null && offset > 0) {
      results = results.skip(offset).toList();
    }
    if (limit != null && limit > 0) {
      results = results.take(limit).toList();
    }
    return results;
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    final list = tables[table] ?? [];
    int count = 0;
    for (int i = 0; i < list.length; i++) {
      final row = list[i];
      bool match = false;
      if (where == null) {
        match = true;
      } else if (where == 'id = ?' &&
          whereArgs != null &&
          whereArgs.isNotEmpty) {
        match = row['id'] == whereArgs.first;
      } else if (where == 'transaction_id = ?' &&
          whereArgs != null &&
          whereArgs.isNotEmpty) {
        match = row['transaction_id'] == whereArgs.first;
      }
      if (match) {
        final updated = Map<String, dynamic>.from(row)..addAll(values);
        list[i] = updated;
        count++;
      }
    }
    return count;
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final list = tables[table] ?? [];
    final before = list.length;
    list.removeWhere((row) {
      if (where == null) return true;
      if (where == 'id = ?' && whereArgs != null && whereArgs.isNotEmpty) {
        return row['id'] == whereArgs.first;
      }
      if (where == 'transaction_id = ?' &&
          whereArgs != null &&
          whereArgs.isNotEmpty) {
        return row['transaction_id'] == whereArgs.first;
      }
      return false;
    });
    return before - list.length;
  }

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) async {
    if (sql.contains('UPDATE') &&
        sql.contains('SET current_balance = current_balance + ?') &&
        arguments != null) {
      final delta = (arguments[0] as num).toDouble();
      final id = arguments[1] as String;
      final accounts = tables[AppDatabase.tableBankAccounts] ?? [];
      for (final acc in accounts) {
        if (acc['id'] == id) {
          final cur = (acc['current_balance'] as num).toDouble();
          acc['current_balance'] = cur + delta;
          return 1;
        }
      }
    }
    return 0;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Financial Safety & Integrity Edge Cases', () {
    late TestFakeDatabaseExecutor fakeExecutor;
    late AppDatabase db;

    setUp(() {
      fakeExecutor = TestFakeDatabaseExecutor();
      db = AppDatabase.forTesting(fakeExecutor);
    });

    test('Debt payment edit preserves principal/interest split without over-reducing debt', () async {
      final now = DateTime.now();
      final debt = DebtEntity(
        id: 'debt-split-1',
        title: 'Home Loan',
        principalAmount: 10000.0,
        remainingAmount: 10000.0,
        interestRate: 8.5,
        monthlyEmi: 100.0,
        startDate: now,
        type: DebtType.homeLoan,
        status: DebtStatus.active,
        createdAt: now,
        updatedAt: now,
      );
      await fakeExecutor.insert(AppDatabase.tableDebts, debt.toMap());

      // 1. Initial Payment: ₹100 payment = ₹80 principal, ₹20 interest
      final txInitial = TransactionEntity(
        id: 'tx-debt-split-1',
        title: 'EMI #1',
        amount: 100.0,
        type: TransactionType.expense,
        category: 'Debt Repayment',
        date: now,
        paymentSource: 'Bank Account',
        linkedEntityId: debt.id,
        createdAt: now,
        updatedAt: now,
      );

      await db.recordDebtPaymentAtomic(
        debt: debt,
        amount: 100.0,
        principalPortion: 80.0,
        interestPortion: 20.0,
        transaction: txInitial,
        executor: fakeExecutor,
      );

      // Verify remaining amount is ₹9,920 (10000 - 80)
      var debtRows = await fakeExecutor.query(
        AppDatabase.tableDebts,
        where: 'id = ?',
        whereArgs: [debt.id],
      );
      expect((debtRows.first['remaining_amount'] as num).toDouble(), 9920.0);

      // Verify payment row has 80 principal and 20 interest
      var paymentRows = await fakeExecutor.query(
        AppDatabase.tableDebtPayments,
        where: 'transaction_id = ?',
        whereArgs: [txInitial.id],
      );
      expect(paymentRows.length, 1);
      expect((paymentRows.first['principal_portion'] as num).toDouble(), 80.0);
      expect((paymentRows.first['interest_portion'] as num).toDouble(), 20.0);

      // 2. User edits the note/title on the transaction (amount remains ₹100)
      final txEditedNote = txInitial.copyWith(
        title: 'EMI #1 - Corrected Note',
        notes: 'Updated note for EMI',
        updatedAt: DateTime.now(),
      );

      await db.saveTransactionAtomic(
        transaction: txEditedNote,
        previousTransaction: txInitial,
        executor: fakeExecutor,
      );

      // CRITICAL CHECK: Editing note must NOT re-apply full ₹100 as principal!
      debtRows = await fakeExecutor.query(
        AppDatabase.tableDebts,
        where: 'id = ?',
        whereArgs: [debt.id],
      );
      expect(
        (debtRows.first['remaining_amount'] as num).toDouble(),
        9920.0,
        reason: 'Editing note should preserve ₹80 principal and NOT reduce balance to ₹9,900',
      );

      paymentRows = await fakeExecutor.query(
        AppDatabase.tableDebtPayments,
        where: 'transaction_id = ?',
        whereArgs: [txInitial.id],
      );
      expect((paymentRows.first['principal_portion'] as num).toDouble(), 80.0);
      expect((paymentRows.first['interest_portion'] as num).toDouble(), 20.0);

      // 3. User edits the amount from ₹100 to ₹200 (should scale split 80%:20% -> 160:40)
      final txEditedAmount = txInitial.copyWith(
        amount: 200.0,
        updatedAt: DateTime.now(),
      );

      await db.saveTransactionAtomic(
        transaction: txEditedAmount,
        previousTransaction: txEditedNote,
        executor: fakeExecutor,
      );

      debtRows = await fakeExecutor.query(
        AppDatabase.tableDebts,
        where: 'id = ?',
        whereArgs: [debt.id],
      );
      expect(
        (debtRows.first['remaining_amount'] as num).toDouble(),
        9840.0,
        reason: 'Scaled 80% principal of ₹200 = ₹160; remaining debt = 10000 - 160 = 9840',
      );

      paymentRows = await fakeExecutor.query(
        AppDatabase.tableDebtPayments,
        where: 'transaction_id = ?',
        whereArgs: [txInitial.id],
      );
      expect((paymentRows.first['principal_portion'] as num).toDouble(), 160.0);
      expect((paymentRows.first['interest_portion'] as num).toDouble(), 40.0);
    });

    test('Unambiguous legacy history matching: rejects ambiguous equal amounts, accepts unique match', () async {
      final now = DateTime.now();
      final goal = SavingsGoalEntity(
        id: 'goal-ambiguous-test',
        title: 'Emergency Fund',
        targetAmount: 10000.0,
        currentAmount: 2000.0,
        category: 'Emergency',
        targetDate: now.add(const Duration(days: 365)),
        createdAt: now,
        updatedAt: now,
      );
      await fakeExecutor.insert(AppDatabase.tableSavingsGoals, goal.toMap());

      // Insert TWO unlinked contributions of identical ₹500 amount
      await fakeExecutor.insert(AppDatabase.tableGoalContributions, {
        'id': 'contrib-1',
        'goal_id': goal.id,
        'amount': 500.0,
        'transaction_id': null,
        'date': now.toIso8601String(),
        'createdAt': now.toIso8601String(),
      });
      await fakeExecutor.insert(AppDatabase.tableGoalContributions, {
        'id': 'contrib-2',
        'goal_id': goal.id,
        'amount': 500.0,
        'transaction_id': null,
        'date': now.toIso8601String(),
        'createdAt': now.toIso8601String(),
      });

      // Legacy transaction without explicit transaction_id on contribution
      final legacyTx = TransactionEntity(
        id: 'tx-legacy-ambig',
        title: 'Legacy Contribution',
        amount: 500.0,
        type: TransactionType.transfer,
        category: 'Savings',
        date: now,
        paymentSource: 'Bank Account',
        linkedEntityId: goal.id,
        createdAt: now,
        updatedAt: now,
      );
      await fakeExecutor.insert(
        AppDatabase.tableTransactions,
        legacyTx.toMap(),
      );

      // Attempt deletion: Because 2 unlinked contributions exist with ₹500, it is AMBIGUOUS
      await db.deleteTransactionAtomic(legacyTx.id, executor: fakeExecutor);

      // Verify aggregate is NOT modified and neither contribution is deleted
      var goalRows = await fakeExecutor.query(
        AppDatabase.tableSavingsGoals,
        where: 'id = ?',
        whereArgs: [goal.id],
      );
      expect(
        (goalRows.first['current_amount'] as num).toDouble(),
        2000.0,
        reason: 'Ambiguous candidates must NOT modify aggregate',
      );
      var contribRows = await fakeExecutor.query(
        AppDatabase.tableGoalContributions,
        where: 'goal_id = ?',
        whereArgs: [goal.id],
      );
      expect(
        contribRows.length,
        2,
        reason: 'Ambiguous candidates must not be arbitrarily deleted',
      );

      // Now remove one contribution so only ONE unambiguous match remains
      await fakeExecutor.delete(
        AppDatabase.tableGoalContributions,
        where: 'id = ?',
        whereArgs: ['contrib-1'],
      );

      // Re-insert legacyTx and delete again
      await fakeExecutor.insert(
        AppDatabase.tableTransactions,
        legacyTx.toMap(),
      );
      await db.deleteTransactionAtomic(legacyTx.id, executor: fakeExecutor);

      // Now exactly 1 candidate matches unambiguously: aggregate should be reverted
      goalRows = await fakeExecutor.query(
        AppDatabase.tableSavingsGoals,
        where: 'id = ?',
        whereArgs: [goal.id],
      );
      expect(
        (goalRows.first['current_amount'] as num).toDouble(),
        1500.0,
        reason: 'Unambiguous single candidate properly reverts goal aggregate',
      );
      contribRows = await fakeExecutor.query(
        AppDatabase.tableGoalContributions,
        where: 'goal_id = ?',
        whereArgs: [goal.id],
      );
      expect(contribRows.length, 0);
    });

    test(
      'logAsTransaction: false does not leave orphaned transaction ID',
      () async {
        final now = DateTime.now();
        final goal = SavingsGoalEntity(
          id: 'goal-no-tx-test',
          title: 'Car Fund',
          targetAmount: 50000.0,
          currentAmount: 1000.0,
          category: 'Vehicle',
          targetDate: now.add(const Duration(days: 365)),
          createdAt: now,
          updatedAt: now,
        );
        await fakeExecutor.insert(AppDatabase.tableSavingsGoals, goal.toMap());

        // Add contribution with logAsTransaction = false
        await db.addSavingsGoalContributionAtomic(
          goal: goal,
          amount: 250.0,
          logAsTransaction: false,
          executor: fakeExecutor,
        );

        final contribRows = await fakeExecutor.query(
          AppDatabase.tableGoalContributions,
          where: 'goal_id = ?',
          whereArgs: [goal.id],
        );
        expect(contribRows.length, 1);
        expect(
          contribRows.first['transaction_id'],
          isNull,
          reason: 'logAsTransaction: false must set transaction_id to null and avoid orphaned IDs',
        );

        final debt = DebtEntity(
          id: 'debt-no-tx-test',
          title: 'Personal Loan',
          principalAmount: 5000.0,
          remainingAmount: 5000.0,
          interestRate: 10.0,
          monthlyEmi: 100.0,
          startDate: now,
          type: DebtType.personalLoan,
          status: DebtStatus.active,
          createdAt: now,
          updatedAt: now,
        );
        await fakeExecutor.insert(AppDatabase.tableDebts, debt.toMap());

        // Record debt payment with logAsTransaction = false
        await db.recordDebtPaymentAtomic(
          debt: debt,
          amount: 200.0,
          logAsTransaction: false,
          executor: fakeExecutor,
        );

        final paymentRows = await fakeExecutor.query(
          AppDatabase.tableDebtPayments,
          where: 'debt_id = ?',
          whereArgs: [debt.id],
        );
        expect(paymentRows.length, 1);
        expect(
          paymentRows.first['transaction_id'],
          isNull,
          reason: 'logAsTransaction: false must set transaction_id to null and avoid orphaned IDs',
        );
      },
    );

    test('deleteSettlementTransactionAtomic atomically restores original transaction and reverts account balance', () async {
      final now = DateTime.now();
      final account = BankAccountEntity(
        id: 'acc-reimb-dest',
        accountName: 'Savings',
        bankName: 'HDFC',
        accountType: AccountType.savings,
        usedFor: 'General',
        initialBalance: 1000.0,
        currentBalance: 1500.0, // Reimbursed 500 was deposited here
        createdAt: now,
        updatedAt: now,
      );
      await fakeExecutor.insert(AppDatabase.tableBankAccounts, account.toMap());

      final origTx = TransactionEntity(
        id: 'tx-shared-orig-1',
        title: 'Team Dinner',
        amount: 1000.0,
        type: TransactionType.expense,
        category: 'Food & Dining',
        date: now,
        paymentSource: 'Cash',
        isShared: true,
        myShareAmount: 500.0,
        reimbursedAmount: 500.0,
        isSettled: true,
        createdAt: now,
        updatedAt: now,
      );
      await fakeExecutor.insert(AppDatabase.tableTransactions, origTx.toMap());

      final settlementTx = TransactionEntity(
        id: 'tx-settlement-reimb-1',
        title: 'Reimbursement: Team Dinner',
        amount: 500.0,
        type: TransactionType.income,
        category: CategoryConstants.categorySharedReimbursement,
        date: now,
        paymentSource: 'Savings',
        accountId: account.id,
        linkedEntityId: origTx.id,
        createdAt: now,
        updatedAt: now,
      );
      await fakeExecutor.insert(
        AppDatabase.tableTransactions,
        settlementTx.toMap(),
      );

      // Rollback definition for original
      final rolledBackOrig = origTx.copyWith(
        reimbursedAmount: 0.0,
        isSettled: false,
        updatedAt: DateTime.now(),
      );

      // Perform atomic delete
      await db.deleteSettlementTransactionAtomic(
        settlementTransactionId: settlementTx.id,
        updatedOriginals: [rolledBackOrig],
        executor: fakeExecutor,
      );

      // 1. Settlement transaction should be deleted
      final settlementRows = await fakeExecutor.query(
        AppDatabase.tableTransactions,
        where: 'id = ?',
        whereArgs: [settlementTx.id],
      );
      expect(settlementRows.isEmpty, true);

      // 2. Account balance should be reverted by -500 (from 1500 -> 1000)
      final accRows = await fakeExecutor.query(
        AppDatabase.tableBankAccounts,
        where: 'id = ?',
        whereArgs: [account.id],
      );
      expect((accRows.first['current_balance'] as num).toDouble(), 1000.0);

      // 3. Original transaction should have rolledBack values
      final origRows = await fakeExecutor.query(
        AppDatabase.tableTransactions,
        where: 'id = ?',
        whereArgs: [origTx.id],
      );
      expect((origRows.first['reimbursed_amount'] as num).toDouble(), 0.0);
      expect(origRows.first['is_settled'], 0);
    });

    test('createSavingsGoalAtomic atomically creates goal, initial deposit, transaction, and adjusts account', () async {
      final now = DateTime.now();
      final account = BankAccountEntity(
        id: 'acc-goal-init',
        accountName: 'Salary Account',
        bankName: 'Axis',
        accountType: AccountType.savings,
        usedFor: 'Salary',
        initialBalance: 5000.0,
        currentBalance: 5000.0,
        createdAt: now,
        updatedAt: now,
      );
      await fakeExecutor.insert(AppDatabase.tableBankAccounts, account.toMap());

      final goal = SavingsGoalEntity(
        id: 'goal-atomic-init-1',
        title: 'MacBook Pro',
        targetAmount: 200000.0,
        currentAmount: 0.0,
        category: 'Gadgets',
        targetDate: now.add(const Duration(days: 365)),
        createdAt: now,
        updatedAt: now,
      );

      await db.createSavingsGoalAtomic(
        goal: goal,
        initialAmount: 25000.0,
        deductFromAccount: true,
        accountId: account.id,
        paymentSource: account.accountName,
        executor: fakeExecutor,
      );

      // Goal created with ₹25,000
      final goalRows = await fakeExecutor.query(
        AppDatabase.tableSavingsGoals,
        where: 'id = ?',
        whereArgs: [goal.id],
      );
      expect(goalRows.length, 1);
      expect((goalRows.first['current_amount'] as num).toDouble(), 25000.0);

      // Bank account deducted by ₹25,000 (from 5000 to -20000)
      final accRows = await fakeExecutor.query(
        AppDatabase.tableBankAccounts,
        where: 'id = ?',
        whereArgs: [account.id],
      );
      expect((accRows.first['current_balance'] as num).toDouble(), -20000.0);

      // Contribution recorded with transaction_id attached
      final contribRows = await fakeExecutor.query(
        AppDatabase.tableGoalContributions,
        where: 'goal_id = ?',
        whereArgs: [goal.id],
      );
      expect(contribRows.length, 1);
      expect((contribRows.first['amount'] as num).toDouble(), 25000.0);
      expect(contribRows.first['transaction_id'], isNotNull);

      // Transaction recorded
      final txId = contribRows.first['transaction_id'] as String;
      final txRows = await fakeExecutor.query(
        AppDatabase.tableTransactions,
        where: 'id = ?',
        whereArgs: [txId],
      );
      expect(txRows.length, 1);
      expect((txRows.first['amount'] as num).toDouble(), 25000.0);
      expect(txRows.first['linked_entity_id'], goal.id);
    });

    test('batchInsertTransactions generates fresh UUIDs for colliding IDs to protect local data', () async {
      final now = DateTime.now();
      final localTx = TransactionEntity(
        id: 'tx-collision-test',
        title: 'Local Important Transaction',
        amount: 999.0,
        type: TransactionType.expense,
        category: 'Important',
        date: now,
        paymentSource: 'Bank Account',
        createdAt: now,
        updatedAt: now,
      );
      await fakeExecutor.insert(AppDatabase.tableTransactions, localTx.toMap());

      // Imported CSV transaction with the same ID 'tx-collision-test'
      final importedTx = TransactionEntity(
        id: 'tx-collision-test',
        title: 'Imported CSV Transaction',
        amount: 50.0,
        type: TransactionType.expense,
        category: 'Snacks',
        date: now,
        paymentSource: 'Cash',
        createdAt: now,
        updatedAt: now,
      );

      await db.batchInsertTransactions([importedTx], executor: fakeExecutor);

      // Check transactions in database
      final allRows = await fakeExecutor.query(AppDatabase.tableTransactions);
      expect(
        allRows.length,
        2,
        reason: 'Both local and imported transactions must be preserved',
      );

      final localRow = allRows.firstWhere(
        (r) => r['id'] == 'tx-collision-test',
      );
      expect(
        localRow['title'],
        'Local Important Transaction',
        reason: 'Local transaction must never be overwritten',
      );
      expect((localRow['amount'] as num).toDouble(), 999.0);

      final importedRow = allRows.firstWhere(
        (r) => r['id'] != 'tx-collision-test',
      );
      expect(importedRow['title'], 'Imported CSV Transaction');
      expect((importedRow['amount'] as num).toDouble(), 50.0);
    });

    test('insertTransaction rejects duplicate ID and aborts without overwriting existing data', () async {
      final now = DateTime.now();
      final originalTx = TransactionEntity(
        id: 'tx-existing-id-1',
        title: 'Original Transaction',
        amount: 250.0,
        type: TransactionType.expense,
        category: 'Shopping',
        date: now,
        paymentSource: 'Cash',
        createdAt: now,
        updatedAt: now,
      );
      await fakeExecutor.insert(
        AppDatabase.tableTransactions,
        originalTx.toMap(),
      );

      final duplicateTx = TransactionEntity(
        id: 'tx-existing-id-1',
        title: 'Duplicate Collision Transaction',
        amount: 50.0,
        type: TransactionType.expense,
        category: 'Food',
        date: now,
        paymentSource: 'Cash',
        createdAt: now,
        updatedAt: now,
      );

      // Attempting to insert duplicate ID via insertTransaction must throw StateError
      expect(
        () => db.insertTransaction(duplicateTx),
        throwsA(isA<StateError>()),
      );

      // Verify original transaction is completely unchanged
      final rows = await fakeExecutor.query(
        AppDatabase.tableTransactions,
        where: 'id = ?',
        whereArgs: ['tx-existing-id-1'],
      );
      expect(rows.length, 1);
      expect(rows.first['title'], 'Original Transaction');
      expect((rows.first['amount'] as num).toDouble(), 250.0);
    });

    test('payRecurringExpenseAtomic rolls back transaction and does not advance due date if account write fails', () async {
      final now = DateTime.now();
      final dueDate = DateTime(2026, 10, 10);
      final nextMonth = DateTime(2026, 11, 10);

      final recurring = RecurringExpenseEntity(
        id: 'rec-atomic-fail-1',
        title: 'Gym Membership',
        amount: 60.0,
        category: 'Health',
        frequency: RecurringFrequency.monthly,
        paymentSource: 'Missing Bank Account',
        accountId: 'non-existent-bank-id',
        startDate: now,
        nextDueDate: dueDate,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );
      await fakeExecutor.insert(AppDatabase.tableRecurring, recurring.toMap());

      final paymentTx = TransactionEntity(
        id: 'tx-rec-pay-fail-1',
        title: 'Gym Payment Oct',
        amount: 60.0,
        type: TransactionType.expense,
        category: 'Health',
        date: dueDate,
        paymentSource: 'Missing Bank Account',
        accountId: 'non-existent-bank-id',
        createdAt: now,
        updatedAt: now,
      );

      final ghostAccount = BankAccountEntity(
        id: 'non-existent-bank-id',
        accountName: 'Ghost Account',
        bankName: 'None',
        accountType: AccountType.savings,
        usedFor: 'General',
        initialBalance: 0.0,
        currentBalance: 0.0,
        isDefault: false,
        createdAt: now,
        updatedAt: now,
      );

      // Attempt payment with invalid accountId -> throws StateError and rolls back
      expect(
        () => db.payRecurringExpenseAtomic(
          recurringExpense: recurring,
          fromAccount: ghostAccount,
          transaction: paymentTx,
          nextDueDate: nextMonth,
        ),
        throwsA(isA<StateError>()),
      );

      // Verify payment transaction was NOT inserted
      final txRows = await fakeExecutor.query(
        AppDatabase.tableTransactions,
        where: 'id = ?',
        whereArgs: [paymentTx.id],
      );
      expect(
        txRows,
        isEmpty,
        reason: 'Transaction must be rolled back on failure',
      );

      // Verify recurring expense due date was NOT advanced
      final recurRows = await fakeExecutor.query(
        AppDatabase.tableRecurring,
        where: 'id = ?',
        whereArgs: [recurring.id],
      );
      expect(recurRows.length, 1);
      final restoredRecur = RecurringExpenseEntity.fromMap(recurRows.first);
      expect(restoredRecur.nextDueDate, dueDate);
    });

    test('saveInvestmentAtomic rolls back investment and transaction if bank balance adjustment fails', () async {
      final now = DateTime.now();
      final investment = InvestmentEntity(
        id: 'inv-atomic-fail-1',
        name: 'Vanguard Index',
        assetClass: AssetClass.equity,
        investedAmount: 500.0,
        currentValue: 500.0,
        sourceAccountId: 'missing-account-123',
        createdAt: now,
        updatedAt: now,
      );

      final dummyAccount = BankAccountEntity(
        id: 'missing-account-123',
        accountName: 'Ghost Account',
        bankName: 'None',
        accountType: AccountType.savings,
        usedFor: 'General',
        initialBalance: 0.0,
        currentBalance: 0.0,
        isDefault: false,
        createdAt: now,
        updatedAt: now,
      );

      final tx = TransactionEntity(
        id: 'tx-inv-fail-1',
        title: 'Vanguard Buy',
        amount: 500.0,
        type: TransactionType.expense,
        category: 'Investment',
        date: now,
        paymentSource: 'Ghost Account',
        accountId: 'missing-account-123',
        createdAt: now,
        updatedAt: now,
      );

      // Should fail because missing-account-123 does not exist in tableBankAccounts
      expect(
        () => db.saveInvestmentAtomic(
          investment: investment,
          sourceAccount: dummyAccount,
          transaction: tx,
        ),
        throwsA(isA<StateError>()),
      );

      // Verify neither the investment nor the transaction exists in the database
      final invRows = await fakeExecutor.query(
        AppDatabase.tableInvestments,
        where: 'id = ?',
        whereArgs: [investment.id],
      );
      expect(invRows, isEmpty, reason: 'Investment write must be rolled back');

      final txRows = await fakeExecutor.query(
        AppDatabase.tableTransactions,
        where: 'id = ?',
        whereArgs: [tx.id],
      );
      expect(txRows, isEmpty, reason: 'Transaction write must be rolled back');
    });

    test('Editing reimbursement across comma-separated parent IDs updates structured sharedWith splits correctly', () async {
      final now = DateTime.now();

      // Parent Bill 1: Total ₹100, Rahul owes ₹50 (unsettled)
      final parent1Shares = [
        const SplitPersonShare(
          personName: 'Rahul',
          amount: 50.0,
          reimbursedAmount: 0.0,
          isSettled: false,
        ),
      ];
      final parent1 = TransactionEntity(
        id: 'tx-parent-1',
        title: 'Team Lunch',
        amount: 100.0,
        type: TransactionType.expense,
        category: 'Food',
        date: now,
        paymentSource: 'Cash',
        isShared: true,
        myShareAmount: 50.0,
        reimbursedAmount: 0.0,
        isSettled: false,
        sharedWith: SplitHelper.encodeShares(parent1Shares),
        createdAt: now,
        updatedAt: now,
      );
      await fakeExecutor.insert(AppDatabase.tableTransactions, parent1.toMap());

      // Parent Bill 2: Total ₹80, Rahul owes ₹40 (unsettled)
      final parent2Shares = [
        const SplitPersonShare(
          personName: 'Rahul',
          amount: 40.0,
          reimbursedAmount: 0.0,
          isSettled: false,
        ),
      ];
      final parent2 = TransactionEntity(
        id: 'tx-parent-2',
        title: 'Team Coffee',
        amount: 80.0,
        type: TransactionType.expense,
        category: 'Food',
        date: now,
        paymentSource: 'Cash',
        isShared: true,
        myShareAmount: 40.0,
        reimbursedAmount: 0.0,
        isSettled: false,
        sharedWith: SplitHelper.encodeShares(parent2Shares),
        createdAt: now,
        updatedAt: now,
      );
      await fakeExecutor.insert(AppDatabase.tableTransactions, parent2.toMap());

      // Initial settlement: Rahul pays ₹70 (settles ₹50 on parent1, and ₹20 on parent2)
      // Parent 1 becomes fully settled (reimbursed ₹50), Parent 2 partially settled (reimbursed ₹20 of ₹40)
      final parent1AfterInitial = parent1.copyWith(
        reimbursedAmount: 50.0,
        isSettled: true,
        sharedWith: SplitHelper.encodeShares([
          const SplitPersonShare(
            personName: 'Rahul',
            amount: 50.0,
            reimbursedAmount: 50.0,
            isSettled: true,
          ),
        ]),
      );
      await fakeExecutor.update(
        AppDatabase.tableTransactions,
        parent1AfterInitial.toMap(),
        where: 'id = ?',
        whereArgs: [parent1.id],
      );

      final parent2AfterInitial = parent2.copyWith(
        reimbursedAmount: 20.0,
        isSettled: false,
        sharedWith: SplitHelper.encodeShares([
          const SplitPersonShare(
            personName: 'Rahul',
            amount: 40.0,
            reimbursedAmount: 20.0,
            isSettled: false,
          ),
        ]),
      );
      await fakeExecutor.update(
        AppDatabase.tableTransactions,
        parent2AfterInitial.toMap(),
        where: 'id = ?',
        whereArgs: [parent2.id],
      );

      // Settlement Transaction: ₹70 linking comma-separated IDs "tx-parent-1, tx-parent-2"
      final initialSettlementTx = TransactionEntity(
        id: 'tx-settle-combined',
        title: 'Rahul Reimbursement',
        amount: 70.0,
        type: TransactionType.income,
        category: CategoryConstants.categorySharedReimbursement,
        date: now,
        paymentSource: 'Cash',
        sharedWith: 'Rahul',
        linkedEntityId: 'tx-parent-1, tx-parent-2',
        createdAt: now,
        updatedAt: now,
      );
      await fakeExecutor.insert(
        AppDatabase.tableTransactions,
        initialSettlementTx.toMap(),
      );

      // Now user edits the settlement transaction from ₹70 to ₹90 (+₹20 increase)
      // The extra ₹20 should apply to parent2, making parent2 fully settled (₹20 + ₹20 = ₹40)!
      final updatedSettlementTx = initialSettlementTx.copyWith(
        amount: 90.0,
        updatedAt: DateTime.now(),
      );

      await db.saveTransactionAtomic(
        transaction: updatedSettlementTx,
        previousTransaction: initialSettlementTx,
      );

      // Verify Parent 1 is still fully settled (₹50)
      final p1Rows = await fakeExecutor.query(
        AppDatabase.tableTransactions,
        where: 'id = ?',
        whereArgs: [parent1.id],
      );
      final p1Updated = TransactionEntity.fromMap(p1Rows.first);
      expect(p1Updated.reimbursedAmount, 50.0);
      expect(p1Updated.isSettled, isTrue);
      final p1Shares = SplitHelper.parseShares(p1Updated.sharedWith);
      expect(p1Shares.first.reimbursedAmount, 50.0);
      expect(p1Shares.first.isSettled, isTrue);

      // Verify Parent 2 received the remaining ₹20 and is now also fully settled (₹40 of ₹40)
      final p2Rows = await fakeExecutor.query(
        AppDatabase.tableTransactions,
        where: 'id = ?',
        whereArgs: [parent2.id],
      );
      final p2Updated = TransactionEntity.fromMap(p2Rows.first);
      expect(p2Updated.reimbursedAmount, 40.0);
      expect(p2Updated.isSettled, isTrue);
      final p2Shares = SplitHelper.parseShares(p2Updated.sharedWith);
      expect(p2Shares.first.reimbursedAmount, 40.0);
      expect(p2Shares.first.isSettled, isTrue);
    });

    test('Non-positive or non-finite payment/contribution amounts throw ArgumentError and abort', () async {
      final now = DateTime.now();
      final goal = SavingsGoalEntity(
        id: 'goal-invalid-amt',
        title: 'Emergency Fund',
        targetAmount: 1000.0,
        currentAmount: 0.0,
        category: 'General',
        targetDate: now.add(const Duration(days: 30)),
        createdAt: now,
        updatedAt: now,
      );
      await fakeExecutor.insert(AppDatabase.tableSavingsGoals, goal.toMap());

      expect(
        () => db.addSavingsGoalContributionAtomic(
          goal: goal,
          amount: -50.0,
          transaction: TransactionEntity(
            id: 'tx-neg-goal',
            title: 'Neg Deposit',
            amount: -50.0,
            type: TransactionType.expense,
            category: 'Savings',
            date: now,
            paymentSource: 'Cash',
            createdAt: now,
            updatedAt: now,
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => db.addSavingsGoalContributionAtomic(
          goal: goal,
          amount: double.nan,
          transaction: TransactionEntity(
            id: 'tx-nan-goal',
            title: 'NaN Deposit',
            amount: 0.0,
            type: TransactionType.expense,
            category: 'Savings',
            date: now,
            paymentSource: 'Cash',
            createdAt: now,
            updatedAt: now,
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Settlement increase exceeding available parent shares throws ArgumentError and rolls back', () async {
      final now = DateTime.now();

      // Parent expense: ₹100 total, Rahul owes ₹50. Already reimbursed ₹30, so only ₹20 remaining unpaid!
      final parentShares = [
        const SplitPersonShare(
          personName: 'Rahul',
          amount: 50.0,
          reimbursedAmount: 30.0,
          isSettled: false,
        ),
      ];
      final parent = TransactionEntity(
        id: 'tx-parent-limit-1',
        title: 'Dinner Party',
        amount: 100.0,
        type: TransactionType.expense,
        category: 'Food',
        date: now,
        paymentSource: 'Cash',
        isShared: true,
        myShareAmount: 50.0,
        reimbursedAmount: 30.0,
        isSettled: false,
        sharedWith: SplitHelper.encodeShares(parentShares),
        createdAt: now,
        updatedAt: now,
      );
      await fakeExecutor.insert(AppDatabase.tableTransactions, parent.toMap());

      final prevSettlement = TransactionEntity(
        id: 'tx-settle-limit-1',
        title: 'Rahul Settlement',
        amount: 30.0,
        type: TransactionType.income,
        category: CategoryConstants.categorySharedReimbursement,
        date: now,
        paymentSource: 'Cash',
        sharedWith: 'Rahul',
        linkedEntityId: parent.id,
        createdAt: now,
        updatedAt: now,
      );
      await fakeExecutor.insert(
        AppDatabase.tableTransactions,
        prevSettlement.toMap(),
      );

      // Attempt to increase settlement by ₹40 (from ₹30 to ₹70), but parent only owes ₹20!
      final excessiveSettlement = prevSettlement.copyWith(
        amount: 70.0,
        updatedAt: DateTime.now(),
      );

      expect(
        () => db.saveTransactionAtomic(
          transaction: excessiveSettlement,
          previousTransaction: prevSettlement,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Verify parent was not corrupted and remains at ₹30
      final pRows = await fakeExecutor.query(
        AppDatabase.tableTransactions,
        where: 'id = ?',
        whereArgs: [parent.id],
      );
      final pCurrent = TransactionEntity.fromMap(pRows.first);
      expect(pCurrent.reimbursedAmount, 30.0);
      expect(pCurrent.isSettled, isFalse);
    });

    test('Settlement edit with non-existent parent ID throws StateError and aborts', () async {
      final now = DateTime.now();
      final prevSettlement = TransactionEntity(
        id: 'tx-settle-ghost-parent',
        title: 'Settlement for Missing Parent',
        amount: 50.0,
        type: TransactionType.income,
        category: CategoryConstants.categorySharedReimbursement,
        date: now,
        paymentSource: 'Cash',
        sharedWith: 'Rahul',
        linkedEntityId: 'ghost-parent-999',
        createdAt: now,
        updatedAt: now,
      );
      await fakeExecutor.insert(
        AppDatabase.tableTransactions,
        prevSettlement.toMap(),
      );

      final editedSettlement = prevSettlement.copyWith(
        amount: 60.0,
        updatedAt: DateTime.now(),
      );

      expect(
        () => db.saveTransactionAtomic(
          transaction: editedSettlement,
          previousTransaction: prevSettlement,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('Recurring payment atomic rejects execution if due date in DB has already advanced', () async {
      final now = DateTime.now();
      final recurring = RecurringExpenseEntity(
        id: 'recur-dup-check',
        title: 'Broadband Bill',
        amount: 1000.0,
        category: 'Utilities',
        frequency: RecurringFrequency.monthly,
        paymentSource: 'HDFC Bank',
        startDate: now,
        nextDueDate: now,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );
      // Simulate that DB already advanced to next month (e.g. from an earlier rapid tap)
      final advancedRecur = recurring.copyWith(
        nextDueDate: now.add(const Duration(days: 30)),
      );
      await fakeExecutor.insert(
        AppDatabase.tableRecurring,
        advancedRecur.toMap(),
      );

      final tx = TransactionEntity(
        id: 'tx-recur-second-tap',
        title: recurring.title,
        amount: recurring.amount,
        type: TransactionType.expense,
        category: recurring.category,
        date: now,
        paymentSource: 'Cash',
        createdAt: now,
        updatedAt: now,
      );

      // Attempting to pay for `recurring.nextDueDate` (which is now) when DB has now + 30 days
      expect(
        () => db.payRecurringExpenseAtomic(
          recurringExpense: recurring,
          nextDueDate: now.add(const Duration(days: 30)),
          transaction: tx,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('Recurring payment atomic rejects dangling account/card ID when no target entity is provided', () async {
      final now = DateTime.now();
      final recurring = RecurringExpenseEntity(
        id: 'recur-dangling-check',
        title: 'Gym Membership',
        amount: 1500.0,
        category: 'Health',
        frequency: RecurringFrequency.monthly,
        paymentSource: 'Bank Account',
        startDate: now,
        nextDueDate: now,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );
      await fakeExecutor.insert(AppDatabase.tableRecurring, recurring.toMap());

      final txWithDanglingAccount = TransactionEntity(
        id: 'tx-recur-dangling-1',
        title: recurring.title,
        amount: recurring.amount,
        type: TransactionType.expense,
        category: recurring.category,
        date: now,
        paymentSource: 'Bank Account',
        accountId: 'deleted-bank-account-456',
        createdAt: now,
        updatedAt: now,
      );

      expect(
        () => db.payRecurringExpenseAtomic(
          recurringExpense: recurring,
          nextDueDate: now.add(const Duration(days: 30)),
          fromAccount: null, // Account missing from active ledger
          transaction: txWithDanglingAccount,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('Settlement edit then delete across multiple parents with earlier partial repayment restores splits perfectly', () async {
      final now = DateTime.now();

      // Parent 1: Total ₹100, Rahul owes ₹50. Earlier partial repayment of ₹20 already recorded!
      // Unpaid pending on Parent 1 = ₹30.
      final p1InitialShares = [
        const SplitPersonShare(
          personName: 'Rahul',
          amount: 50.0,
          reimbursedAmount: 20.0,
          isSettled: false,
        ),
      ];
      final parent1 = TransactionEntity(
        id: 'tx-parent-editdel-1',
        title: 'Dinner Part 1',
        amount: 100.0,
        type: TransactionType.expense,
        category: 'Food',
        date: now,
        paymentSource: 'Cash',
        isShared: true,
        myShareAmount: 50.0,
        reimbursedAmount: 20.0,
        isSettled: false,
        sharedWith: SplitHelper.encodeShares(p1InitialShares),
        createdAt: now,
        updatedAt: now,
      );
      await fakeExecutor.insert(AppDatabase.tableTransactions, parent1.toMap());

      // Parent 2: Total ₹80, Rahul owes ₹40. Reimbursed = ₹0.
      final p2InitialShares = [
        const SplitPersonShare(
          personName: 'Rahul',
          amount: 40.0,
          reimbursedAmount: 0.0,
          isSettled: false,
        ),
      ];
      final parent2 = TransactionEntity(
        id: 'tx-parent-editdel-2',
        title: 'Dinner Part 2',
        amount: 80.0,
        type: TransactionType.expense,
        category: 'Food',
        date: now,
        paymentSource: 'Cash',
        isShared: true,
        myShareAmount: 40.0,
        reimbursedAmount: 0.0,
        isSettled: false,
        sharedWith: SplitHelper.encodeShares(p2InitialShares),
        createdAt: now,
        updatedAt: now,
      );
      await fakeExecutor.insert(AppDatabase.tableTransactions, parent2.toMap());

      // Step 1: Initial Settlement of ₹40 linking "tx-parent-editdel-1, tx-parent-editdel-2".
      // Parent 1 absorbs ₹30 (becoming ₹50, fully settled).
      // Parent 2 absorbs remaining ₹10 (becoming ₹10 of ₹40).
      final parent1AfterSettle = parent1.copyWith(
        reimbursedAmount: 50.0,
        isSettled: true,
        sharedWith: SplitHelper.encodeShares([
          const SplitPersonShare(
            personName: 'Rahul',
            amount: 50.0,
            reimbursedAmount: 50.0,
            isSettled: true,
          ),
        ]),
      );
      await fakeExecutor.update(
        AppDatabase.tableTransactions,
        parent1AfterSettle.toMap(),
        where: 'id = ?',
        whereArgs: [parent1.id],
      );

      final parent2AfterSettle = parent2.copyWith(
        reimbursedAmount: 10.0,
        isSettled: false,
        sharedWith: SplitHelper.encodeShares([
          const SplitPersonShare(
            personName: 'Rahul',
            amount: 40.0,
            reimbursedAmount: 10.0,
            isSettled: false,
          ),
        ]),
      );
      await fakeExecutor.update(
        AppDatabase.tableTransactions,
        parent2AfterSettle.toMap(),
        where: 'id = ?',
        whereArgs: [parent2.id],
      );

      final initialSettlement = TransactionEntity(
        id: 'tx-settle-editdel-main',
        title: 'Rahul Combined Settlement',
        amount: 40.0,
        type: TransactionType.income,
        category: CategoryConstants.categorySharedReimbursement,
        date: now,
        paymentSource: 'Cash',
        sharedWith: 'Rahul',
        linkedEntityId: '${parent1.id}, ${parent2.id}',
        createdAt: now,
        updatedAt: now,
      );
      await fakeExecutor.insert(
        AppDatabase.tableTransactions,
        initialSettlement.toMap(),
      );

      // Step 2: Edit the settlement from ₹40 to ₹60 (+₹20 increase).
      // Parent 1 was already at max (₹50). Parent 2 absorbs the extra ₹20 (₹10 + ₹20 = ₹30).
      final editedSettlement = initialSettlement.copyWith(
        amount: 60.0,
        updatedAt: DateTime.now(),
      );

      await db.saveTransactionAtomic(
        transaction: editedSettlement,
        previousTransaction: initialSettlement,
      );

      // Verify intermediate edited state
      final p1EditRows = await fakeExecutor.query(
        AppDatabase.tableTransactions,
        where: 'id = ?',
        whereArgs: [parent1.id],
      );
      final p1Edit = TransactionEntity.fromMap(p1EditRows.first);
      expect(p1Edit.reimbursedAmount, 50.0);
      expect(p1Edit.isSettled, isTrue);

      final p2EditRows = await fakeExecutor.query(
        AppDatabase.tableTransactions,
        where: 'id = ?',
        whereArgs: [parent2.id],
      );
      final p2Edit = TransactionEntity.fromMap(p2EditRows.first);
      expect(p2Edit.reimbursedAmount, 30.0);
      expect(p2Edit.isSettled, isFalse);

      // Step 3: Now delete the settlement (simulating the provider delete flow with fresh parents).
      // Rolling back ₹60 in reverse:
      // Parent 2 rolls back its ₹30 (becomes ₹0).
      // Parent 1 rolls back remaining ₹30 (becomes ₹50 - ₹30 = ₹20, its earlier partial repayment!).
      final updatedOrigs = <TransactionEntity>[];
      var remainingRollback = editedSettlement.amount; // ₹60

      final freshParents = [p1Edit, p2Edit];
      // Reverse order rollback
      for (final orig in freshParents.reversed) {
        if (remainingRollback <= 0) break;
        final shares = SplitHelper.parseShares(orig.sharedWith);
        final reversedShares = shares.reversed.toList();
        final updatedReversed = <SplitPersonShare>[];
        double amtReverted = 0.0;
        for (final s in reversedShares) {
          final avail = remainingRollback - amtReverted;
          if (s.reimbursedAmount > 0 && avail > 0) {
            final canRevert = avail.clamp(0.0, s.reimbursedAmount);
            amtReverted += canRevert;
            final newReimbursed = (s.reimbursedAmount - canRevert).clamp(
              0.0,
              s.amount,
            );
            updatedReversed.add(
              s.copyWith(
                reimbursedAmount: newReimbursed,
                isSettled: newReimbursed >= s.amount && s.amount > 0,
              ),
            );
          } else {
            updatedReversed.add(s);
          }
        }
        remainingRollback -= amtReverted;
        final newParentReimbursed = (orig.reimbursedAmount - amtReverted).clamp(
          0.0,
          double.infinity,
        );
        final updatedOrig = orig.copyWith(
          reimbursedAmount: newParentReimbursed,
          isSettled:
              newParentReimbursed >= orig.friendsShare && orig.friendsShare > 0,
          sharedWith: SplitHelper.encodeShares(
            updatedReversed.reversed.toList(),
          ),
          updatedAt: DateTime.now(),
        );
        updatedOrigs.add(updatedOrig);
      }

      await db.deleteSettlementTransactionAtomic(
        settlementTransactionId: editedSettlement.id,
        updatedOriginals: updatedOrigs,
      );

      // Verify that after deletion:
      // Parent 1 is back to its earlier partial repayment of ₹20, unsettled!
      final p1FinalRows = await fakeExecutor.query(
        AppDatabase.tableTransactions,
        where: 'id = ?',
        whereArgs: [parent1.id],
      );
      final p1Final = TransactionEntity.fromMap(p1FinalRows.first);
      expect(p1Final.reimbursedAmount, 20.0);
      expect(p1Final.isSettled, isFalse);
      final p1FinalShares = SplitHelper.parseShares(p1Final.sharedWith);
      expect(p1FinalShares.first.reimbursedAmount, 20.0);
      expect(p1FinalShares.first.isSettled, isFalse);

      // Parent 2 is back to ₹0, unsettled!
      final p2FinalRows = await fakeExecutor.query(
        AppDatabase.tableTransactions,
        where: 'id = ?',
        whereArgs: [parent2.id],
      );
      final p2Final = TransactionEntity.fromMap(p2FinalRows.first);
      expect(p2Final.reimbursedAmount, 0.0);
      expect(p2Final.isSettled, isFalse);
      final p2FinalShares = SplitHelper.parseShares(p2Final.sharedWith);
      expect(p2FinalShares.first.reimbursedAmount, 0.0);
      expect(p2FinalShares.first.isSettled, isFalse);

      // Settlement transaction itself is deleted from SQLite
      final settleRows = await fakeExecutor.query(
        AppDatabase.tableTransactions,
        where: 'id = ?',
        whereArgs: [editedSettlement.id],
      );
      expect(settleRows, isEmpty);
    });

    test('saveTransactionAtomic rolls back parent settlement shares when settlement category is changed to ordinary income/expense', () async {
      final fakeExecutor = TestFakeDatabaseExecutor();
      final db = AppDatabase.instance;

      final now = DateTime.now();

      // Parent transaction: ₹100 lent/shared with Alice (amount 200, myShare 100 => friendsShare 100), currently fully reimbursed
      final parentShare = const SplitPersonShare(
        personName: 'Alice',
        amount: 100.0,
        reimbursedAmount: 100.0,
        isSettled: true,
      );
      final parent = TransactionEntity(
        id: 'parent_cat_change_1',
        title: 'Dinner with Alice',
        amount: 200.0,
        type: TransactionType.expense,
        category: 'Food & Dining',
        date: now,
        paymentSource: 'Cash',
        isShared: true,
        myShareAmount: 100.0,
        reimbursedAmount: 100.0,
        isSettled: true,
        sharedWith: SplitHelper.encodeShares([parentShare]),
        createdAt: now,
        updatedAt: now,
      );
      await fakeExecutor.insert(AppDatabase.tableTransactions, parent.toMap());

      // Existing settlement transaction: ₹100 reimbursement from Alice
      final settlementTx = TransactionEntity(
        id: 'settlement_to_change',
        title: 'Settlement from Alice',
        amount: 100.0,
        type: TransactionType.income,
        category: CategoryConstants.categorySharedReimbursement,
        date: now,
        paymentSource: 'Cash',
        linkedEntityId: parent.id,
        sharedWith: 'Alice',
        createdAt: now,
        updatedAt: now,
      );
      await fakeExecutor.insert(
        AppDatabase.tableTransactions,
        settlementTx.toMap(),
      );

      // User changes the transaction's category from 'Shared Expense Reimbursement' to 'Salary'
      final convertedTx = settlementTx.copyWith(
        category: 'Salary',
        title: 'Salary from Work',
        updatedAt: DateTime.now(),
      );

      await db.saveTransactionAtomic(
        transaction: convertedTx,
        previousTransaction: settlementTx,
        executor: fakeExecutor,
      );

      // Verify that the parent transaction was rolled back in SQLite
      final parentRows = await fakeExecutor.query(
        AppDatabase.tableTransactions,
        where: 'id = ?',
        whereArgs: [parent.id],
      );
      expect(parentRows, isNotEmpty);
      final updatedParent = TransactionEntity.fromMap(parentRows.first);
      expect(updatedParent.reimbursedAmount, 0.0);
      expect(updatedParent.isSettled, isFalse);

      final updatedShares = SplitHelper.parseShares(updatedParent.sharedWith);
      expect(updatedShares.length, 1);
      expect(updatedShares.first.reimbursedAmount, 0.0);
      expect(updatedShares.first.isSettled, isFalse);

      // Verify the transaction itself is updated to 'Salary'
      final savedTxRows = await fakeExecutor.query(
        AppDatabase.tableTransactions,
        where: 'id = ?',
        whereArgs: [settlementTx.id],
      );
      expect(savedTxRows, isNotEmpty);
      final savedTx = TransactionEntity.fromMap(savedTxRows.first);
      expect(savedTx.category, 'Salary');
    });

    test('saveTransactionAtomic rolls back multiple parent settlement shares when category changed away from settlement', () async {
      final fakeExecutor = TestFakeDatabaseExecutor();
      final db = AppDatabase.instance;

      final now = DateTime.now();

      const s1 = SplitPersonShare(
        personName: 'Bob',
        amount: 40.0,
        reimbursedAmount: 40.0,
        isSettled: true,
      );
      final parent1 = TransactionEntity(
        id: 'multi_p1',
        title: 'Lunch',
        amount: 80.0,
        type: TransactionType.expense,
        category: 'Food & Dining',
        date: now,
        paymentSource: 'Cash',
        isShared: true,
        myShareAmount: 40.0,
        reimbursedAmount: 40.0,
        isSettled: true,
        sharedWith: SplitHelper.encodeShares([s1]),
        createdAt: now,
        updatedAt: now,
      );

      const s2 = SplitPersonShare(
        personName: 'Bob',
        amount: 60.0,
        reimbursedAmount: 60.0,
        isSettled: true,
      );
      final parent2 = TransactionEntity(
        id: 'multi_p2',
        title: 'Cinema',
        amount: 120.0,
        type: TransactionType.expense,
        category: 'Entertainment',
        date: now,
        paymentSource: 'Cash',
        isShared: true,
        myShareAmount: 60.0,
        reimbursedAmount: 60.0,
        isSettled: true,
        sharedWith: SplitHelper.encodeShares([s2]),
        createdAt: now,
        updatedAt: now,
      );

      await fakeExecutor.insert(AppDatabase.tableTransactions, parent1.toMap());
      await fakeExecutor.insert(AppDatabase.tableTransactions, parent2.toMap());

      // Settlement of ₹100 across both parents
      final settlementTx = TransactionEntity(
        id: 'multi_settle_100',
        title: 'Bob Settled',
        amount: 100.0,
        type: TransactionType.income,
        category: CategoryConstants.categorySharedReimbursement,
        date: now,
        paymentSource: 'Cash',
        linkedEntityId: '${parent1.id}, ${parent2.id}',
        sharedWith: 'Bob',
        createdAt: now,
        updatedAt: now,
      );
      await fakeExecutor.insert(
        AppDatabase.tableTransactions,
        settlementTx.toMap(),
      );

      // Changed category to 'Other'
      final convertedTx = settlementTx.copyWith(
        category: 'Other',
        title: 'Random Income',
        updatedAt: DateTime.now(),
      );

      await db.saveTransactionAtomic(
        transaction: convertedTx,
        previousTransaction: settlementTx,
        executor: fakeExecutor,
      );

      // Verify both parents rolled back to ₹0 reimbursed and unsettled
      final p1Rows = await fakeExecutor.query(
        AppDatabase.tableTransactions,
        where: 'id = ?',
        whereArgs: [parent1.id],
      );
      final p1 = TransactionEntity.fromMap(p1Rows.first);
      expect(p1.reimbursedAmount, 0.0);
      expect(p1.isSettled, isFalse);

      final p2Rows = await fakeExecutor.query(
        AppDatabase.tableTransactions,
        where: 'id = ?',
        whereArgs: [parent2.id],
      );
      final p2 = TransactionEntity.fromMap(p2Rows.first);
      expect(p2.reimbursedAmount, 0.0);
      expect(p2.isSettled, isFalse);
    });

    test('Unlinked settlement deletion skips rollback when multiple ambiguous candidates exist via production deleteTransaction', () async {
      final txRepo = MockTestTransactionRepository();
      final container = ProviderContainer(
        overrides: [transactionRepositoryProvider.overrideWithValue(txRepo)],
      );
      addTearDown(container.dispose);

      final now = DateTime.now();

      final c1 = TransactionEntity(
        id: 'cand_1',
        title: 'Trip with Charlie 1',
        amount: 100.0,
        type: TransactionType.expense,
        category: 'Travel',
        date: now,
        paymentSource: 'Cash',
        isShared: true,
        myShareAmount: 50.0,
        reimbursedAmount: 50.0,
        isSettled: true,
        sharedWith: SplitHelper.encodeShares([
          const SplitPersonShare(
            personName: 'Charlie',
            amount: 50.0,
            reimbursedAmount: 50.0,
            isSettled: true,
          ),
        ]),
        createdAt: now,
        updatedAt: now,
      );

      final c2 = TransactionEntity(
        id: 'cand_2',
        title: 'Trip with Charlie 2',
        amount: 100.0,
        type: TransactionType.expense,
        category: 'Travel',
        date: now,
        paymentSource: 'Cash',
        isShared: true,
        myShareAmount: 50.0,
        reimbursedAmount: 50.0,
        isSettled: true,
        sharedWith: SplitHelper.encodeShares([
          const SplitPersonShare(
            personName: 'Charlie',
            amount: 50.0,
            reimbursedAmount: 50.0,
            isSettled: true,
          ),
        ]),
        createdAt: now,
        updatedAt: now,
      );

      final unlinkedSettlement = TransactionEntity(
        id: 'unlinked_settle',
        title: 'Reimbursement from Charlie',
        amount: 50.0,
        type: TransactionType.income,
        category: CategoryConstants.categorySharedReimbursement,
        date: now,
        paymentSource: 'Cash',
        linkedEntityId: null,
        sharedWith: 'Charlie',
        createdAt: now,
        updatedAt: now,
      );

      await txRepo.addTransaction(c1);
      await txRepo.addTransaction(c2);
      await txRepo.addTransaction(unlinkedSettlement);

      // Initialize provider state
      await container.read(transactionListNotifierProvider.future);

      // Call the REAL production deleteTransaction method!
      await container
          .read(transactionListNotifierProvider.notifier)
          .deleteTransaction(unlinkedSettlement.id);

      // Verify that the settlement was deleted
      final allAfter = await txRepo.getAllTransactions();
      expect(allAfter.any((t) => t.id == unlinkedSettlement.id), isFalse);

      // Verify that NEITHER c1 nor c2 was rolled back (both remain reimbursed: 50.0, isSettled: true)
      final afterC1 = allAfter.firstWhere((t) => t.id == 'cand_1');
      expect(afterC1.reimbursedAmount, 50.0);
      expect(afterC1.isSettled, isTrue);
      final sharesC1 = SplitHelper.parseShares(afterC1.sharedWith);
      expect(sharesC1.first.reimbursedAmount, 50.0);
      expect(sharesC1.first.isSettled, isTrue);

      final afterC2 = allAfter.firstWhere((t) => t.id == 'cand_2');
      expect(afterC2.reimbursedAmount, 50.0);
      expect(afterC2.isSettled, isTrue);
      final sharesC2 = SplitHelper.parseShares(afterC2.sharedWith);
      expect(sharesC2.first.reimbursedAmount, 50.0);
      expect(sharesC2.first.isSettled, isTrue);
    });

    test('saveTransactionAtomic rejects settlement category change when full amount cannot be rolled back', () async {
      final fakeExecutor = TestFakeDatabaseExecutor();
      final db = AppDatabase.instance;

      final now = DateTime.now();

      // Parent only has 30.0 reimbursed (not 100.0)
      const share = SplitPersonShare(
        personName: 'Dan',
        amount: 100.0,
        reimbursedAmount: 30.0,
        isSettled: false,
      );
      final parent = TransactionEntity(
        id: 'parent_partial_avail',
        title: 'Project Tools',
        amount: 200.0,
        type: TransactionType.expense,
        category: 'Electronics',
        date: now,
        paymentSource: 'Cash',
        isShared: true,
        myShareAmount: 100.0,
        reimbursedAmount: 30.0,
        isSettled: false,
        sharedWith: SplitHelper.encodeShares([share]),
        createdAt: now,
        updatedAt: now,
      );
      await fakeExecutor.insert(AppDatabase.tableTransactions, parent.toMap());

      // Settlement was ₹100.0
      final settlementTx = TransactionEntity(
        id: 'settle_100_excess',
        title: 'Dan Settlement',
        amount: 100.0,
        type: TransactionType.income,
        category: CategoryConstants.categorySharedReimbursement,
        date: now,
        paymentSource: 'Cash',
        linkedEntityId: parent.id,
        sharedWith: 'Dan',
        createdAt: now,
        updatedAt: now,
      );
      await fakeExecutor.insert(
        AppDatabase.tableTransactions,
        settlementTx.toMap(),
      );

      // Converting settlement to ordinary income category
      final convertedTx = settlementTx.copyWith(
        category: 'Freelance',
        title: 'Freelance Project',
        updatedAt: DateTime.now(),
      );

      // Must throw ArgumentError and abort because parent can only absorb 30, leaving 70 unrolled back!
      expect(
        () async => await db.saveTransactionAtomic(
          transaction: convertedTx,
          previousTransaction: settlementTx,
          executor: fakeExecutor,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('exceeds total reimbursed amount across linked expenses'),
          ),
        ),
      );

      // Verify parent was NOT modified due to atomic rollback
      final pRows = await fakeExecutor.query(
        AppDatabase.tableTransactions,
        where: 'id = ?',
        whereArgs: [parent.id],
      );
      final p = TransactionEntity.fromMap(pRows.first);
      expect(p.reimbursedAmount, 30.0);
      expect(p.isSettled, isFalse);
    });

    test('Legacy unlinked goal contribution with same amount but different timestamp is not deleted on delete', () async {
      final fakeExecutor = TestFakeDatabaseExecutor();
      final db = AppDatabase.instance;

      final now = DateTime.now();
      final oldDate = now.subtract(const Duration(days: 10));

      final goal = SavingsGoalEntity(
        id: 'goal_legacy_keep',
        title: 'Emergency Fund',
        targetAmount: 50000.0,
        currentAmount: 10000.0,
        category: 'Emergency',
        targetDate: now.add(const Duration(days: 365)),
        createdAt: oldDate,
        updatedAt: oldDate,
      );
      await fakeExecutor.insert(AppDatabase.tableSavingsGoals, goal.toMap());

      // Old contribution from 10 days ago (transaction_id = null)
      final legacyContrib = GoalContributionEntity(
        id: 'contrib_old_legacy',
        goalId: goal.id,
        amount: 500.0,
        date: oldDate,
        createdAt: oldDate,
        transactionId: null,
      );
      await fakeExecutor.insert(
        AppDatabase.tableGoalContributions,
        legacyContrib.toMap(),
      );

      // Fresh transaction created TODAY for ₹500, linked to goal
      final txToday = TransactionEntity(
        id: 'tx_today_500',
        title: 'Goal Deposit Today',
        amount: 500.0,
        type: TransactionType.expense,
        category: 'Savings & Investments',
        date: now,
        paymentSource: 'Cash',
        linkedEntityId: goal.id,
        createdAt: now,
        updatedAt: now,
      );
      await fakeExecutor.insert(AppDatabase.tableTransactions, txToday.toMap());

      // User deletes today's transaction
      await db.deleteTransactionAtomic(txToday.id, executor: fakeExecutor);

      // Verify: The 10-day-old legacy contribution is STILL present in database!
      final contribRows = await fakeExecutor.query(
        AppDatabase.tableGoalContributions,
        where: 'id = ?',
        whereArgs: [legacyContrib.id],
      );
      expect(
        contribRows,
        isNotEmpty,
        reason: 'Unrelated legacy contribution must not be deleted',
      );

      // Verify: The goal currentAmount remains 10000.0 (not decremented to 9500.0)!
      final goalRows = await fakeExecutor.query(
        AppDatabase.tableSavingsGoals,
        where: 'id = ?',
        whereArgs: [goal.id],
      );
      final g = SavingsGoalEntity.fromMap(goalRows.first);
      expect(
        g.currentAmount,
        10000.0,
        reason: 'Goal currentAmount must not be decremented for unrelated legacy entry',
      );
    });

    test('Legacy unlinked goal contribution with same amount but different timestamp is not modified or deleted on transaction edit', () async {
      final fakeExecutor = TestFakeDatabaseExecutor();
      final db = AppDatabase.instance;

      final now = DateTime.now();
      final oldDate = now.subtract(const Duration(days: 10));

      final goal = SavingsGoalEntity(
        id: 'goal_legacy_keep_edit',
        title: 'Emergency Fund',
        targetAmount: 50000.0,
        currentAmount: 10000.0,
        category: 'Emergency',
        targetDate: now.add(const Duration(days: 365)),
        createdAt: oldDate,
        updatedAt: oldDate,
      );
      await fakeExecutor.insert(AppDatabase.tableSavingsGoals, goal.toMap());

      // Old contribution from 10 days ago (transaction_id = null)
      final legacyContrib = GoalContributionEntity(
        id: 'contrib_old_legacy_edit',
        goalId: goal.id,
        amount: 500.0,
        date: oldDate,
        createdAt: oldDate,
        transactionId: null,
      );
      await fakeExecutor.insert(
        AppDatabase.tableGoalContributions,
        legacyContrib.toMap(),
      );

      // Fresh transaction created TODAY for ₹500, linked to goal
      final txToday = TransactionEntity(
        id: 'tx_today_500_edit',
        title: 'Goal Deposit Today',
        amount: 500.0,
        type: TransactionType.expense,
        category: 'Savings & Investments',
        date: now,
        paymentSource: 'Cash',
        linkedEntityId: goal.id,
        createdAt: now,
        updatedAt: now,
      );
      await fakeExecutor.insert(AppDatabase.tableTransactions, txToday.toMap());

      // User edits today's transaction: changes amount to 600 and category to Food (unlinking it)
      final txEdited = txToday.copyWith(
        title: 'Dinner Instead',
        amount: 600.0,
        category: 'Food & Dining',
        linkedEntityId: null,
        updatedAt: now,
      );
      await db.saveTransactionAtomic(
        transaction: txEdited,
        previousTransaction: txToday,
        executor: fakeExecutor,
      );

      // Verify: The 10-day-old legacy contribution is STILL present in database!
      final contribRows = await fakeExecutor.query(
        AppDatabase.tableGoalContributions,
        where: 'id = ?',
        whereArgs: [legacyContrib.id],
      );
      expect(
        contribRows,
        isNotEmpty,
        reason: 'Unrelated legacy contribution must not be deleted on transaction edit',
      );

      // Verify: Goal currentAmount was NOT decremented by the legacy contribution!
      final goalRows = await fakeExecutor.query(
        AppDatabase.tableSavingsGoals,
        where: 'id = ?',
        whereArgs: [goal.id],
      );
      final g = SavingsGoalEntity.fromMap(goalRows.first);
      expect(
        g.currentAmount,
        10000.0,
        reason: 'Goal currentAmount must remain intact when an unrelated legacy contribution exists',
      );
    });

    test('Legacy unlinked debt payment with same amount but different timestamp is not deleted on delete', () async {
      final fakeExecutor = TestFakeDatabaseExecutor();
      final db = AppDatabase.instance;

      final now = DateTime.now();
      final oldDate = now.subtract(const Duration(days: 14));

      final debt = DebtEntity(
        id: 'debt_legacy_keep',
        title: 'Friend Loan',
        principalAmount: 20000.0,
        remainingAmount: 15000.0,
        type: DebtType.peerBorrowed,
        monthlyEmi: 1000.0,
        startDate: oldDate,
        createdAt: oldDate,
        updatedAt: oldDate,
      );
      await fakeExecutor.insert(AppDatabase.tableDebts, debt.toMap());

      // Old payment from 14 days ago (transaction_id = null)
      final legacyPayment = DebtPaymentEntity(
        id: 'payment_old_legacy',
        debtId: debt.id,
        amount: 1000.0,
        date: oldDate,
        principalPortion: 1000.0,
        interestPortion: 0.0,
        createdAt: oldDate,
        transactionId: null,
      );
      await fakeExecutor.insert(
        AppDatabase.tableDebtPayments,
        legacyPayment.toMap(),
      );

      // Fresh transaction created TODAY for ₹1000, linked to debt
      final txToday = TransactionEntity(
        id: 'tx_today_debt_1000',
        title: 'Debt Payment Today',
        amount: 1000.0,
        type: TransactionType.expense,
        category: 'Debt Payment',
        date: now,
        paymentSource: 'Cash',
        linkedEntityId: debt.id,
        createdAt: now,
        updatedAt: now,
      );
      await fakeExecutor.insert(AppDatabase.tableTransactions, txToday.toMap());

      // User deletes today's transaction
      await db.deleteTransactionAtomic(txToday.id, executor: fakeExecutor);

      // Verify: The 14-day-old payment is STILL present in database!
      final paymentRows = await fakeExecutor.query(
        AppDatabase.tableDebtPayments,
        where: 'id = ?',
        whereArgs: [legacyPayment.id],
      );
      expect(
        paymentRows,
        isNotEmpty,
        reason: 'Unrelated legacy payment must not be deleted',
      );

      // Verify: Debt remainingAmount was NOT incremented for unrelated legacy entry!
      final debtRows = await fakeExecutor.query(
        AppDatabase.tableDebts,
        where: 'id = ?',
        whereArgs: [debt.id],
      );
      final d = DebtEntity.fromMap(debtRows.first);
      expect(
        d.remainingAmount,
        15000.0,
        reason: 'Debt balance must not be modified for unrelated legacy entry',
      );
    });

    test('Legacy unlinked debt payment with same amount but different timestamp is not modified or deleted on transaction edit', () async {
      final fakeExecutor = TestFakeDatabaseExecutor();
      final db = AppDatabase.instance;

      final now = DateTime.now();
      final oldDate = now.subtract(const Duration(days: 14));

      final debt = DebtEntity(
        id: 'debt_legacy_keep_edit',
        title: 'Friend Loan',
        principalAmount: 20000.0,
        remainingAmount: 15000.0,
        type: DebtType.peerBorrowed,
        monthlyEmi: 1000.0,
        startDate: oldDate,
        createdAt: oldDate,
        updatedAt: oldDate,
      );
      await fakeExecutor.insert(AppDatabase.tableDebts, debt.toMap());

      // Old payment from 14 days ago (transaction_id = null)
      final legacyPayment = DebtPaymentEntity(
        id: 'payment_old_legacy_edit',
        debtId: debt.id,
        amount: 1000.0,
        date: oldDate,
        principalPortion: 1000.0,
        interestPortion: 0.0,
        createdAt: oldDate,
        transactionId: null,
      );
      await fakeExecutor.insert(
        AppDatabase.tableDebtPayments,
        legacyPayment.toMap(),
      );

      // Fresh transaction created TODAY for ₹1000, linked to debt
      final txToday = TransactionEntity(
        id: 'tx_today_debt_1000_edit',
        title: 'Debt Payment Today',
        amount: 1000.0,
        type: TransactionType.expense,
        category: 'Debt Payment',
        date: now,
        paymentSource: 'Cash',
        linkedEntityId: debt.id,
        createdAt: now,
        updatedAt: now,
      );
      await fakeExecutor.insert(AppDatabase.tableTransactions, txToday.toMap());

      // User edits today's transaction: changes amount to 1200 and unlinks it
      final txEdited = txToday.copyWith(
        title: 'General Expense',
        amount: 1200.0,
        category: 'Shopping',
        linkedEntityId: null,
        updatedAt: now,
      );
      await db.saveTransactionAtomic(
        transaction: txEdited,
        previousTransaction: txToday,
        executor: fakeExecutor,
      );

      // Verify: The 14-day-old payment is STILL present in database!
      final paymentRows = await fakeExecutor.query(
        AppDatabase.tableDebtPayments,
        where: 'id = ?',
        whereArgs: [legacyPayment.id],
      );
      expect(
        paymentRows,
        isNotEmpty,
        reason:
            'Unrelated legacy payment must not be deleted on transaction edit',
      );

      // Verify: Debt remainingAmount was NOT incremented by the legacy payment!
      final debtRows = await fakeExecutor.query(
        AppDatabase.tableDebts,
        where: 'id = ?',
        whereArgs: [debt.id],
      );
      final d = DebtEntity.fromMap(debtRows.first);
      expect(
        d.remainingAmount,
        15000.0,
        reason: 'Debt balance must remain intact when an unrelated legacy payment exists',
      );
    });
  });
}
