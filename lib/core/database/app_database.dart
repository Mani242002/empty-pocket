import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

import '../domain/entities/ai_assistant_entity.dart';
import '../domain/entities/backup_entity.dart';
import '../domain/entities/bank_account_entity.dart';
import '../domain/entities/budget_entity.dart';
import '../domain/entities/credit_card_entity.dart';
import '../domain/entities/debt_entity.dart';
import '../domain/entities/investment_entity.dart';
import '../domain/entities/recurring_expense_entity.dart';
import '../domain/entities/savings_goal_entity.dart';
import '../domain/entities/split_person_share.dart';
import '../domain/entities/transaction_entity.dart';
import '../domain/entities/category_constants.dart';
import '../services/log_service.dart';
import '../utilities/loan_share_helper.dart';
import '../utilities/split_helper.dart';

/// Local SQLite Database manager for EmptyPocket
class AppDatabase {
  static const String _databaseName = 'empty_pocket.db';
  static const int _databaseVersion = 14;

  static const String tableTransactions = 'transactions';
  static const String tableBudgets = 'budgets';
  static const String tableRecurring = 'recurring_expenses';
  static const String tableSavingsGoals = 'savings_goals';
  static const String tableGoalContributions = 'goal_contributions';
  static const String tableDebts = 'debts';
  static const String tableDebtPayments = 'debt_payments';
  static const String tableInvestments = 'investments';
  static const String tableChatSessions = 'ai_chat_sessions';
  static const String tableChatMessages = 'ai_chat_messages';
  static const String tableBankAccounts = 'bank_accounts';
  static const String tableCreditCards = 'credit_cards';
  static const String tableAiReports = 'ai_reports';

  static final AppDatabase instance = AppDatabase._internal();

  Database? db;
  Completer<Database>? _dbCompleter;
  int _initRetryCount = 0;
  static const int _maxRetries = 3;

  AppDatabase._internal({this.db});

  /// Factory constructor for injecting mock databases in unit/integration tests
  @visibleForTesting
  factory AppDatabase.forTesting(Database mockDb) {
    return AppDatabase._internal(db: mockDb);
  }

  static int? _extractDateMs(dynamic rawDate) {
    if (rawDate is int) {
      return rawDate;
    }
    if (rawDate is String) {
      return DateTime.tryParse(rawDate)?.millisecondsSinceEpoch;
    }
    return null;
  }

