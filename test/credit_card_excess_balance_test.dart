import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:empty_pocket/core/database/app_database.dart';
import 'package:empty_pocket/core/domain/entities/credit_card_entity.dart';
import 'package:empty_pocket/core/domain/entities/transaction_entity.dart';
import 'package:empty_pocket/core/calculation/financial_calculator.dart';

class _MockDbExecutor implements DatabaseExecutor {
  final Map<String, List<Map<String, dynamic>>> tables = {
    AppDatabase.tableTransactions: [],
    AppDatabase.tableCreditCards: [],
    AppDatabase.tableBankAccounts: [],
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
    return list.where((row) {
      if (where == null) return true;
      if (where == 'id = ?' && whereArgs != null && whereArgs.isNotEmpty) {
        return row['id'] == whereArgs.first;
      }
      return true;
    }).map((row) {
      if (columns == null) return Map<String, Object?>.from(row);
      final filtered = <String, Object?>{};
      for (final col in columns) {
        if (row.containsKey(col)) filtered[col] = row[col];
      }
      return filtered;
    }).toList();
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
      }
      if (match) {
        list[i] = Map<String, dynamic>.from(row)..addAll(values);
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
      return false;
    });
    return before - list.length;
  }

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) async => 0;

  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) async => 0;

  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) async => 0;

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async => [];

  @override
  Future<QueryCursor> queryCursor(String table, {bool? distinct, List<String>? columns, String? where, List<Object?>? whereArgs, String? groupBy, String? having, String? orderBy, int? limit, int? offset, int? bufferSize}) => throw UnimplementedError();

  @override
  Future<QueryCursor> rawQueryCursor(String sql, List<Object?>? arguments, {int? bufferSize}) => throw UnimplementedError();
}

