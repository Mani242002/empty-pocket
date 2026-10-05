import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../domain/entities/debt_entity.dart';
import 'transaction_repository.dart';

abstract class DebtRepository {
  Future<List<DebtEntity>> getAllDebts();
  Future<void> saveDebt(DebtEntity debt, {DatabaseExecutor? executor});
  Future<void> deleteDebt(String id, {DatabaseExecutor? executor});
  Future<void> addPayment(
    DebtPaymentEntity payment, {
    DatabaseExecutor? executor,
  });
  Future<void> deletePayment(String id, {DatabaseExecutor? executor});
  Future<List<DebtPaymentEntity>> getPaymentsForDebt(String debtId);
}

class SqliteDebtRepository implements DebtRepository {
  final AppDatabase _db;

  SqliteDebtRepository(this._db);

  @override
  Future<List<DebtEntity>> getAllDebts() {
    return _db.getAllDebts();
  }

  @override
  Future<void> saveDebt(DebtEntity debt, {DatabaseExecutor? executor}) async {
    await _db.insertDebt(debt, executor: executor);
  }

  @override
  Future<void> deleteDebt(String id, {DatabaseExecutor? executor}) async {
    await _db.deleteDebt(id, executor: executor);
  }

  @override
  Future<void> addPayment(
    DebtPaymentEntity payment, {
    DatabaseExecutor? executor,
  }) async {
    await _db.insertDebtPayment(payment, executor: executor);
  }

  @override
  Future<void> deletePayment(String id, {DatabaseExecutor? executor}) async {
    await _db.deleteDebtPayment(id, executor: executor);
  }

  @override
  Future<List<DebtPaymentEntity>> getPaymentsForDebt(String debtId) {
    return _db.getPaymentsForDebt(debtId);
  }
}

class InMemoryDebtRepository implements DebtRepository {
  final List<DebtEntity> _debts = [];
  final List<DebtPaymentEntity> _payments = [];

  InMemoryDebtRepository([
    List<DebtEntity>? initialDebts,
    List<DebtPaymentEntity>? initialPayments,
  ]) {
    if (initialDebts != null) _debts.addAll(initialDebts);
    if (initialPayments != null) _payments.addAll(initialPayments);
  }

  @override
  Future<List<DebtEntity>> getAllDebts() async {
    return List<DebtEntity>.from(_debts);
  }

  @override
  Future<void> saveDebt(DebtEntity debt, {DatabaseExecutor? executor}) async {
    _debts.removeWhere((d) => d.id == debt.id);
    _debts.add(debt);
  }

  @override
  Future<void> deleteDebt(String id, {DatabaseExecutor? executor}) async {
    _debts.removeWhere((d) => d.id == id);
    _payments.removeWhere((p) => p.debtId == id);
  }

  @override
  Future<void> addPayment(
    DebtPaymentEntity payment, {
    DatabaseExecutor? executor,
  }) async {
    _payments.add(payment);
  }

  @override
  Future<void> deletePayment(String id, {DatabaseExecutor? executor}) async {
    _payments.removeWhere((p) => p.id == id);
  }

  @override
  Future<List<DebtPaymentEntity>> getPaymentsForDebt(String debtId) async {
    return _payments.where((p) => p.debtId == debtId).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }
}

final debtRepositoryProvider = Provider<DebtRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return SqliteDebtRepository(db);
});
