import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../domain/entities/bank_account_entity.dart';
import 'transaction_repository.dart';

abstract class BankAccountRepository {
  Future<List<BankAccountEntity>> getAllAccounts();
  Future<BankAccountEntity?> getAccountById(String id);
  Future<void> saveAccount(
    BankAccountEntity account, {
    DatabaseExecutor? executor,
  });
  Future<void> updateAccount(
    BankAccountEntity account, {
    DatabaseExecutor? executor,
  });
  Future<void> adjustBalance(
    String id,
    double delta, {
    DatabaseExecutor? executor,
  });
  Future<void> deleteAccount(String id, {DatabaseExecutor? executor});
}

class SqliteBankAccountRepository implements BankAccountRepository {
  final AppDatabase _db;

  SqliteBankAccountRepository(this._db);

  @override
  Future<List<BankAccountEntity>> getAllAccounts() {
    return _db.getAllBankAccounts();
  }

  @override
  Future<BankAccountEntity?> getAccountById(String id) {
    return _db.getBankAccountById(id);
  }

  @override
  Future<void> saveAccount(
    BankAccountEntity account, {
    DatabaseExecutor? executor,
  }) async {
    await _db.insertBankAccount(account, executor: executor);
  }

  @override
  Future<void> updateAccount(
    BankAccountEntity account, {
    DatabaseExecutor? executor,
  }) async {
    await _db.updateBankAccount(account, executor: executor);
  }

  @override
  Future<void> adjustBalance(
    String id,
    double delta, {
    DatabaseExecutor? executor,
  }) async {
    await _db.adjustBankAccountBalance(id, delta, executor: executor);
  }

  @override
  Future<void> deleteAccount(String id, {DatabaseExecutor? executor}) async {
    await _db.deleteBankAccount(id, executor: executor);
  }
}

class InMemoryBankAccountRepository implements BankAccountRepository {
  final List<BankAccountEntity> _accounts = [];

  InMemoryBankAccountRepository([List<BankAccountEntity>? initial]) {
    if (initial != null) {
      _accounts.addAll(initial);
    }
  }

  @override
  Future<List<BankAccountEntity>> getAllAccounts() async {
    return List<BankAccountEntity>.from(_accounts);
  }

  @override
  Future<BankAccountEntity?> getAccountById(String id) async {
    final matches = _accounts.where((a) => a.id == id);
    return matches.isNotEmpty ? matches.first : null;
  }

  @override
  Future<void> saveAccount(
    BankAccountEntity account, {
    DatabaseExecutor? executor,
  }) async {
    _accounts.removeWhere((a) => a.id == account.id);
    _accounts.add(account);
  }

  @override
  Future<void> updateAccount(
    BankAccountEntity account, {
    DatabaseExecutor? executor,
  }) async {
    final index = _accounts.indexWhere((a) => a.id == account.id);
    if (index != -1) {
      _accounts[index] = account;
    } else {
      _accounts.add(account);
    }
  }

  @override
  Future<void> adjustBalance(
    String id,
    double delta, {
    DatabaseExecutor? executor,
  }) async {
    final index = _accounts.indexWhere((a) => a.id == id);
    if (index != -1) {
      final old = _accounts[index];
      _accounts[index] = old.copyWith(
        currentBalance: old.currentBalance + delta,
      );
    }
  }

  @override
  Future<void> deleteAccount(String id, {DatabaseExecutor? executor}) async {
    _accounts.removeWhere((a) => a.id == id);
  }
}

/// Bank Account Repository Provider
final bankAccountRepositoryProvider = Provider<BankAccountRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return SqliteBankAccountRepository(db);
});
