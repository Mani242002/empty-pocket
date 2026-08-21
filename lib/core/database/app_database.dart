import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../domain/entities/transaction_entity.dart';

/// Local SQLite Database manager for EmptyPocket
class AppDatabase {
  static const String _databaseName = 'empty_pocket.db';
  static const int _databaseVersion = 1;

  static const String tableTransactions = 'transactions';

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
    );
  }

  Future<void> _onCreate(Database db, int version) async {
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
  }

  Future<int> insertTransaction(TransactionEntity transaction) async {
    final db = await database;
    return await db.insert(
      tableTransactions,
      transaction.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateTransaction(TransactionEntity transaction) async {
    final db = await database;
    return await db.update(
      tableTransactions,
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<int> deleteTransaction(String id) async {
    final db = await database;
    return await db.delete(
      tableTransactions,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<TransactionEntity>> getAllTransactions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableTransactions,
      orderBy: 'date DESC, created_at DESC',
    );

    return maps.map((map) => TransactionEntity.fromMap(map)).toList();
  }

  Future<int> clearAllTransactions() async {
    final db = await database;
    return await db.delete(tableTransactions);
  }

  Future<void> close() async {
    final currentDb = db;
    if (currentDb != null && currentDb.isOpen) {
      await currentDb.close();
      db = null;
    }
  }
}
