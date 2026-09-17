import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:empty_pocket/features/dashboard/presentation/widgets/dashboard_quick_actions.dart';
import 'package:empty_pocket/features/budgets/presentation/screens/budgets_screen.dart';
import 'package:empty_pocket/features/reports/presentation/widgets/interactive_cashflow_line_chart.dart';
import 'package:empty_pocket/core/domain/entities/reports_entity.dart';
import 'package:empty_pocket/core/repositories/budget_repository.dart';
import 'package:empty_pocket/core/repositories/savings_goal_repository.dart';
import 'package:empty_pocket/core/repositories/recurring_repository.dart';
import 'package:empty_pocket/core/repositories/transaction_repository.dart';
import 'package:empty_pocket/core/repositories/bank_account_repository.dart';
import 'package:empty_pocket/core/repositories/credit_card_repository.dart';
import 'package:empty_pocket/core/repositories/debt_repository.dart';
import 'package:empty_pocket/core/repositories/investment_repository.dart';
import 'package:empty_pocket/core/domain/entities/transaction_entity.dart';
import 'package:empty_pocket/features/transactions/presentation/widgets/transaction_list_item.dart';
import 'package:empty_pocket/features/settings/presentation/screens/settings_screen.dart';
import 'package:empty_pocket/features/reports/presentation/screens/reports_analytics_screen.dart';
import 'package:empty_pocket/features/reports/presentation/state/reports_provider.dart';
import 'package:empty_pocket/app/presentation/screens/main_navigation_scaffold.dart';
import 'package:empty_pocket/app/theme/app_theme.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Responsive Layout & Overflow Prevention Widget Tests', () {
    testWidgets('DashboardQuickActions adapts gracefully on compact 320dp width without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: ProviderScope(
              child: DashboardQuickActions(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Add Expense'), findsOneWidget);
      expect(find.text('Add Income'), findsOneWidget);
      expect(find.text('Set Budget'), findsOneWidget);
    });

    testWidgets('DashboardQuickActions renders horizontally on standard 400dp width screen', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: ProviderScope(
              child: DashboardQuickActions(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Add Expense'), findsOneWidget);
      expect(find.text('Add Income'), findsOneWidget);
      expect(find.text('Set Budget'), findsOneWidget);
    });

    testWidgets('BudgetsScreen has no inner FloatingActionButton to clash with MainNavigationScaffold FAB', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final inMemoryBudgetRepo = InMemoryBudgetRepository();
      final inMemoryRecurringRepo = InMemoryRecurringRepository();
      final inMemorySavingsRepo = InMemorySavingsGoalRepository();
      final inMemoryTxRepo = InMemoryTransactionRepository();
      final inMemoryBankRepo = InMemoryBankAccountRepository();
      final inMemoryCardRepo = InMemoryCreditCardRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            budgetRepositoryProvider.overrideWithValue(inMemoryBudgetRepo),
            recurringRepositoryProvider.overrideWithValue(inMemoryRecurringRepo),
            savingsGoalRepositoryProvider.overrideWithValue(inMemorySavingsRepo),
            transactionRepositoryProvider.overrideWithValue(inMemoryTxRepo),
            bankAccountRepositoryProvider.overrideWithValue(inMemoryBankRepo),
            creditCardRepositoryProvider.overrideWithValue(inMemoryCardRepo),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const BudgetsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Ensure BudgetsScreen itself does not render its own FAB
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('InteractiveCashflowLineChart header renders cleanly without overflow on 320dp screen', (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final trends = [
        MonthlyTrendData(
          month: DateTime(2026, 9, 1),
          totalIncome: 75000.0,
          totalExpense: 32000.0,
          netSavings: 43000.0,
          savingsRate: 57.3,
        ),
        MonthlyTrendData(
          month: DateTime(2026, 10, 1),
          totalIncome: 80000.0,
          totalExpense: 35000.0,
          netSavings: 45000.0,
          savingsRate: 56.25,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: InteractiveCashflowLineChart(
                trends: trends,
                forecast: const [],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Actual Recorded'), findsOneWidget);
    });

    testWidgets('TransactionListItem renders cleanly without empty box and without overflow on compact 320dp width', (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final tx = TransactionEntity(
        id: 'test-tx-1',
        title: 'Groceries at Supermarket',
        amount: 273.0,
        type: TransactionType.expense,
        category: 'Groceries',
        date: DateTime(2026, 9, 15, 10, 40),
        paymentSource: 'Indian Overseas Bank',
        createdAt: DateTime(2026, 9, 15),
        updatedAt: DateTime(2026, 9, 15),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TransactionListItem(transaction: tx),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Groceries at Supermarket'), findsOneWidget);
      // Ensure the subtitle contains category, time, and payment source without empty box
      expect(find.textContaining('Groceries • 10:40 AM • Indian Overseas Bank'), findsOneWidget);
    });

    testWidgets('SettingsScreen Theme Mode SegmentedButton fits all options on 320dp width without text wrap', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Theme Mode'), findsOneWidget);
      expect(find.text('System'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
    });

    testWidgets('ReportsAnalyticsScreen category shifts header renders cleanly without overflow on 320dp width', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final sampleChanges = [
        const CategoryMomChange(
          category: 'Money Lent / Helping Friend',
          currentMonthAmount: 16000,
          previousMonthAmount: 0,
          diffAmount: 16000,
          percentChange: 100,
        ),
      ];

      final inMemoryBudgetRepo = InMemoryBudgetRepository();
      final inMemoryRecurringRepo = InMemoryRecurringRepository();
      final inMemorySavingsRepo = InMemorySavingsGoalRepository();
      final inMemoryTxRepo = InMemoryTransactionRepository();
      final inMemoryBankRepo = InMemoryBankAccountRepository();
      final inMemoryCardRepo = InMemoryCreditCardRepository();
      final inMemoryDebtRepo = InMemoryDebtRepository();
      final inMemoryInvestmentRepo = InMemoryInvestmentRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            budgetRepositoryProvider.overrideWithValue(inMemoryBudgetRepo),
            recurringRepositoryProvider.overrideWithValue(inMemoryRecurringRepo),
            savingsGoalRepositoryProvider.overrideWithValue(inMemorySavingsRepo),
            transactionRepositoryProvider.overrideWithValue(inMemoryTxRepo),
            bankAccountRepositoryProvider.overrideWithValue(inMemoryBankRepo),
            creditCardRepositoryProvider.overrideWithValue(inMemoryCardRepo),
            debtRepositoryProvider.overrideWithValue(inMemoryDebtRepo),
            investmentRepositoryProvider.overrideWithValue(inMemoryInvestmentRepo),
            categoryMomChangesProvider.overrideWithValue(sampleChanges),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const ReportsAnalyticsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Month-Over-Month Category Shifts'), findsOneWidget);
      expect(find.text('vs Previous Month'), findsOneWidget);
    });

    testWidgets('MainNavigationScaffold hides FloatingActionButton on Settings screen to prevent overlap', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final inMemoryBudgetRepo = InMemoryBudgetRepository();
      final inMemoryRecurringRepo = InMemoryRecurringRepository();
      final inMemorySavingsRepo = InMemorySavingsGoalRepository();
      final inMemoryTxRepo = InMemoryTransactionRepository();
      final inMemoryBankRepo = InMemoryBankAccountRepository();
      final inMemoryCardRepo = InMemoryCreditCardRepository();
      final inMemoryDebtRepo = InMemoryDebtRepository();
      final inMemoryInvestmentRepo = InMemoryInvestmentRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            budgetRepositoryProvider.overrideWithValue(inMemoryBudgetRepo),
            recurringRepositoryProvider.overrideWithValue(inMemoryRecurringRepo),
            savingsGoalRepositoryProvider.overrideWithValue(inMemorySavingsRepo),
            transactionRepositoryProvider.overrideWithValue(inMemoryTxRepo),
            bankAccountRepositoryProvider.overrideWithValue(inMemoryBankRepo),
            creditCardRepositoryProvider.overrideWithValue(inMemoryCardRepo),
            debtRepositoryProvider.overrideWithValue(inMemoryDebtRepo),
            investmentRepositoryProvider.overrideWithValue(inMemoryInvestmentRepo),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const MainNavigationScaffold(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // On Dashboard (tab 0), FAB is present
      expect(find.byType(FloatingActionButton), findsOneWidget);

      // Tap Settings tab (destination 4)
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      // On Settings (tab 4), FAB should be hidden so it doesn't obstruct settings cards or switches
      expect(find.byType(FloatingActionButton), findsNothing);
    });
  });
}
