import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:empty_pocket/core/domain/entities/bank_account_entity.dart';
import 'package:empty_pocket/core/domain/entities/transaction_entity.dart';
import 'package:empty_pocket/core/repositories/bank_account_repository.dart';
import 'package:empty_pocket/core/repositories/transaction_repository.dart';
import 'package:empty_pocket/features/accounts/presentation/state/accounts_cards_provider.dart';
import 'package:sqflite/sqflite.dart';

class _InMemoryBankAccountRepository implements BankAccountRepository {
  final Map<String, BankAccountEntity> _store = {};

  _InMemoryBankAccountRepository([List<BankAccountEntity> initial = const []]) {
    for (final a in initial) {
      _store[a.id] = a;
    }
  }

  @override
  Future<List<BankAccountEntity>> getAllAccounts() async {
    return _store.values.toList();
  }

  @override
  Future<BankAccountEntity?> getAccountById(String id) async {
    return _store[id];
  }

  @override
  Future<void> saveAccount(
    BankAccountEntity account, {
    DatabaseExecutor? executor,
  }) async {
    _store[account.id] = account;
  }

  @override
  Future<void> updateAccount(
    BankAccountEntity account, {
    DatabaseExecutor? executor,
  }) async {
    _store[account.id] = account;
  }

  @override
  Future<void> adjustBalance(
    String id,
    double delta, {
    DatabaseExecutor? executor,
  }) async {
    final acc = _store[id];
    if (acc != null) {
      _store[id] = acc.copyWith(
        currentBalance: acc.currentBalance + delta,
        updatedAt: DateTime.now(),
      );
    }
  }

  @override
  Future<void> deleteAccount(String id, {DatabaseExecutor? executor}) async {
    _store.remove(id);
  }
}

