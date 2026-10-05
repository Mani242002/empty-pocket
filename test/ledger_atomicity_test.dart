import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:empty_pocket/core/database/app_database.dart';
import 'package:empty_pocket/core/domain/entities/bank_account_entity.dart';
import 'package:empty_pocket/core/domain/entities/credit_card_entity.dart';
import 'package:empty_pocket/core/domain/entities/savings_goal_entity.dart';
import 'package:empty_pocket/core/domain/entities/debt_entity.dart';
import 'package:empty_pocket/core/domain/entities/transaction_entity.dart';

class FakeDatabaseExecutor implements DatabaseExecutor {
  final Map<String, List<Map<String, dynamic>>> tables = {
    AppDatabase.tableTransactions: [],
    AppDatabase.tableBankAccounts: [],
    AppDatabase.tableCreditCards: [],
    AppDatabase.tableSavingsGoals: [],
    AppDatabase.tableGoalContributions: [],
    AppDatabase.tableDebts: [],
    AppDatabase.tableDebtPayments: [],
  };

  @override
  Database get database => throw UnimplementedError();

  @override
  Batch batch() => throw UnimplementedError();

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) async {}

  @override
  Future<QueryCursor> queryCursor(
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
    int? bufferSize,
  }) => throw UnimplementedError();

  @override
  Future<QueryCursor> rawQueryCursor(
    String sql,
    List<Object?>? arguments, {
    int? bufferSize,
  }) => throw UnimplementedError();

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
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) async => 0;

  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) async => 0;

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async => [];
}

