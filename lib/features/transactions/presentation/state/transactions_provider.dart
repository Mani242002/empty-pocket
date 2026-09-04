import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/calculation/financial_calculator.dart';
import '../../../../core/domain/entities/transaction_entity.dart';
import '../../../../core/repositories/transaction_repository.dart';
import '../../../accounts/presentation/state/accounts_cards_provider.dart';

/// Monthly Financial Summary model
class MonthlyFinancialSummary {
  final double totalIncome;
  final double totalExpense;
  final double netBalance;
  final double savingsRate;
  final int incomeCount;
  final int expenseCount;

  const MonthlyFinancialSummary({
    required this.totalIncome,
    required this.totalExpense,
    required this.netBalance,
    required this.savingsRate,
    required this.incomeCount,
    required this.expenseCount,
  });

  static const MonthlyFinancialSummary empty = MonthlyFinancialSummary(
    totalIncome: 0.0,
    totalExpense: 0.0,
    netBalance: 0.0,
    savingsRate: 0.0,
    incomeCount: 0,
    expenseCount: 0,
  );
}

/// Selected Month Provider for filtering
class SelectedMonthNotifier extends StateNotifier<DateTime> {
  SelectedMonthNotifier()
      : super(DateTime(DateTime.now().year, DateTime.now().month, 1));

  void previousMonth() {
    state = DateTime(state.year, state.month - 1, 1);
  }

  void nextMonth() {
    state = DateTime(state.year, state.month + 1, 1);
  }

  void setMonth(DateTime month) {
    state = DateTime(month.year, month.month, 1);
  }

  void resetToCurrentMonth() {
    final now = DateTime.now();
    state = DateTime(now.year, now.month, 1);
  }
}

final selectedMonthProvider =
    StateNotifierProvider<SelectedMonthNotifier, DateTime>((ref) {
  return SelectedMonthNotifier();
});

/// Reactive Transaction List AsyncNotifier
class TransactionListNotifier extends AsyncNotifier<List<TransactionEntity>> {
  @override
  FutureOr<List<TransactionEntity>> build() async {
    final repository = ref.watch(transactionRepositoryProvider);
    return await repository.getAllTransactions();
  }