class _InMemoryTransactionRepository implements TransactionRepository {
  final List<TransactionEntity> _transactions = [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<void> addTransaction(
    TransactionEntity transaction, {
    DatabaseExecutor? executor,
  }) async {
    _transactions.add(transaction);
  }

  @override
  Future<List<TransactionEntity>> getAllTransactions() async {
    return List.unmodifiable(_transactions);
  }

  @override
  Future<void> performTransferAtomic({
    required BankAccountEntity fromAccount,
    required BankAccountEntity toAccount,
    required double amount,
    required TransactionEntity transaction,
    DatabaseExecutor? executor,
  }) async {
    _transactions.add(transaction);
  }

  @override
  Future<void> saveTransactionAtomic({
    required TransactionEntity transaction,
    TransactionEntity? previousTransaction,
    Map<String, double>? multiGoalAllocations,
    String? multiGoalSourceAccountId,
    DatabaseExecutor? executor,
  }) async {
    _transactions.add(transaction);
  }
}

void main() {
  group('Cash in Hand & Physical Cash Architecture Tests', () {
    test('Auto-provisions default Cash in Hand when no cash account exists',
        () async {
      final bankRepo = _InMemoryBankAccountRepository([
        BankAccountEntity(
          id: 'bank-1',
          accountName: 'HDFC Bank',
          bankName: 'HDFC',
          accountType: AccountType.savings,
          usedFor: 'Salary & Income Hub',
          initialBalance: 50000.0,
          currentBalance: 50000.0,
          isDefault: true,
          isArchived: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ]);

      final container = ProviderContainer(
        overrides: [
          bankAccountRepositoryProvider.overrideWithValue(bankRepo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(bankAccountListProvider.future);

      final cashAccount = await container
          .read(bankAccountListProvider.notifier)
          .ensureDefaultCashAccount();

      final accounts = await container.read(bankAccountListProvider.future);

      expect(accounts.length, 2);
      expect(cashAccount.accountName, 'Cash in Hand');
      expect(cashAccount.bankName, 'Physical Cash');
      expect(cashAccount.currentBalance, 0.0);
    });

    test('Separates pure bank accounts from physical cash accounts correctly',
        () async {
      final bankRepo = _InMemoryBankAccountRepository([
        BankAccountEntity(
          id: 'bank-1',
          accountName: 'HDFC Bank',
          bankName: 'HDFC',
          accountType: AccountType.savings,
          usedFor: 'Salary',
          initialBalance: 25000.0,
          currentBalance: 25000.0,
          isDefault: true,
          isArchived: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        BankAccountEntity(
          id: 'bank-2',
          accountName: 'SBI Current',
          bankName: 'SBI',
          accountType: AccountType.current,
          usedFor: 'Business',
          initialBalance: 15000.0,
          currentBalance: 15000.0,
          isDefault: false,
          isArchived: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        BankAccountEntity(
          id: 'cash-1',
          accountName: 'Cash in Hand',
          bankName: 'Physical Cash',
          accountType: AccountType.cash,
          usedFor: 'Daily Spending',
          initialBalance: 3200.0,
          currentBalance: 3200.0,
          isDefault: false,
          isArchived: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ]);

      final container = ProviderContainer(
        overrides: [
          bankAccountRepositoryProvider.overrideWithValue(bankRepo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(bankAccountListProvider.future);

      final pureBanks = container.read(pureBankAccountsProvider);
      final cashWallets = container.read(activeCashAccountsProvider);
      final totalBank = container.read(totalBankBalanceProvider);
      final totalCash = container.read(totalPhysicalCashBalanceProvider);
      final combinedLiquid = container.read(combinedLiquidCashProvider);

      expect(pureBanks.length, 2);
      expect(cashWallets.length, 1);
      expect(totalBank, 40000.0);
      expect(totalCash, 3200.0);
      expect(combinedLiquid, 43200.0);
    });

    test('ATM Cash Withdrawal transfer updates titles and balances correctly',
        () async {
      final hdfc = BankAccountEntity(
        id: 'hdfc-1',
        accountName: 'HDFC Bank',
        bankName: 'HDFC',
        accountType: AccountType.savings,
        usedFor: 'Salary',
        initialBalance: 20000.0,
        currentBalance: 20000.0,
        isDefault: true,
        isArchived: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final cashInHand = BankAccountEntity(
        id: 'cash-1',
        accountName: 'Cash in Hand',
        bankName: 'Physical Cash',
        accountType: AccountType.cash,
        usedFor: 'Daily Spending',
        initialBalance: 500.0,
        currentBalance: 500.0,
        isDefault: false,
        isArchived: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final bankRepo = _InMemoryBankAccountRepository([hdfc, cashInHand]);
      final txRepo = _InMemoryTransactionRepository();

      final container = ProviderContainer(
        overrides: [
          bankAccountRepositoryProvider.overrideWithValue(bankRepo),
          transactionRepositoryProvider.overrideWithValue(txRepo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(bankAccountListProvider.future);

      final operations = container.read(accountOperationsProvider);
      await operations.performTransfer(
        fromAccount: hdfc,
        toAccount: cashInHand,
        amount: 3000.0,
      );

      final allTxs = await txRepo.getAllTransactions();
      expect(allTxs.length, 1);
      final transferTx = allTxs.first;

      expect(transferTx.title, 'ATM Cash Withdrawal');
      expect(transferTx.category, 'ATM / Cash Withdrawal');
      expect(transferTx.amount, 3000.0);
      expect(transferTx.accountId, hdfc.id);
      expect(transferTx.toAccountId, cashInHand.id);

      final updatedHdfc = await bankRepo.getAccountById(hdfc.id);
      final updatedCash = await bankRepo.getAccountById(cashInHand.id);

      expect(updatedHdfc?.currentBalance, 17000.0);
      expect(updatedCash?.currentBalance, 3500.0);
    });

    test('Cash Deposit transfer updates titles and balances correctly',
        () async {
      final sbi = BankAccountEntity(
        id: 'sbi-1',
        accountName: 'SBI Bank',
        bankName: 'SBI',
        accountType: AccountType.savings,
        usedFor: 'Emergency',
        initialBalance: 10000.0,
        currentBalance: 10000.0,
        isDefault: true,
        isArchived: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final cashInHand = BankAccountEntity(
        id: 'cash-1',
        accountName: 'Cash in Hand',
        bankName: 'Physical Cash',
        accountType: AccountType.cash,
        usedFor: 'Daily Spending',
        initialBalance: 5000.0,
        currentBalance: 5000.0,
        isDefault: false,
        isArchived: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final bankRepo = _InMemoryBankAccountRepository([sbi, cashInHand]);
      final txRepo = _InMemoryTransactionRepository();

      final container = ProviderContainer(
        overrides: [
          bankAccountRepositoryProvider.overrideWithValue(bankRepo),
          transactionRepositoryProvider.overrideWithValue(txRepo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(bankAccountListProvider.future);

      final operations = container.read(accountOperationsProvider);
      await operations.performTransfer(
        fromAccount: cashInHand,
        toAccount: sbi,
        amount: 2000.0,
      );

      final allTxs = await txRepo.getAllTransactions();
      expect(allTxs.length, 1);
      final depositTx = allTxs.first;

      expect(depositTx.title, 'Cash Deposit: SBI Bank');
      expect(depositTx.category, 'Cash Deposit');
      expect(depositTx.amount, 2000.0);
      expect(depositTx.accountId, cashInHand.id);
      expect(depositTx.toAccountId, sbi.id);

      final updatedCash = await bankRepo.getAccountById(cashInHand.id);
      final updatedSbi = await bankRepo.getAccountById(sbi.id);

      expect(updatedCash?.currentBalance, 3000.0);
      expect(updatedSbi?.currentBalance, 12000.0);
    });

    test('Adjusting cash balance allows tracking deficits gracefully',
        () async {
      final cashInHand = BankAccountEntity(
        id: 'cash-1',
        accountName: 'Cash in Hand',
        bankName: 'Physical Cash',
        accountType: AccountType.cash,
        usedFor: 'Daily Spending',
        initialBalance: 0.0,
        currentBalance: 0.0,
        isDefault: false,
        isArchived: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final bankRepo = _InMemoryBankAccountRepository([cashInHand]);

      final container = ProviderContainer(
        overrides: [
          bankAccountRepositoryProvider.overrideWithValue(bankRepo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(bankAccountListProvider.future);

      // Spend 450 in cash before recording ATM withdrawal
      await container
          .read(bankAccountListProvider.notifier)
          .adjustAccountBalance(cashInHand.id, -450.0);

      final totalCash = container.read(totalPhysicalCashBalanceProvider);
      expect(totalCash, -450.0);

      // Count exact cash and set to 1500
      final updatedAccount = cashInHand.copyWith(
        currentBalance: 1500.0,
        updatedAt: DateTime.now(),
      );
      await container
          .read(bankAccountListProvider.notifier)
          .saveAccount(updatedAccount);

      final reconciledCash = container.read(totalPhysicalCashBalanceProvider);
      expect(reconciledCash, 1500.0);
    });
  });
}