void main() {
  group('True Ledger Atomicity & Schema v14 Tests', () {
    late FakeDatabaseExecutor fakeExecutor;

    setUp(() {
      fakeExecutor = FakeDatabaseExecutor();
    });

    test('1:N Multi-Goal Allocations: correctly records transaction_id and reverts on atomic deletion', () async {
      final db = AppDatabase.instance;

      // Seed Account
      final account = BankAccountEntity(
        id: 'acc-1',
        accountName: 'Checking Account',
        bankName: 'Test Bank',
        accountType: AccountType.current,
        usedFor: 'Daily Expenses',
        initialBalance: 1000.0,
        currentBalance: 1000.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await fakeExecutor.insert(AppDatabase.tableBankAccounts, account.toMap());

      // Seed Goals
      final goal1 = SavingsGoalEntity(
        id: 'goal-1',
        title: 'Vacation',
        targetAmount: 500.0,
        currentAmount: 100.0,
        category: 'Travel',
        targetDate: DateTime.now().add(const Duration(days: 30)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final goal2 = SavingsGoalEntity(
        id: 'goal-2',
        title: 'Emergency Fund',
        targetAmount: 1000.0,
        currentAmount: 200.0,
        category: 'Emergency',
        targetDate: DateTime.now().add(const Duration(days: 60)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await fakeExecutor.insert(AppDatabase.tableSavingsGoals, goal1.toMap());
      await fakeExecutor.insert(AppDatabase.tableSavingsGoals, goal2.toMap());

      // Save Transaction with multi-goal allocations: 150 to goal1, 50 to goal2
      final tx = TransactionEntity(
        id: 'tx-multi-1',
        title: 'Salary Split',
        amount: 200.0,
        type: TransactionType.income,
        category: 'Salary',
        date: DateTime.now(),
        paymentSource: 'account',
        accountId: 'acc-1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await db.saveTransactionAtomic(
        transaction: tx,
        multiGoalAllocations: {'goal-1': 150.0, 'goal-2': 50.0},
        multiGoalSourceAccountId: 'acc-1',
        executor: fakeExecutor,
      );

      // Verify Account Balance updated
      final accRows = await fakeExecutor.query(
        AppDatabase.tableBankAccounts,
        where: 'id = ?',
        whereArgs: ['acc-1'],
      );
      expect((accRows.first['current_balance'] as num).toDouble(), 1200.0);

      // Verify Goal Balances updated
      final g1Rows = await fakeExecutor.query(
        AppDatabase.tableSavingsGoals,
        where: 'id = ?',
        whereArgs: ['goal-1'],
      );
      expect((g1Rows.first['current_amount'] as num).toDouble(), 250.0);

      final g2Rows = await fakeExecutor.query(
        AppDatabase.tableSavingsGoals,
        where: 'id = ?',
        whereArgs: ['goal-2'],
      );
      expect((g2Rows.first['current_amount'] as num).toDouble(), 250.0);

      // Verify Contributions have transaction_id
      final contribs = await fakeExecutor.query(
        AppDatabase.tableGoalContributions,
        where: 'transaction_id = ?',
        whereArgs: ['tx-multi-1'],
      );
      expect(contribs.length, 2);
      expect(
        contribs.any(
          (c) =>
              c['goal_id'] == 'goal-1' &&
              (c['amount'] as num).toDouble() == 150.0,
        ),
        isTrue,
      );
      expect(
        contribs.any(
          (c) =>
              c['goal_id'] == 'goal-2' &&
              (c['amount'] as num).toDouble() == 50.0,
        ),
        isTrue,
      );

      // Atomically delete transaction
      await db.deleteTransactionAtomic('tx-multi-1', executor: fakeExecutor);

      // Account balance reverted
      final accReverted = await fakeExecutor.query(
        AppDatabase.tableBankAccounts,
        where: 'id = ?',
        whereArgs: ['acc-1'],
      );
      expect((accReverted.first['current_balance'] as num).toDouble(), 1000.0);

      // Goal amounts reverted
      final g1Reverted = await fakeExecutor.query(
        AppDatabase.tableSavingsGoals,
        where: 'id = ?',
        whereArgs: ['goal-1'],
      );
      expect((g1Reverted.first['current_amount'] as num).toDouble(), 100.0);

      final g2Reverted = await fakeExecutor.query(
        AppDatabase.tableSavingsGoals,
        where: 'id = ?',
        whereArgs: ['goal-2'],
      );
      expect((g2Reverted.first['current_amount'] as num).toDouble(), 200.0);

      // Contributions deleted
      final contribsAfter = await fakeExecutor.query(
        AppDatabase.tableGoalContributions,
        where: 'transaction_id = ?',
        whereArgs: ['tx-multi-1'],
      );
      expect(contribsAfter, isEmpty);
    });

    test('Goal Status Preservation: preserves paused status when decremented below target', () async {
      final db = AppDatabase.instance;

      // Seed Account
      final account = BankAccountEntity(
        id: 'acc-1',
        accountName: 'Savings',
        bankName: 'Test Bank',
        accountType: AccountType.savings,
        usedFor: 'Savings',
        initialBalance: 2000.0,
        currentBalance: 2000.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await fakeExecutor.insert(AppDatabase.tableBankAccounts, account.toMap());

      // Seed Goal with PAUSED status
      final pausedGoal = SavingsGoalEntity(
        id: 'goal-paused',
        title: 'New Car',
        targetAmount: 1000.0,
        currentAmount: 800.0,
        category: 'Vehicle',
        targetDate: DateTime.now().add(const Duration(days: 90)),
        status: GoalStatus.paused,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await fakeExecutor.insert(
        AppDatabase.tableSavingsGoals,
        pausedGoal.toMap(),
      );

      // Transaction contributing 100 to paused goal (total becomes 900, still below 1000)
      final tx = TransactionEntity(
        id: 'tx-paused-1',
        title: 'Car Fund Deposit',
        amount: 100.0,
        type: TransactionType.income,
        category: 'Savings',
        date: DateTime.now(),
        paymentSource: 'account',
        accountId: 'acc-1',
        linkedEntityId: 'goal-paused',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await db.saveTransactionAtomic(transaction: tx, executor: fakeExecutor);

      var gRows = await fakeExecutor.query(
        AppDatabase.tableSavingsGoals,
        where: 'id = ?',
        whereArgs: ['goal-paused'],
      );
      expect(SavingsGoalEntity.fromMap(gRows.first).status, GoalStatus.paused);
      expect(SavingsGoalEntity.fromMap(gRows.first).currentAmount, 900.0);

      // Now delete the transaction -> decrements from 900 to 800. Status MUST stay paused!
      await db.deleteTransactionAtomic('tx-paused-1', executor: fakeExecutor);

      gRows = await fakeExecutor.query(
        AppDatabase.tableSavingsGoals,
        where: 'id = ?',
        whereArgs: ['goal-paused'],
      );
      expect(SavingsGoalEntity.fromMap(gRows.first).status, GoalStatus.paused);
      expect(SavingsGoalEntity.fromMap(gRows.first).currentAmount, 800.0);
    });

    test('Goal Status Transition: completed status reverts to active when decremented below target', () async {
      final db = AppDatabase.instance;

      final account = BankAccountEntity(
        id: 'acc-1',
        accountName: 'Savings',
        bankName: 'Test Bank',
        accountType: AccountType.savings,
        usedFor: 'Savings',
        initialBalance: 2000.0,
        currentBalance: 2000.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await fakeExecutor.insert(AppDatabase.tableBankAccounts, account.toMap());

      // Seed Goal with ACTIVE status
      final activeGoal = SavingsGoalEntity(
        id: 'goal-active',
        title: 'Laptop',
        targetAmount: 1000.0,
        currentAmount: 800.0,
        category: 'Electronics',
        targetDate: DateTime.now().add(const Duration(days: 90)),
        status: GoalStatus.active,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await fakeExecutor.insert(
        AppDatabase.tableSavingsGoals,
        activeGoal.toMap(),
      );

      // Transaction contributing 200 -> reaches 1000, becomes completed
      final tx = TransactionEntity(
        id: 'tx-laptop',
        title: 'Laptop Final Deposit',
        amount: 200.0,
        type: TransactionType.income,
        category: 'Savings',
        date: DateTime.now(),
        paymentSource: 'account',
        accountId: 'acc-1',
        linkedEntityId: 'goal-active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await db.saveTransactionAtomic(transaction: tx, executor: fakeExecutor);

      var gRows = await fakeExecutor.query(
        AppDatabase.tableSavingsGoals,
        where: 'id = ?',
        whereArgs: ['goal-active'],
      );
      expect(
        SavingsGoalEntity.fromMap(gRows.first).status,
        GoalStatus.completed,
      );
      expect(SavingsGoalEntity.fromMap(gRows.first).currentAmount, 1000.0);

      // Delete transaction -> drops below 1000, transitions from completed to active
      await db.deleteTransactionAtomic('tx-laptop', executor: fakeExecutor);

      gRows = await fakeExecutor.query(
        AppDatabase.tableSavingsGoals,
        where: 'id = ?',
        whereArgs: ['goal-active'],
      );
      expect(SavingsGoalEntity.fromMap(gRows.first).status, GoalStatus.active);
      expect(SavingsGoalEntity.fromMap(gRows.first).currentAmount, 800.0);
    });

    test('autoSyncAccount recalculates allocationPercentage based on linked bank account balance', () async {
      final db = AppDatabase.instance;

      // Seed Account with balance 2000.0
      final account = BankAccountEntity(
        id: 'acc-sync',
        accountName: 'Linked Savings Account',
        bankName: 'Sync Bank',
        accountType: AccountType.savings,
        usedFor: 'Sync Savings',
        initialBalance: 2000.0,
        currentBalance: 2000.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await fakeExecutor.insert(AppDatabase.tableBankAccounts, account.toMap());

      // Seed Goal with autoSyncAccount = true, linked to acc-sync
      final syncGoal = SavingsGoalEntity(
        id: 'goal-sync',
        title: 'Sync Fund',
        targetAmount: 5000.0,
        currentAmount: 200.0,
        category: 'Investments',
        targetDate: DateTime.now().add(const Duration(days: 120)),
        autoSyncAccount: true,
        linkedAccountId: 'acc-sync',
        allocationPercentage: 10.0, // 200 / 2000 = 10%
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await fakeExecutor.insert(
        AppDatabase.tableSavingsGoals,
        syncGoal.toMap(),
      );

      // Save transaction adding 400 to the goal (account balance becomes 2400)
      final tx = TransactionEntity(
        id: 'tx-sync-1',
        title: 'Sync Deposit',
        amount: 400.0,
        type: TransactionType.income,
        category: 'Savings',
        date: DateTime.now(),
        paymentSource: 'account',
        accountId: 'acc-sync',
        linkedEntityId: 'goal-sync',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await db.saveTransactionAtomic(transaction: tx, executor: fakeExecutor);

      // Account balance was 2000 + 400 = 2400.
      // Goal amount = 200 + 400 = 600.
      // 600 / 2400 * 100 = 25.0%
      final gRows = await fakeExecutor.query(
        AppDatabase.tableSavingsGoals,
        where: 'id = ?',
        whereArgs: ['goal-sync'],
      );
      final updated = SavingsGoalEntity.fromMap(gRows.first);
      expect(updated.currentAmount, 600.0);
      expect(updated.allocationPercentage, closeTo(25.0, 0.01));
    });

    test('Debt Payoff & Reversion: transitions to paidOff when remaining reaches 0 and reverts to active', () async {
      final db = AppDatabase.instance;

      final account = BankAccountEntity(
        id: 'acc-debt',
        accountName: 'Checking',
        bankName: 'Test Bank',
        accountType: AccountType.current,
        usedFor: 'Bills',
        initialBalance: 5000.0,
        currentBalance: 5000.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await fakeExecutor.insert(AppDatabase.tableBankAccounts, account.toMap());

      // Seed Debt: principal 1000, remaining 300
      final debt = DebtEntity(
        id: 'debt-1',
        title: 'Student Loan',
        type: DebtType.personalLoan,
        principalAmount: 1000.0,
        remainingAmount: 300.0,
        interestRate: 5.0,
        monthlyEmi: 50.0,
        startDate: DateTime.now().subtract(const Duration(days: 365)),
        status: DebtStatus.active,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await fakeExecutor.insert(AppDatabase.tableDebts, debt.toMap());

      // Pay off remaining 300
      final tx = TransactionEntity(
        id: 'tx-debt-payoff',
        title: 'Final Debt Payment',
        amount: 300.0,
        type: TransactionType.expense,
        category: 'Debt Repayment',
        date: DateTime.now(),
        paymentSource: 'account',
        accountId: 'acc-debt',
        linkedEntityId: 'debt-1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await db.saveTransactionAtomic(transaction: tx, executor: fakeExecutor);

      var dRows = await fakeExecutor.query(
        AppDatabase.tableDebts,
        where: 'id = ?',
        whereArgs: ['debt-1'],
      );
      var updatedDebt = DebtEntity.fromMap(dRows.first);
      expect(updatedDebt.remainingAmount, 0.0);
      expect(updatedDebt.status, DebtStatus.paidOff);

      // Verify Debt Payment record has transaction_id
      final pRows = await fakeExecutor.query(
        AppDatabase.tableDebtPayments,
        where: 'transaction_id = ?',
        whereArgs: ['tx-debt-payoff'],
      );
      expect(pRows.length, 1);
      expect((pRows.first['amount'] as num).toDouble(), 300.0);

      // Revert payment by deleting transaction
      await db.deleteTransactionAtomic(
        'tx-debt-payoff',
        executor: fakeExecutor,
      );

      dRows = await fakeExecutor.query(
        AppDatabase.tableDebts,
        where: 'id = ?',
        whereArgs: ['debt-1'],
      );
      updatedDebt = DebtEntity.fromMap(dRows.first);
      expect(updatedDebt.remainingAmount, 300.0);
      expect(updatedDebt.status, DebtStatus.active);

      // Payment record deleted
      final pRowsAfter = await fakeExecutor.query(
        AppDatabase.tableDebtPayments,
        where: 'transaction_id = ?',
        whereArgs: ['tx-debt-payoff'],
      );
      expect(pRowsAfter, isEmpty);
    });

    test('Atomic settleSharedExpenseAtomic updates original, inserts settlement, and credits account', () async {
      final db = AppDatabase.instance;

      final account = BankAccountEntity(
        id: 'acc-settle',
        accountName: 'Main Account',
        bankName: 'Test Bank',
        accountType: AccountType.current,
        usedFor: 'Main',
        initialBalance: 500.0,
        currentBalance: 500.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await fakeExecutor.insert(AppDatabase.tableBankAccounts, account.toMap());

      final originalTx = TransactionEntity(
        id: 'tx-shared-orig',
        title: 'Dinner with Bob',
        amount: 100.0,
        type: TransactionType.expense,
        category: 'Food',
        date: DateTime.now().subtract(const Duration(days: 2)),
        paymentSource: 'account',
        accountId: 'acc-settle',
        isShared: true,
        myShareAmount: 50.0,
        reimbursedAmount: 0.0,
        isSettled: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await fakeExecutor.insert(
        AppDatabase.tableTransactions,
        originalTx.toMap(),
      );

      final updatedOrig = originalTx.copyWith(
        reimbursedAmount: 50.0,
        isSettled: true,
        updatedAt: DateTime.now(),
      );

      final settlementTx = TransactionEntity(
        id: 'tx-reimbursement-bob',
        title: 'Reimbursement: Dinner with Bob',
        amount: 50.0,
        type: TransactionType.income,
        category: 'Shared Reimbursement',
        date: DateTime.now(),
        paymentSource: 'account',
        accountId: 'acc-settle',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await db.settleSharedExpenseAtomic(
        updatedOriginal: updatedOrig,
        settlementTransaction: settlementTx,
        executor: fakeExecutor,
      );

      // Account balance increased by 50.0 to 550.0
      final accRows = await fakeExecutor.query(
        AppDatabase.tableBankAccounts,
        where: 'id = ?',
        whereArgs: ['acc-settle'],
      );
      expect((accRows.first['current_balance'] as num).toDouble(), 550.0);

      // Original transaction settled
      final origRows = await fakeExecutor.query(
        AppDatabase.tableTransactions,
        where: 'id = ?',
        whereArgs: ['tx-shared-orig'],
      );
      final orig = TransactionEntity.fromMap(origRows.first);
      expect(orig.reimbursedAmount, 50.0);
      expect(orig.isSettled, isTrue);

      // Settlement transaction inserted
      final settleRows = await fakeExecutor.query(
        AppDatabase.tableTransactions,
        where: 'id = ?',
        whereArgs: ['tx-reimbursement-bob'],
      );
      expect(settleRows.length, 1);
      expect(TransactionEntity.fromMap(settleRows.first).amount, 50.0);
    });

    test('saveTransactionAtomic rejects duplicate transaction ID', () async {
      final db = AppDatabase.instance;
      final tx = TransactionEntity(
        id: 'tx-dup-test',
        title: 'Original Expense',
        amount: 50.0,
        type: TransactionType.expense,
        category: 'Food',
        date: DateTime.now(),
        paymentSource: 'Cash',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await db.saveTransactionAtomic(transaction: tx, executor: fakeExecutor);

      // Attempting to insert another transaction with the exact same ID must fail
      expect(
        () => db.saveTransactionAtomic(transaction: tx, executor: fakeExecutor),
        throwsA(isA<StateError>()),
      );
    });

    test(
      'saveTransactionAtomic rejects edit if transaction IDs do not match',
      () async {
        final db = AppDatabase.instance;
        final tx1 = TransactionEntity(
          id: 'tx-edit-1',
          title: 'Original Expense',
          amount: 50.0,
          type: TransactionType.expense,
          category: 'Food',
          date: DateTime.now(),
          paymentSource: 'Cash',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final tx2 = tx1.copyWith(id: 'tx-edit-2');

        expect(
          () => db.saveTransactionAtomic(
            transaction: tx2,
            previousTransaction: tx1,
            executor: fakeExecutor,
          ),
          throwsA(isA<ArgumentError>()),
        );
      },
    );

    test('reverting debt payment only restores principal portion and NOT full amount', () async {
      final db = AppDatabase.instance;
      final debt = DebtEntity(
        id: 'debt-principal-test',
        title: 'Home Loan',
        type: DebtType.homeLoan,
        principalAmount: 1000.0,
        remainingAmount: 1000.0,
        interestRate: 10.0,
        monthlyEmi: 100.0,
        startDate: DateTime.now(),
        dueDateDay: 5,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await fakeExecutor.insert(AppDatabase.tableDebts, debt.toMap());

      // Record payment of 100 where 80 is principal and 20 is interest
      await db.recordDebtPaymentAtomic(
        debt: debt,
        amount: 100.0,
        principalPortion: 80.0,
        interestPortion: 20.0,
        logAsTransaction: true,
        executor: fakeExecutor,
      );

      var dRows = await fakeExecutor.query(
        AppDatabase.tableDebts,
        where: 'id = ?',
        whereArgs: ['debt-principal-test'],
      );
      var updatedDebt = DebtEntity.fromMap(dRows.first);
      // Principal reduced by 80, not 100
      expect(updatedDebt.remainingAmount, 920.0);

      // Find the generated transaction
      final pRows = await fakeExecutor.query(
        AppDatabase.tableDebtPayments,
        where: 'debt_id = ?',
        whereArgs: ['debt-principal-test'],
      );
      expect(pRows.length, 1);
      final txId = pRows.first['transaction_id'] as String;

      // Revert payment by deleting transaction
      await db.deleteTransactionAtomic(txId, executor: fakeExecutor);

      dRows = await fakeExecutor.query(
        AppDatabase.tableDebts,
        where: 'id = ?',
        whereArgs: ['debt-principal-test'],
      );
      updatedDebt = DebtEntity.fromMap(dRows.first);
      // Remaining amount is restored by 80 (back to 1000.0), NOT 100 (which would have incorrectly made it 1020.0)
      expect(updatedDebt.remainingAmount, 1000.0);
    });

    test('preserves GoalStatus.paused even when contribution brings currentAmount >= targetAmount', () async {
      final db = AppDatabase.instance;
      final goal = SavingsGoalEntity(
        id: 'goal-paused-test',
        title: 'Emergency Fund',
        targetAmount: 1000.0,
        currentAmount: 800.0,
        category: 'General',
        status: GoalStatus.paused,
        targetDate: DateTime.now().add(const Duration(days: 60)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await fakeExecutor.insert(AppDatabase.tableSavingsGoals, goal.toMap());

      // Add 300 to goal, making currentAmount 1100 >= targetAmount 1000
      await db.addSavingsGoalContributionAtomic(
        goal: goal,
        amount: 300.0,
        logAsTransaction: true,
        executor: fakeExecutor,
      );

      var gRows = await fakeExecutor.query(
        AppDatabase.tableSavingsGoals,
        where: 'id = ?',
        whereArgs: ['goal-paused-test'],
      );
      var updatedGoal = SavingsGoalEntity.fromMap(gRows.first);
      expect(updatedGoal.currentAmount, 1100.0);
      // CRITICAL: Must stay paused!
      expect(updatedGoal.status, GoalStatus.paused);

      // Revert the contribution
      final cRows = await fakeExecutor.query(
        AppDatabase.tableGoalContributions,
        where: 'goal_id = ?',
        whereArgs: ['goal-paused-test'],
      );
      final txId = cRows.first['transaction_id'] as String;
      await db.deleteTransactionAtomic(txId, executor: fakeExecutor);

      gRows = await fakeExecutor.query(
        AppDatabase.tableSavingsGoals,
        where: 'id = ?',
        whereArgs: ['goal-paused-test'],
      );
      updatedGoal = SavingsGoalEntity.fromMap(gRows.first);
      expect(updatedGoal.currentAmount, 800.0);
      expect(updatedGoal.status, GoalStatus.paused);
    });

    test('historical fallback only alters aggregate when matching unlinked history row is found and deleted', () async {
      final db = AppDatabase.instance;
      final goal = SavingsGoalEntity(
        id: 'goal-fallback-test',
        title: 'Vacation',
        targetAmount: 1000.0,
        currentAmount: 500.0,
        category: 'Travel',
        status: GoalStatus.active,
        targetDate: DateTime.now().add(const Duration(days: 90)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await fakeExecutor.insert(AppDatabase.tableSavingsGoals, goal.toMap());

      // 1. Unlinked contribution in history table (transaction_id IS NULL)
      await fakeExecutor.insert(AppDatabase.tableGoalContributions, {
        'id': 'unlinked-c-1',
        'goal_id': 'goal-fallback-test',
        'amount': 200.0,
        'date': DateTime.now().toIso8601String(),
        'transaction_id': null,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Transaction with linkedEntityId = 'goal-fallback-test', amount = 200
      final txWithCandidate = TransactionEntity(
        id: 'tx-fallback-match',
        title: 'Goal Contribution',
        amount: 200.0,
        type: TransactionType.transfer,
        category: 'Savings',
        date: DateTime.now(),
        paymentSource: 'Cash',
        linkedEntityId: 'goal-fallback-test',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await fakeExecutor.insert(
        AppDatabase.tableTransactions,
        txWithCandidate.toMap(),
      );

      // Delete transaction: should match unlinked row, delete it, and revert 200 from goal
      await db.deleteTransactionAtomic(
        'tx-fallback-match',
        executor: fakeExecutor,
      );

      var gRows = await fakeExecutor.query(
        AppDatabase.tableSavingsGoals,
        where: 'id = ?',
        whereArgs: ['goal-fallback-test'],
      );
      expect(SavingsGoalEntity.fromMap(gRows.first).currentAmount, 300.0);
      var cRows = await fakeExecutor.query(
        AppDatabase.tableGoalContributions,
        where: 'id = ?',
        whereArgs: ['unlinked-c-1'],
      );
      expect(cRows, isEmpty); // Deleted from history!

      // 2. Transaction with linkedEntityId where NO unlinked row matches:
      final txNoCandidate = TransactionEntity(
        id: 'tx-fallback-no-match',
        title: 'Another Contribution',
        amount: 150.0,
        type: TransactionType.transfer,
        category: 'Savings',
        date: DateTime.now(),
        paymentSource: 'Cash',
        linkedEntityId: 'goal-fallback-test',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await fakeExecutor.insert(
        AppDatabase.tableTransactions,
        txNoCandidate.toMap(),
      );

      // Delete transaction: with no unlinked row, goal aggregate MUST NOT be altered
      await db.deleteTransactionAtomic(
        'tx-fallback-no-match',
        executor: fakeExecutor,
      );
      gRows = await fakeExecutor.query(
        AppDatabase.tableSavingsGoals,
        where: 'id = ?',
        whereArgs: ['goal-fallback-test'],
      );
      expect(SavingsGoalEntity.fromMap(gRows.first).currentAmount, 300.0);
    });

    test(
      'atomic transfer performs debit, credit, and logs transaction atomically',
      () async {
        final db = AppDatabase.instance;
        final accA = BankAccountEntity(
          id: 'acc-tf-a',
          accountName: 'Account A',
          bankName: 'Bank A',
          accountType: AccountType.current,
          usedFor: 'Checking',
          initialBalance: 500.0,
          currentBalance: 500.0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final accB = BankAccountEntity(
          id: 'acc-tf-b',
          accountName: 'Account B',
          bankName: 'Bank B',
          accountType: AccountType.savings,
          usedFor: 'Savings',
          initialBalance: 200.0,
          currentBalance: 200.0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await fakeExecutor.insert(AppDatabase.tableBankAccounts, accA.toMap());
        await fakeExecutor.insert(AppDatabase.tableBankAccounts, accB.toMap());

        final tx = TransactionEntity(
          id: 'tx-tf-1',
          title: 'Transfer A -> B',
          amount: 150.0,
          type: TransactionType.transfer,
          category: 'Transfer',
          date: DateTime.now(),
          paymentSource: 'Account A',
          accountId: 'acc-tf-a',
          toAccountId: 'acc-tf-b',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await db.performTransferAtomic(
          fromAccount: accA,
          toAccount: accB,
          amount: 150.0,
          transaction: tx,
          executor: fakeExecutor,
        );

        final rowsA = await fakeExecutor.query(
          AppDatabase.tableBankAccounts,
          where: 'id = ?',
          whereArgs: ['acc-tf-a'],
        );
        final rowsB = await fakeExecutor.query(
          AppDatabase.tableBankAccounts,
          where: 'id = ?',
          whereArgs: ['acc-tf-b'],
        );
        expect((rowsA.first['current_balance'] as num).toDouble(), 350.0);
        expect((rowsB.first['current_balance'] as num).toDouble(), 350.0);

        final txRows = await fakeExecutor.query(
          AppDatabase.tableTransactions,
          where: 'id = ?',
          whereArgs: ['tx-tf-1'],
        );
        expect(txRows.length, 1);
      },
    );

    test('atomic credit card bill payment deducts bank, restores credit limit, and logs transaction', () async {
      final db = AppDatabase.instance;
      final bank = BankAccountEntity(
        id: 'acc-cc-bank',
        accountName: 'Salary Account',
        bankName: 'Bank',
        accountType: AccountType.savings,
        usedFor: 'Salary',
        initialBalance: 2000.0,
        currentBalance: 2000.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final card = CreditCardEntity(
        id: 'card-cc-1',
        cardName: 'Sapphire Card',
        bankName: 'Chase',
        creditLimit: 5000.0,
        usedAmount: 1200.0,
        statementDateDay: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await fakeExecutor.insert(AppDatabase.tableBankAccounts, bank.toMap());
      await fakeExecutor.insert(AppDatabase.tableCreditCards, card.toMap());

      final tx = TransactionEntity(
        id: 'tx-cc-bill',
        title: 'Bill Pay: Sapphire Card',
        amount: 500.0,
        type: TransactionType.expense,
        category: 'Credit Card Bill Payment',
        date: DateTime.now(),
        paymentSource: 'Salary Account',
        accountId: 'acc-cc-bank',
        creditCardId: 'card-cc-1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await db.payCreditCardBillAtomic(
        fromAccount: bank,
        creditCard: card,
        amount: 500.0,
        transaction: tx,
        executor: fakeExecutor,
      );

      final bRows = await fakeExecutor.query(
        AppDatabase.tableBankAccounts,
        where: 'id = ?',
        whereArgs: ['acc-cc-bank'],
      );
      final cRows = await fakeExecutor.query(
        AppDatabase.tableCreditCards,
        where: 'id = ?',
        whereArgs: ['card-cc-1'],
      );
      expect((bRows.first['current_balance'] as num).toDouble(), 1500.0);
      expect((cRows.first['used_amount'] as num).toDouble(), 700.0);

      final txRows = await fakeExecutor.query(
        AppDatabase.tableTransactions,
        where: 'id = ?',
        whereArgs: ['tx-cc-bill'],
      );
      expect(txRows.length, 1);
    });
  });
}
