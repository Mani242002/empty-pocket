import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/repositories/budget_repository.dart';
import '../../../../core/repositories/debt_repository.dart';
import '../../../../core/repositories/investment_repository.dart';
import '../../../../core/repositories/recurring_repository.dart';
import '../../../../core/repositories/savings_goal_repository.dart';
import '../../../../core/repositories/transaction_repository.dart';
import '../../../../core/services/backup_service.dart';
import '../../../../core/services/overlay_service.dart';
import '../../../budgets/presentation/state/budgets_provider.dart';
import '../../../budgets/presentation/state/recurring_provider.dart';
import '../../../debts/presentation/state/debts_provider.dart';
import '../../../investments/presentation/state/investments_provider.dart';
import '../../../savings/presentation/state/savings_goals_provider.dart';
import '../../../transactions/presentation/state/transactions_provider.dart';

final backupServiceProvider = Provider<BackupService>((ref) => BackupService());

class AppLockNotifier extends AsyncNotifier<bool> {
  static const String _keyAppLock = 'app_lock_enabled';

  @override
  Future<bool> build() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyAppLock) ?? false;
    } catch (e) {
      debugPrint('[AppLockNotifier] build error: $e');
      return false;
    }
  }

  Future<void> toggleAppLock(bool enabled) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_keyAppLock, enabled);
        return enabled;
      } catch (e) {
        debugPrint('[AppLockNotifier] toggleAppLock error: $e');
        rethrow;
      }
    });
  }
}

final appLockProvider = AsyncNotifierProvider<AppLockNotifier, bool>(
  AppLockNotifier.new,
);

class FloatingBubbleNotifier extends StateNotifier<bool> {
  static const String _keyBubble = 'floating_bubble_enabled';

  FloatingBubbleNotifier() : super(false) {
    _loadState();
  }

  Future<void> _loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getBool(_keyBubble) ?? false;
    } catch (e) {
      debugPrint('[FloatingBubbleNotifier] _loadState error: $e');
    }
  }

  Future<bool> toggleBubble(bool enabled) async {
    state = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyBubble, enabled);
    } catch (e) {
      debugPrint('[FloatingBubbleNotifier] toggleBubble error: $e');
    }

    if (enabled) {
      final granted = await OverlayService.isPermissionGranted();
      if (!granted) {
        final res = await OverlayService.requestPermission();
        if (res != true) {
          state = false;
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool(_keyBubble, false);
          } catch (e) {
            debugPrint('[FloatingBubbleNotifier] error resetting bubble pref: $e');
          }
          return false;
        }
      }
      await OverlayService.showFloatingBubble();
    } else {
      try {
        await OverlayService.closeOverlay();
      } catch (e) {
        debugPrint('[FloatingBubbleNotifier] closeOverlay error: $e');
      }
    }

    return true;
  }
}

final floatingBubbleProvider =
    StateNotifierProvider<FloatingBubbleNotifier, bool>((ref) {
  return FloatingBubbleNotifier();
});

class BackupOperationsNotifier extends StateNotifier<AsyncValue<String?>> {
  final Ref ref;

  BackupOperationsNotifier(this.ref) : super(const AsyncValue.data(null));

