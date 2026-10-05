import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/calculation/financial_calculator.dart';
import '../../../../core/domain/entities/debt_entity.dart';
import '../../../../core/domain/entities/transaction_entity.dart';
import '../../../../core/repositories/debt_repository.dart';
import '../../../../core/repositories/transaction_repository.dart';
import '../../../accounts/presentation/state/accounts_cards_provider.dart';
import '../../../transactions/presentation/state/transactions_provider.dart';

class DebtListNotifier extends AsyncNotifier<List<DebtEntity>> {
  @override
  FutureOr<List<DebtEntity>> build() async {
    final repository = ref.watch(debtRepositoryProvider);
    return await repository.getAllDebts();
  }

  Future<void> saveDebt(DebtEntity debt) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(debtRepositoryProvider);
      await repository.saveDebt(debt);
      return await repository.getAllDebts();
    });
  }

  Future<void> deleteDebt(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(debtRepositoryProvider);
      await repository.deleteDebt(id);
      return await repository.getAllDebts();
    });
  }

  Future<void> recordPayment({
    required DebtEntity debt,
    required double amount,
    double principalPortion = 0.0,
    double interestPortion = 0.0,
    String? notes,
    bool logAsTransaction = true,
    String paymentSource = 'Bank Account',
    String? accountId,
  }) async {
    final now = DateTime.now();
    final effectivePrincipal = principalPortion > 0 ? principalPortion : amount;
    final effectiveInterest = interestPortion > 0
        ? interestPortion
        : (amount - effectivePrincipal).clamp(0.0, double.infinity);
    final txId = const Uuid().v4();

    final tx = logAsTransaction
        ? TransactionEntity(
            id: txId,
            title: 'EMI: ${debt.title}',
            amount: amount,
            type: TransactionType.expense,
            category: 'Debt & Loan Repayment',
            date: now,
            paymentSource: paymentSource,
            accountId: accountId,
            linkedEntityId: debt.id,
            notes: notes ?? 'Debt repayment for "${debt.title}"',
            createdAt: now,
            updatedAt: now,
          )
        : null;

    final txRepo = ref.read(transactionRepositoryProvider);
    if (txRepo is SqliteTransactionRepository) {
      await txRepo.recordDebtPaymentAtomic(
        debt: debt,
        amount: amount,
        principalPortion: effectivePrincipal,
        interestPortion: effectiveInterest,
        notes: notes,
        logAsTransaction: logAsTransaction,
        paymentSource: paymentSource,
        accountId: accountId,
        transaction: tx,
      );
    } else {
      final repository = ref.read(debtRepositoryProvider);
      final payment = DebtPaymentEntity(
        id: const Uuid().v4(),
        debtId: debt.id,
        amount: amount,
        principalPortion: effectivePrincipal,
        interestPortion: effectiveInterest,
        date: now,
        notes: notes,
        sourceAccountId: accountId,
        transactionId: tx?.id,
        createdAt: now,
      );
      await repository.addPayment(payment);

      final newRemaining = max(0.0, debt.remainingAmount - effectivePrincipal);
      final isPaidOff = newRemaining <= 0;

      final updatedDebt = debt.copyWith(
        remainingAmount: newRemaining,
        status: isPaidOff ? DebtStatus.paidOff : debt.status,
        updatedAt: now,
      );
      await saveDebt(updatedDebt);

      if (logAsTransaction && tx != null) {
        if (accountId != null) {
          await ref
              .read(bankAccountListProvider.notifier)
              .adjustAccountBalance(accountId, -amount);
        }
        await ref
            .read(transactionListNotifierProvider.notifier)
            .addTransaction(tx);
      }
    }

    state = AsyncValue.data(
      await ref.read(debtRepositoryProvider).getAllDebts(),
    );
    ref.invalidate(bankAccountListProvider);
    ref.invalidate(transactionListNotifierProvider);
  }
}

final debtListNotifierProvider =
    AsyncNotifierProvider<DebtListNotifier, List<DebtEntity>>(
      DebtListNotifier.new,
    );

/// Aggregated liabilities summary
final overallLiabilitiesSummaryProvider = Provider<OverallLiabilitiesSummary>((
  ref,
) {
  final debtsAsync = ref.watch(debtListNotifierProvider);

  return debtsAsync.maybeWhen(
    data: (debts) =>
        FinancialCalculator.calculateOverallLiabilitiesSummary(debts),
    orElse: () => OverallLiabilitiesSummary.empty,
  );
});

/// Metrics for all debts
final debtRepaymentMetricsListProvider = Provider<List<DebtRepaymentMetrics>>((
  ref,
) {
  final debtsAsync = ref.watch(debtListNotifierProvider);

  return debtsAsync.maybeWhen(
    data: (debts) =>
        debts.map((d) => FinancialCalculator.calculateDebtProgress(d)).toList(),
    orElse: () => [],
  );
});

/// Active debts only
final activeDebtsProvider = Provider<List<DebtEntity>>((ref) {
  final debtsAsync = ref.watch(debtListNotifierProvider);

  return debtsAsync.maybeWhen(
    data: (debts) => debts
        .where((d) => d.status == DebtStatus.active && d.remainingAmount > 0)
        .toList(),
    orElse: () => [],
  );
});

/// Payment history for a single debt
final debtPaymentsProvider =
    FutureProvider.family<List<DebtPaymentEntity>, String>((ref, debtId) async {
      final repository = ref.watch(debtRepositoryProvider);
      return await repository.getPaymentsForDebt(debtId);
    });
