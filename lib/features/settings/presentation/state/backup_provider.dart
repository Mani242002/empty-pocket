import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/domain/entities/ai_assistant_entity.dart';
import '../../../../core/repositories/ai_chat_repository.dart';
import '../../../../core/repositories/bank_account_repository.dart';
import '../../../../core/repositories/budget_repository.dart';
import '../../../../core/repositories/credit_card_repository.dart';
import '../../../../core/repositories/debt_repository.dart';
import '../../../../core/repositories/investment_repository.dart';
import '../../../../core/repositories/recurring_repository.dart';
import '../../../../core/repositories/savings_goal_repository.dart';
import '../../../../core/repositories/transaction_repository.dart';
import '../../../../core/services/backup_service.dart';
import '../../../../core/services/log_service.dart';
import '../../../../core/services/overlay_service.dart';
import '../../../accounts/presentation/state/accounts_cards_provider.dart';
import '../../../ai_assistant/presentation/state/ai_assistant_provider.dart';
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

class FloatingBubbleNotifier extends StateNotifier<bool> with WidgetsBindingObserver {
  static const String _keyBubble = 'floating_bubble_enabled';

  FloatingBubbleNotifier() : super(false) {
    WidgetsBinding.instance.addObserver(this);
    _loadState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && this.state) {
      _checkAndRecoverBubble();
    }
  }

  Future<void> _checkAndRecoverBubble() async {
    try {
      final isGranted = await OverlayService.isPermissionGranted();
      if (isGranted) {
        final isActive = await OverlayService.isActive();
        if (!isActive) {
          LogService.info('FloatingBubbleNotifier', 'Auto-recovering floating bubble on app resume');
          await OverlayService.showFloatingBubble();
        }
      }
    } catch (e, stack) {
      LogService.error('FloatingBubbleNotifier', '_checkAndRecoverBubble error', e, stack);
    }
  }

  Future<void> _loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(_keyBubble) ?? false;
      state = enabled;
      if (enabled) {
        await _checkAndRecoverBubble();
      }
    } catch (e, stack) {
      LogService.error('FloatingBubbleNotifier', '_loadState error', e, stack);
    }
  }

  Future<bool> toggleBubble(bool enabled) async {
    state = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyBubble, enabled);
    } catch (e) {
      LogService.error('FloatingBubbleNotifier', 'toggleBubble error', e);
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
            LogService.error('FloatingBubbleNotifier', 'error resetting bubble pref', e);
          }
          return false;
        }
      }
      await OverlayService.showFloatingBubble();
    } else {
      try {
        await OverlayService.closeOverlay();
      } catch (e) {
        LogService.error('FloatingBubbleNotifier', 'closeOverlay error', e);
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
      final bankRepo = ref.read(bankAccountRepositoryProvider);
      final cardRepo = ref.read(creditCardRepositoryProvider);
      final chatRepo = ref.read(aiChatRepositoryProvider);

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
      final bankAccounts = await bankRepo.getAllAccounts();
      final creditCards = await cardRepo.getAllCards();

      List<AiChatSession> chatSessions = [];
      List<AiChatMessage> chatMessages = [];
      try {
        chatSessions = await chatRepo.getAllSessions();
        chatMessages = await chatRepo.getAllMessages();
      } catch (e) {
        debugPrint('[BackupOperationsNotifier] Chat repository query error: $e');
      }

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
        chatSessions: chatSessions,
        chatMessages: chatMessages,
        bankAccounts: bankAccounts,
        creditCards: creditCards,
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
      final bankRepo = ref.read(bankAccountRepositoryProvider);
      final cardRepo = ref.read(creditCardRepositoryProvider);
      final chatRepo = ref.read(aiChatRepositoryProvider);

      await backupService.restoreAll(
        backup: backup,
        transactionRepo: txRepo,
        budgetRepo: budgetRepo,
        savingsRepo: savingsRepo,
        debtRepo: debtRepo,
        investmentRepo: investRepo,
        recurringRepo: recurRepo,
        bankAccountRepo: bankRepo,
        creditCardRepo: cardRepo,
        aiChatRepo: chatRepo,
      );

      _refreshAllProviders();
      state = AsyncValue.data(
        'Successfully restored ${backup.metadata.transactionsCount} transactions, ${backup.metadata.bankAccountsCount} accounts, ${backup.metadata.creditCardsCount} cards, ${backup.metadata.savingsGoalsCount} goals, ${backup.metadata.debtsCount} debts, ${backup.metadata.investmentsCount} investments.',
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
      final bankRepo = ref.read(bankAccountRepositoryProvider);
      final cardRepo = ref.read(creditCardRepositoryProvider);
      final chatRepo = ref.read(aiChatRepositoryProvider);

      await backupService.wipeAllData(
        transactionRepo: txRepo,
        budgetRepo: budgetRepo,
        savingsRepo: savingsRepo,
        debtRepo: debtRepo,
        investmentRepo: investRepo,
        recurringRepo: recurRepo,
        bankAccountRepo: bankRepo,
        creditCardRepo: cardRepo,
        aiChatRepo: chatRepo,
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
    ref.invalidate(bankAccountListProvider);
    ref.invalidate(creditCardListProvider);
    ref.read(aiChatProvider.notifier).loadChatData();
  }
}

final backupOperationsProvider =
    StateNotifierProvider<BackupOperationsNotifier, AsyncValue<String?>>((ref) {
  return BackupOperationsNotifier(ref);
});
