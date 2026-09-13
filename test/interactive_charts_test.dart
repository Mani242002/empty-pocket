import 'package:empty_pocket/core/calculation/financial_calculator.dart';
import 'package:empty_pocket/core/domain/entities/reports_entity.dart';
import 'package:empty_pocket/features/budgets/presentation/widgets/monthly_budgets_tab.dart';
import 'package:empty_pocket/features/budgets/presentation/widgets/recurring_bills_tab.dart';
import 'package:empty_pocket/features/budgets/presentation/widgets/savings_goals_tab.dart';
import 'package:empty_pocket/features/budgets/presentation/widgets/shared_splits_tab.dart';
import 'package:empty_pocket/features/reports/presentation/widgets/interactive_cashflow_line_chart.dart';
import 'package:empty_pocket/features/reports/presentation/widgets/interactive_donut_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InteractiveDonutChart Widget Tests', () {
    testWidgets('renders empty state cleanly when no categories provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InteractiveDonutChart(categories: []),
          ),
        ),
      );

      expect(find.byType(InteractiveDonutChart), findsOneWidget);
      expect(find.text('TOTAL SPENT'), findsNothing);
    });

    testWidgets('renders categories and center total properly', (tester) async {
      const categories = [
        CategorySpendingSummary(category: 'Food & Dining', amount: 3500, percentage: 70, count: 12),
        CategorySpendingSummary(category: 'Entertainment', amount: 1500, percentage: 30, count: 4),
      ];

      int? tappedIndex;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveDonutChart(
              categories: categories,
              onSliceSelected: (index) => tappedIndex = index,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('TOTAL SPENT'), findsOneWidget);
      expect(find.text('2 Categories'), findsOneWidget);
      expect(find.text('Tap a slice to inspect category'), findsOneWidget);
      expect(tappedIndex, isNull);

      // Tap on the chart area to trigger slice selection
      await tester.tap(find.byType(InteractiveDonutChart), warnIfMissed: false);
      await tester.pumpAndSettle();
    });
  });

  group('InteractiveCashflowLineChart Widget Tests', () {
    testWidgets('renders fallback when empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InteractiveCashflowLineChart(
              trends: [],
              forecast: [],
            ),
          ),
        ),
      );

      expect(find.text('No transaction history to display cashflow curves'), findsOneWidget);
    });

    testWidgets('renders historical trends and 3-month forecast with scrubber', (tester) async {
      final now = DateTime(2026, 9, 1);
      final trends = [
        MonthlyTrendData(
          month: DateTime(2026, 7, 1),
          totalIncome: 50000,
          totalExpense: 30000,
          netSavings: 20000,
          savingsRate: 40,
        ),
        MonthlyTrendData(
          month: DateTime(2026, 8, 1),
          totalIncome: 55000,
          totalExpense: 32000,
          netSavings: 23000,
          savingsRate: 41.8,
        ),
        MonthlyTrendData(
          month: now,
          totalIncome: 60000,
          totalExpense: 35000,
          netSavings: 25000,
          savingsRate: 41.6,
        ),
      ];

      final forecast = [
        CashFlowForecastItem(
          month: DateTime(2026, 10, 1),
          projectedIncome: 60000,
          projectedFixedExpenses: 28000,
          projectedNetCash: 32000,
          projectedCumulativeBalance: 150000,
        ),
        CashFlowForecastItem(
          month: DateTime(2026, 11, 1),
          projectedIncome: 60000,
          projectedFixedExpenses: 28000,
          projectedNetCash: 32000,
          projectedCumulativeBalance: 182000,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: InteractiveCashflowLineChart(
                trends: trends,
                forecast: forecast,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('INCOME'), findsOneWidget);
      expect(find.text('EXPENSE'), findsOneWidget);
      expect(find.text('NET CASH'), findsOneWidget);
      expect(find.text('Forecast (*)'), findsOneWidget);
      expect(find.text('Drag to scrub'), findsOneWidget);

      // Perform drag gesture on the chart
      await tester.drag(find.byType(InteractiveCashflowLineChart), const Offset(-50, 0));
      await tester.pumpAndSettle();
    });
  });

  group('Extracted Budget Tabs Structure Tests', () {
    test('Tabs can be instantiated as const widgets', () {
      const monthlyTab = MonthlyBudgetsTab();
      const savingsTab = SavingsGoalsTab();
      const recurringTab = RecurringBillsTab();
      const sharedTab = SharedSplitsTab();

      expect(monthlyTab, isNotNull);
      expect(savingsTab, isNotNull);
      expect(recurringTab, isNotNull);
      expect(sharedTab, isNotNull);
    });
  });
}
