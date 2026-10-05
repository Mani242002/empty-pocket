import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:empty_pocket/core/database/app_database.dart';
import 'package:empty_pocket/core/domain/entities/transaction_entity.dart';
import 'package:empty_pocket/core/domain/entities/credit_card_entity.dart';
import 'package:empty_pocket/core/domain/entities/savings_goal_entity.dart';
import 'package:empty_pocket/core/domain/entities/debt_entity.dart';
import 'package:empty_pocket/core/domain/entities/bank_account_entity.dart';

void main() {
  group('Database Schema & Migration Contract Tests', () {
    test('AppDatabase table constants match production schema contracts', () {
      expect(AppDatabase.tableTransactions, 'transactions');
      expect(AppDatabase.tableBudgets, 'budgets');
      expect(AppDatabase.tableRecurring, 'recurring_expenses');
      expect(AppDatabase.tableSavingsGoals, 'savings_goals');
      expect(AppDatabase.tableGoalContributions, 'goal_contributions');
      expect(AppDatabase.tableDebts, 'debts');
      expect(AppDatabase.tableDebtPayments, 'debt_payments');
      expect(AppDatabase.tableInvestments, 'investments');
      expect(AppDatabase.tableChatSessions, 'ai_chat_sessions');
      expect(AppDatabase.tableChatMessages, 'ai_chat_messages');
      expect(AppDatabase.tableBankAccounts, 'bank_accounts');
      expect(AppDatabase.tableCreditCards, 'credit_cards');
      expect(AppDatabase.tableAiReports, 'ai_reports');
    });

    test(
      'TransactionEntity serialization supports v12 schema fields seamlessly',
      () {
        final now = DateTime.now();
        final tx = TransactionEntity(
          id: 'tx_v12_001',
          title: 'Credit Card Bill Payment',
          amount: 25000.0,
          type: TransactionType.transfer,
          category: 'Credit Card Payment',
          date: now,
          paymentSource: 'HDFC Salary Bank',
          accountId: 'acc_001',
          toAccountId: null,
          creditCardId: 'card_001',
          notes: 'Monthly statement payoff',
          isShared: true,
          myShareAmount: 12500.0,
          reimbursedAmount: 12500.0,
          isSettled: true,
          sharedWith: 'Partner',
          linkedEntityId: 'linked_001',
          createdAt: now,
          updatedAt: now,
        );

        final map = tx.toMap();
        expect(map['id'], 'tx_v12_001');
        expect(map['account_id'], 'acc_001');
        expect(map['credit_card_id'], 'card_001');
        expect(map['is_shared'], 1);
        expect(map['my_share_amount'], 12500.0);
        expect(map['reimbursed_amount'], 12500.0);
        expect(map['is_settled'], 1);
        expect(map['shared_with'], 'Partner');
        expect(map['linked_entity_id'], 'linked_001');

        // Round-trip deserialization
        final restored = TransactionEntity.fromMap(map);
        expect(restored.id, tx.id);
        expect(restored.accountId, tx.accountId);
        expect(restored.creditCardId, tx.creditCardId);
        expect(restored.isShared, tx.isShared);
        expect(restored.isSettled, tx.isSettled);
      },
    );

    test(
      'CreditCardEntity supports v12 initial_used_amount migration contract',
      () {
        final now = DateTime.now();
        final card = CreditCardEntity(
          id: 'card_v12',
          cardName: 'Millennia',
          bankName: 'HDFC',
          cardNetwork: CardNetwork.visa,
          creditLimit: 150000.0,
          usedAmount: 18000.0,
          initialUsedAmount: 18000.0,
          statementDateDay: 20,
          gracePeriodDays: 20,
          cardTheme: 'obsidian',
          createdAt: now,
          updatedAt: now,
        );

        final map = card.toMap();
        expect(map['initial_used_amount'], 18000.0);
        expect(map['used_amount'], 18000.0);

        // Verify deserialization from legacy row missing initial_used_amount falls back safely to used_amount
        final legacyMap = Map<String, dynamic>.from(map)
          ..remove('initial_used_amount');
        final legacyRestored = CreditCardEntity.fromMap(legacyMap);
        expect(legacyRestored.initialUsedAmount, 18000.0);
      },
    );

    test('BankAccountEntity safely serializes and deserializes current ledger balance', () {
      final now = DateTime.now();
      final account = BankAccountEntity(
        id: 'acc_002',
        accountName: 'Emergency Savings',
        bankName: 'ICICI Bank',
        accountType: AccountType.savings,
        usedFor: 'Emergency',
        initialBalance: 120000.0,
        currentBalance: 120000.0,
        colorHex: '#6366F1',
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      );

      final map = account.toMap();
      expect(map['account_name'], 'Emergency Savings');
      expect(map['current_balance'], 120000.0);
      expect(map['is_default'], 1);

      final restored = BankAccountEntity.fromMap(map);
      expect(restored.id, account.id);
      expect(restored.currentBalance, 120000.0);
      expect(restored.isDefault, isTrue);
    });

    test('GoalContributionEntity supports v14 transaction_id serialization and deserialization contract', () {
      final now = DateTime.now();
      final contrib = GoalContributionEntity(
        id: 'contrib_v14_01',
        goalId: 'goal_01',
        amount: 5000.0,
        date: now,
        notes: 'Monthly savings',
        transactionId: 'tx_v14_contrib_01',
        createdAt: now,
      );

      final map = contrib.toMap();
      expect(map['id'], 'contrib_v14_01');
      expect(map['goal_id'], 'goal_01');
      expect(map['transaction_id'], 'tx_v14_contrib_01');

      // Round-trip
      final restored = GoalContributionEntity.fromMap(map);
      expect(restored.id, contrib.id);
      expect(restored.transactionId, 'tx_v14_contrib_01');

      // Legacy map without transaction_id
      final legacyMap = Map<String, dynamic>.from(map)
        ..remove('transaction_id');
      final legacyRestored = GoalContributionEntity.fromMap(legacyMap);
      expect(legacyRestored.transactionId, isNull);
    });

    test('DebtPaymentEntity supports v14 transaction_id serialization and deserialization contract', () {
      final now = DateTime.now();
      final payment = DebtPaymentEntity(
        id: 'payment_v14_01',
        debtId: 'debt_01',
        amount: 10000.0,
        date: now,
        principalPortion: 8000.0,
        interestPortion: 2000.0,
        notes: 'Car loan EMI',
        transactionId: 'tx_v14_payment_01',
        createdAt: now,
      );

      final map = payment.toMap();
      expect(map['id'], 'payment_v14_01');
      expect(map['debt_id'], 'debt_01');
      expect(map['transaction_id'], 'tx_v14_payment_01');
      expect(map['principal_portion'], 8000.0);
      expect(map['interest_portion'], 2000.0);

      // Round-trip
      final restored = DebtPaymentEntity.fromMap(map);
      expect(restored.id, payment.id);
      expect(restored.transactionId, 'tx_v14_payment_01');
      expect(restored.principalPortion, 8000.0);
      expect(restored.interestPortion, 2000.0);

      // Legacy map without transaction_id
      final legacyMap = Map<String, dynamic>.from(map)
        ..remove('transaction_id');
      final legacyRestored = DebtPaymentEntity.fromMap(legacyMap);
      expect(legacyRestored.transactionId, isNull);
    });
  });

  group('Real SQLite v13 to v14 Migration Execution Tests', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    test('Upgrading real SQLite database from v13 to v14 creates columns, indexes, and performs unambiguous bidirectional backfill', () async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(version: 13),
      );

      // Create v13 tables (without transaction_id column)
      await db.execute('''
        CREATE TABLE ${AppDatabase.tableTransactions} (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          amount REAL NOT NULL,
          type TEXT NOT NULL,
          category TEXT NOT NULL,
          date INTEGER NOT NULL,
          payment_source TEXT NOT NULL,
          notes TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          account_id TEXT,
          to_account_id TEXT,
          credit_card_id TEXT,
          is_shared INTEGER NOT NULL DEFAULT 0,
          my_share_amount REAL,
          reimbursed_amount REAL NOT NULL DEFAULT 0.0,
          is_settled INTEGER NOT NULL DEFAULT 0,
          shared_with TEXT,
          linked_entity_id TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE ${AppDatabase.tableGoalContributions} (
          id TEXT PRIMARY KEY,
          goal_id TEXT NOT NULL,
          amount REAL NOT NULL,
          date INTEGER NOT NULL,
          notes TEXT,
          created_at INTEGER NOT NULL,
          source_account_id TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE ${AppDatabase.tableDebtPayments} (
          id TEXT PRIMARY KEY,
          debt_id TEXT NOT NULL,
          amount REAL NOT NULL,
          payment_date INTEGER NOT NULL,
          principal_portion REAL NOT NULL,
          interest_portion REAL NOT NULL,
          notes TEXT,
          created_at INTEGER NOT NULL,
          source_account_id TEXT
        )
      ''');

      // Populate v13 Data
      // Case 1: Unambiguous goal match (amount 500, created 3s apart <= 60000ms)
      await db.insert(AppDatabase.tableGoalContributions, {
        'id': 'contrib_unambiguous',
        'goal_id': 'goal_test_1',
        'amount': 500.0,
        'date': 1700000000000,
        'notes': 'Goal deposit',
        'created_at': 1700000000000,
      });
      await db.insert(AppDatabase.tableTransactions, {
        'id': 'tx_goal_unambiguous',
        'title': 'Deposit for Goal 1',
        'amount': 500.0,
        'type': 'expense',
        'category': 'Savings & Investments',
        'date': 1700000003000, // 3s diff
        'payment_source': 'Bank Account',
        'linked_entity_id': 'goal_test_1',
        'created_at': 1700000003000,
        'updated_at': 1700000003000,
      });

      // Case 2: Unrelated legacy contribution with same amount but different date (> 60s diff)
      await db.insert(AppDatabase.tableGoalContributions, {
        'id': 'contrib_unrelated_date',
        'goal_id': 'goal_test_1',
        'amount': 250.0,
        'date': 1700000000000,
        'notes': 'Unrelated older deposit',
        'created_at': 1700000000000,
      });
      await db.insert(AppDatabase.tableTransactions, {
        'id': 'tx_goal_unrelated_date',
        'title': 'Different transaction same amount',
        'amount': 250.0,
        'type': 'expense',
        'category': 'Savings & Investments',
        'date': 1700090000000, // > 24 hours diff
        'payment_source': 'Bank Account',
        'linked_entity_id': 'goal_test_1',
        'created_at': 1700090000000,
        'updated_at': 1700090000000,
      });

      // Case 3: Ambiguous contributions (2 equal amounts within same 60s)
      await db.insert(AppDatabase.tableGoalContributions, {
        'id': 'contrib_ambig_1',
        'goal_id': 'goal_test_2',
        'amount': 300.0,
        'date': 1700000000000,
        'created_at': 1700000000000,
      });
      await db.insert(AppDatabase.tableGoalContributions, {
        'id': 'contrib_ambig_2',
        'goal_id': 'goal_test_2',
        'amount': 300.0,
        'date': 1700000000000,
        'created_at': 1700000000000,
      });
      await db.insert(AppDatabase.tableTransactions, {
        'id': 'tx_goal_ambig_1',
        'title': 'Goal 2 ambiguous tx 1',
        'amount': 300.0,
        'type': 'expense',
        'category': 'Savings & Investments',
        'date': 1700000000000,
        'payment_source': 'Bank Account',
        'linked_entity_id': 'goal_test_2',
        'created_at': 1700000000000,
        'updated_at': 1700000000000,
      });

      // Case 4: Unambiguous debt match
      await db.insert(AppDatabase.tableDebtPayments, {
        'id': 'payment_unambiguous',
        'debt_id': 'debt_test_1',
        'amount': 1500.0,
        'payment_date': 1700000000000,
        'principal_portion': 1200.0,
        'interest_portion': 300.0,
        'created_at': 1700000000000,
      });
      await db.insert(AppDatabase.tableTransactions, {
        'id': 'tx_debt_unambiguous',
        'title': 'Debt 1 Payment',
        'amount': 1500.0,
        'type': 'expense',
        'category': 'Debt Payment',
        'date': 1700000002000,
        'payment_source': 'Bank Account',
        'linked_entity_id': 'debt_test_1',
        'created_at': 1700000002000,
        'updated_at': 1700000002000,
      });

      // Execute migration from v13 to v14
      await AppDatabase.instance.onUpgradeForTesting(db, 13, 14);

      // Verify transaction_id column was added to tableGoalContributions
      final contribInfo = await db.rawQuery(
        'PRAGMA table_info(${AppDatabase.tableGoalContributions})',
      );
      expect(contribInfo.any((col) => col['name'] == 'transaction_id'), isTrue);

      // Verify transaction_id column was added to tableDebtPayments
      final paymentInfo = await db.rawQuery(
        'PRAGMA table_info(${AppDatabase.tableDebtPayments})',
      );
      expect(paymentInfo.any((col) => col['name'] == 'transaction_id'), isTrue);

      // Verify unambiguous match is backfilled
      final unambigContribRows = await db.query(
        AppDatabase.tableGoalContributions,
        where: 'id = ?',
        whereArgs: ['contrib_unambiguous'],
      );
      expect(unambigContribRows.first['transaction_id'], 'tx_goal_unambiguous');

      // Verify unrelated legacy record with different date is NOT backfilled (remains NULL)
      final unrelatedDateRows = await db.query(
        AppDatabase.tableGoalContributions,
        where: 'id = ?',
        whereArgs: ['contrib_unrelated_date'],
      );
      expect(unrelatedDateRows.first['transaction_id'], isNull);

      // Verify ambiguous records remain NULL
      final ambig1Rows = await db.query(
        AppDatabase.tableGoalContributions,
        where: 'id = ?',
        whereArgs: ['contrib_ambig_1'],
      );
      expect(ambig1Rows.first['transaction_id'], isNull);

      final ambig2Rows = await db.query(
        AppDatabase.tableGoalContributions,
        where: 'id = ?',
        whereArgs: ['contrib_ambig_2'],
      );
      expect(ambig2Rows.first['transaction_id'], isNull);

      // Verify unambiguous debt payment is backfilled
      final unambigPaymentRows = await db.query(
        AppDatabase.tableDebtPayments,
        where: 'id = ?',
        whereArgs: ['payment_unambiguous'],
      );
      expect(unambigPaymentRows.first['transaction_id'], 'tx_debt_unambiguous');

      await db.close();
    });
  });
}