  Future<void> addTransaction(TransactionEntity transaction) async {
    final previous = state.valueOrNull ?? [];
    final optimistic = [transaction, ...previous]..sort((a, b) => b.date.compareTo(a.date));
    state = AsyncValue.data(optimistic);

    try {
      final repository = ref.read(transactionRepositoryProvider);
      await repository.addTransaction(transaction);
    } catch (e, stack) {
      state = AsyncValue.data(previous);
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> updateTransaction(TransactionEntity transaction) async {
    final previous = state.valueOrNull ?? [];
    final optimistic = previous.map((t) => t.id == transaction.id ? transaction : t).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    state = AsyncValue.data(optimistic);

    try {
      final repository = ref.read(transactionRepositoryProvider);
      await repository.updateTransaction(transaction);
    } catch (e, stack) {
      state = AsyncValue.data(previous);
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> deleteTransaction(String id) async {
    final previous = state.valueOrNull ?? [];
    final target = previous.where((t) => t.id == id);
    final prevTx = target.isNotEmpty ? target.first : null;

    var optimistic = previous.where((t) => t.id != id).toList();
    state = AsyncValue.data(optimistic);

    try {
      final repository = ref.read(transactionRepositoryProvider);
      if (prevTx != null) {
        // If this was a reimbursement settlement, roll back the original transaction's reimbursedAmount and isSettled status
        if (prevTx.category == 'Shared Expense Reimbursement' && prevTx.linkedEntityId != null) {
          final origMatches = previous.where((t) => t.id == prevTx.linkedEntityId).toList();
          if (origMatches.isNotEmpty) {
            final orig = origMatches.first;
            final rolledBackReimbursed = (orig.reimbursedAmount - prevTx.amount).clamp(0.0, double.infinity);
            final rolledBackSettled = rolledBackReimbursed >= orig.friendsShare && orig.friendsShare > 0;
            final updatedOrig = orig.copyWith(
              reimbursedAmount: rolledBackReimbursed,
              isSettled: rolledBackSettled,
              updatedAt: DateTime.now(),
            );
            await repository.updateTransaction(updatedOrig);
            optimistic = optimistic.map((t) => t.id == orig.id ? updatedOrig : t).toList();
            state = AsyncValue.data(optimistic);
          }
        }

        // 1. Revert balance impact for linked accounts and credit cards
        if (prevTx.type == TransactionType.income) {
          if (prevTx.accountId != null) {
            await ref
                .read(bankAccountListProvider.notifier)
                .adjustAccountBalance(prevTx.accountId!, -prevTx.amount);
          } else if (prevTx.creditCardId != null) {
            await ref
                .read(creditCardListProvider.notifier)
                .adjustUsedAmount(prevTx.creditCardId!, prevTx.amount);
          }
        } else if (prevTx.type == TransactionType.expense) {
          if (prevTx.creditCardId != null) {
            await ref
                .read(creditCardListProvider.notifier)
                .adjustUsedAmount(prevTx.creditCardId!, -prevTx.amount);
          } else if (prevTx.accountId != null) {
            await ref
                .read(bankAccountListProvider.notifier)
                .adjustAccountBalance(prevTx.accountId!, prevTx.amount);
          }
        } else if (prevTx.type == TransactionType.transfer) {
          if (prevTx.accountId != null) {
            await ref
                .read(bankAccountListProvider.notifier)
                .adjustAccountBalance(prevTx.accountId!, prevTx.amount);
          }
          if (prevTx.toAccountId != null) {
            await ref
                .read(bankAccountListProvider.notifier)
                .adjustAccountBalance(prevTx.toAccountId!, -prevTx.amount);
          } else if (prevTx.creditCardId != null) {
            await ref
                .read(creditCardListProvider.notifier)
                .adjustUsedAmount(prevTx.creditCardId!, prevTx.amount);
          }
        }
      }
      await repository.deleteTransaction(id);
    } catch (e, stack) {
      state = AsyncValue.data(previous);
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> clearAll() async {
    final previous = state.valueOrNull ?? [];
    state = const AsyncValue.data([]);
    try {
      final repository = ref.read(transactionRepositoryProvider);
      await repository.clearAllTransactions();
    } catch (e, stack) {
      state = AsyncValue.data(previous);
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> settleSharedExpense({
    required String transactionId,
    required double amountReceived,
    required String destinationAccountId,
    String? notes,
  }) async {
    final previous = state.valueOrNull ?? [];
    final targetList = previous.where((t) => t.id == transactionId).toList();
    if (targetList.isEmpty) return;

    final original = targetList.first;
    final updatedReimbursed = original.reimbursedAmount + amountReceived;
    final isFullySettled = updatedReimbursed >= original.friendsShare;

    final updatedOriginal = original.copyWith(
      reimbursedAmount: updatedReimbursed,
      isSettled: isFullySettled,
      updatedAt: DateTime.now(),
    );

    final now = DateTime.now();
    final destAccounts = ref.read(bankAccountListProvider).valueOrNull ?? [];
    final destAcc = destAccounts.firstWhere(
      (a) => a.id == destinationAccountId,
      orElse: () => destAccounts.first,
    );

    final settlementTx = TransactionEntity(
      id: const Uuid().v4(),
      title: 'Reimbursement: ${original.title}',
      amount: amountReceived,
      type: TransactionType.income,
      category: 'Shared Expense Reimbursement',
      date: now,
      paymentSource: destAcc.accountName,
      accountId: destAcc.id,
      creditCardId: original.creditCardId,
      linkedEntityId: original.id,
      notes: notes ?? 'Reimbursement collected for "${original.title}"',
      createdAt: now,
      updatedAt: now,
    );

    final optimistic = previous
        .map((t) => t.id == transactionId ? updatedOriginal : t)
        .toList();
    state = AsyncValue.data([settlementTx, ...optimistic]..sort((a, b) => b.date.compareTo(a.date)));

    try {
      final repository = ref.read(transactionRepositoryProvider);
      await repository.updateTransaction(updatedOriginal);
      await repository.addTransaction(settlementTx);

      await ref
          .read(bankAccountListProvider.notifier)
          .adjustAccountBalance(destAcc.id, amountReceived);
    } catch (e, stack) {
      state = AsyncValue.data(previous);
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }
}

final transactionListNotifierProvider =
    AsyncNotifierProvider<TransactionListNotifier, List<TransactionEntity>>(
  TransactionListNotifier.new,
);

/// Provider for transactions filtered by currently selected month
final monthlyTransactionsProvider = Provider<List<TransactionEntity>>((ref) {
  final transactionsAsync = ref.watch(transactionListNotifierProvider);
  final selectedMonth = ref.watch(selectedMonthProvider);

  return transactionsAsync.maybeWhen(
    data: (transactions) =>
        FinancialCalculator.filterByMonth(transactions, selectedMonth),
    orElse: () => [],
  );
});

/// Provider for current month financial summary
final monthlyFinancialSummaryProvider = Provider<MonthlyFinancialSummary>((ref) {
  final monthlyTransactions = ref.watch(monthlyTransactionsProvider);

  if (monthlyTransactions.isEmpty) {
    return MonthlyFinancialSummary.empty;
  }

  final income = FinancialCalculator.calculateTotalIncome(monthlyTransactions);
  final expense = FinancialCalculator.calculateTotalExpense(monthlyTransactions);
  final net = FinancialCalculator.calculateNetBalance(monthlyTransactions);
  final savingsRate = FinancialCalculator.calculateSavingsRate(income, expense);

  final incomeCount = monthlyTransactions
      .where((t) => t.type == TransactionType.income)
      .length;
  final expenseCount = monthlyTransactions
      .where((t) => t.type == TransactionType.expense)
      .length;

  return MonthlyFinancialSummary(
    totalIncome: income,
    totalExpense: expense,
    netBalance: net,
    savingsRate: savingsRate,
    incomeCount: incomeCount,
    expenseCount: expenseCount,
  );
});

/// Provider for top 5 recent transactions overall
final recentTransactionsProvider = Provider<List<TransactionEntity>>((ref) {
  final transactionsAsync = ref.watch(transactionListNotifierProvider);

  return transactionsAsync.maybeWhen(
    data: (transactions) => transactions.take(5).toList(),
    orElse: () => [],
  );
});

/// Provider for category spending breakdown of current month
final monthlyCategoryBreakdownProvider = Provider<List<CategorySpendingSummary>>((ref) {
  final monthlyTransactions = ref.watch(monthlyTransactionsProvider);
  return FinancialCalculator.calculateCategoryBreakdown(monthlyTransactions);
});

/// Provider for month-over-month spending comparison
final monthlySpendingComparisonProvider = Provider<MonthlySpendingComparison>((ref) {
  final transactionsAsync = ref.watch(transactionListNotifierProvider);
  final selectedMonth = ref.watch(selectedMonthProvider);

  return transactionsAsync.maybeWhen(
    data: (transactions) =>
        FinancialCalculator.calculateMonthOverMonthComparison(transactions, selectedMonth),
    orElse: () => MonthlySpendingComparison.empty,
  );
});

/// Provider for active un-settled shared transactions
final pendingSharedExpensesProvider = Provider<List<TransactionEntity>>((ref) {
  final transactionsAsync = ref.watch(transactionListNotifierProvider);
  return transactionsAsync.maybeWhen(
    data: (transactions) =>
        transactions.where((t) => t.isShared && !t.isSettled).toList(),
    orElse: () => [],
  );
});

/// Provider for total pending reimbursements yet to be collected
final pendingReimbursementsTotalProvider = Provider<double>((ref) {
  final pending = ref.watch(pendingSharedExpensesProvider);
  return FinancialCalculator.calculatePendingReimbursements(pending);
});

/// Provider for credit card funds earmarked in bank accounts from reimbursements
final creditCardEarmarkedReserveProvider = Provider<double>((ref) {
  final transactionsAsync = ref.watch(transactionListNotifierProvider);
  return transactionsAsync.maybeWhen(
    data: (transactions) =>
        FinancialCalculator.calculateCreditCardEarmarkedReserve(transactions),
    orElse: () => 0.0,
  );
});

/// Provider for all shared expenses (both settled and pending)
final allSharedExpensesProvider = Provider<List<TransactionEntity>>((ref) {
  final transactionsAsync = ref.watch(transactionListNotifierProvider);
  return transactionsAsync.maybeWhen(
    data: (transactions) => transactions.where((t) => t.isShared).toList(),
    orElse: () => [],
  );
});
