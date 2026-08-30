import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/calculation/financial_calculator.dart';
import '../../../../core/domain/entities/bank_account_entity.dart';
import '../../../../core/domain/entities/credit_card_entity.dart';
import '../../../../core/domain/entities/transaction_entity.dart';
import '../../../../core/repositories/bank_account_repository.dart';
import '../../../../core/repositories/credit_card_repository.dart';
import '../../../transactions/presentation/state/transactions_provider.dart';

/// Bank Accounts Notifier
class BankAccountListNotifier extends AsyncNotifier<List<BankAccountEntity>> {
  @override
  FutureOr<List<BankAccountEntity>> build() async {
    final repository = ref.watch(bankAccountRepositoryProvider);
    final accounts = await repository.getAllAccounts();
    return accounts;
  }

  Future<void> saveAccount(BankAccountEntity account) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(bankAccountRepositoryProvider);
      await repository.saveAccount(account);
      return await repository.getAllAccounts();
    });
  }

  Future<void> deleteAccount(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(bankAccountRepositoryProvider);
      await repository.deleteAccount(id);
      return await repository.getAllAccounts();
    });
  }

  Future<void> setDefaultAccount(String id) async {
    final current = state.valueOrNull ?? [];
    for (final acc in current) {
      final isDef = acc.id == id;
      if (acc.isDefault != isDef) {
        await saveAccount(acc.copyWith(isDefault: isDef, updatedAt: DateTime.now()));
      }
    }
  }

  Future<void> adjustAccountBalance(String id, double delta) async {
    final repository = ref.read(bankAccountRepositoryProvider);
    final account = await repository.getAccountById(id);
    if (account != null) {
      final updated = account.copyWith(
        currentBalance: account.currentBalance + delta,
        updatedAt: DateTime.now(),
      );
      await repository.updateAccount(updated);
      ref.invalidateSelf();
    }
  }
}

final bankAccountListProvider =
    AsyncNotifierProvider<BankAccountListNotifier, List<BankAccountEntity>>(
  BankAccountListNotifier.new,
);

/// Active (non-archived) Bank Accounts
final activeBankAccountsProvider = Provider<List<BankAccountEntity>>((ref) {
  final accountsAsync = ref.watch(bankAccountListProvider);
  return accountsAsync.maybeWhen(
    data: (accounts) => accounts.where((a) => !a.isArchived).toList(),
    orElse: () => [],
  );
});

/// Default Bank Account for quick selections
final defaultBankAccountProvider = Provider<BankAccountEntity?>((ref) {
  final accounts = ref.watch(activeBankAccountsProvider);
  if (accounts.isEmpty) return null;
  final def = accounts.where((a) => a.isDefault);
  return def.isNotEmpty ? def.first : accounts.first;
});

/// Combined Total Liquid Cash across all active accounts
final combinedLiquidCashProvider = Provider<double>((ref) {
  final accounts = ref.watch(activeBankAccountsProvider);
  return FinancialCalculator.calculateCombinedLiquidCash(accounts);
});

/// Credit Cards Notifier
class CreditCardListNotifier extends AsyncNotifier<List<CreditCardEntity>> {
  @override
  FutureOr<List<CreditCardEntity>> build() async {
    final repository = ref.watch(creditCardRepositoryProvider);
    return await repository.getAllCards();
  }

  Future<void> saveCard(CreditCardEntity card) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(creditCardRepositoryProvider);
      await repository.saveCard(card);
      return await repository.getAllCards();
    });
  }

  Future<void> deleteCard(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(creditCardRepositoryProvider);
      await repository.deleteCard(id);
      return await repository.getAllCards();
    });
  }

  Future<void> adjustUsedAmount(String id, double delta) async {
    final repository = ref.read(creditCardRepositoryProvider);
    final card = await repository.getCardById(id);
    if (card != null) {
      final newUsed = max(0.0, card.usedAmount + delta);
      final updated = card.copyWith(
        usedAmount: newUsed,
        updatedAt: DateTime.now(),
      );
      await repository.updateCard(updated);
      ref.invalidateSelf();
    }
  }
}