  Future<String> exportFullJsonBackup() async {
    state = const AsyncValue.loading();
    try {
      final txRepo = ref.read(transactionRepositoryProvider);
      final budgetRepo = ref.read(budgetRepositoryProvider);
      final savingsRepo = ref.read(savingsGoalRepositoryProvider);
      final debtRepo = ref.read(debtRepositoryProvider);
      final investRepo = ref.read(investmentRepositoryProvider);
      final recurRepo = ref.read(recurringRepositoryProvider);

      final txs = await txRepo.getAllTransactions();
      final budgets = await budgetRepo.getAllBudgets();
      final goals = await savingsRepo.getAllGoals();
      final contribs = <dynamic>[];
      for (final g in goals) {
        final c = await savingsRepo.getContributionsForGoal(g.id);
        contribs.addAll(c);
      }
      final debts = await debtRepo.getAllDebts();
      final payments = <dynamic>[];
      for (final d in debts) {
        final p = await debtRepo.getPaymentsForDebt(d.id);
        payments.addAll(p);
      }
      final investments = await investRepo.getAllInvestments();
      final recurring = await recurRepo.getAllRecurringExpenses();

      final backupService = ref.read(backupServiceProvider);
      final jsonStr = backupService.exportFullDatabaseJson(
        transactions: txs,
        budgets: budgets,
        savingsGoals: goals,
        savingsContributions: contribs.cast(),
        debts: debts,
        debtPayments: payments.cast(),
        investments: investments,
        recurringExpenses: recurring,
      );

      state = const AsyncValue.data('Backup exported successfully');
      return jsonStr;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<String> exportTransactionsCsv() async {
    state = const AsyncValue.loading();
    try {
      final txRepo = ref.read(transactionRepositoryProvider);
      final txs = await txRepo.getAllTransactions();

      final backupService = ref.read(backupServiceProvider);
      final csv = backupService.exportTransactionsToCsv(txs);

      state = const AsyncValue.data('Transactions CSV exported successfully');
      return csv;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> restoreFromJson(String jsonContent) async {
    state = const AsyncValue.loading();
    try {
      final backupService = ref.read(backupServiceProvider);
      final backup = backupService.parseBackupJson(jsonContent);

      final txRepo = ref.read(transactionRepositoryProvider);
      final budgetRepo = ref.read(budgetRepositoryProvider);
      final savingsRepo = ref.read(savingsGoalRepositoryProvider);
      final debtRepo = ref.read(debtRepositoryProvider);
      final investRepo = ref.read(investmentRepositoryProvider);
      final recurRepo = ref.read(recurringRepositoryProvider);

      await backupService.restoreAll(
        backup: backup,
        transactionRepo: txRepo,
        budgetRepo: budgetRepo,
        savingsRepo: savingsRepo,
        debtRepo: debtRepo,
        investmentRepo: investRepo,
        recurringRepo: recurRepo,
      );

      _refreshAllProviders();
      state = AsyncValue.data(
        'Successfully restored ${backup.metadata.transactionsCount} transactions, ${backup.metadata.savingsGoalsCount} goals, ${backup.metadata.debtsCount} debts, and ${backup.metadata.investmentsCount} investments.',
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> wipeAllData() async {
    state = const AsyncValue.loading();
    try {
      final backupService = ref.read(backupServiceProvider);
      final txRepo = ref.read(transactionRepositoryProvider);
      final budgetRepo = ref.read(budgetRepositoryProvider);
      final savingsRepo = ref.read(savingsGoalRepositoryProvider);
      final debtRepo = ref.read(debtRepositoryProvider);
      final investRepo = ref.read(investmentRepositoryProvider);
      final recurRepo = ref.read(recurringRepositoryProvider);

      await backupService.wipeAllData(
        transactionRepo: txRepo,
        budgetRepo: budgetRepo,
        savingsRepo: savingsRepo,
        debtRepo: debtRepo,
        investmentRepo: investRepo,
        recurringRepo: recurRepo,
      );

      _refreshAllProviders();
      state = const AsyncValue.data('All offline financial data wiped.');
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  void _refreshAllProviders() {
    ref.invalidate(transactionListNotifierProvider);
    ref.invalidate(budgetListNotifierProvider);
    ref.invalidate(savingsGoalsListNotifierProvider);
    ref.invalidate(debtListNotifierProvider);
    ref.invalidate(investmentListNotifierProvider);
    ref.invalidate(recurringListNotifierProvider);
  }
}

final backupOperationsProvider =
    StateNotifierProvider<BackupOperationsNotifier, AsyncValue<String?>>((ref) {
  return BackupOperationsNotifier(ref);
});