  /// Thread-safe database getter with completer-based lock
  Future<Database> get database async {
    if (db != null) return db!;

    if (_dbCompleter != null) {
      return _dbCompleter!.future;
    }

    if (_initRetryCount >= _maxRetries) {
      LogService.warning(
        'AppDatabase',
        'Max retries reached ($_maxRetries), resetting counter to attempt fresh recovery',
      );
      _initRetryCount = 0;
    }

    final completer = Completer<Database>();
    _dbCompleter = completer;
    try {
      _initRetryCount++;
      db = await _initDatabase();
      _initRetryCount = 0;
      completer.complete(db!);
      return db!;
    } catch (e, stack) {
      _dbCompleter = null;
      LogService.error(
        'AppDatabase',
        'Database init failure (Attempt $_initRetryCount)',
        e,
        stack,
      );
      completer.completeError(e);
      completer.future.ignore();
      rethrow;
    }
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: (db) async {
        try {
          // Prevent multi-engine/isolate lock contention by waiting up to 5s
          await db.execute('PRAGMA busy_timeout = 5000');
        } catch (e, st) {
          LogService.warning(
            'AppDatabase',
            'Failed to set busy_timeout pragma: $e',
            e,
            st,
          );
        }
        try {
          // Enforce SQLite Foreign Key constraints
          await db.execute('PRAGMA foreign_keys = ON');
        } catch (e, st) {
          LogService.warning(
            'AppDatabase',
            'Failed to enable foreign_keys pragma: $e',
            e,
            st,
          );
        }
        try {
          // Enable WAL mode for fast disk I/O and non-blocking concurrent reads.
          // In Android sqflite, PRAGMAs that return a result set (such as journal_mode)
          // throw an exception when run via db.execute() because Android SQLiteDatabase.execSQL()
          // forbids queries that return a result. db.rawQuery() must be used instead.
          await db.rawQuery('PRAGMA journal_mode = WAL');
        } catch (e, st) {
          LogService.warning(
            'AppDatabase',
            'Failed to set journal_mode pragma: $e',
            e,
            st,
          );
        }
        try {
          // Set synchronous mode to NORMAL for optimal performance and safety in WAL mode
          await db.execute('PRAGMA synchronous = NORMAL');
        } catch (e, st) {
          LogService.warning(
            'AppDatabase',
            'Failed to set synchronous pragma: $e',
            e,
            st,
          );
        }
      },
      onOpen: (db) async {
        await _ensureIndexes(db);
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _ensureIndexes(Database db) async {
    try {
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_transactions_date ON $tableTransactions(date DESC)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_transactions_type ON $tableTransactions(type)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_transactions_account ON $tableTransactions(account_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_transactions_card ON $tableTransactions(credit_card_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_transactions_shared ON $tableTransactions(is_shared, is_settled)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_transactions_category ON $tableTransactions(category)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_ai_reports_timestamp ON $tableAiReports(timestamp DESC)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_contributions_tx ON $tableGoalContributions(transaction_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_debt_payments_tx ON $tableDebtPayments(transaction_id)',
      );
    } catch (e, stack) {
      LogService.error(
        'AppDatabase',
        'Failed to ensure indexes on open',
        e,
        stack,
      );
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // Transactions Table
    await db.execute('''
      CREATE TABLE $tableTransactions (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        category TEXT NOT NULL,
        date INTEGER NOT NULL,
        payment_source TEXT NOT NULL,
        account_id TEXT,
        to_account_id TEXT,
        credit_card_id TEXT,
        notes TEXT,
        is_shared INTEGER NOT NULL DEFAULT 0,
        my_share_amount REAL,
        reimbursed_amount REAL NOT NULL DEFAULT 0.0,
        is_settled INTEGER NOT NULL DEFAULT 0,
        shared_with TEXT,
        linked_entity_id TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_transactions_date ON $tableTransactions(date DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_transactions_type ON $tableTransactions(type)',
    );
    await db.execute(
      'CREATE INDEX idx_transactions_account ON $tableTransactions(account_id)',
    );
    await db.execute(
      'CREATE INDEX idx_transactions_card ON $tableTransactions(credit_card_id)',
    );
    await db.execute(
      'CREATE INDEX idx_transactions_shared ON $tableTransactions(is_shared, is_settled)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transactions_category ON $tableTransactions(category)',
    );

    // Budgets Table
    await _createBudgetsTable(db);

    // Recurring Expenses Table
    await _createRecurringTable(db);

    // Savings Goals & Contributions Tables
    await _createSavingsTables(db);

    // Debts & Payments Tables
    await _createDebtsTables(db);

    // Investments Table
    await _createInvestmentsTable(db);

    // AI Chat Sessions & Messages Tables
    await _createChatTables(db);

    // Bank Accounts & Credit Cards Tables
    await _createBankAccountsTable(db);
    await _createCreditCardsTable(db);

    // AI Reports Table
    await _createAiReportsTable(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createBudgetsTable(db);
      await _createRecurringTable(db);
    }
    if (oldVersion < 3) {
      await _createSavingsTables(db);
    }
    if (oldVersion < 4) {
      await _createDebtsTables(db);
    }
    if (oldVersion < 5) {
      await _createInvestmentsTable(db);
    }
    if (oldVersion < 6) {
      // Add unique index on budgets for month + category
      await db.execute('''
        CREATE UNIQUE INDEX IF NOT EXISTS idx_budgets_month_category
        ON $tableBudgets(month, category);
      ''');
    }
    if (oldVersion < 7) {
      await _createChatTables(db);
    }
    if (oldVersion < 8) {
      await _createBankAccountsTable(db);
      await _createCreditCardsTable(db);
      try {
        await db.execute(
          'ALTER TABLE $tableTransactions ADD COLUMN account_id TEXT',
        );
      } catch (e) {
        LogService.debug('AppDatabase', 'account_id column migration: $e');
      }
      try {
        await db.execute(
          'ALTER TABLE $tableTransactions ADD COLUMN to_account_id TEXT',
        );
      } catch (e) {
        LogService.debug('AppDatabase', 'to_account_id column migration: $e');
      }
      try {
        await db.execute(
          'ALTER TABLE $tableTransactions ADD COLUMN credit_card_id TEXT',
        );
      } catch (e) {
        LogService.debug('AppDatabase', 'credit_card_id column migration: $e');
      }
      try {
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_transactions_account ON $tableTransactions(account_id)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_transactions_card ON $tableTransactions(credit_card_id)',
        );
      } catch (e) {
        LogService.debug('AppDatabase', 'Transaction indexes migration: $e');
      }
    }
    if (oldVersion < 9) {
      try {
        await db.execute(
          'ALTER TABLE $tableTransactions ADD COLUMN is_shared INTEGER NOT NULL DEFAULT 0',
        );
      } catch (e) {
        LogService.debug('AppDatabase', 'is_shared column migration: $e');
      }
      try {
        await db.execute(
          'ALTER TABLE $tableTransactions ADD COLUMN my_share_amount REAL',
        );
      } catch (e) {
        LogService.debug('AppDatabase', 'my_share_amount column migration: $e');
      }
      try {
        await db.execute(
          'ALTER TABLE $tableTransactions ADD COLUMN reimbursed_amount REAL NOT NULL DEFAULT 0.0',
        );
      } catch (e) {
        LogService.debug(
          'AppDatabase',
          'reimbursed_amount column migration: $e',
        );
      }
      try {
        await db.execute(
          'ALTER TABLE $tableTransactions ADD COLUMN is_settled INTEGER NOT NULL DEFAULT 0',
        );
      } catch (e) {
        LogService.debug('AppDatabase', 'is_settled column migration: $e');
      }
      try {
        await db.execute(
          'ALTER TABLE $tableTransactions ADD COLUMN shared_with TEXT',
        );
      } catch (e) {
        LogService.debug('AppDatabase', 'shared_with column migration: $e');
      }
      try {
        await db.execute(
          'ALTER TABLE $tableTransactions ADD COLUMN linked_entity_id TEXT',
        );
      } catch (e) {
        LogService.debug(
          'AppDatabase',
          'linked_entity_id column migration: $e',
        );
      }
      try {
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_transactions_shared ON $tableTransactions(is_shared, is_settled)',
        );
      } catch (e) {
        LogService.debug(
          'AppDatabase',
          'Shared transaction index migration: $e',
        );
      }
      try {
        await db.execute(
          'ALTER TABLE $tableRecurring ADD COLUMN account_id TEXT',
        );
        await db.execute(
          'ALTER TABLE $tableRecurring ADD COLUMN credit_card_id TEXT',
        );
      } catch (e) {
        LogService.debug(
          'AppDatabase',
          'Recurring accounts column migration: $e',
        );
      }
      try {
        await db.execute(
          'ALTER TABLE $tableSavingsGoals ADD COLUMN linked_account_id TEXT',
        );
      } catch (e) {
        LogService.debug(
          'AppDatabase',
          'Savings goal linked_account_id migration: $e',
        );
      }
      try {
        await db.execute(
          'ALTER TABLE $tableGoalContributions ADD COLUMN source_account_id TEXT',
        );
      } catch (e) {
        LogService.debug(
          'AppDatabase',
          'Goal contribution source_account_id migration: $e',
        );
      }
      try {
        await db.execute(
          'ALTER TABLE $tableDebts ADD COLUMN linked_account_id TEXT',
        );
      } catch (e) {
        LogService.debug(
          'AppDatabase',
          'Debts linked_account_id migration: $e',
        );
      }
      try {
        await db.execute(
          'ALTER TABLE $tableDebtPayments ADD COLUMN source_account_id TEXT',
        );
      } catch (e) {
        LogService.debug(
          'AppDatabase',
          'Debt payments source_account_id migration: $e',
        );
      }
      try {
        await db.execute(
          'ALTER TABLE $tableInvestments ADD COLUMN source_account_id TEXT',
        );
      } catch (e) {
        LogService.debug(
          'AppDatabase',
          'Investments source_account_id migration: $e',
        );
      }
    }
    if (oldVersion < 10) {
      try {
        await db.execute(
          'ALTER TABLE $tableSavingsGoals ADD COLUMN allocation_percentage REAL NOT NULL DEFAULT 100.0',
        );
      } catch (e) {
        LogService.debug(
          'AppDatabase',
          'allocation_percentage column migration: $e',
        );
      }
      try {
        await db.execute(
          'ALTER TABLE $tableSavingsGoals ADD COLUMN auto_sync_account INTEGER NOT NULL DEFAULT 0',
        );
      } catch (e) {
        LogService.debug(
          'AppDatabase',
          'auto_sync_account column migration: $e',
        );
      }
    }
    if (oldVersion < 11) {
      await _createAiReportsTable(db);
    }
    if (oldVersion < 12) {
      try {
        await db.execute(
          'ALTER TABLE $tableCreditCards ADD COLUMN initial_used_amount REAL NOT NULL DEFAULT 0.0',
        );
        await db.execute(
          'UPDATE $tableCreditCards SET initial_used_amount = used_amount WHERE initial_used_amount = 0.0',
        );
      } catch (e) {
        LogService.debug(
          'AppDatabase',
          'initial_used_amount column migration: $e',
        );
      }
    }
    if (oldVersion < 13) {
      try {
        await db.execute(
          'ALTER TABLE $tableBudgets ADD COLUMN account_id TEXT',
        );
      } catch (e) {
        LogService.debug(
          'AppDatabase',
          'account_id column migration for budgets: $e',
        );
      }
    }
    if (oldVersion < 14) {
      await _addColumnIfNotExists(
        db,
        tableGoalContributions,
        'transaction_id',
        'TEXT',
      );
      await _addColumnIfNotExists(
        db,
        tableDebtPayments,
        'transaction_id',
        'TEXT',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_contributions_tx ON $tableGoalContributions(transaction_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_debt_payments_tx ON $tableDebtPayments(transaction_id)',
      );

      // Bidirectional Unambiguous Backfill for Savings Goals
      final goalTxs = await db.rawQuery(
        'SELECT id, linked_entity_id, amount, date FROM $tableTransactions WHERE linked_entity_id IS NOT NULL AND linked_entity_id != ""',
      );
      for (final tx in goalTxs) {
        final txId = tx['id'] as String;
        final goalId = tx['linked_entity_id'] as String;
        final amount = (tx['amount'] as num).toDouble();
        final date = tx['date'] as int;

        final contribMatches = await db.rawQuery(
          'SELECT id FROM $tableGoalContributions WHERE goal_id = ? AND abs(amount - ?) < 0.001 AND abs(date - ?) <= 60000 AND transaction_id IS NULL',
          [goalId, amount, date],
        );
        if (contribMatches.length == 1) {
          final contribId = contribMatches.first['id'] as String;
          final reverseMatches = await db.rawQuery(
            'SELECT id FROM $tableTransactions WHERE linked_entity_id = ? AND abs(amount - ?) < 0.001 AND abs(date - ?) <= 60000',
            [goalId, amount, date],
          );
          if (reverseMatches.length == 1) {
            await db.rawUpdate(
              'UPDATE $tableGoalContributions SET transaction_id = ? WHERE id = ?',
              [txId, contribId],
            );
          }
        }
      }

      // Bidirectional Unambiguous Backfill for Debts
      final debtTxs = await db.rawQuery(
        'SELECT id, linked_entity_id, amount, date FROM $tableTransactions WHERE linked_entity_id IS NOT NULL AND linked_entity_id != ""',
      );
      for (final tx in debtTxs) {
        final txId = tx['id'] as String;
        final debtId = tx['linked_entity_id'] as String;
        final amount = (tx['amount'] as num).toDouble();
        final date = tx['date'] as int;

        final tableInfo = await db.rawQuery(
          'PRAGMA table_info($tableDebtPayments)',
        );
        final dateCol = tableInfo.any((col) => col['name'] == 'date')
            ? 'date'
            : 'payment_date';

        final paymentMatches = await db.rawQuery(
          'SELECT id FROM $tableDebtPayments WHERE debt_id = ? AND abs(amount - ?) < 0.001 AND abs($dateCol - ?) <= 60000 AND transaction_id IS NULL',
          [debtId, amount, date],
        );
        if (paymentMatches.length == 1) {
          final paymentId = paymentMatches.first['id'] as String;
          final reverseMatches = await db.rawQuery(
            'SELECT id FROM $tableTransactions WHERE linked_entity_id = ? AND abs(amount - ?) < 0.001 AND abs(date - ?) <= 60000',
            [debtId, amount, date],
          );
          if (reverseMatches.length == 1) {
            await db.rawUpdate(
              'UPDATE $tableDebtPayments SET transaction_id = ? WHERE id = ?',
              [txId, paymentId],
            );
          }
        }
      }
      // Ambiguous legacy records remain transaction_id = NULL.
    }
  }

  @visibleForTesting
  Future<void> onUpgradeForTesting(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    await _onUpgrade(db, oldVersion, newVersion);
  }

  static Future<bool> _columnExists(
    DatabaseExecutor db,
    String table,
    String column,
  ) async {
    final result = await db.rawQuery('PRAGMA table_info($table)');
    return result.any(
      (row) =>
          (row['name'] as String?).toString().toLowerCase() ==
          column.toLowerCase(),
    );
  }

  static Future<void> _addColumnIfNotExists(
    DatabaseExecutor db,
    String table,
    String column,
    String typeWithConstraints,
  ) async {
    final exists = await _columnExists(db, table, column);
    if (!exists) {
      await db.execute(
        'ALTER TABLE $table ADD COLUMN $column $typeWithConstraints',
      );
    }
  }

  Future<void> _createAiReportsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableAiReports (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        type TEXT NOT NULL,
        markdown_content TEXT NOT NULL,
        model_used TEXT NOT NULL,
        model_display_name TEXT NOT NULL,
        provider_used TEXT NOT NULL,
        timestamp INTEGER NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ai_reports_timestamp ON $tableAiReports(timestamp DESC)',
    );
  }

  Future<void> _createBankAccountsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableBankAccounts (
        id TEXT PRIMARY KEY,
        account_name TEXT NOT NULL,
        bank_name TEXT NOT NULL,
        account_type TEXT NOT NULL,
        used_for TEXT NOT NULL,
        initial_balance REAL NOT NULL,
        current_balance REAL NOT NULL,
        color_hex TEXT,
        is_default INTEGER NOT NULL,
        is_archived INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_bank_accounts_type ON $tableBankAccounts(account_type)',
    );
  }

  Future<void> _createCreditCardsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableCreditCards (
        id TEXT PRIMARY KEY,
        card_name TEXT NOT NULL,
        bank_name TEXT NOT NULL,
        card_network TEXT NOT NULL,
        credit_limit REAL NOT NULL,
        used_amount REAL NOT NULL,
        initial_used_amount REAL NOT NULL DEFAULT 0.0,
        statement_date_day INTEGER NOT NULL,
        grace_period_days INTEGER NOT NULL,
        card_theme TEXT NOT NULL,
        is_archived INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _createChatTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableChatSessions (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        provider TEXT NOT NULL,
        model_used TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_chat_sessions_updated ON $tableChatSessions(updated_at DESC)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableChatMessages (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        text TEXT NOT NULL,
        is_user INTEGER NOT NULL,
        timestamp INTEGER NOT NULL,
        FOREIGN KEY (session_id) REFERENCES $tableChatSessions(id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_chat_messages_session ON $tableChatMessages(session_id, timestamp ASC)',
    );
  }

  Future<void> _createBudgetsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableBudgets (
        id TEXT PRIMARY KEY,
        category TEXT NOT NULL,
        limit_amount REAL NOT NULL,
        month INTEGER NOT NULL,
        account_id TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_budgets_month ON $tableBudgets(month)',
    );
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_budgets_month_category
      ON $tableBudgets(month, category)
    ''');
  }

  Future<void> _createRecurringTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableRecurring (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        frequency TEXT NOT NULL,
        payment_source TEXT NOT NULL,
        account_id TEXT,
        credit_card_id TEXT,
        start_date INTEGER NOT NULL,
        next_due_date INTEGER NOT NULL,
        is_active INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_recurring_due ON $tableRecurring(next_due_date ASC)',
    );
  }

  Future<void> _createSavingsTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableSavingsGoals (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        target_amount REAL NOT NULL,
        current_amount REAL NOT NULL,
        category TEXT NOT NULL,
        target_date INTEGER NOT NULL,
        is_emergency_fund INTEGER NOT NULL,
        status TEXT NOT NULL,
        linked_account_id TEXT,
        allocation_percentage REAL NOT NULL DEFAULT 100.0,
        auto_sync_account INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableGoalContributions (
        id TEXT PRIMARY KEY,
        goal_id TEXT NOT NULL,
        amount REAL NOT NULL,
        date INTEGER NOT NULL,
        notes TEXT,
        source_account_id TEXT,
        transaction_id TEXT,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (goal_id) REFERENCES $tableSavingsGoals(id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_contributions_goal ON $tableGoalContributions(goal_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_contributions_tx ON $tableGoalContributions(transaction_id)',
    );
  }

  Future<void> _createDebtsTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableDebts (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        type TEXT NOT NULL,
        principal_amount REAL NOT NULL,
        remaining_amount REAL NOT NULL,
        interest_rate REAL NOT NULL,
        tenure_months INTEGER NOT NULL,
        monthly_emi REAL NOT NULL,
        start_date INTEGER NOT NULL,
        due_date_day INTEGER NOT NULL,
        lender_name TEXT,
        status TEXT NOT NULL,
        linked_account_id TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableDebtPayments (
        id TEXT PRIMARY KEY,
        debt_id TEXT NOT NULL,
        amount REAL NOT NULL,
        principal_portion REAL NOT NULL,
        interest_portion REAL NOT NULL,
        date INTEGER NOT NULL,
        notes TEXT,
        source_account_id TEXT,
        transaction_id TEXT,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (debt_id) REFERENCES $tableDebts(id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_debt_payments_debt ON $tableDebtPayments(debt_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_debt_payments_tx ON $tableDebtPayments(transaction_id)',
    );
  }

  Future<void> _createInvestmentsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableInvestments (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        asset_class TEXT NOT NULL,
        invested_amount REAL NOT NULL,
        current_value REAL NOT NULL,
        units REAL,
        buy_price REAL,
        current_price REAL,
        institution TEXT,
        notes TEXT,
        source_account_id TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_investments_asset ON $tableInvestments(asset_class)',
    );
  }

  // --- Transactions ---

  Future<int> insertTransaction(
    TransactionEntity transaction, {
    DatabaseExecutor? executor,
  }) async {
    final client = executor ?? await database;
    final existing = await client.query(
      tableTransactions,
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [transaction.id],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      throw StateError(
        'Transaction with id "${transaction.id}" already exists.',
      );
    }
    return await client.insert(
      tableTransactions,
      transaction.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<void> batchInsertTransactions(
    List<TransactionEntity> transactions, {
    DatabaseExecutor? executor,
  }) async {
    Future<void> work(DatabaseExecutor txn) async {
      final existingRows = await txn.query(tableTransactions, columns: ['id']);
      final existingIds = existingRows.map((r) => r['id'] as String).toSet();
      final batch = txn.batch();
      for (var tx in transactions) {
        if (existingIds.contains(tx.id)) {
          tx = tx.copyWith(id: const Uuid().v4());
        }
        existingIds.add(tx.id);
        batch.insert(
          tableTransactions,
          tx.toMap(),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }
      await batch.commit(noResult: true);
    }

    if (executor != null) {
      await work(executor);
    } else {
      final database = await this.database;
      await database.transaction(work);
    }
  }

  Future<int> updateTransaction(
    TransactionEntity transaction, {
    DatabaseExecutor? executor,
  }) async {
    final client = executor ?? await database;
    return await client.update(
      tableTransactions,
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<int> deleteTransaction(String id, {DatabaseExecutor? executor}) async {
    final client = executor ?? await database;
    return await client.delete(
      tableTransactions,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Atomically saves a transaction (add or edit), adjusts bank accounts/credit cards,
  /// updates linked savings goals, creates/reverts goal contributions (with transaction_id),
  /// updates debts, and creates/reverts debt payments (with transaction_id) in a single ACID transaction.
  Future<void> saveTransactionAtomic({
    required TransactionEntity transaction,
    TransactionEntity? previousTransaction,
    Map<String, double>? multiGoalAllocations,
    String? multiGoalSourceAccountId,
    DatabaseExecutor? executor,
  }) async {
    if (executor != null) {
      await _executeSaveTransactionInTxn(
        executor,
        transaction: transaction,
        previousTransaction: previousTransaction,
        multiGoalAllocations: multiGoalAllocations,
        multiGoalSourceAccountId: multiGoalSourceAccountId,
      );
    } else {
      final client = await database;
      await client.transaction((txn) async {
        await _executeSaveTransactionInTxn(
          txn,
          transaction: transaction,
          previousTransaction: previousTransaction,
          multiGoalAllocations: multiGoalAllocations,
          multiGoalSourceAccountId: multiGoalSourceAccountId,
        );
      });
    }
  }

  static Future<void> _executeSaveTransactionInTxn(
    DatabaseExecutor txn, {
    required TransactionEntity transaction,
    TransactionEntity? previousTransaction,
    Map<String, double>? multiGoalAllocations,
    String? multiGoalSourceAccountId,
  }) async {
    // Preserve principal/interest split for re-application if editing a debt payment
    double? preservedDebtPrincipal;
    double? preservedDebtInterest;

    // 1. Revert previous transaction impact if editing
    if (previousTransaction != null) {
      await _applyTxBalanceImpactInTxn(
        txn,
        previousTransaction,
        isRevert: true,
      );

      // Revert linked goal contributions matching transaction_id
      final linkedContribs = await txn.query(
        tableGoalContributions,
        where: 'transaction_id = ?',
        whereArgs: [previousTransaction.id],
      );
      for (final row in linkedContribs) {
        final goalId = row['goal_id'] as String;
        final amount = (row['amount'] as num).toDouble();
        await _revertGoalContributionInTxn(txn, goalId, amount);
      }
      if (linkedContribs.isNotEmpty) {
        await txn.delete(
          tableGoalContributions,
          where: 'transaction_id = ?',
          whereArgs: [previousTransaction.id],
        );
      }

      // Revert linked debt payments matching transaction_id using principal_portion,
      // preserving the principal/interest split for re-application if this is an edit.
      final linkedPayments = await txn.query(
        tableDebtPayments,
        where: 'transaction_id = ?',
        whereArgs: [previousTransaction.id],
      );
      if (linkedPayments.isNotEmpty) {
        final firstPayment = linkedPayments.first;
        final oldAmount = (firstPayment['amount'] as num).toDouble();
        final oldPrincipal =
            (firstPayment['principal_portion'] as num?)?.toDouble() ??
            oldAmount;
        final oldInterest =
            (firstPayment['interest_portion'] as num?)?.toDouble() ?? 0.0;
        if ((transaction.amount - oldAmount).abs() < 0.001) {
          preservedDebtPrincipal = oldPrincipal;
          preservedDebtInterest = oldInterest;
        } else if (oldAmount > 0) {
          final ratio = (oldPrincipal / oldAmount).clamp(0.0, 1.0);
          preservedDebtPrincipal = transaction.amount * ratio;
          preservedDebtInterest = transaction.amount - preservedDebtPrincipal;
        }
      }
      for (final row in linkedPayments) {
        final debtId = row['debt_id'] as String;
        final principal =
            (row['principal_portion'] as num?)?.toDouble() ??
            (row['amount'] as num).toDouble();
        await _revertDebtPaymentInTxn(txn, debtId, principal);
      }
      if (linkedPayments.isNotEmpty) {
        await txn.delete(
          tableDebtPayments,
          where: 'transaction_id = ?',
          whereArgs: [previousTransaction.id],
        );
      }

      // Consistent Fallback: only modify goal or debt aggregate if exactly one unambiguous unlinked history row is identified
      // matching the transaction date within 60 seconds (mirroring the v14 migration contract) with bidirectional uniqueness.
      final prevLinkedId = previousTransaction.linkedEntityId?.trim();
      if (prevLinkedId != null &&
          prevLinkedId.isNotEmpty &&
          linkedContribs.isEmpty &&
          linkedPayments.isEmpty) {
        final txDate = previousTransaction.date.millisecondsSinceEpoch;
        final unlinkedContribs = await txn.query(
          tableGoalContributions,
          where: 'goal_id = ? AND transaction_id IS NULL',
          whereArgs: [prevLinkedId],
        );
        final candidateContribs = unlinkedContribs.where((c) {
          final amtMatches =
              ((c['amount'] as num).toDouble() - previousTransaction.amount)
                  .abs() <
              0.001;
          final cDate = _extractDateMs(c['date']);
          final dateMatches = cDate != null && (cDate - txDate).abs() <= 60000;
          return amtMatches && dateMatches;
        }).toList();

        if (candidateContribs.length == 1) {
          final reverseTxMatches = await txn.query(
            tableTransactions,
            where: 'linked_entity_id = ? AND abs(amount - ?) < 0.001 AND abs(date - ?) <= 60000',
            whereArgs: [prevLinkedId, previousTransaction.amount, txDate],
          );
          if (reverseTxMatches.length == 1) {
            final candidateContrib = candidateContribs.single;
            final amt = (candidateContrib['amount'] as num).toDouble();
            await _revertGoalContributionInTxn(txn, prevLinkedId, amt);
            await txn.delete(
              tableGoalContributions,
              where: 'id = ?',
              whereArgs: [candidateContrib['id']],
            );
          }
        } else {
          final unlinkedPayments = await txn.query(
            tableDebtPayments,
            where: 'debt_id = ? AND transaction_id IS NULL',
            whereArgs: [prevLinkedId],
          );
          final candidatePayments = unlinkedPayments.where((p) {
            final amtMatches =
                ((p['amount'] as num).toDouble() - previousTransaction.amount)
                    .abs() <
                0.001;
            final pDate = _extractDateMs(p['date'] ?? p['payment_date']);
            final dateMatches =
                pDate != null && (pDate - txDate).abs() <= 60000;
            return amtMatches && dateMatches;
          }).toList();

          if (candidatePayments.length == 1) {
            final reverseDebtMatches = await txn.query(
              tableTransactions,
              where: 'linked_entity_id = ? AND abs(amount - ?) < 0.001 AND abs(date - ?) <= 60000',
              whereArgs: [prevLinkedId, previousTransaction.amount, txDate],
            );
            if (reverseDebtMatches.length == 1) {
              final candidatePayment = candidatePayments.single;
              final oldAmount = (candidatePayment['amount'] as num).toDouble();
              final oldPrincipal =
                  (candidatePayment['principal_portion'] as num?)?.toDouble() ??
                  oldAmount;
              final oldInterest =
                  (candidatePayment['interest_portion'] as num?)?.toDouble() ??
                  0.0;
              if ((transaction.amount - oldAmount).abs() < 0.001) {
                preservedDebtPrincipal = oldPrincipal;
                preservedDebtInterest = oldInterest;
              } else if (oldAmount > 0) {
                final ratio = (oldPrincipal / oldAmount).clamp(0.0, 1.0);
                preservedDebtPrincipal = transaction.amount * ratio;
                preservedDebtInterest =
                    transaction.amount - preservedDebtPrincipal;
              }
              await _revertDebtPaymentInTxn(txn, prevLinkedId, oldPrincipal);
              await txn.delete(
                tableDebtPayments,
                where: 'id = ?',
                whereArgs: [candidatePayment['id']],
              );
            }
          }
        }
      }

      // If previous transaction was a shared reimbursement or loan repayment, adjust parent transaction(s)
      final wasSettlement =
          previousTransaction.category ==
              CategoryConstants.categorySharedReimbursement ||
          previousTransaction.category ==
              CategoryConstants.categoryLoanRepayment;
      final isStillSettlement =
          transaction.category ==
              CategoryConstants.categorySharedReimbursement ||
          transaction.category == CategoryConstants.categoryLoanRepayment;

      if (wasSettlement) {
        final rawLinked = previousTransaction.linkedEntityId?.trim() ?? '';
        final parentIds = rawLinked
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();

        if (parentIds.isNotEmpty) {
          final personName =
              (previousTransaction.sharedWith ?? transaction.sharedWith)
                  ?.trim();
          final cleanPerson = personName?.isNotEmpty == true
              ? personName!.toLowerCase()
              : null;

          if (!isStillSettlement) {
            // Category was changed away from settlement -> roll back entire previous settlement from parents
            var remainingToRollback = previousTransaction.amount;
            for (final parentId in parentIds.reversed) {
              if (remainingToRollback <= 0.0001) break;
              final parentRows = await txn.query(
                tableTransactions,
                where: 'id = ?',
                whereArgs: [parentId],
                limit: 1,
              );
              if (parentRows.isEmpty) {
                throw StateError(
                  'Linked parent transaction $parentId does not exist.',
                );
              }
              final parent = TransactionEntity.fromMap(parentRows.first);
              final loan = LoanShareHelper.parseLoan(parent.sharedWith);
              String? updatedSharedWith = parent.sharedWith;
              double amountRevertedFromThisParent = 0.0;

              if (loan != null) {
                amountRevertedFromThisParent = remainingToRollback.clamp(
                  0.0,
                  loan.repaidAmount,
                );
                final newRepaid =
                    (loan.repaidAmount - amountRevertedFromThisParent).clamp(
                      0.0,
                      double.infinity,
                    );
                final isRepaid =
                    newRepaid >= loan.totalExpected && loan.totalExpected > 0;
                final updatedLoan = loan.copyWith(
                  repaidAmount: newRepaid,
                  isRepaid: isRepaid,
                );
                updatedSharedWith = LoanShareHelper.encodeLoan(updatedLoan);
              } else {
                final shares = SplitHelper.parseShares(parent.sharedWith);
                if (shares.isNotEmpty) {
                  final isRealPersonInShares =
                      cleanPerson != null &&
                      shares.any(
                        (s) => s.personName.trim().toLowerCase() == cleanPerson,
                      );
                  final effectivePerson = isRealPersonInShares
                      ? cleanPerson
                      : null;

                  final reversedShares = shares.reversed.toList();
                  final updatedReversed = <SplitPersonShare>[];
                  for (final s in reversedShares) {
                    final isPersonMatch =
                        effectivePerson != null &&
                        s.personName.trim().toLowerCase() == effectivePerson;
                    final available =
                        remainingToRollback - amountRevertedFromThisParent;
                    if ((isPersonMatch || effectivePerson == null) &&
                        s.reimbursedAmount > 0 &&
                        available > 0) {
                      final canRevert = available.clamp(
                        0.0,
                        s.reimbursedAmount,
                      );
                      amountRevertedFromThisParent += canRevert;
                      final newShareReimbursed =
                          (s.reimbursedAmount - canRevert).clamp(0.0, s.amount);
                      updatedReversed.add(
                        s.copyWith(
                          reimbursedAmount: newShareReimbursed,
                          isSettled:
                              newShareReimbursed >= s.amount && s.amount > 0,
                        ),
                      );
                    } else {
                      updatedReversed.add(s);
                    }
                  }
                  updatedSharedWith = SplitHelper.encodeShares(
                    updatedReversed.reversed.toList(),
                  );
                }
                if (amountRevertedFromThisParent <= 0 && shares.isEmpty) {
                  amountRevertedFromThisParent = remainingToRollback.clamp(
                    0.0,
                    parent.reimbursedAmount,
                  );
                }
              }

              remainingToRollback -= amountRevertedFromThisParent;
              final rolledBackReimbursed =
                  (parent.reimbursedAmount - amountRevertedFromThisParent)
                      .clamp(0.0, double.infinity);
              final rolledBackSettled =
                  rolledBackReimbursed >= parent.friendsShare &&
                  parent.friendsShare > 0;
              final updatedParent = parent.copyWith(
                reimbursedAmount: rolledBackReimbursed,
                isSettled: rolledBackSettled,
                sharedWith: updatedSharedWith,
                updatedAt: DateTime.now(),
              );
              await txn.update(
                tableTransactions,
                updatedParent.toMap(),
                where: 'id = ?',
                whereArgs: [parentId],
              );
            }

            if (remainingToRollback > 0.001) {
              throw ArgumentError(
                'Settlement category change rollback of ${previousTransaction.amount.toStringAsFixed(2)} exceeds total reimbursed amount across linked expenses by ${remainingToRollback.toStringAsFixed(2)}.',
              );
            }
          } else {
            // Still a settlement -> adjust reimbursement difference across parents if amount changed
            final delta = transaction.amount - previousTransaction.amount;
            if (delta.abs() > 0.0001) {
              if (delta < 0) {
                // Reimbursement decreased -> rollback (-delta) across parents (in reverse order)
                var remainingToRollback = -delta;
                for (final parentId in parentIds.reversed) {
                  if (remainingToRollback <= 0.0001) break;
                  final parentRows = await txn.query(
                    tableTransactions,
                    where: 'id = ?',
                    whereArgs: [parentId],
                    limit: 1,
                  );
                  if (parentRows.isEmpty) {
                    throw StateError(
                      'Linked parent transaction $parentId does not exist.',
                    );
                  }
                  final parent = TransactionEntity.fromMap(parentRows.first);
                  final loan = LoanShareHelper.parseLoan(parent.sharedWith);
                  String? updatedSharedWith = parent.sharedWith;
                  double amountRevertedFromThisParent = 0.0;

                  if (loan != null) {
                    amountRevertedFromThisParent = remainingToRollback.clamp(
                      0.0,
                      loan.repaidAmount,
                    );
                    final newRepaid =
                        (loan.repaidAmount - amountRevertedFromThisParent)
                            .clamp(0.0, double.infinity);
                    final isRepaid =
                        newRepaid >= loan.totalExpected &&
                        loan.totalExpected > 0;
                    final updatedLoan = loan.copyWith(
                      repaidAmount: newRepaid,
                      isRepaid: isRepaid,
                    );
                    updatedSharedWith = LoanShareHelper.encodeLoan(updatedLoan);
                  } else {
                    final shares = SplitHelper.parseShares(parent.sharedWith);
                    if (shares.isNotEmpty) {
                      final isRealPersonInShares =
                          cleanPerson != null &&
                          shares.any(
                            (s) =>
                                s.personName.trim().toLowerCase() ==
                                cleanPerson,
                          );
                      final effectivePerson = isRealPersonInShares
                          ? cleanPerson
                          : null;

                      final reversedShares = shares.reversed.toList();
                      final updatedReversed = <SplitPersonShare>[];
                      for (final s in reversedShares) {
                        final isPersonMatch =
                            effectivePerson != null &&
                            s.personName.trim().toLowerCase() ==
                                effectivePerson;
                        final available =
                            remainingToRollback - amountRevertedFromThisParent;
                        if ((isPersonMatch || effectivePerson == null) &&
                            s.reimbursedAmount > 0 &&
                            available > 0) {
                          final canRevert = available.clamp(
                            0.0,
                            s.reimbursedAmount,
                          );
                          amountRevertedFromThisParent += canRevert;
                          final newShareReimbursed =
                              (s.reimbursedAmount - canRevert).clamp(
                                0.0,
                                s.amount,
                              );
                          updatedReversed.add(
                            s.copyWith(
                              reimbursedAmount: newShareReimbursed,
                              isSettled:
                                  newShareReimbursed >= s.amount &&
                                  s.amount > 0,
                            ),
                          );
                        } else {
                          updatedReversed.add(s);
                        }
                      }
                      updatedSharedWith = SplitHelper.encodeShares(
                        updatedReversed.reversed.toList(),
                      );
                    }
                    if (amountRevertedFromThisParent <= 0 && shares.isEmpty) {
                      amountRevertedFromThisParent = remainingToRollback.clamp(
                        0.0,
                        parent.reimbursedAmount,
                      );
                    }
                  }

                  remainingToRollback -= amountRevertedFromThisParent;
                  final rolledBackReimbursed =
                      (parent.reimbursedAmount - amountRevertedFromThisParent)
                          .clamp(0.0, double.infinity);
                  final rolledBackSettled =
                      rolledBackReimbursed >= parent.friendsShare &&
                      parent.friendsShare > 0;
                  final updatedParent = parent.copyWith(
                    reimbursedAmount: rolledBackReimbursed,
                    isSettled: rolledBackSettled,
                    sharedWith: updatedSharedWith,
                    updatedAt: DateTime.now(),
                  );
                  await txn.update(
                    tableTransactions,
                    updatedParent.toMap(),
                    where: 'id = ?',
                    whereArgs: [parentId],
                  );
                }

                if (remainingToRollback > 0.001) {
                  throw ArgumentError(
                    'Settlement reduction of ${delta.abs().toStringAsFixed(2)} exceeds total reimbursed amount across linked expenses by ${remainingToRollback.toStringAsFixed(2)}.',
                  );
                }
              } else {
                // Reimbursement increased (delta > 0) -> apply additional reimbursement across parents
                var remainingToAdd = delta;
                for (final parentId in parentIds) {
                  if (remainingToAdd <= 0.0001) break;
                  final parentRows = await txn.query(
                    tableTransactions,
                    where: 'id = ?',
                    whereArgs: [parentId],
                    limit: 1,
                  );
                  if (parentRows.isEmpty) {
                    throw StateError(
                      'Linked parent transaction $parentId does not exist.',
                    );
                  }
                  final parent = TransactionEntity.fromMap(parentRows.first);
                  final loan = LoanShareHelper.parseLoan(parent.sharedWith);
                  String? updatedSharedWith = parent.sharedWith;
                  double amountAddedToThisParent = 0.0;

                  if (loan != null) {
                    final pendingLoan = (loan.totalExpected - loan.repaidAmount)
                        .clamp(0.0, double.infinity);
                    if (pendingLoan > 0.0001) {
                      amountAddedToThisParent = remainingToAdd.clamp(
                        0.0,
                        pendingLoan,
                      );
                      final newRepaid =
                          loan.repaidAmount + amountAddedToThisParent;
                      final isRepaid =
                          newRepaid >= loan.totalExpected &&
                          loan.totalExpected > 0;
                      final updatedLoan = loan.copyWith(
                        repaidAmount: newRepaid,
                        isRepaid: isRepaid,
                      );
                      updatedSharedWith = LoanShareHelper.encodeLoan(
                        updatedLoan,
                      );
                    }
                  } else {
                    final shares = SplitHelper.parseShares(parent.sharedWith);
                    if (shares.isNotEmpty) {
                      final isRealPersonInShares =
                          cleanPerson != null &&
                          shares.any(
                            (s) =>
                                s.personName.trim().toLowerCase() ==
                                cleanPerson,
                          );
                      final effectivePerson = isRealPersonInShares
                          ? cleanPerson
                          : null;

                      final updatedShares = <SplitPersonShare>[];
                      for (final s in shares) {
                        final isPersonMatch =
                            effectivePerson != null &&
                            s.personName.trim().toLowerCase() ==
                                effectivePerson;
                        final available =
                            remainingToAdd - amountAddedToThisParent;
                        final pendingShare = (s.amount - s.reimbursedAmount)
                            .clamp(0.0, double.infinity);
                        if ((isPersonMatch || effectivePerson == null) &&
                            pendingShare > 0.0001 &&
                            available > 0.0001) {
                          final canAdd = available.clamp(0.0, pendingShare);
                          amountAddedToThisParent += canAdd;
                          final newShareReimbursed =
                              s.reimbursedAmount + canAdd;
                          updatedShares.add(
                            s.copyWith(
                              reimbursedAmount: newShareReimbursed,
                              isSettled:
                                  newShareReimbursed >= s.amount &&
                                  s.amount > 0,
                            ),
                          );
                        } else {
                          updatedShares.add(s);
                        }
                      }
                      updatedSharedWith = SplitHelper.encodeShares(
                        updatedShares,
                      );
                    } else {
                      final pendingTotal = parent.pendingReimbursement;
                      if (pendingTotal > 0.0001) {
                        amountAddedToThisParent = remainingToAdd.clamp(
                          0.0,
                          pendingTotal,
                        );
                      }
                    }
                  }

                  remainingToAdd -= amountAddedToThisParent;
                  final newReimbursed =
                      parent.reimbursedAmount + amountAddedToThisParent;
                  final newSettled =
                      newReimbursed >= parent.friendsShare &&
                      parent.friendsShare > 0;
                  final updatedParent = parent.copyWith(
                    reimbursedAmount: newReimbursed,
                    isSettled: newSettled,
                    sharedWith: updatedSharedWith,
                    updatedAt: DateTime.now(),
                  );
                  await txn.update(
                    tableTransactions,
                    updatedParent.toMap(),
                    where: 'id = ?',
                    whereArgs: [parentId],
                  );
                }

                if (remainingToAdd > 0.001) {
                  throw ArgumentError(
                    'Settlement increase of ${delta.toStringAsFixed(2)} exceeds remaining unpaid amount across linked expenses by ${remainingToAdd.toStringAsFixed(2)}.',
                  );
                }
              }
            }
          }
        }
      }

      if (transaction.id != previousTransaction.id) {
        throw ArgumentError(
          'Cannot update transaction: ID mismatch (${transaction.id} != ${previousTransaction.id})',
        );
      }
      final updatedCount = await txn.update(
        tableTransactions,
        transaction.toMap(),
        where: 'id = ?',
        whereArgs: [transaction.id],
      );
      if (updatedCount != 1) {
        throw StateError(
          'Cannot update transaction ${transaction.id}: expected 1 row to update, but affected $updatedCount rows.',
        );
      }
    } else {
      final existing = await txn.query(
        tableTransactions,
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [transaction.id],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        throw StateError(
          'Transaction with ID ${transaction.id} already exists. Duplicate additions are rejected.',
        );
      }
      await txn.insert(
        tableTransactions,
        transaction.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    }

    // 2. Apply new transaction balance impact
    await _applyTxBalanceImpactInTxn(txn, transaction, isRevert: false);

    // 3. Apply multi-goal allocations or linked entity impacts
    if (multiGoalAllocations != null && multiGoalAllocations.isNotEmpty) {
      for (final entry in multiGoalAllocations.entries) {
        final goalId = entry.key;
        final allocAmount = entry.value;
        if (allocAmount <= 0) continue;
        await _applyGoalContributionInTxn(
          txn,
          goalId,
          allocAmount,
          transaction,
          notes: 'Allocated from: ${transaction.title}',
          sourceAccountId: multiGoalSourceAccountId ?? transaction.accountId,
        );
      }
    } else if (transaction.linkedEntityId != null &&
        transaction.linkedEntityId!.trim().isNotEmpty) {
      final linkedId = transaction.linkedEntityId!.trim();
      // Check if goal
      final goalCheck = await txn.query(
        tableSavingsGoals,
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [linkedId],
        limit: 1,
      );
      if (goalCheck.isNotEmpty) {
        await _applyGoalContributionInTxn(
          txn,
          linkedId,
          transaction.amount,
          transaction,
        );
      } else {
        // Check if debt
        final debtCheck = await txn.query(
          tableDebts,
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [linkedId],
          limit: 1,
        );
        if (debtCheck.isNotEmpty) {
          await _applyDebtPaymentInTxn(
            txn,
            linkedId,
            transaction.amount,
            transaction,
            principalPortion: preservedDebtPrincipal,
            interestPortion: preservedDebtInterest,
          );
        }
      }
    }
  }

  /// Atomically settles multiple shared expenses in a single ACID transaction.
  Future<void> settleSharedExpensesAtomic({
    required List<TransactionEntity> updatedOriginals,
    required TransactionEntity settlementTransaction,
    List<TransactionEntity>? additionalTransactions,
    DatabaseExecutor? executor,
  }) async {
    Future<void> work(DatabaseExecutor txn) async {
      if (settlementTransaction.accountId != null) {
        await _adjustAccountBalanceInTxn(
          txn,
          settlementTransaction.accountId!,
          settlementTransaction.amount,
        );
      }
      for (final orig in updatedOriginals) {
        final count = await txn.update(
          tableTransactions,
          orig.toMap(),
          where: 'id = ?',
          whereArgs: [orig.id],
        );
        if (count != 1) {
          throw StateError(
            'Failed to update shared transaction ${orig.id}: affected $count rows.',
          );
        }
      }
      final existing = await txn.query(
        tableTransactions,
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [settlementTransaction.id],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        throw StateError(
          'Settlement transaction ${settlementTransaction.id} already exists.',
        );
      }
      await txn.insert(
        tableTransactions,
        settlementTransaction.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      if (additionalTransactions != null) {
        for (final addTx in additionalTransactions) {
          final addExisting = await txn.query(
            tableTransactions,
            columns: ['id'],
            where: 'id = ?',
            whereArgs: [addTx.id],
            limit: 1,
          );
          if (addExisting.isNotEmpty) {
            throw StateError(
              'Additional transaction ${addTx.id} already exists.',
            );
          }
          await txn.insert(
            tableTransactions,
            addTx.toMap(),
            conflictAlgorithm: ConflictAlgorithm.abort,
          );
        }
      }
    }

    if (executor != null) {
      await work(executor);
    } else {
      final client = await database;
      await client.transaction(work);
    }
  }

  /// Atomically settles a single shared expense reimbursement.
  Future<void> settleSharedExpenseAtomic({
    required TransactionEntity updatedOriginal,
    required TransactionEntity settlementTransaction,
    DatabaseExecutor? executor,
  }) async {
    await settleSharedExpensesAtomic(
      updatedOriginals: [updatedOriginal],
      settlementTransaction: settlementTransaction,
      executor: executor,
    );
  }

  /// Atomically deletes a settlement transaction (reimbursement or loan repayment),
  /// restores original transactions to their rolled-back amounts/shares, and reverts
  /// destination account balance in a single ACID SQLite transaction.
  Future<void> deleteSettlementTransactionAtomic({
    required String settlementTransactionId,
    required List<TransactionEntity> updatedOriginals,
    DatabaseExecutor? executor,
  }) async {
    Future<void> work(DatabaseExecutor txn) async {
      final rows = await txn.query(
        tableTransactions,
        where: 'id = ?',
        whereArgs: [settlementTransactionId],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final settlementTx = TransactionEntity.fromMap(rows.first);
        await _applyTxBalanceImpactInTxn(txn, settlementTx, isRevert: true);
      }

      await txn.delete(
        tableTransactions,
        where: 'id = ?',
        whereArgs: [settlementTransactionId],
      );

      for (final orig in updatedOriginals) {
        final count = await txn.update(
          tableTransactions,
          orig.toMap(),
          where: 'id = ?',
          whereArgs: [orig.id],
        );
        if (count != 1) {
          throw StateError(
            'Failed to update shared transaction ${orig.id}: affected $count rows.',
          );
        }
      }
    }

    if (executor != null) {
      await work(executor);
    } else {
      final client = await database;
      await client.transaction(work);
    }
  }

  /// Atomically creates a savings goal with an optional initial deposit,
  /// adjusts bank account balance, records goal contribution, and logs
  /// initial transaction in a single ACID SQLite transaction.
  Future<void> createSavingsGoalAtomic({
    required SavingsGoalEntity goal,
    required double initialAmount,
    bool deductFromAccount = true,
    String? accountId,
    String paymentSource = 'Bank Account',
    TransactionEntity? transaction,
    DatabaseExecutor? executor,
  }) async {
    Future<void> work(DatabaseExecutor txn) async {
      final effectiveAmount = initialAmount > 0 ? initialAmount : 0.0;
      final newCurrentAmount = goal.currentAmount + effectiveAmount;
      final newStatus =
          (newCurrentAmount >= goal.targetAmount && goal.targetAmount > 0)
          ? GoalStatus.completed
          : goal.status;

      double? updatedAllocPct;
      if (goal.autoSyncAccount && goal.linkedAccountId != null) {
        final accRows = await txn.query(
          tableBankAccounts,
          columns: ['current_balance'],
          where: 'id = ?',
          whereArgs: [goal.linkedAccountId],
          limit: 1,
        );
        if (accRows.isNotEmpty) {
          final accBal = (accRows.first['current_balance'] as num).toDouble();
          if (accBal > 0) {
            updatedAllocPct = (newCurrentAmount / accBal * 100.0).clamp(
              0.0,
              100.0,
            );
          }
        }
      }

      final finalGoal = goal.copyWith(
        currentAmount: newCurrentAmount,
        status: newStatus,
        allocationPercentage: updatedAllocPct ?? goal.allocationPercentage,
        updatedAt: DateTime.now(),
      );

      await txn.insert(
        tableSavingsGoals,
        finalGoal.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      if (effectiveAmount > 0) {
        final now = DateTime.now();
        TransactionEntity? tx;
        if (deductFromAccount && accountId != null) {
          await _adjustAccountBalanceInTxn(txn, accountId, -effectiveAmount);
          tx =
              transaction ??
              TransactionEntity(
                id: const Uuid().v4(),
                title: 'Goal: ${goal.title}',
                amount: effectiveAmount,
                type: TransactionType.expense,
                category: 'Savings & Investments',
                date: now,
                paymentSource: paymentSource,
                accountId: accountId,
                linkedEntityId: goal.id,
                notes: 'Initial deposit for goal "${goal.title}"',
                createdAt: now,
                updatedAt: now,
              );
          await txn.insert(
            tableTransactions,
            tx.toMap(),
            conflictAlgorithm: ConflictAlgorithm.abort,
          );
        }

        final contribution = GoalContributionEntity(
          id: const Uuid().v4(),
          goalId: goal.id,
          amount: effectiveAmount,
          date: now,
          notes: 'Initial savings deposit for "${goal.title}"',
          sourceAccountId: deductFromAccount ? accountId : null,
          transactionId: tx?.id,
          createdAt: now,
        );
        await txn.insert(
          tableGoalContributions,
          contribution.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }

    if (executor != null) {
      await work(executor);
    } else {
      final client = await database;
      await client.transaction(work);
    }
  }

  /// Exports all financial and user data in a single ACID read transaction
  /// to ensure consistent point-in-time snapshot integrity.
  Future<Map<String, dynamic>> exportSnapshotTables() async {
    final client = await database;
    return await client.transaction((txn) async {
      final txRows = await txn.query(tableTransactions);
      final budgetRows = await txn.query(tableBudgets);
      final goalRows = await txn.query(tableSavingsGoals);
      final contribRows = await txn.query(tableGoalContributions);
      final debtRows = await txn.query(tableDebts);
      final paymentRows = await txn.query(tableDebtPayments);
      final investRows = await txn.query(tableInvestments);
      final recurRows = await txn.query(tableRecurring);
      final bankRows = await txn.query(tableBankAccounts);
      final cardRows = await txn.query(tableCreditCards);
      final chatSessionRows = await txn.query(tableChatSessions);
      final chatMessageRows = await txn.query(tableChatMessages);
      final reportRows = await txn.query(tableAiReports);

      return {
        'transactions': txRows.map(TransactionEntity.fromMap).toList(),
        'budgets': budgetRows.map(BudgetEntity.fromMap).toList(),
        'savingsGoals': goalRows.map(SavingsGoalEntity.fromMap).toList(),
        'savingsContributions': contribRows
            .map(GoalContributionEntity.fromMap)
            .toList(),
        'debts': debtRows.map(DebtEntity.fromMap).toList(),
        'debtPayments': paymentRows.map(DebtPaymentEntity.fromMap).toList(),
        'investments': investRows.map(InvestmentEntity.fromMap).toList(),
        'recurringExpenses': recurRows
            .map(RecurringExpenseEntity.fromMap)
            .toList(),
        'bankAccounts': bankRows.map(BankAccountEntity.fromMap).toList(),
        'creditCards': cardRows.map(CreditCardEntity.fromMap).toList(),
        'chatSessions': chatSessionRows.map(AiChatSession.fromMap).toList(),
        'chatMessages': chatMessageRows.map(AiChatMessage.fromMap).toList(),
        'aiReports': reportRows.map(AiReportItem.fromMap).toList(),
      };
    });
  }

  /// Atomically transfers funds between accounts and records the transfer transaction in one SQLite transaction.
  Future<void> performTransferAtomic({
    required BankAccountEntity fromAccount,
    required BankAccountEntity toAccount,
    required double amount,
    required TransactionEntity transaction,
    DatabaseExecutor? executor,
  }) async {
    Future<void> work(DatabaseExecutor txn) async {
      await _adjustAccountBalanceInTxn(txn, fromAccount.id, -amount);
      await _adjustAccountBalanceInTxn(txn, toAccount.id, amount);
      final existing = await txn.query(
        tableTransactions,
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [transaction.id],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        throw StateError(
          'Transfer transaction ${transaction.id} already exists.',
        );
      }
      await txn.insert(
        tableTransactions,
        transaction.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    }

    if (executor != null) {
      await work(executor);
    } else {
      final client = await database;
      await client.transaction(work);
    }
  }

  /// Atomically pays a credit card bill, restores available credit limit,
  /// deducts from bank account, and records the payment transaction in one SQLite transaction.
  Future<void> payCreditCardBillAtomic({
    required BankAccountEntity fromAccount,
    required CreditCardEntity creditCard,
    required double amount,
    required TransactionEntity transaction,
    DatabaseExecutor? executor,
  }) async {
    Future<void> work(DatabaseExecutor txn) async {
      await _adjustAccountBalanceInTxn(txn, fromAccount.id, -amount);
      await _adjustCardUsedAmountInTxn(txn, creditCard.id, -amount);
      final existing = await txn.query(
        tableTransactions,
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [transaction.id],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        throw StateError(
          'Bill payment transaction ${transaction.id} already exists.',
        );
      }
      await txn.insert(
        tableTransactions,
        transaction.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    }

    if (executor != null) {
      await work(executor);
    } else {
      final client = await database;
      await client.transaction(work);
    }
  }

  /// Atomically adds a goal contribution, updates goal progress & status (preserving paused status),
  /// adjusts bank account balances, and logs transaction in an ACID SQLite transaction.
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
    Future<void> work(DatabaseExecutor txn) async {
      final tx = logAsTransaction
          ? (transaction ??
                TransactionEntity(
                  id: const Uuid().v4(),
                  title: 'Goal: ${goal.title}',
                  amount: amount,
                  type: TransactionType.transfer,
                  category: 'Savings & Investments',
                  date: DateTime.now(),
                  paymentSource: paymentSource,
                  accountId:
                      (accountId != null && accountId != goal.linkedAccountId)
                      ? accountId
                      : null,
                  toAccountId:
                      (accountId != null && accountId != goal.linkedAccountId)
                      ? goal.linkedAccountId
                      : null,
                  linkedEntityId: goal.id,
                  notes:
                      notes ?? 'Savings contribution towards "${goal.title}"',
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                ))
          : null;

      if (tx != null) {
        await _applyTxBalanceImpactInTxn(txn, tx, isRevert: false);
        final existing = await txn.query(
          tableTransactions,
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [tx.id],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          throw StateError('Transaction ${tx.id} already exists.');
        }
        await txn.insert(
          tableTransactions,
          tx.toMap(),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }

      await _applyGoalContributionInTxn(
        txn,
        goal.id,
        amount,
        tx,
        notes: notes,
        sourceAccountId: accountId,
      );
    }

    if (executor != null) {
      await work(executor);
    } else {
      final client = await database;
      await client.transaction(work);
    }
  }

  /// Atomically records a debt payment, updates remaining debt balance,
  /// adjusts bank account balance, and logs transaction in an ACID SQLite transaction.
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
    Future<void> work(DatabaseExecutor txn) async {
      final tx = logAsTransaction
          ? (transaction ??
                TransactionEntity(
                  id: const Uuid().v4(),
                  title: 'EMI: ${debt.title}',
                  amount: amount,
                  type: TransactionType.expense,
                  category: 'Debt & Loan Repayment',
                  date: DateTime.now(),
                  paymentSource: paymentSource,
                  accountId: accountId,
                  linkedEntityId: debt.id,
                  notes: notes ?? 'Debt repayment for "${debt.title}"',
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                ))
          : null;

      if (tx != null) {
        await _applyTxBalanceImpactInTxn(txn, tx, isRevert: false);
        final existing = await txn.query(
          tableTransactions,
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [tx.id],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          throw StateError('Transaction ${tx.id} already exists.');
        }
        await txn.insert(
          tableTransactions,
          tx.toMap(),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }

      await _applyDebtPaymentInTxn(
        txn,
        debt.id,
        amount,
        tx,
        principalPortion: principalPortion,
        interestPortion: interestPortion,
        notes: notes,
        sourceAccountId: accountId,
      );
    }

    if (executor != null) {
      await work(executor);
    } else {
      final client = await database;
      await client.transaction(work);
    }
  }

  /// Atomically pays a recurring bill: adjusts bank account or credit card balance,
  /// logs the transaction, and advances next due date in one ACID SQLite transaction.
  Future<void> payRecurringExpenseAtomic({
    required RecurringExpenseEntity recurringExpense,
    required DateTime nextDueDate,
    BankAccountEntity? fromAccount,
    CreditCardEntity? creditCard,
    required TransactionEntity transaction,
    DatabaseExecutor? executor,
  }) async {
    Future<void> work(DatabaseExecutor txn) async {
      final existingRecur = await txn.query(
        tableRecurring,
        where: 'id = ?',
        whereArgs: [recurringExpense.id],
        limit: 1,
      );
      if (existingRecur.isEmpty) {
        throw StateError(
          'Recurring expense ${recurringExpense.id} does not exist.',
        );
      }

      final storedDueMillis = existingRecur.first['next_due_date'] as int?;
      if (storedDueMillis != null) {
        final expectedDueMillis =
            recurringExpense.nextDueDate.millisecondsSinceEpoch;
        if (storedDueMillis > expectedDueMillis) {
          throw StateError(
            'Recurring expense "${recurringExpense.title}" has already been paid for this period (due date has already advanced).',
          );
        }
      }

      if (fromAccount != null) {
        await _adjustAccountBalanceInTxn(
          txn,
          fromAccount.id,
          -recurringExpense.amount,
        );
      } else if (creditCard != null) {
        await _adjustCardUsedAmountInTxn(
          txn,
          creditCard.id,
          recurringExpense.amount,
        );
      } else {
        // Enforce ledger target integrity: no dangling account/card IDs
        if (transaction.accountId != null) {
          throw StateError(
            'Account "${transaction.accountId}" was specified on transaction but no valid account was provided for balance deduction.',
          );
        }
        if (transaction.creditCardId != null) {
          throw StateError(
            'Credit card "${transaction.creditCardId}" was specified on transaction but no valid card was provided for balance deduction.',
          );
        }
      }

      final existingTx = await txn.query(
        tableTransactions,
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [transaction.id],
        limit: 1,
      );
      if (existingTx.isNotEmpty) {
        throw StateError(
          'Recurring payment transaction ${transaction.id} already exists.',
        );
      }
      await txn.insert(
        tableTransactions,
        transaction.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      final updatedRecur = recurringExpense.copyWith(
        nextDueDate: nextDueDate,
        updatedAt: DateTime.now(),
      );
      await txn.update(
        tableRecurring,
        updatedRecur.toMap(),
        where: 'id = ?',
        whereArgs: [recurringExpense.id],
      );
    }

    if (executor != null) {
      await work(executor);
    } else {
      final client = await database;
      await client.transaction(work);
    }
  }

  /// Atomically saves/updates an investment, optionally deducting the invested amount
  /// from a source bank account and logging the transaction in one ACID SQLite transaction.
  Future<void> saveInvestmentAtomic({
    required InvestmentEntity investment,
    BankAccountEntity? sourceAccount,
    TransactionEntity? transaction,
    DatabaseExecutor? executor,
  }) async {
    Future<void> work(DatabaseExecutor txn) async {
      if (sourceAccount != null && transaction != null) {
        await _adjustAccountBalanceInTxn(
          txn,
          sourceAccount.id,
          -investment.investedAmount,
        );

        final existingTx = await txn.query(
          tableTransactions,
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [transaction.id],
          limit: 1,
        );
        if (existingTx.isNotEmpty) {
          throw StateError(
            'Investment transaction ${transaction.id} already exists.',
          );
        }
        await txn.insert(
          tableTransactions,
          transaction.toMap(),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }

      final existing = await txn.query(
        tableInvestments,
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [investment.id],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        await txn.update(
          tableInvestments,
          investment.toMap(),
          where: 'id = ?',
          whereArgs: [investment.id],
        );
      } else {
        await txn.insert(
          tableInvestments,
          investment.toMap(),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }
    }

    if (executor != null) {
      await work(executor);
    } else {
      final client = await database;
      await client.transaction(work);
    }
  }

  /// Atomically deletes a transaction and reverts its linked bank account / credit card balance impacts,
  /// savings goals contributions, and debt payments within an ACID SQLite transaction.
  Future<void> deleteTransactionAtomic(
    String id, {
    DatabaseExecutor? executor,
  }) async {
    if (executor != null) {
      await _executeDeleteTransactionInTxn(executor, id);
    } else {
      final client = await database;
      await client.transaction((txn) async {
        await _executeDeleteTransactionInTxn(txn, id);
      });
    }
  }

  static Future<void> _executeDeleteTransactionInTxn(
    DatabaseExecutor txn,
    String id,
  ) async {
    final rows = await txn.query(
      tableTransactions,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      final tx = TransactionEntity.fromMap(rows.first);
      await _applyTxBalanceImpactInTxn(txn, tx, isRevert: true);

      // Revert and delete linked goal contributions
      final linkedContribs = await txn.query(
        tableGoalContributions,
        where: 'transaction_id = ?',
        whereArgs: [id],
      );
      for (final row in linkedContribs) {
        final goalId = row['goal_id'] as String;
        final amount = (row['amount'] as num).toDouble();
        await _revertGoalContributionInTxn(txn, goalId, amount);
      }
      if (linkedContribs.isNotEmpty) {
        await txn.delete(
          tableGoalContributions,
          where: 'transaction_id = ?',
          whereArgs: [id],
        );
      }

      // Revert and delete linked debt payments using principal_portion
      final linkedPayments = await txn.query(
        tableDebtPayments,
        where: 'transaction_id = ?',
        whereArgs: [id],
      );
      for (final row in linkedPayments) {
        final debtId = row['debt_id'] as String;
        final principal =
            (row['principal_portion'] as num?)?.toDouble() ??
            (row['amount'] as num).toDouble();
        await _revertDebtPaymentInTxn(txn, debtId, principal);
      }
      if (linkedPayments.isNotEmpty) {
        await txn.delete(
          tableDebtPayments,
          where: 'transaction_id = ?',
          whereArgs: [id],
        );
      }

      // Consistent Fallback: only modify goal or debt aggregate if exactly one unambiguous unlinked history row is identified
      // matching the transaction date within 60 seconds (mirroring the v14 migration contract) with bidirectional uniqueness.
      final linkedId = tx.linkedEntityId?.trim();
      if (linkedId != null &&
          linkedId.isNotEmpty &&
          linkedContribs.isEmpty &&
          linkedPayments.isEmpty) {
        final txDate = tx.date.millisecondsSinceEpoch;
        final unlinkedContribs = await txn.query(
          tableGoalContributions,
          where: 'goal_id = ? AND transaction_id IS NULL',
          whereArgs: [linkedId],
        );
        final candidateContribs = unlinkedContribs.where((c) {
          final amtMatches =
              ((c['amount'] as num).toDouble() - tx.amount).abs() < 0.001;
          final cDate = _extractDateMs(c['date']);
          final dateMatches = cDate != null && (cDate - txDate).abs() <= 60000;
          return amtMatches && dateMatches;
        }).toList();

        if (candidateContribs.length == 1) {
          final reverseTxMatches = await txn.query(
            tableTransactions,
            where: 'linked_entity_id = ? AND abs(amount - ?) < 0.001 AND abs(date - ?) <= 60000',
            whereArgs: [linkedId, tx.amount, txDate],
          );
          if (reverseTxMatches.length == 1) {
            final candidateContrib = candidateContribs.single;
            final amt = (candidateContrib['amount'] as num).toDouble();
            await _revertGoalContributionInTxn(txn, linkedId, amt);
            await txn.delete(
              tableGoalContributions,
              where: 'id = ?',
              whereArgs: [candidateContrib['id']],
            );
          }
        } else {
          final unlinkedPayments = await txn.query(
            tableDebtPayments,
            where: 'debt_id = ? AND transaction_id IS NULL',
            whereArgs: [linkedId],
          );
          final candidatePayments = unlinkedPayments.where((p) {
            final amtMatches =
                ((p['amount'] as num).toDouble() - tx.amount).abs() < 0.001;
            final pDate = _extractDateMs(p['date'] ?? p['payment_date']);
            final dateMatches =
                pDate != null && (pDate - txDate).abs() <= 60000;
            return amtMatches && dateMatches;
          }).toList();

          if (candidatePayments.length == 1) {
            final reverseDebtMatches = await txn.query(
              tableTransactions,
              where: 'linked_entity_id = ? AND abs(amount - ?) < 0.001 AND abs(date - ?) <= 60000',
              whereArgs: [linkedId, tx.amount, txDate],
            );
            if (reverseDebtMatches.length == 1) {
              final candidatePayment = candidatePayments.single;
              final principal =
                  (candidatePayment['principal_portion'] as num?)?.toDouble() ??
                  (candidatePayment['amount'] as num).toDouble();
              await _revertDebtPaymentInTxn(txn, linkedId, principal);
              await txn.delete(
                tableDebtPayments,
                where: 'id = ?',
                whereArgs: [candidatePayment['id']],
              );
            }
          }
        }
      }
    }
    await txn.delete(tableTransactions, where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> _revertGoalContributionInTxn(
    DatabaseExecutor txn,
    String goalId,
    double amount,
  ) async {
    final goalRows = await txn.query(
      tableSavingsGoals,
      where: 'id = ?',
      whereArgs: [goalId],
      limit: 1,
    );
    if (goalRows.isNotEmpty) {
      final goal = SavingsGoalEntity.fromMap(goalRows.first);
      final newAmount = (goal.currentAmount - amount)
          .clamp(0.0, double.infinity)
          .toDouble();

      // Preserve GoalStatus.paused under all circumstances; only completed reverts to active
      GoalStatus newStatus;
      if (goal.status == GoalStatus.paused) {
        newStatus = GoalStatus.paused;
      } else if (newAmount >= goal.targetAmount) {
        newStatus = GoalStatus.completed;
      } else if (goal.status == GoalStatus.completed) {
        newStatus = GoalStatus.active;
      } else {
        newStatus = goal.status;
      }

      double? updatedAllocPct;
      if (goal.autoSyncAccount && goal.linkedAccountId != null) {
        final accRows = await txn.query(
          tableBankAccounts,
          columns: ['current_balance'],
          where: 'id = ?',
          whereArgs: [goal.linkedAccountId],
          limit: 1,
        );
        if (accRows.isNotEmpty) {
          final accBal = (accRows.first['current_balance'] as num).toDouble();
          if (accBal > 0) {
            updatedAllocPct = (newAmount / accBal * 100.0).clamp(0.0, 100.0);
          }
        }
      }

      await txn.update(
        tableSavingsGoals,
        goal
            .copyWith(
              currentAmount: newAmount,
              status: newStatus,
              allocationPercentage:
                  updatedAllocPct ?? goal.allocationPercentage,
              updatedAt: DateTime.now(),
            )
            .toMap(),
        where: 'id = ?',
        whereArgs: [goalId],
      );
    }
  }

  static Future<void> _applyGoalContributionInTxn(
    DatabaseExecutor txn,
    String goalId,
    double amount,
    TransactionEntity? tx, {
    String? notes,
    String? sourceAccountId,
  }) async {
    if (amount <= 0 || !amount.isFinite) {
      throw ArgumentError(
        'Contribution amount must be positive and finite: $amount',
      );
    }
    final goalRows = await txn.query(
      tableSavingsGoals,
      where: 'id = ?',
      whereArgs: [goalId],
      limit: 1,
    );
    if (goalRows.isEmpty) {
      throw StateError('Savings goal with ID "$goalId" does not exist.');
    }
    final goal = SavingsGoalEntity.fromMap(goalRows.first);
    final newAmount = (goal.currentAmount + amount)
        .clamp(0.0, double.infinity)
        .toDouble();

    // Preserve GoalStatus.paused; never auto-complete a paused goal
    GoalStatus newStatus;
    if (goal.status == GoalStatus.paused) {
      newStatus = GoalStatus.paused;
    } else if (newAmount >= goal.targetAmount) {
      newStatus = GoalStatus.completed;
    } else {
      newStatus = goal.status;
    }

    double? updatedAllocPct;
    if (goal.autoSyncAccount && goal.linkedAccountId != null) {
      final accRows = await txn.query(
        tableBankAccounts,
        columns: ['current_balance'],
        where: 'id = ?',
        whereArgs: [goal.linkedAccountId],
        limit: 1,
      );
      if (accRows.isNotEmpty) {
        final accBal = (accRows.first['current_balance'] as num).toDouble();
        if (accBal > 0) {
          updatedAllocPct = (newAmount / accBal * 100.0).clamp(0.0, 100.0);
        }
      }
    }

    await txn.update(
      tableSavingsGoals,
      goal
          .copyWith(
            currentAmount: newAmount,
            status: newStatus,
            allocationPercentage: updatedAllocPct ?? goal.allocationPercentage,
            updatedAt: DateTime.now(),
          )
          .toMap(),
      where: 'id = ?',
      whereArgs: [goalId],
    );

    final contrib = GoalContributionEntity(
      id: const Uuid().v4(),
      goalId: goalId,
      amount: amount,
      date: tx?.date ?? DateTime.now(),
      notes:
          notes ??
          tx?.notes ??
          (tx != null ? 'Contribution from ${tx.title}' : 'Goal contribution'),
      sourceAccountId: sourceAccountId ?? tx?.accountId,
      transactionId: tx?.id,
      createdAt: DateTime.now(),
    );
    await txn.insert(
      tableGoalContributions,
      contrib.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> _revertDebtPaymentInTxn(
    DatabaseExecutor txn,
    String debtId,
    double principalReduction,
  ) async {
    final debtRows = await txn.query(
      tableDebts,
      where: 'id = ?',
      whereArgs: [debtId],
      limit: 1,
    );
    if (debtRows.isNotEmpty) {
      final debt = DebtEntity.fromMap(debtRows.first);
      final newRemaining = (debt.remainingAmount + principalReduction)
          .clamp(0.0, debt.principalAmount)
          .toDouble();
      final newStatus = newRemaining <= 0
          ? DebtStatus.paidOff
          : (debt.status == DebtStatus.paidOff
                ? DebtStatus.active
                : debt.status);

      await txn.update(
        tableDebts,
        debt
            .copyWith(
              remainingAmount: newRemaining,
              status: newStatus,
              updatedAt: DateTime.now(),
            )
            .toMap(),
        where: 'id = ?',
        whereArgs: [debtId],
      );
    }
  }

  static Future<void> _applyDebtPaymentInTxn(
    DatabaseExecutor txn,
    String debtId,
    double amount,
    TransactionEntity? tx, {
    double? principalPortion,
    double? interestPortion,
    String? notes,
    String? sourceAccountId,
  }) async {
    if (amount <= 0 || !amount.isFinite) {
      throw ArgumentError(
        'Payment amount must be positive and finite: $amount',
      );
    }
    if (principalPortion != null &&
        (principalPortion < 0 || !principalPortion.isFinite)) {
      throw ArgumentError(
        'Principal portion must be non-negative and finite: $principalPortion',
      );
    }
    if (interestPortion != null &&
        (interestPortion < 0 || !interestPortion.isFinite)) {
      throw ArgumentError(
        'Interest portion must be non-negative and finite: $interestPortion',
      );
    }
    final debtRows = await txn.query(
      tableDebts,
      where: 'id = ?',
      whereArgs: [debtId],
      limit: 1,
    );
    if (debtRows.isEmpty) {
      throw StateError('Debt with ID "$debtId" does not exist.');
    }
    final debt = DebtEntity.fromMap(debtRows.first);
    final effectivePrincipal =
        (principalPortion != null && principalPortion > 0)
        ? principalPortion
        : amount;
    final effectiveInterest =
        interestPortion ??
        (amount - effectivePrincipal).clamp(0.0, double.infinity);
    final newRemaining = (debt.remainingAmount - effectivePrincipal)
        .clamp(0.0, debt.principalAmount)
        .toDouble();
    final newStatus = newRemaining <= 0
        ? DebtStatus.paidOff
        : (debt.status == DebtStatus.paidOff ? DebtStatus.active : debt.status);

    await txn.update(
      tableDebts,
      debt
          .copyWith(
            remainingAmount: newRemaining,
            status: newStatus,
            updatedAt: DateTime.now(),
          )
          .toMap(),
      where: 'id = ?',
      whereArgs: [debtId],
    );

    final payment = DebtPaymentEntity(
      id: const Uuid().v4(),
      debtId: debtId,
      amount: amount,
      principalPortion: effectivePrincipal,
      interestPortion: effectiveInterest,
      date: tx?.date ?? DateTime.now(),
      notes:
          notes ??
          tx?.notes ??
          (tx != null ? 'Payment from ${tx.title}' : 'Debt payment'),
      sourceAccountId: sourceAccountId ?? tx?.accountId,
      transactionId: tx?.id,
      createdAt: DateTime.now(),
    );
    await txn.insert(
      tableDebtPayments,
      payment.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> _applyTxBalanceImpactInTxn(
    DatabaseExecutor txn,
    TransactionEntity tx, {
    bool isRevert = false,
  }) async {
    final factor = isRevert ? -1.0 : 1.0;
    if (tx.type == TransactionType.income) {
      if (tx.accountId != null) {
        await _adjustAccountBalanceInTxn(
          txn,
          tx.accountId!,
          factor * tx.amount,
        );
      } else if (tx.creditCardId != null) {
        await _adjustCardUsedAmountInTxn(
          txn,
          tx.creditCardId!,
          -factor * tx.amount,
        );
      }
    } else if (tx.type == TransactionType.expense) {
      if (tx.creditCardId != null) {
        await _adjustCardUsedAmountInTxn(
          txn,
          tx.creditCardId!,
          factor * tx.amount,
        );
      } else if (tx.accountId != null) {
        await _adjustAccountBalanceInTxn(
          txn,
          tx.accountId!,
          -factor * tx.amount,
        );
      }
    } else if (tx.type == TransactionType.transfer) {
      if (tx.accountId != null) {
        await _adjustAccountBalanceInTxn(
          txn,
          tx.accountId!,
          -factor * tx.amount,
        );
      }
      if (tx.toAccountId != null) {
        await _adjustAccountBalanceInTxn(
          txn,
          tx.toAccountId!,
          factor * tx.amount,
        );
      } else if (tx.creditCardId != null) {
        await _adjustCardUsedAmountInTxn(
          txn,
          tx.creditCardId!,
          -factor * tx.amount,
        );
      }
    }
  }

  static Future<void> _adjustAccountBalanceInTxn(
    DatabaseExecutor txn,
    String accountId,
    double delta,
  ) async {
    final rows = await txn.query(
      tableBankAccounts,
      where: 'id = ?',
      whereArgs: [accountId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError(
        'Bank account with ID "$accountId" does not exist in database.',
      );
    }
    final acc = BankAccountEntity.fromMap(rows.first);
    final newBalance = acc.currentBalance + delta;
    await txn.update(
      tableBankAccounts,
      acc
          .copyWith(currentBalance: newBalance, updatedAt: DateTime.now())
          .toMap(),
      where: 'id = ?',
      whereArgs: [accountId],
    );
  }

  static Future<void> _adjustCardUsedAmountInTxn(
    DatabaseExecutor txn,
    String cardId,
    double delta,
  ) async {
    final rows = await txn.query(
      tableCreditCards,
      where: 'id = ?',
      whereArgs: [cardId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError(
        'Credit card with ID "$cardId" does not exist in database.',
      );
    }
    final card = CreditCardEntity.fromMap(rows.first);
    final newUsed = (card.usedAmount + delta).clamp(0.0, double.infinity);
    await txn.update(
      tableCreditCards,
      card.copyWith(usedAmount: newUsed, updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [cardId],
    );
  }

  Future<List<TransactionEntity>> getAllTransactions() async {
    final database = await this.database;
    final List<Map<String, dynamic>> maps = await database.query(
      tableTransactions,
      orderBy: 'date DESC, created_at DESC',
    );

    return maps.map((map) => TransactionEntity.fromMap(map)).toList();
  }

  Future<List<TransactionEntity>> getTransactionsPaginated({
    int limit = 50,
    int offset = 0,
  }) async {
    final database = await this.database;
    final List<Map<String, dynamic>> maps = await database.query(
      tableTransactions,
      orderBy: 'date DESC, created_at DESC',
      limit: limit,
      offset: offset,
    );

    return maps.map((map) => TransactionEntity.fromMap(map)).toList();
  }

  Future<List<TransactionEntity>> getPendingSharedExpenses() async {
    final database = await this.database;
    final List<Map<String, dynamic>> maps = await database.query(
      tableTransactions,
      where: 'is_shared = 1 AND is_settled = 0',
      orderBy: 'date DESC, created_at DESC',
    );

    return maps.map((map) => TransactionEntity.fromMap(map)).toList();
  }

  Future<List<TransactionEntity>> getAllSharedExpenses() async {
    final database = await this.database;
    final List<Map<String, dynamic>> maps = await database.query(
      tableTransactions,
      where: 'is_shared = 1',
      orderBy: 'date DESC, created_at DESC',
    );

    return maps.map((map) => TransactionEntity.fromMap(map)).toList();
  }

  Future<int> clearAllTransactions() async {
    final database = await this.database;
    return await database.delete(tableTransactions);
  }

  // --- Budgets ---

  Future<int> insertBudget(BudgetEntity budget) async {
    final database = await this.database;
    return await database.insert(
      tableBudgets,
      budget.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> batchInsertBudgets(List<BudgetEntity> budgets) async {
    final database = await this.database;
    await database.transaction((txn) async {
      final batch = txn.batch();
      for (final b in budgets) {
        batch.insert(
          tableBudgets,
          b.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<int> updateBudget(BudgetEntity budget) async {
    final database = await this.database;
    return await database.update(
      tableBudgets,
      budget.toMap(),
      where: 'id = ?',
      whereArgs: [budget.id],
    );
  }

  Future<int> deleteBudget(String id) async {
    final database = await this.database;
    return await database.delete(
      tableBudgets,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<BudgetEntity>> getBudgetsForMonth(DateTime month) async {
    final database = await this.database;
    final monthStart = DateTime(
      month.year,
      month.month,
      1,
    ).millisecondsSinceEpoch;
    final List<Map<String, dynamic>> maps = await database.query(
      tableBudgets,
      where: 'month = ?',
      whereArgs: [monthStart],
      orderBy: 'category ASC',
    );

    return maps.map((map) => BudgetEntity.fromMap(map)).toList();
  }

  Future<List<BudgetEntity>> getAllBudgets() async {
    final database = await this.database;
    final List<Map<String, dynamic>> maps = await database.query(
      tableBudgets,
      orderBy: 'month DESC, category ASC',
    );

    return maps.map((map) => BudgetEntity.fromMap(map)).toList();
  }

  // --- Recurring Expenses ---

  Future<int> insertRecurringExpense(RecurringExpenseEntity item) async {
    final database = await this.database;
    return await database.insert(
      tableRecurring,
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> batchInsertRecurringExpenses(
    List<RecurringExpenseEntity> items,
  ) async {
    final database = await this.database;
    await database.transaction((txn) async {
      final batch = txn.batch();
      for (final item in items) {
        batch.insert(
          tableRecurring,
          item.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<int> updateRecurringExpense(RecurringExpenseEntity item) async {
    final database = await this.database;
    return await database.update(
      tableRecurring,
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> deleteRecurringExpense(String id) async {
    final database = await this.database;
    return await database.delete(
      tableRecurring,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<RecurringExpenseEntity>> getAllRecurringExpenses() async {
    final database = await this.database;
    final List<Map<String, dynamic>> maps = await database.query(
      tableRecurring,
      orderBy: 'next_due_date ASC, title ASC',
    );

    return maps.map((map) => RecurringExpenseEntity.fromMap(map)).toList();
  }

  // --- Savings Goals ---

  Future<int> insertSavingsGoal(
    SavingsGoalEntity goal, {
    DatabaseExecutor? executor,
  }) async {
    final client = executor ?? (await database);
    return await client.insert(
      tableSavingsGoals,
      goal.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> batchInsertSavingsGoals(List<SavingsGoalEntity> goals) async {
    final database = await this.database;
    await database.transaction((txn) async {
      final batch = txn.batch();
      for (final goal in goals) {
        batch.insert(
          tableSavingsGoals,
          goal.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<int> updateSavingsGoal(
    SavingsGoalEntity goal, {
    DatabaseExecutor? executor,
  }) async {
    final client = executor ?? (await database);
    return await client.update(
      tableSavingsGoals,
      goal.toMap(),
      where: 'id = ?',
      whereArgs: [goal.id],
    );
  }

  /// Atomic cascading delete for savings goal and its associated contributions
  Future<int> deleteSavingsGoal(String id, {DatabaseExecutor? executor}) async {
    if (executor != null) {
      await executor.delete(
        tableGoalContributions,
        where: 'goal_id = ?',
        whereArgs: [id],
      );
      return await executor.delete(
        tableSavingsGoals,
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    final database = await this.database;
    int result = 0;
    await database.transaction((txn) async {
      await txn.delete(
        tableGoalContributions,
        where: 'goal_id = ?',
        whereArgs: [id],
      );
      result = await txn.delete(
        tableSavingsGoals,
        where: 'id = ?',
        whereArgs: [id],
      );
    });
    return result;
  }

  Future<List<SavingsGoalEntity>> getAllSavingsGoals() async {
    final database = await this.database;
    final List<Map<String, dynamic>> maps = await database.query(
      tableSavingsGoals,
      orderBy: 'is_emergency_fund DESC, target_date ASC',
    );

    return maps.map((map) => SavingsGoalEntity.fromMap(map)).toList();
  }

  // --- Goal Contributions ---

  Future<int> insertGoalContribution(
    GoalContributionEntity contribution, {
    DatabaseExecutor? executor,
  }) async {
    final client = executor ?? (await database);
    return await client.insert(
      tableGoalContributions,
      contribution.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> batchInsertGoalContributions(
    List<GoalContributionEntity> contributions,
  ) async {
    final database = await this.database;
    await database.transaction((txn) async {
      final batch = txn.batch();
      for (final c in contributions) {
        batch.insert(
          tableGoalContributions,
          c.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<GoalContributionEntity>> getContributionsForGoal(
    String goalId,
  ) async {
    final database = await this.database;
    final List<Map<String, dynamic>> maps = await database.query(
      tableGoalContributions,
      where: 'goal_id = ?',
      whereArgs: [goalId],
      orderBy: 'date DESC, created_at DESC',
    );

    return maps.map((map) => GoalContributionEntity.fromMap(map)).toList();
  }

  Future<int> deleteGoalContribution(
    String id, {
    DatabaseExecutor? executor,
  }) async {
    final client = executor ?? (await database);
    return await client.delete(
      tableGoalContributions,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Debts & Liabilities ---

  Future<int> insertDebt(DebtEntity debt, {DatabaseExecutor? executor}) async {
    final client = executor ?? (await database);
    return await client.insert(
      tableDebts,
      debt.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> batchInsertDebts(List<DebtEntity> debts) async {
    final database = await this.database;
    await database.transaction((txn) async {
      final batch = txn.batch();
      for (final d in debts) {
        batch.insert(
          tableDebts,
          d.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<int> updateDebt(DebtEntity debt, {DatabaseExecutor? executor}) async {
    final client = executor ?? (await database);
    return await client.update(
      tableDebts,
      debt.toMap(),
      where: 'id = ?',
      whereArgs: [debt.id],
    );
  }

  /// Atomic cascading delete for debt and its payment history
  Future<int> deleteDebt(String id, {DatabaseExecutor? executor}) async {
    if (executor != null) {
      await executor.delete(
        tableDebtPayments,
        where: 'debt_id = ?',
        whereArgs: [id],
      );
      return await executor.delete(
        tableDebts,
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    final database = await this.database;
    int result = 0;
    await database.transaction((txn) async {
      await txn.delete(
        tableDebtPayments,
        where: 'debt_id = ?',
        whereArgs: [id],
      );
      result = await txn.delete(tableDebts, where: 'id = ?', whereArgs: [id]);
    });
    return result;
  }

  Future<List<DebtEntity>> getAllDebts() async {
    final database = await this.database;
    final List<Map<String, dynamic>> maps = await database.query(
      tableDebts,
      orderBy: 'status ASC, remaining_amount DESC',
    );

    return maps.map((map) => DebtEntity.fromMap(map)).toList();
  }

  // --- Debt Payments ---

  Future<int> insertDebtPayment(
    DebtPaymentEntity payment, {
    DatabaseExecutor? executor,
  }) async {
    final client = executor ?? (await database);
    return await client.insert(
      tableDebtPayments,
      payment.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> batchInsertDebtPayments(List<DebtPaymentEntity> payments) async {
    final database = await this.database;
    await database.transaction((txn) async {
      final batch = txn.batch();
      for (final p in payments) {
        batch.insert(
          tableDebtPayments,
          p.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<DebtPaymentEntity>> getPaymentsForDebt(String debtId) async {
    final database = await this.database;
    final List<Map<String, dynamic>> maps = await database.query(
      tableDebtPayments,
      where: 'debt_id = ?',
      whereArgs: [debtId],
      orderBy: 'date DESC, created_at DESC',
    );

    return maps.map((map) => DebtPaymentEntity.fromMap(map)).toList();
  }

  Future<int> deleteDebtPayment(String id, {DatabaseExecutor? executor}) async {
    final client = executor ?? (await database);
    return await client.delete(
      tableDebtPayments,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Investments ---

  Future<int> insertInvestment(InvestmentEntity investment) async {
    final database = await this.database;
    return await database.insert(
      tableInvestments,
      investment.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> batchInsertInvestments(
    List<InvestmentEntity> investments,
  ) async {
    final database = await this.database;
    await database.transaction((txn) async {
      final batch = txn.batch();
      for (final inv in investments) {
        batch.insert(
          tableInvestments,
          inv.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<int> updateInvestment(InvestmentEntity investment) async {
    final database = await this.database;
    return await database.update(
      tableInvestments,
      investment.toMap(),
      where: 'id = ?',
      whereArgs: [investment.id],
    );
  }

  Future<int> deleteInvestment(String id) async {
    final database = await this.database;
    return await database.delete(
      tableInvestments,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<InvestmentEntity>> getAllInvestments() async {
    final database = await this.database;
    final List<Map<String, dynamic>> maps = await database.query(
      tableInvestments,
      orderBy: 'current_value DESC',
    );

    return maps.map((map) => InvestmentEntity.fromMap(map)).toList();
  }

  // --- AI Chat Sessions & Messages ---

  Future<int> insertChatSession(AiChatSession session) async {
    final database = await this.database;
    return await database.insert(
      tableChatSessions,
      session.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> batchInsertChatSessions(List<AiChatSession> sessions) async {
    final database = await this.database;
    await database.transaction((txn) async {
      final batch = txn.batch();
      for (final s in sessions) {
        batch.insert(
          tableChatSessions,
          s.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<int> updateChatSession(AiChatSession session) async {
    final database = await this.database;
    return await database.update(
      tableChatSessions,
      session.toMap(),
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }

  Future<int> deleteChatSession(String id) async {
    final database = await this.database;
    return await database.delete(
      tableChatSessions,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<AiChatSession>> getAllChatSessions() async {
    final database = await this.database;
    final List<Map<String, dynamic>> maps = await database.query(
      tableChatSessions,
      orderBy: 'updated_at DESC',
    );

    return maps.map((map) => AiChatSession.fromMap(map)).toList();
  }

  Future<AiChatSession?> getChatSessionById(String id) async {
    final database = await this.database;
    final List<Map<String, dynamic>> maps = await database.query(
      tableChatSessions,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return AiChatSession.fromMap(maps.first);
  }

  Future<int> insertChatMessage(AiChatMessage message) async {
    final database = await this.database;
    return await database.insert(
      tableChatMessages,
      message.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> batchInsertChatMessages(List<AiChatMessage> messages) async {
    final database = await this.database;
    await database.transaction((txn) async {
      final batch = txn.batch();
      for (final m in messages) {
        batch.insert(
          tableChatMessages,
          m.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<AiChatMessage>> getMessagesForSession(String sessionId) async {
    final database = await this.database;
    final List<Map<String, dynamic>> maps = await database.query(
      tableChatMessages,
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp ASC',
    );

    return maps.map((map) => AiChatMessage.fromMap(map)).toList();
  }

  Future<List<AiChatMessage>> getAllChatMessages() async {
    final database = await this.database;
    final List<Map<String, dynamic>> maps = await database.query(
      tableChatMessages,
      orderBy: 'timestamp ASC',
    );

    return maps.map((map) => AiChatMessage.fromMap(map)).toList();
  }

  Future<int> deleteChatMessage(String id) async {
    final database = await this.database;
    return await database.delete(
      tableChatMessages,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearAllChatHistory() async {
    final database = await this.database;
    await database.transaction((txn) async {
      await txn.delete(tableChatMessages);
      await txn.delete(tableChatSessions);
    });
  }

  // --- Bank Accounts ---

  Future<int> insertBankAccount(
    BankAccountEntity account, {
    DatabaseExecutor? executor,
  }) async {
    final client = executor ?? (await database);
    return await client.insert(
      tableBankAccounts,
      account.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> batchInsertBankAccounts(List<BankAccountEntity> accounts) async {
    final database = await this.database;
    await database.transaction((txn) async {
      final batch = txn.batch();
      for (final a in accounts) {
        batch.insert(
          tableBankAccounts,
          a.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<int> updateBankAccount(
    BankAccountEntity account, {
    DatabaseExecutor? executor,
  }) async {
    final client = executor ?? (await database);
    return await client.update(
      tableBankAccounts,
      account.toMap(),
      where: 'id = ?',
      whereArgs: [account.id],
    );
  }

  /// Atomically adjust bank account balance at the SQLite engine level to prevent race conditions
  Future<int> adjustBankAccountBalance(
    String accountId,
    double delta, {
    DatabaseExecutor? executor,
  }) async {
    final client = executor ?? (await database);
    return await client.rawUpdate(
      'UPDATE $tableBankAccounts SET current_balance = current_balance + ?, updated_at = ? WHERE id = ?',
      [delta, DateTime.now().millisecondsSinceEpoch, accountId],
    );
  }

  Future<int> deleteBankAccount(String id, {DatabaseExecutor? executor}) async {
    final client = executor ?? (await database);
    return await client.delete(
      tableBankAccounts,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<BankAccountEntity>> getAllBankAccounts() async {
    final database = await this.database;
    final List<Map<String, dynamic>> maps = await database.query(
      tableBankAccounts,
      orderBy: 'is_default DESC, current_balance DESC',
    );

    return maps.map((map) => BankAccountEntity.fromMap(map)).toList();
  }

  Future<BankAccountEntity?> getBankAccountById(String id) async {
    final database = await this.database;
    final List<Map<String, dynamic>> maps = await database.query(
      tableBankAccounts,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return BankAccountEntity.fromMap(maps.first);
  }

  // --- Credit Cards ---

  Future<int> insertCreditCard(
    CreditCardEntity card, {
    DatabaseExecutor? executor,
  }) async {
    final client = executor ?? (await database);
    return await client.insert(
      tableCreditCards,
      card.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> batchInsertCreditCards(List<CreditCardEntity> cards) async {
    final database = await this.database;
    await database.transaction((txn) async {
      final batch = txn.batch();
      for (final c in cards) {
        batch.insert(
          tableCreditCards,
          c.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<int> updateCreditCard(
    CreditCardEntity card, {
    DatabaseExecutor? executor,
  }) async {
    final client = executor ?? (await database);
    return await client.update(
      tableCreditCards,
      card.toMap(),
      where: 'id = ?',
      whereArgs: [card.id],
    );
  }

  /// Atomically adjust credit card used amount at the SQLite engine level to prevent race conditions
  Future<int> adjustCreditCardUsedAmount(
    String cardId,
    double delta, {
    DatabaseExecutor? executor,
  }) async {
    final client = executor ?? (await database);
    return await client.rawUpdate(
      'UPDATE $tableCreditCards SET used_amount = CASE WHEN used_amount + ? < 0 THEN 0.0 ELSE used_amount + ? END, updated_at = ? WHERE id = ?',
      [delta, delta, DateTime.now().millisecondsSinceEpoch, cardId],
    );
  }

  Future<int> deleteCreditCard(String id, {DatabaseExecutor? executor}) async {
    final client = executor ?? (await database);
    return await client.delete(
      tableCreditCards,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<CreditCardEntity>> getAllCreditCards() async {
    final database = await this.database;
    final List<Map<String, dynamic>> maps = await database.query(
      tableCreditCards,
      orderBy: 'credit_limit DESC',
    );

    return maps.map((map) => CreditCardEntity.fromMap(map)).toList();
  }

  Future<CreditCardEntity?> getCreditCardById(String id) async {
    final database = await this.database;
    final List<Map<String, dynamic>> maps = await database.query(
      tableCreditCards,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return CreditCardEntity.fromMap(maps.first);
  }

  // ==========================================
  // AI REPORTS OPERATIONS
  // ==========================================

  Future<void> insertAiReport(Map<String, dynamic> reportMap) async {
    final database = await this.database;
    await database.insert(
      tableAiReports,
      reportMap,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getAllAiReports() async {
    final database = await this.database;
    return await database.query(tableAiReports, orderBy: 'timestamp DESC');
  }

  Future<void> deleteAiReport(String id) async {
    final database = await this.database;
    await database.delete(tableAiReports, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearAllAiReports() async {
    final database = await this.database;
    await database.delete(tableAiReports);
  }

  /// Clear all tables in a single atomic transaction
  Future<void> clearAllData() async {
    final client = await database;
    await client.transaction((txn) async {
      await txn.delete(tableTransactions);
      await txn.delete(tableBudgets);
      await txn.delete(tableRecurring);
      await txn.delete(tableGoalContributions);
      await txn.delete(tableSavingsGoals);
      await txn.delete(tableDebtPayments);
      await txn.delete(tableDebts);
      await txn.delete(tableInvestments);
      await txn.delete(tableChatMessages);
      await txn.delete(tableChatSessions);
      await txn.delete(tableCreditCards);
      await txn.delete(tableBankAccounts);
      await txn.delete(tableAiReports);
    });
  }

  /// Atomically wipe and restore database from a backup in a single ACID transaction.
  /// If any record insertion fails or causes a constraint violation, the entire transaction
  /// rolls back automatically, preserving the user's existing data safely.
  Future<void> atomicRestoreBackup(FullDatabaseBackup backup) async {
    final client = await database;
    await client.transaction((txn) async {
      // 1. Wipe all existing tables (children before parents to prevent foreign key errors)
      await txn.delete(tableTransactions);
      await txn.delete(tableBudgets);
      await txn.delete(tableRecurring);
      await txn.delete(tableGoalContributions);
      await txn.delete(tableSavingsGoals);
      await txn.delete(tableDebtPayments);
      await txn.delete(tableDebts);
      await txn.delete(tableInvestments);
      await txn.delete(tableChatMessages);
      await txn.delete(tableChatSessions);
      await txn.delete(tableCreditCards);
      await txn.delete(tableBankAccounts);
      await txn.delete(tableAiReports);

      // 2. Insert new records in safe dependency order using high-performance SQLite batch
      final batch = txn.batch();
      for (final a in backup.bankAccounts) {
        batch.insert(
          tableBankAccounts,
          a.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final c in backup.creditCards) {
        batch.insert(
          tableCreditCards,
          c.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final t in backup.transactions) {
        batch.insert(
          tableTransactions,
          t.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final b in backup.budgets) {
        batch.insert(
          tableBudgets,
          b.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final g in backup.savingsGoals) {
        batch.insert(
          tableSavingsGoals,
          g.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final c in backup.savingsContributions) {
        batch.insert(
          tableGoalContributions,
          c.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final d in backup.debts) {
        batch.insert(
          tableDebts,
          d.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final p in backup.debtPayments) {
        batch.insert(
          tableDebtPayments,
          p.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final i in backup.investments) {
        batch.insert(
          tableInvestments,
          i.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final r in backup.recurringExpenses) {
        batch.insert(
          tableRecurring,
          r.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final s in backup.chatSessions) {
        batch.insert(
          tableChatSessions,
          s.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final m in backup.chatMessages) {
        batch.insert(
          tableChatMessages,
          m.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final rep in backup.aiReports) {
        batch.insert(
          tableAiReports,
          rep.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> close() async {
    final currentDb = db;
    if (currentDb != null && currentDb.isOpen) {
      await currentDb.close();
      db = null;
      _dbCompleter = null;
      _initRetryCount = 0;
    }
  }
}