final creditCardListProvider =
    AsyncNotifierProvider<CreditCardListNotifier, List<CreditCardEntity>>(
  CreditCardListNotifier.new,
);

/// Active (non-archived) Credit Cards
final activeCreditCardsProvider = Provider<List<CreditCardEntity>>((ref) {
  final cardsAsync = ref.watch(creditCardListProvider);
  return cardsAsync.maybeWhen(
    data: (cards) => cards.where((c) => !c.isArchived).toList(),
    orElse: () => [],
  );
});

/// Combined Credit Summary (Total limit, used, available, utilization %, next due)
final combinedCreditSummaryProvider = Provider<CombinedCreditSummary>((ref) {
  final cards = ref.watch(activeCreditCardsProvider);
  return FinancialCalculator.calculateCombinedCreditSummary(cards);
});

/// Global Account Operations Service (Transfers, Card Payments, Balance Sync)
class AccountOperationsNotifier {
  final Ref _ref;

  AccountOperationsNotifier(this._ref);

  /// Transfer funds between two bank accounts
  Future<void> performTransfer({
    required BankAccountEntity fromAccount,
    required BankAccountEntity toAccount,
    required double amount,
    String? notes,
    DateTime? date,
  }) async {
    if (amount <= 0) return;
    final now = date ?? DateTime.now();

    // 1. Decrement source account
    await _ref
        .read(bankAccountListProvider.notifier)
        .adjustAccountBalance(fromAccount.id, -amount);

    // 2. Increment destination account
    await _ref
        .read(bankAccountListProvider.notifier)
        .adjustAccountBalance(toAccount.id, amount);

    // 3. Record transfer transaction
    final tx = TransactionEntity(
      id: const Uuid().v4(),
      title: 'Transfer: ${fromAccount.accountName} → ${toAccount.accountName}',
      amount: amount,
      type: TransactionType.transfer,
      category: 'Account Transfer',
      date: now,
      paymentSource: fromAccount.accountName,
      accountId: fromAccount.id,
      toAccountId: toAccount.id,
      notes: notes ?? 'Transfer to ${toAccount.accountName} (${toAccount.usedFor})',
      createdAt: now,
      updatedAt: now,
    );

    await _ref.read(transactionListNotifierProvider.notifier).addTransaction(tx);
  }

  /// Pay Credit Card bill from a Bank Account
  Future<void> payCreditCardBill({
    required BankAccountEntity fromAccount,
    required CreditCardEntity creditCard,
    required double amount,
    String? notes,
    DateTime? date,
  }) async {
    if (amount <= 0) return;
    final now = date ?? DateTime.now();

    // 1. Deduct money from bank account
    await _ref
        .read(bankAccountListProvider.notifier)
        .adjustAccountBalance(fromAccount.id, -amount);

    // 2. Reduce credit card used amount
    await _ref
        .read(creditCardListProvider.notifier)
        .adjustUsedAmount(creditCard.id, -amount);

    // 3. Record repayment transaction as internal transfer (avoiding double-counting in expenses)
    final tx = TransactionEntity(
      id: const Uuid().v4(),
      title: 'Bill Pay: ${creditCard.cardName}',
      amount: amount,
      type: TransactionType.transfer,
      category: 'Credit Card Bill Pay',
      date: now,
      paymentSource: fromAccount.accountName,
      accountId: fromAccount.id,
      creditCardId: creditCard.id,
      notes: notes ?? 'Credit card bill payoff for ${creditCard.cardName}',
      createdAt: now,
      updatedAt: now,
    );

    await _ref.read(transactionListNotifierProvider.notifier).addTransaction(tx);
  }
}

final accountOperationsProvider = Provider<AccountOperationsNotifier>((ref) {
  return AccountOperationsNotifier(ref);
});
