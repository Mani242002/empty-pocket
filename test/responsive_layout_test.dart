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
  });
}
