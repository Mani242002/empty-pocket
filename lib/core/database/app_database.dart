import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../domain/entities/budget_entity.dart';
import '../domain/entities/debt_entity.dart';
import '../domain/entities/investment_entity.dart';
import '../domain/entities/recurring_expense_entity.dart';
import '../domain/entities/savings_goal_entity.dart';
import '../domain/entities/transaction_entity.dart';

/// Local SQLite Database manager for EmptyPocket
class AppDatabase {
  static const String _databaseName = 'empty_pocket.db';
  static const int _databaseVersion = 5;

  static const String tableTransactions = 'transactions';
  static const String tableBudgets = 'budgets';
  static const String tableRecurring = 'recurring_expenses';
  static const String tableSavingsGoals = 'savings_goals';
  static const String tableGoalContributions = 'goal_contributions';
  static const String tableDebts = 'debts';
  static const String tableDebtPayments = 'debt_payments';
  static const String tableInvestments = 'investments';

  Database? db;

  AppDatabase({this.db});

  Future<Database> get database async {
    if (db != null) return db!;
    db = await _initDatabase();
    return db!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
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
        created_at INTEGER NOT NULL
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
        created_at INTEGER NOT NULL
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
    final monthStart = DateTime(month.year, month.month, 1).millisecondsSinceEpoch;
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

  Future<int> updateSavingsGoal(SavingsGoalEntity goal) async {
    final database = await this.database;
    return await database.update(
      tableSavingsGoals,
      goal.toMap(),
      where: 'id = ?',
      whereArgs: [goal.id],
    );
  }

  Future<int> deleteSavingsGoal(String id) async {
    final database = await this.database;
    await database.delete(
      tableGoalContributions,
      where: 'goal_id = ?',
      whereArgs: [id],
    );
    return await database.delete(
      tableSavingsGoals,
      where: 'id = ?',
      whereArgs: [id],
    );
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

  Future<int> insertGoalContribution(GoalContributionEntity contribution) async {
    final database = await this.database;
    return await database.insert(
      tableGoalContributions,
      contribution.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<GoalContributionEntity>> getContributionsForGoal(String goalId) async {
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

  Future<int> updateDebt(DebtEntity debt) async {
    final database = await this.database;
    return await database.update(
      tableDebts,
      debt.toMap(),
      where: 'id = ?',
      whereArgs: [debt.id],
    );
  }

  Future<int> deleteDebt(String id) async {
    final database = await this.database;
    await database.delete(
      tableDebtPayments,
      where: 'debt_id = ?',
      whereArgs: [id],
    );
    return await database.delete(
      tableDebts,
      where: 'id = ?',
      whereArgs: [id],
    );
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

  Future<void> close() async {
    final currentDb = db;
    if (currentDb != null && currentDb.isOpen) {
      await currentDb.close();
      db = null;
    }
  }
}
