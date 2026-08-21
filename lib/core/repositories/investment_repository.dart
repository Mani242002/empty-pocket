import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../domain/entities/investment_entity.dart';
import 'transaction_repository.dart';

abstract class InvestmentRepository {
  Future<List<InvestmentEntity>> getAllInvestments();
  Future<void> saveInvestment(InvestmentEntity investment);
  Future<void> deleteInvestment(String id);
}

class SqliteInvestmentRepository implements InvestmentRepository {
  final AppDatabase _db;

  SqliteInvestmentRepository(this._db);

  @override
  Future<List<InvestmentEntity>> getAllInvestments() {
    return _db.getAllInvestments();
  }

  @override
  Future<void> saveInvestment(InvestmentEntity investment) async {
    await _db.insertInvestment(investment);
  }

  @override
  Future<void> deleteInvestment(String id) async {
    await _db.deleteInvestment(id);
  }
}

class InMemoryInvestmentRepository implements InvestmentRepository {
  final List<InvestmentEntity> _investments = [];

  InMemoryInvestmentRepository([List<InvestmentEntity>? initialInvestments]) {
    if (initialInvestments != null) _investments.addAll(initialInvestments);
  }

  @override
  Future<List<InvestmentEntity>> getAllInvestments() async {
    return List<InvestmentEntity>.from(_investments)
      ..sort((a, b) => b.currentValue.compareTo(a.currentValue));
  }

  @override
  Future<void> saveInvestment(InvestmentEntity investment) async {
    _investments.removeWhere((i) => i.id == investment.id);
    _investments.add(investment);
  }

  @override
  Future<void> deleteInvestment(String id) async {
    _investments.removeWhere((i) => i.id == id);
  }
}

final investmentRepositoryProvider = Provider<InvestmentRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return SqliteInvestmentRepository(db);
});
