import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../domain/entities/bank_account_entity.dart';
import 'transaction_repository.dart';

abstract class BankAccountRepository {
  Future<List<BankAccountEntity>> getAllAccounts();
  Future<BankAccountEntity?> getAccountById(String id);
  Future<void> saveAccount(BankAccountEntity account);
  Future<void> updateAccount(BankAccountEntity account);
  Future<void> adjustBalance(String id, double delta);
  Future<void> deleteAccount(String id);
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
  Future<void> saveAccount(BankAccountEntity account) async {
    await _db.insertBankAccount(account);
  }

  @override
  Future<void> updateAccount(BankAccountEntity account) async {
    await _db.updateBankAccount(account);
  }

  @override
  Future<void> adjustBalance(String id, double delta) async {
    await _db.adjustBankAccountBalance(id, delta);
  }

  @override
  Future<void> deleteAccount(String id) async {
    await _db.deleteBankAccount(id);
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
  Future<void> saveAccount(BankAccountEntity account) async {
    _accounts.removeWhere((a) => a.id == account.id);
    _accounts.add(account);
  }

  @override
  Future<void> updateAccount(BankAccountEntity account) async {
    final index = _accounts.indexWhere((a) => a.id == account.id);
    if (index != -1) {
      _accounts[index] = account;
    } else {
      _accounts.add(account);
    }
  }

  @override
  Future<void> adjustBalance(String id, double delta) async {
    final index = _accounts.indexWhere((a) => a.id == id);
    if (index != -1) {
      final old = _accounts[index];
      _accounts[index] = old.copyWith(currentBalance: old.currentBalance + delta);
    }
  }

  @override
  Future<void> deleteAccount(String id) async {
    _accounts.removeWhere((a) => a.id == id);
  }
}

/// Bank Account Repository Provider
final bankAccountRepositoryProvider = Provider<BankAccountRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return SqliteBankAccountRepository(db);
});
