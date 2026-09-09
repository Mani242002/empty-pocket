import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/calculation/financial_calculator.dart';
import '../../../../core/domain/entities/transaction_entity.dart';
import '../../../../core/repositories/transaction_repository.dart';
import '../../../../core/utilities/split_helper.dart';
import '../../../../core/utilities/loan_share_helper.dart';
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
        // If this was a reimbursement or loan repayment settlement, roll back the original transaction
        if ((prevTx.category == 'Shared Expense Reimbursement' ||
                prevTx.category == 'Loan Repayment Received') &&
            prevTx.linkedEntityId != null) {
          final origMatches = previous.where((t) => t.id == prevTx.linkedEntityId).toList();
          if (origMatches.isNotEmpty) {
            final orig = origMatches.first;
            final loan = LoanShareHelper.parseLoan(orig.sharedWith);
            final rolledBackReimbursed =
                (orig.reimbursedAmount - prevTx.amount).clamp(0.0, double.infinity);

            LoanShareData? updatedLoan;
            bool rolledBackSettled;
            if (loan != null) {
              final newRepaid = (loan.repaidAmount - prevTx.amount).clamp(0.0, double.infinity);
              final isRepaid = newRepaid >= loan.totalExpected && loan.totalExpected > 0;
              updatedLoan = loan.copyWith(repaidAmount: newRepaid, isRepaid: isRepaid);
              rolledBackSettled = isRepaid;
            } else {
              rolledBackSettled = rolledBackReimbursed >= orig.friendsShare && orig.friendsShare > 0;
            }

            final updatedOrig = orig.copyWith(
              reimbursedAmount: rolledBackReimbursed,
              isSettled: rolledBackSettled,
              sharedWith: updatedLoan != null ? LoanShareHelper.encodeLoan(updatedLoan) : orig.sharedWith,
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

  /// Record repayment received for money lent to a friend or relative
  Future<void> recordLoanRepayment({
    required String originalTransactionId,
    required double amountRepaid,
    required String destinationAccountId,
    DateTime? repaymentDate,
    String? notes,
  }) async {
    final previous = state.valueOrNull ?? [];
    final targetList = previous.where((t) => t.id == originalTransactionId).toList();
    if (targetList.isEmpty) return;

    final original = targetList.first;
    final loan = LoanShareHelper.parseLoan(original.sharedWith);
    final totalExpected = loan?.totalExpected ?? original.amount;
    final newRepaid = original.reimbursedAmount + amountRepaid;
    final isFullySettled = newRepaid >= totalExpected;

    LoanShareData? updatedLoan;
    if (loan != null) {
      updatedLoan = loan.copyWith(
        repaidAmount: newRepaid,
        isRepaid: isFullySettled,
      );
    }

    final updatedOriginal = original.copyWith(
      reimbursedAmount: newRepaid,
      isSettled: isFullySettled,
      sharedWith: updatedLoan != null ? LoanShareHelper.encodeLoan(updatedLoan) : original.sharedWith,
      updatedAt: DateTime.now(),
    );

    final now = repaymentDate ?? DateTime.now();
    final destAccounts = ref.read(bankAccountListProvider).valueOrNull ?? [];
    final destAcc = destAccounts.where((a) => a.id == destinationAccountId).firstOrNull;
    final paymentSource = destAcc != null ? destAcc.accountName : 'Cash';
    final borrowerName = loan?.borrowerName ?? 'Friend';

    final repaymentTx = TransactionEntity(
      id: const Uuid().v4(),
      title: 'Repayment: $borrowerName',
      amount: amountRepaid,
      type: TransactionType.income,
      category: 'Loan Repayment Received',
      date: now,
      paymentSource: paymentSource,
      accountId: destAcc?.id,
      linkedEntityId: original.id,
      notes: notes ?? 'Loan repayment received from $borrowerName for "${original.title}"',
      createdAt: now,
      updatedAt: now,
    );

    final optimistic = previous
        .map((t) => t.id == originalTransactionId ? updatedOriginal : t)
        .toList();
    state = AsyncValue.data([repaymentTx, ...optimistic]..sort((a, b) => b.date.compareTo(a.date)));

    try {
      final repository = ref.read(transactionRepositoryProvider);
      await repository.updateTransaction(updatedOriginal);
      await repository.addTransaction(repaymentTx);

      if (destAcc != null) {
        await ref
            .read(bankAccountListProvider.notifier)
            .adjustAccountBalance(destAcc.id, amountRepaid);
      }
    } catch (e, stack) {
      state = AsyncValue.data(previous);
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  /// Settle all pending shared expenses at once in a single bulk operation
  Future<void> settleAllPendingSharedExpenses({
    required String destinationAccountId,
    String? notes,
  }) async {
    final previous = state.valueOrNull ?? [];
    final pendingSplits = previous
        .where((t) => t.isShared && !t.isSettled && t.pendingReimbursement > 0)
        .toList();
    if (pendingSplits.isEmpty) return;

    double totalReimbursed = 0.0;
    final List<TransactionEntity> updatedOriginals = [];
    final now = DateTime.now();

    for (final orig in pendingSplits) {
      final pending = orig.pendingReimbursement;
      totalReimbursed += pending;

      // Mark individual shares as settled if structured JSON
      String? updatedSharedWith = orig.sharedWith;
      final shares = SplitHelper.parseShares(orig.sharedWith);
      if (shares.isNotEmpty) {
        final updatedShares = shares
            .map((s) => s.copyWith(reimbursedAmount: s.amount, isSettled: true))
            .toList();
        updatedSharedWith = SplitHelper.encodeShares(updatedShares);
      }

      final updatedOrig = orig.copyWith(
        reimbursedAmount: orig.friendsShare,
        isSettled: true,
        sharedWith: updatedSharedWith,
        updatedAt: now,
      );
      updatedOriginals.add(updatedOrig);
    }

    if (totalReimbursed <= 0) return;

    final destAccounts = ref.read(bankAccountListProvider).valueOrNull ?? [];
    final destAcc = destAccounts.firstWhere(
      (a) => a.id == destinationAccountId,
      orElse: () => destAccounts.first,
    );

    final settlementTx = TransactionEntity(
      id: const Uuid().v4(),
      title: 'Reimbursement: Cleared All Pending (${pendingSplits.length} expenses)',
      amount: totalReimbursed,
      type: TransactionType.income,
      category: 'Shared Expense Reimbursement',
      date: now,
      paymentSource: destAcc.accountName,
      accountId: destAcc.id,
      notes: notes ?? 'Cleared all ${pendingSplits.length} pending shared expenses payback',
      createdAt: now,
      updatedAt: now,
    );

    final updatedMap = {for (final u in updatedOriginals) u.id: u};
    final optimistic = previous
        .map((t) => updatedMap[t.id] ?? t)
        .toList();
    state = AsyncValue.data([settlementTx, ...optimistic]..sort((a, b) => b.date.compareTo(a.date)));

    try {
      final repository = ref.read(transactionRepositoryProvider);
      for (final u in updatedOriginals) {
        await repository.updateTransaction(u);
      }
      await repository.addTransaction(settlementTx);

      await ref
          .read(bankAccountListProvider.notifier)
          .adjustAccountBalance(destAcc.id, totalReimbursed);
    } catch (e, stack) {
      state = AsyncValue.data(previous);
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  /// Settle all pending reimbursements of a specific person across all different expenses
  Future<void> settlePersonReimbursements({
    required String personName,
    required String destinationAccountId,
    double? customAmount,
    double? offsetExpenseAmount,
    String? offsetExpenseCategory,
    String? notes,
  }) async {
    final previous = state.valueOrNull ?? [];
    final cleanName = personName.trim().toLowerCase();
    final now = DateTime.now();

    final List<TransactionEntity> matchingExpenses = [];
    final List<TransactionEntity> updatedOriginals = [];
    double totalCollected = 0.0;

    for (final tx in previous) {
      if (!tx.isShared || tx.isSettled || tx.pendingReimbursement <= 0) continue;

      // 1. Check if this is a Money Lent / Personal Help loan
      final loan = LoanShareHelper.parseLoan(tx.sharedWith);
      if (loan != null) {
        if (loan.borrowerName.trim().toLowerCase() == cleanName && loan.pendingAmount > 0) {
          matchingExpenses.add(tx);
          final pending = loan.pendingAmount > 0 ? loan.pendingAmount : tx.pendingReimbursement;
          totalCollected += pending;

          final updatedLoan = loan.copyWith(
            repaidAmount: loan.totalExpected,
            isRepaid: true,
          );
          final updatedTx = tx.copyWith(
            reimbursedAmount: tx.friendsShare,
            isSettled: true,
            sharedWith: LoanShareHelper.encodeLoan(updatedLoan),
            updatedAt: now,
          );
          updatedOriginals.add(updatedTx);
        }
        continue;
      }

      // 2. Structured split shares array
      final shares = SplitHelper.parseShares(tx.sharedWith);
      if (shares.isNotEmpty) {
        bool hasPersonShare = false;
        double personPending = 0.0;
        final updatedShares = shares.map((s) {
          if (s.personName.trim().toLowerCase() == cleanName && s.pendingAmount > 0) {
            hasPersonShare = true;
            personPending += s.pendingAmount;
            return s.copyWith(reimbursedAmount: s.amount, isSettled: true);
          }
          return s;
        }).toList();

        if (hasPersonShare && personPending > 0) {
          matchingExpenses.add(tx);
          totalCollected += personPending;

          final newReimbursed = (tx.reimbursedAmount + personPending).clamp(0.0, tx.friendsShare);
          final fullySettled = newReimbursed >= tx.friendsShare ||
              updatedShares.every((s) => s.isSettled);

          final updatedTx = tx.copyWith(
            reimbursedAmount: newReimbursed,
            isSettled: fullySettled,
            sharedWith: SplitHelper.encodeShares(updatedShares),
            updatedAt: now,
          );
          updatedOriginals.add(updatedTx);
        }
      } else if (tx.sharedWith != null &&
          !tx.sharedWith!.trim().startsWith('{') &&
          !tx.sharedWith!.trim().startsWith('[') &&
          tx.sharedWith!.trim().toLowerCase().contains(cleanName)) {
        // Fallback for non-JSON plain text sharedWith containing person's name
        matchingExpenses.add(tx);
        final pending = tx.pendingReimbursement;
        totalCollected += pending;

        final updatedTx = tx.copyWith(
          reimbursedAmount: tx.friendsShare,
          isSettled: true,
          updatedAt: now,
        );
        updatedOriginals.add(updatedTx);
      }
    }

    if (totalCollected <= 0 || updatedOriginals.isEmpty) return;
    final finalAmount = customAmount ?? totalCollected;

    final destAccounts = ref.read(bankAccountListProvider).valueOrNull ?? [];
    final destAcc = destAccounts.firstWhere(
      (a) => a.id == destinationAccountId,
      orElse: () => destAccounts.first,
    );

    final bool isAllLoans = matchingExpenses.isNotEmpty &&
        matchingExpenses.every((t) => LoanShareHelper.parseLoan(t.sharedWith) != null);

    final settlementTx = TransactionEntity(
      id: const Uuid().v4(),
      title: isAllLoans
          ? 'Loan Repayment: $personName'
          : 'Reimbursement: $personName (${matchingExpenses.length} expenses)',
      amount: finalAmount,
      type: TransactionType.income,
      category: isAllLoans ? 'Loan Repayment Received' : 'Shared Expense Reimbursement',
      date: now,
      paymentSource: destAcc.accountName,
      accountId: destAcc.id,
      notes: notes ?? (isAllLoans
          ? 'Repayment received from $personName for loan'
          : 'Full reimbursement collected from $personName across ${matchingExpenses.length} shared bills'),
      createdAt: now,
      updatedAt: now,
    );

    TransactionEntity? offsetTx;
    if (offsetExpenseAmount != null && offsetExpenseAmount > 0) {
      offsetTx = TransactionEntity(
        id: const Uuid().v4(),
        title: 'Share owed to $personName (Offset)',
        amount: offsetExpenseAmount,
        type: TransactionType.expense,
        category: offsetExpenseCategory ?? 'Food & Dining',
        date: now,
        paymentSource: destAcc.accountName,
        accountId: null, // Zero cash impact since net was credited
        notes: 'Offset share deducted against reimbursement by $personName',
        createdAt: now,
        updatedAt: now,
      );
    }

    final updatedMap = {for (final u in updatedOriginals) u.id: u};
    final optimistic = previous
        .map((t) => updatedMap[t.id] ?? t)
        .toList();

    final newTransactions = [
      settlementTx,
      ?offsetTx,
      ...optimistic,
    ]..sort((a, b) => b.date.compareTo(a.date));

    state = AsyncValue.data(newTransactions);

    try {
      final repository = ref.read(transactionRepositoryProvider);
      for (final u in updatedOriginals) {
        await repository.updateTransaction(u);
      }
      await repository.addTransaction(settlementTx);
      if (offsetTx != null) {
        await repository.addTransaction(offsetTx);
      }

      if (finalAmount > 0) {
        await ref
            .read(bankAccountListProvider.notifier)
            .adjustAccountBalance(destAcc.id, finalAmount);
      }
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

/// Provider for all pending shared expenses grouped by person
final pendingByPersonSummaryProvider = Provider<List<PersonPendingSummary>>((ref) {
  final pendingTransactions = ref.watch(pendingSharedExpensesProvider);
  return SplitHelper.groupPendingByPerson(pendingTransactions);
});