void main() {
  group('Credit Card Excess Balance & Cashback Tests', () {
    final now = DateTime.now();

    test('Zero dues card receiving cashback has negative usedAmount, excess credit, and expanded available limit', () {
      final card = CreditCardEntity(
        id: 'card-1',
        cardName: 'Flipkart Axis',
        bankName: 'Axis Bank',
        creditLimit: 100000.0,
        usedAmount: 0.0,
        statementDateDay: 15,
        gracePeriodDays: 20,
        createdAt: now,
        updatedAt: now,
      );

      expect(card.currentDues, 0.0);
      expect(card.excessCredit, 0.0);
      expect(card.availableLimit, 100000.0);
      expect(card.utilizationRatio, 0.0);

      // Cashback of ₹3,988.00 received on card with zero dues
      // usedAmount becomes -3988.0
      final updatedCard = card.copyWith(usedAmount: -3988.0);

      expect(updatedCard.usedAmount, -3988.0);
      expect(
        updatedCard.currentDues,
        0.0,
        reason: 'Current dues must remain 0.00 when in excess credit',
      );
      expect(
        updatedCard.excessCredit,
        3988.0,
        reason: 'Excess credit must be positive 3988.00',
      );
      expect(
        updatedCard.availableLimit,
        103988.0,
        reason: 'Available limit must expand by the excess credit',
      );
      expect(
        updatedCard.utilizationRatio,
        0.0,
        reason: 'Utilization ratio must not be negative',
      );
      expect(updatedCard.utilizationHealth, CreditUtilizationHealth.optimal);
    });

    test('Card with partial dues receiving cashback reduces dues or creates excess credit', () {
      final card = CreditCardEntity(
        id: 'card-1',
        cardName: 'Flipkart Axis',
        bankName: 'Axis Bank',
        creditLimit: 100000.0,
        usedAmount: 2000.0,
        statementDateDay: 15,
        gracePeriodDays: 20,
        createdAt: now,
        updatedAt: now,
      );

      // Cashback of ₹5,000 received (delta = -5000)
      final afterCashback = card.copyWith(usedAmount: card.usedAmount - 5000.0);

      expect(afterCashback.usedAmount, -3000.0);
      expect(afterCashback.currentDues, 0.0);
      expect(afterCashback.excessCredit, 3000.0);
      expect(afterCashback.availableLimit, 103000.0);

      // Subsequent purchase of ₹1,000 draws down from excess credit
      final afterPurchase = afterCashback.copyWith(
        usedAmount: afterCashback.usedAmount + 1000.0,
      );
      expect(afterPurchase.usedAmount, -2000.0);
      expect(afterPurchase.currentDues, 0.0);
      expect(afterPurchase.excessCredit, 2000.0);
      expect(afterPurchase.availableLimit, 102000.0);

      // Another purchase of ₹3,000 completely exhausts excess credit and creates ₹1,000 in dues
      final afterSecondPurchase = afterPurchase.copyWith(
        usedAmount: afterPurchase.usedAmount + 3000.0,
      );
      expect(afterSecondPurchase.usedAmount, 1000.0);
      expect(afterSecondPurchase.currentDues, 1000.0);
      expect(afterSecondPurchase.excessCredit, 0.0);
      expect(afterSecondPurchase.availableLimit, 99000.0);
      expect(afterSecondPurchase.utilizationRatio, 1.0);
    });

    test('FinancialCalculator combines multiple cards with excess credit correctly', () {
      final cards = [
        CreditCardEntity(
          id: 'card-1',
          cardName: 'Flipkart Axis',
          bankName: 'Axis Bank',
          creditLimit: 100000.0,
          usedAmount: -3988.0, // Excess credit of 3988
          statementDateDay: 15,
          gracePeriodDays: 20,
          createdAt: now,
          updatedAt: now,
        ),
        CreditCardEntity(
          id: 'card-2',
          cardName: 'HDFC Regalia',
          bankName: 'HDFC Bank',
          creditLimit: 200000.0,
          usedAmount: 15000.0, // Dues of 15000
          statementDateDay: 10,
          gracePeriodDays: 20,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final summary = FinancialCalculator.calculateCombinedCreditSummary(cards);

      expect(summary.totalLimit, 300000.0);
      // Total used must only count actual dues (15000), not negative used
      expect(summary.totalUsed, 15000.0);
      // Available limit: 103988 + 185000 = 288988
      expect(summary.totalAvailable, 288988.0);
    });

    test('SQLite saveTransactionAtomic allows negative usedAmount on refund (user scenario)', () async {
      final executor = _MockDbExecutor();
      final db = AppDatabase.instance;

      final card = CreditCardEntity(
        id: 'axis-card-1',
        cardName: 'FLIPKART Axis',
        bankName: 'Axis Bank',
        creditLimit: 110000.0,
        usedAmount: 0.0,
        statementDateDay: 15,
        gracePeriodDays: 20,
        createdAt: now,
        updatedAt: now,
      );
      await executor.insert(AppDatabase.tableCreditCards, card.toMap());

      // 1. Receive ₹3,988.00 refund on zero-due card
      final refundTx = TransactionEntity(
        id: 'tx-refund-3988',
        title: 'Refund on card',
        amount: 3988.0,
        type: TransactionType.income,
        category: 'Cashback & Refund',
        date: now,
        paymentSource: 'FLIPKART Axis',
        creditCardId: 'axis-card-1',
        createdAt: now,
        updatedAt: now,
      );

      await db.saveTransactionAtomic(
        transaction: refundTx,
        executor: executor,
      );

      var cardRows = await executor.query(
        AppDatabase.tableCreditCards,
        where: 'id = ?',
        whereArgs: ['axis-card-1'],
      );
      var updatedCard = CreditCardEntity.fromMap(cardRows.first);

      expect(updatedCard.usedAmount, -3988.0, reason: 'Used amount must be -3988.0 and not clamped to 0');
      expect(updatedCard.currentDues, 0.0, reason: 'Dues must be 0.0');
      expect(updatedCard.excessCredit, 3988.0, reason: 'Excess credit must be 3988.0');
      expect(updatedCard.availableLimit, 113988.0, reason: 'Available limit expands by excess credit');

      // 2. Make purchases totalling ₹3,186.90
      final purchases = [
        TransactionEntity(
          id: 'tx-bus-1',
          title: 'Bus charges',
          amount: 997.95,
          type: TransactionType.expense,
          category: 'Transportation',
          date: now,
          paymentSource: 'FLIPKART Axis',
          creditCardId: 'axis-card-1',
          createdAt: now,
          updatedAt: now,
        ),
        TransactionEntity(
          id: 'tx-shop',
          title: 'Shopping',
          amount: 204.0,
          type: TransactionType.expense,
          category: 'Shopping',
          date: now,
          paymentSource: 'FLIPKART Axis',
          creditCardId: 'axis-card-1',
          createdAt: now,
          updatedAt: now,
        ),
        TransactionEntity(
          id: 'tx-bus-2',
          title: 'Bus charges',
          amount: 945.45,
          type: TransactionType.expense,
          category: 'Transportation',
          date: now,
          paymentSource: 'FLIPKART Axis',
          creditCardId: 'axis-card-1',
          createdAt: now,
          updatedAt: now,
        ),
        TransactionEntity(
          id: 'tx-ent',
          title: 'Entertainment',
          amount: 399.0,
          type: TransactionType.expense,
          category: 'Entertainment',
          date: now,
          paymentSource: 'FLIPKART Axis',
          creditCardId: 'axis-card-1',
          createdAt: now,
          updatedAt: now,
        ),
        TransactionEntity(
          id: 'tx-bus-3',
          title: 'Bus Ticket',
          amount: 640.50,
          type: TransactionType.expense,
          category: 'Transportation',
          date: now,
          paymentSource: 'FLIPKART Axis',
          creditCardId: 'axis-card-1',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      for (final p in purchases) {
        await db.saveTransactionAtomic(
          transaction: p,
          executor: executor,
        );
      }

      cardRows = await executor.query(
        AppDatabase.tableCreditCards,
        where: 'id = ?',
        whereArgs: ['axis-card-1'],
      );
      updatedCard = CreditCardEntity.fromMap(cardRows.first);

      // Total purchases = 997.95 + 204.00 + 945.45 + 399.00 + 640.50 = 3186.90
      // 3988 - 3186.90 = 801.10 excess credit
      expect(updatedCard.usedAmount, -801.10);
      expect(updatedCard.currentDues, 0.0);
      expect(updatedCard.excessCredit, 801.10);
      expect(updatedCard.availableLimit, 110801.10);
    });

    test('Adding ₹550 refund on zero dues card records ₹550 excess credit in SQLite', () async {
      final executor = _MockDbExecutor();
      final db = AppDatabase.instance;

      final card = CreditCardEntity(
        id: 'axis-card-2',
        cardName: 'FLIPKART Axis',
        bankName: 'Axis Bank',
        creditLimit: 110000.0,
        usedAmount: 0.0,
        statementDateDay: 15,
        gracePeriodDays: 20,
        createdAt: now,
        updatedAt: now,
      );
      await executor.insert(AppDatabase.tableCreditCards, card.toMap());

      final refundTx = TransactionEntity(
        id: 'tx-refund-550',
        title: 'Cashback & Refund',
        amount: 550.0,
        type: TransactionType.income,
        category: 'Cashback & Refund',
        date: now,
        paymentSource: 'FLIPKART Axis',
        creditCardId: 'axis-card-2',
        createdAt: now,
        updatedAt: now,
      );

      await db.saveTransactionAtomic(
        transaction: refundTx,
        executor: executor,
      );

      final cardRows = await executor.query(
        AppDatabase.tableCreditCards,
        where: 'id = ?',
        whereArgs: ['axis-card-2'],
      );
      final updatedCard = CreditCardEntity.fromMap(cardRows.first);

      expect(updatedCard.usedAmount, -550.0);
      expect(updatedCard.currentDues, 0.0);
      expect(updatedCard.excessCredit, 550.0);
      expect(updatedCard.availableLimit, 110550.0);
    });
  });
}
