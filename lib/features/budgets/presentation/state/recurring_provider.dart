import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/calculation/financial_calculator.dart';
import '../../../../core/domain/entities/recurring_expense_entity.dart';
import '../../../../core/domain/entities/transaction_entity.dart';
import '../../../../core/repositories/recurring_repository.dart';
import '../../../accounts/presentation/state/accounts_cards_provider.dart';
import '../../../transactions/presentation/state/transactions_provider.dart';

class RecurringListNotifier
    extends AsyncNotifier<List<RecurringExpenseEntity>> {
  @override
  FutureOr<List<RecurringExpenseEntity>> build() async {
    final repository = ref.watch(recurringRepositoryProvider);
    return await repository.getAllRecurringExpenses();
  }

  Future<void> saveRecurring(RecurringExpenseEntity item) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(recurringRepositoryProvider);
      await repository.saveRecurringExpense(item);
      return await repository.getAllRecurringExpenses();
    });
  }

  Future<void> deleteRecurring(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(recurringRepositoryProvider);
      await repository.deleteRecurringExpense(id);
      return await repository.getAllRecurringExpenses();
    });
  }

  Future<void> toggleActive(String id) async {
    final currentList = state.valueOrNull ?? [];
    final item = currentList.firstWhere((i) => i.id == id);
    final updated = item.copyWith(
      isActive: !item.isActive,
      updatedAt: DateTime.now(),
    );
    await saveRecurring(updated);
  }

  Future<void> logPaymentAsTransaction(
    RecurringExpenseEntity item, {
    String? accountId,
    String? creditCardId,
    bool deductBalance = true,
  }) async {
    final now = DateTime.now();

    String? resolvedAccountId = accountId ?? item.accountId;
    String? resolvedCreditCardId = creditCardId ?? item.creditCardId;

    final repository = ref.read(recurringRepositoryProvider);
    final bankAccounts = ref.read(bankAccountListProvider).valueOrNull ?? [];
    final creditCards = ref.read(creditCardListProvider).valueOrNull ?? [];

    if (resolvedAccountId == null && resolvedCreditCardId == null) {
      final matchedAccount = bankAccounts
          .where(
            (a) =>
                a.accountName.toLowerCase() == item.paymentSource.toLowerCase(),
          )
          .firstOrNull;
      if (matchedAccount != null) {
        resolvedAccountId = matchedAccount.id;
      } else {
        final matchedCard = creditCards
            .where(
              (c) =>
                  c.cardName.toLowerCase() == item.paymentSource.toLowerCase(),
            )
            .firstOrNull;
        if (matchedCard != null) {
          resolvedCreditCardId = matchedCard.id;
        }
      }
    }

    final fromAccount = deductBalance && resolvedAccountId != null
        ? bankAccounts.where((a) => a.id == resolvedAccountId).firstOrNull
        : null;
    final creditCard = deductBalance && resolvedCreditCardId != null
        ? creditCards.where((c) => c.id == resolvedCreditCardId).firstOrNull
        : null;

    if (deductBalance) {
      if (resolvedAccountId != null && fromAccount == null) {
        throw StateError(
          'The bank account configured for "${item.title}" no longer exists. Please edit the recurring expense to select an active account.',
        );
      }
      if (resolvedCreditCardId != null && creditCard == null) {
        throw StateError(
          'The credit card configured for "${item.title}" no longer exists. Please edit the recurring expense to select an active card.',
        );
      }
    } else {
      if (fromAccount == null) resolvedAccountId = null;
      if (creditCard == null) resolvedCreditCardId = null;
    }

    final tx = TransactionEntity(
      id: const Uuid().v4(),
      title: item.title,
      amount: item.amount,
      type: TransactionType.expense,
      category: item.category,
      date: now,
      paymentSource: item.paymentSource,
      accountId: resolvedAccountId,
      creditCardId: resolvedCreditCardId,
      linkedEntityId: item.id,
      notes: 'Recurring payment (${item.frequency.displayName})',
      createdAt: now,
      updatedAt: now,
    );

    final nextDue = FinancialCalculator.calculateNextDueDate(
      item.nextDueDate,
      item.frequency,
    );

    await repository.payRecurringExpenseAtomic(
      recurringExpense: item,
      nextDueDate: nextDue,
      fromAccount: fromAccount,
      creditCard: creditCard,
      transaction: tx,
    );

    if (repository is! SqliteRecurringRepository) {
      if (fromAccount != null) {
        await ref
            .read(bankAccountListProvider.notifier)
            .adjustAccountBalance(fromAccount.id, -item.amount);
      } else if (creditCard != null) {
        await ref
            .read(creditCardListProvider.notifier)
            .adjustUsedAmount(creditCard.id, item.amount);
      }
      await ref
          .read(transactionListNotifierProvider.notifier)
          .addTransaction(tx);
    }

    state = AsyncValue.data(await repository.getAllRecurringExpenses());
    ref.invalidate(bankAccountListProvider);
    ref.invalidate(creditCardListProvider);
    ref.invalidate(transactionListNotifierProvider);
  }
}

final recurringListNotifierProvider =
    AsyncNotifierProvider<RecurringListNotifier, List<RecurringExpenseEntity>>(
      RecurringListNotifier.new,
    );

/// Upcoming recurring payments within 30 days
final upcomingRecurringExpensesProvider =
    Provider<List<RecurringExpenseEntity>>((ref) {
      final allAsync = ref.watch(recurringListNotifierProvider);

      return allAsync.maybeWhen(
        data: (list) => FinancialCalculator.getUpcomingRecurringExpenses(
          list,
          daysAhead: 30,
        ),
        orElse: () => [],
      );
    });

/// Total monthly commitment for active recurring expenses
final monthlyRecurringTotalProvider = Provider<double>((ref) {
  final allAsync = ref.watch(recurringListNotifierProvider);

  return allAsync.maybeWhen(
    data: (list) {
      return list.where((i) => i.isActive).fold(0.0, (sum, i) {
        switch (i.frequency) {
          case RecurringFrequency.daily:
            return sum + (i.amount * 30);
          case RecurringFrequency.weekly:
            return sum + (i.amount * 4.33);
          case RecurringFrequency.monthly:
            return sum + i.amount;
          case RecurringFrequency.yearly:
            return sum + (i.amount / 12);
        }
      });
    },
    orElse: () => 0.0,
  );
});

/// Active recurring bills that are due today or overdue
final recurringBillsDueTodayProvider = Provider<List<RecurringExpenseEntity>>((
  ref,
) {
  final recurringAsync = ref.watch(recurringListNotifierProvider);
  final now = DateTime.now();
  final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);

  return recurringAsync.maybeWhen(
    data: (items) => items
        .where((r) => r.isActive && r.nextDueDate.isBefore(endOfToday))
        .toList(),
    orElse: () => [],
  );
});
