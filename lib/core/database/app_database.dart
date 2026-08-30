import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../domain/entities/ai_assistant_entity.dart';
import '../domain/entities/bank_account_entity.dart';
import '../domain/entities/budget_entity.dart';
import '../domain/entities/credit_card_entity.dart';
import '../domain/entities/debt_entity.dart';
import '../domain/entities/investment_entity.dart';
import '../domain/entities/recurring_expense_entity.dart';
import '../domain/entities/savings_goal_entity.dart';
import '../domain/entities/transaction_entity.dart';
import '../services/log_service.dart';

/// Local SQLite Database manager for EmptyPocket
class AppDatabase {
  static const String _databaseName = 'empty_pocket.db';
  static const int _databaseVersion = 8;

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

  /// Thread-safe database getter with completer-based lock
  Future<Database> get database async {
    if (db != null) return db!;

    if (_dbCompleter != null) {
      return _dbCompleter!.future;
    }

    if (_initRetryCount >= _maxRetries) {
      throw Exception('Database initialization failed after $_maxRetries attempts. Storage may be unavailable or corrupted.');
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
      LogService.error('AppDatabase', 'Database init failure (Attempt $_initRetryCount)', e, stack);
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
        // Enforce SQLite Foreign Key constraints
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
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
        await db.execute('ALTER TABLE $tableTransactions ADD COLUMN account_id TEXT');
      } catch (e) {
        LogService.debug('AppDatabase', 'account_id column migration: $e');
      }
      try {
        await db.execute('ALTER TABLE $tableTransactions ADD COLUMN to_account_id TEXT');
      } catch (e) {
        LogService.debug('AppDatabase', 'to_account_id column migration: $e');
      }
      try {
        await db.execute('ALTER TABLE $tableTransactions ADD COLUMN credit_card_id TEXT');
      } catch (e) {
        LogService.debug('AppDatabase', 'credit_card_id column migration: $e');
      }
      try {
        await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_account ON $tableTransactions(account_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_card ON $tableTransactions(credit_card_id)');
      } catch (e) {
        LogService.debug('AppDatabase', 'Transaction indexes migration: $e');
      }
    }
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
        created_at INTEGER NOT NULL,
        FOREIGN KEY (goal_id) REFERENCES $tableSavingsGoals(id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_contributions_goal ON $tableGoalContributions(goal_id)',
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
        created_at INTEGER NOT NULL,
        FOREIGN KEY (debt_id) REFERENCES $tableDebts(id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_debt_payments_debt ON $tableDebtPayments(debt_id)',
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
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_investments_asset ON $tableInvestments(asset_class)',
    );
  }

  // --- Transactions ---

  Future<int> insertTransaction(TransactionEntity transaction) async {
    final database = await this.database;
    return await database.insert(
      tableTransactions,
      transaction.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> batchInsertTransactions(List<TransactionEntity> transactions) async {
    final database = await this.database;
    await database.transaction((txn) async {
      final batch = txn.batch();
      for (final tx in transactions) {
        batch.insert(
          tableTransactions,
          tx.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<int> updateTransaction(TransactionEntity transaction) async {
    final database = await this.database;
    return await database.update(
      tableTransactions,
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<int> deleteTransaction(String id) async {
    final database = await this.database;
    return await database.delete(
      tableTransactions,
      where: 'id = ?',
      whereArgs: [id],
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

  Future<void> batchInsertRecurringExpenses(List<RecurringExpenseEntity> items) async {
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

  Future<int> insertSavingsGoal(SavingsGoalEntity goal) async {
    final database = await this.database;
    return await database.insert(
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

  Future<int> updateSavingsGoal(SavingsGoalEntity goal) async {
    final database = await this.database;
    return await database.update(
      tableSavingsGoals,
      goal.toMap(),
      where: 'id = ?',
      whereArgs: [goal.id],
    );
  }

  /// Atomic cascading delete for savings goal and its associated contributions
  Future<int> deleteSavingsGoal(String id) async {
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
    GoalContributionEntity contribution,
  ) async {
    final database = await this.database;
    return await database.insert(
      tableGoalContributions,
      contribution.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> batchInsertGoalContributions(List<GoalContributionEntity> contributions) async {
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

  // --- Debts & Liabilities ---

  Future<int> insertDebt(DebtEntity debt) async {
    final database = await this.database;
    return await database.insert(
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

  Future<int> updateDebt(DebtEntity debt) async {
    final database = await this.database;
    return await database.update(
      tableDebts,
      debt.toMap(),
      where: 'id = ?',
      whereArgs: [debt.id],
    );
  }

  /// Atomic cascading delete for debt and its payment history
  Future<int> deleteDebt(String id) async {
    final database = await this.database;
    int result = 0;
    await database.transaction((txn) async {
      await txn.delete(
        tableDebtPayments,
        where: 'debt_id = ?',
        whereArgs: [id],
      );
      result = await txn.delete(
        tableDebts,
        where: 'id = ?',
        whereArgs: [id],
      );
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

  Future<int> insertDebtPayment(DebtPaymentEntity payment) async {
    final database = await this.database;
    return await database.insert(
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

  // --- Investments ---

  Future<int> insertInvestment(InvestmentEntity investment) async {
    final database = await this.database;
    return await database.insert(
      tableInvestments,
      investment.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> batchInsertInvestments(List<InvestmentEntity> investments) async {
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

  Future<int> insertBankAccount(BankAccountEntity account) async {
    final database = await this.database;
    return await database.insert(
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

  Future<int> updateBankAccount(BankAccountEntity account) async {
    final database = await this.database;
    return await database.update(
      tableBankAccounts,
      account.toMap(),
      where: 'id = ?',
      whereArgs: [account.id],
    );
  }

  Future<int> deleteBankAccount(String id) async {
    final database = await this.database;
    return await database.delete(
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

  Future<int> insertCreditCard(CreditCardEntity card) async {
    final database = await this.database;
    return await database.insert(
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

  Future<int> updateCreditCard(CreditCardEntity card) async {
    final database = await this.database;
    return await database.update(
      tableCreditCards,
      card.toMap(),
      where: 'id = ?',
      whereArgs: [card.id],
    );
  }

  Future<int> deleteCreditCard(String id) async {
    final database = await this.database;
    return await database.delete(
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

  /// Clear all tables in a single atomic transaction
  Future<void> clearAllData() async {
    final client = await database;
    await client.transaction((txn) async {
      await txn.delete(tableTransactions);
      await txn.delete(tableBudgets);
      await txn.delete(tableRecurring);
      await txn.delete(tableSavingsGoals);
      await txn.delete(tableGoalContributions);
      await txn.delete(tableDebts);
      await txn.delete(tableDebtPayments);
      await txn.delete(tableInvestments);
      await txn.delete(tableChatMessages);
      await txn.delete(tableChatSessions);
      await txn.delete(tableBankAccounts);
      await txn.delete(tableCreditCards);
    });
  }

  Future<void> close() async {
    final currentDb = db;
    if (currentDb != null && currentDb.isOpen) {
      await currentDb.close();
      db = null;
      _dbCompleter = null;
    }
  }
}
