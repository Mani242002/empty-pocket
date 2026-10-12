import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:empty_pocket/features/dashboard/presentation/widgets/dashboard_quick_actions.dart';
import 'package:empty_pocket/features/dashboard/presentation/widgets/dashboard_header_bar.dart';
import 'package:empty_pocket/features/transactions/presentation/state/transactions_provider.dart';
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
import 'package:empty_pocket/features/transactions/presentation/screens/transactions_screen.dart';
import 'package:empty_pocket/features/settings/presentation/screens/settings_screen.dart';
import 'package:empty_pocket/features/reports/presentation/screens/reports_analytics_screen.dart';
import 'package:empty_pocket/features/reports/presentation/state/reports_provider.dart';
import 'package:empty_pocket/features/dashboard/presentation/widgets/dashboard_accounts_card.dart';
import 'package:empty_pocket/features/reports/presentation/widgets/interactive_donut_chart.dart';

import 'dart:convert';

import 'package:empty_pocket/core/domain/entities/bank_account_entity.dart';
import 'package:empty_pocket/core/domain/entities/credit_card_entity.dart';
import 'package:empty_pocket/core/calculation/financial_calculator.dart';
import 'package:empty_pocket/core/utilities/loan_share_helper.dart';
import 'package:empty_pocket/features/transactions/presentation/screens/transaction_detail_sheet.dart';
import 'package:empty_pocket/features/budgets/presentation/widgets/shared_splits_tab.dart';
import 'package:empty_pocket/app/presentation/screens/main_navigation_scaffold.dart';
import 'package:empty_pocket/app/theme/app_theme.dart';
import 'package:empty_pocket/core/services/notification_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Responsive Layout & Overflow Prevention Widget Tests', () {
    testWidgets(
      'DashboardQuickActions adapts gracefully on compact 320dp width without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(320, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: ProviderScope(child: DashboardQuickActions()),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Add Expense'), findsOneWidget);
        expect(find.text('Add Income'), findsOneWidget);
        expect(find.text('Set Budget'), findsOneWidget);
      },
    );

    testWidgets(
      'DashboardQuickActions renders horizontally on standard 400dp width screen',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: ProviderScope(child: DashboardQuickActions()),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Add Expense'), findsOneWidget);
        expect(find.text('Add Income'), findsOneWidget);
        expect(find.text('Set Budget'), findsOneWidget);
      },
    );

    testWidgets(
      'BudgetsScreen has no inner FloatingActionButton to clash with MainNavigationScaffold FAB',
      (tester) async {
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
              recurringRepositoryProvider.overrideWithValue(
                inMemoryRecurringRepo,
              ),
              savingsGoalRepositoryProvider.overrideWithValue(
                inMemorySavingsRepo,
              ),
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
      },
    );

    testWidgets(
      'InteractiveCashflowLineChart header renders cleanly without overflow on 320dp screen',
      (tester) async {
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
      },
    );

    testWidgets(
      'TransactionListItem renders cleanly without empty box and without overflow on compact 320dp width',
      (tester) async {
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
        expect(
          find.textContaining('Groceries • 10:40 AM • Indian Overseas Bank'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'SettingsScreen Theme Mode SegmentedButton fits all options on 320dp width without text wrap',
      (tester) async {
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
      },
    );

    testWidgets(
      'SettingsScreen Notifications & Reminders section renders with accessible chips on 320dp width with 1.8x font scale without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        SharedPreferences.setMockInitialValues({
          kPrefBudgetAlertsEnabled: true,
          kPrefBudgetAlertThreshold: 80,
          kPrefRoutineReminderFrequency: 3,
        });

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const MediaQuery(
                data: MediaQueryData(
                  size: Size(320, 800),
                  textScaler: TextScaler.linear(1.8),
                ),
                child: SettingsScreen(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final notificationsHeader = find.text('NOTIFICATIONS & REMINDERS');
        await tester.scrollUntilVisible(notificationsHeader, 200);
        expect(notificationsHeader, findsOneWidget);

        // 1. Verify routine frequency chips and their minimum 48dp accessible tap targets
        final routineChipAll = find.widgetWithText(
          ChoiceChip,
          '3 / day (All prompts)',
        );
        await tester.scrollUntilVisible(routineChipAll, 200);
        expect(routineChipAll, findsOneWidget);
        final routineAllSize = tester.getSize(routineChipAll);
        expect(routineAllSize.height, greaterThanOrEqualTo(48.0));

        final routineChipMorning = find.widgetWithText(
          ChoiceChip,
          '1 / day (Morning only)',
        );
        expect(routineChipMorning, findsOneWidget);
        final routineMorningSize = tester.getSize(routineChipMorning);
        expect(routineMorningSize.height, greaterThanOrEqualTo(48.0));

        // 2. Verify early warning threshold chips and their minimum 48dp accessible tap targets
        final threshold70 = find.widgetWithText(ChoiceChip, '70% limit');
        await tester.scrollUntilVisible(threshold70, 200);
        expect(threshold70, findsOneWidget);
        expect(tester.getSize(threshold70).height, greaterThanOrEqualTo(48.0));

        final threshold80 = find.widgetWithText(ChoiceChip, '80% limit');
        expect(threshold80, findsOneWidget);
        expect(tester.getSize(threshold80).height, greaterThanOrEqualTo(48.0));

        final threshold90 = find.widgetWithText(ChoiceChip, '90% limit');
        await tester.ensureVisible(threshold90);
        await tester.pumpAndSettle();
        expect(threshold90, findsOneWidget);
        expect(tester.getSize(threshold90).height, greaterThanOrEqualTo(48.0));

        // 3. Tap to select and verify interaction succeeds without error or layout overflow
        await tester.tap(threshold90);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // 4. Assert that the selected value changed in both the UI and state/persistence
        final chip90 = tester.widget<ChoiceChip>(
          find.widgetWithText(ChoiceChip, '90% limit'),
        );
        expect(chip90.selected, isTrue);

        final chip80 = tester.widget<ChoiceChip>(
          find.widgetWithText(ChoiceChip, '80% limit'),
        );
        expect(chip80.selected, isFalse);

        final container = ProviderScope.containerOf(
          tester.element(find.byType(SettingsScreen)),
        );
        expect(
          container.read(budgetAlertSettingsProvider).approachThreshold,
          equals(90),
        );

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getInt(kPrefBudgetAlertThreshold), equals(90));
      },
    );

    testWidgets(
      'SettingsScreen descriptive list tiles render multi-line subtitles and semantics without overflow at 320dp width with 1.8x font scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        SharedPreferences.setMockInitialValues({
          kPrefBudgetAlertsEnabled: true,
          kPrefBudgetAlertThreshold: 80,
          kPrefRoutineReminderFrequency: 3,
        });

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const MediaQuery(
                data: MediaQueryData(
                  size: Size(320, 800),
                  textScaler: TextScaler.linear(1.8),
                ),
                child: SettingsScreen(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Helper to scroll to and verify a tile's title, subtitle, isThreeLine, and maxLines configuration
        Future<void> scrollToAndVerify(
          String titleText, {
          required int expectedSubtitleMaxLines,
          required bool expectedThreeLine,
        }) async {
          final titleFinder = find.text(titleText);
          await tester.scrollUntilVisible(titleFinder, 300, maxScrolls: 150);
          await tester.pumpAndSettle();

          expect(titleFinder, findsOneWidget);

          final tileFinder = find.ancestor(
            of: titleFinder,
            matching: find.byType(ListTile),
          );
          expect(tileFinder, findsOneWidget);
          final listTile = tester.widget<ListTile>(tileFinder);
          expect(listTile.isThreeLine, equals(expectedThreeLine));

          final subtitleTextWidget = listTile.subtitle as Text;
          expect(subtitleTextWidget.maxLines, equals(expectedSubtitleMaxLines));
          expect(subtitleTextWidget.overflow, equals(TextOverflow.ellipsis));

          final semanticsFinder = find.ancestor(
            of: tileFinder,
            matching: find.byType(Semantics),
          );
          expect(semanticsFinder, findsAtLeastNWidgets(1));
          final semantics = tester.widget<Semantics>(semanticsFinder.first);
          expect(
            semantics.properties.label,
            equals('$titleText: ${subtitleTextWidget.data}'),
          );
        }

        // 1. Verify Currency tile near the top
        await scrollToAndVerify(
          'Currency',
          expectedSubtitleMaxLines: 2,
          expectedThreeLine: true,
        );

        // 2. Verify PocketAI BYOK keys tile
        await scrollToAndVerify(
          'AI Providers & BYOK Keys',
          expectedSubtitleMaxLines: 2,
          expectedThreeLine: true,
        );

        // 3. Verify Privacy & Security tiles
        await scrollToAndVerify(
          'Data Storage',
          expectedSubtitleMaxLines: 2,
          expectedThreeLine: true,
        );

        await scrollToAndVerify(
          'Network Activity',
          expectedSubtitleMaxLines: 2,
          expectedThreeLine: true,
        );

        // 4. Verify Notifications test tiles
        await scrollToAndVerify(
          'Send Instant Test Notification',
          expectedSubtitleMaxLines: 2,
          expectedThreeLine: true,
        );

        await scrollToAndVerify(
          'Test Offline Alarm (Fires in 10s)',
          expectedSubtitleMaxLines: 2,
          expectedThreeLine: true,
        );

        // 5. Verify Data & Backup tiles
        await scrollToAndVerify(
          'Export Full Backup (JSON)',
          expectedSubtitleMaxLines: 2,
          expectedThreeLine: true,
        );

        await scrollToAndVerify(
          'Restore Database (JSON)',
          expectedSubtitleMaxLines: 2,
          expectedThreeLine: true,
        );

        await scrollToAndVerify(
          'Export Transactions (CSV)',
          expectedSubtitleMaxLines: 2,
          expectedThreeLine: true,
        );

        await scrollToAndVerify(
          'Import Transactions (CSV)',
          expectedSubtitleMaxLines: 2,
          expectedThreeLine: true,
        );

        await scrollToAndVerify(
          'Reconcile Account Balances',
          expectedSubtitleMaxLines: 2,
          expectedThreeLine: true,
        );

        // 6. Verify Danger Zone
        await scrollToAndVerify(
          'Factory Reset / Wipe All Data',
          expectedSubtitleMaxLines: 2,
          expectedThreeLine: true,
        );

        // 7. Verify About section: License, Tagline (descriptive -> 2 lines) and Version (concise -> 1 line)
        await scrollToAndVerify(
          'License',
          expectedSubtitleMaxLines: 2,
          expectedThreeLine: true,
        );

        await scrollToAndVerify(
          'Tagline',
          expectedSubtitleMaxLines: 2,
          expectedThreeLine: true,
        );

        await scrollToAndVerify(
          'Version',
          expectedSubtitleMaxLines: 1,
          expectedThreeLine: false,
        );

        // Entire pass on ultra-compact 320dp width with 1.8x font scale ran without any layout exceptions
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'ReportsAnalyticsScreen category shifts header renders cleanly without overflow on 320dp width',
      (tester) async {
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
              recurringRepositoryProvider.overrideWithValue(
                inMemoryRecurringRepo,
              ),
              savingsGoalRepositoryProvider.overrideWithValue(
                inMemorySavingsRepo,
              ),
              transactionRepositoryProvider.overrideWithValue(inMemoryTxRepo),
              bankAccountRepositoryProvider.overrideWithValue(inMemoryBankRepo),
              creditCardRepositoryProvider.overrideWithValue(inMemoryCardRepo),
              debtRepositoryProvider.overrideWithValue(inMemoryDebtRepo),
              investmentRepositoryProvider.overrideWithValue(
                inMemoryInvestmentRepo,
              ),
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
      },
    );

    testWidgets(
      'MainNavigationScaffold hides FloatingActionButton on Settings screen to prevent overlap',
      (tester) async {
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
              recurringRepositoryProvider.overrideWithValue(
                inMemoryRecurringRepo,
              ),
              savingsGoalRepositoryProvider.overrideWithValue(
                inMemorySavingsRepo,
              ),
              transactionRepositoryProvider.overrideWithValue(inMemoryTxRepo),
              bankAccountRepositoryProvider.overrideWithValue(inMemoryBankRepo),
              creditCardRepositoryProvider.overrideWithValue(inMemoryCardRepo),
              debtRepositoryProvider.overrideWithValue(inMemoryDebtRepo),
              investmentRepositoryProvider.overrideWithValue(
                inMemoryInvestmentRepo,
              ),
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
      },
    );

    testWidgets(
      'MainNavigationScaffold renders navigation destinations cleanly on 320dp width with 1.35x textScale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 600);
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
              recurringRepositoryProvider.overrideWithValue(
                inMemoryRecurringRepo,
              ),
              savingsGoalRepositoryProvider.overrideWithValue(
                inMemorySavingsRepo,
              ),
              transactionRepositoryProvider.overrideWithValue(inMemoryTxRepo),
              bankAccountRepositoryProvider.overrideWithValue(inMemoryBankRepo),
              creditCardRepositoryProvider.overrideWithValue(inMemoryCardRepo),
              debtRepositoryProvider.overrideWithValue(inMemoryDebtRepo),
              investmentRepositoryProvider.overrideWithValue(
                inMemoryInvestmentRepo,
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const MediaQuery(
                data: MediaQueryData(
                  size: Size(320, 600),
                  textScaler: TextScaler.linear(1.35),
                ),
                child: MainNavigationScaffold(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Dashboard'), findsOneWidget);
      },
    );

    testWidgets(
      'DashboardAccountsCard renders without overflow on ultra-compact 320dp width with 1.15x textScale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final dummyAccount = BankAccountEntity(
          id: 'acc-1',
          accountName: 'Primary Salary Checking Account',
          bankName: 'Federal Reserve Bank',
          accountType: AccountType.savings,
          usedFor: 'Salary',
          initialBalance: 50000.0,
          currentBalance: 50000.0,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        );

        final dummyCard = CreditCardEntity(
          id: 'card-1',
          cardName: 'Titanium Infinite Privilege Card',
          bankName: 'Global Credit Corp',
          cardNetwork: CardNetwork.visa,
          creditLimit: 100000.0,
          usedAmount: 25000.0,
          statementDateDay: 15,
          gracePeriodDays: 20,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 600),
                textScaler: TextScaler.linear(1.15),
              ),
              child: Scaffold(
                body: ProviderScope(
                  child: SingleChildScrollView(
                    child: DashboardAccountsCard(
                      bankAccounts: [dummyAccount],
                      creditCards: [dummyCard],
                      combinedCash: 50000.0,
                      creditSummary: const CombinedCreditSummary(
                        totalLimit: 100000.0,
                        totalUsed: 25000.0,
                        totalAvailable: 75000.0,
                        overallUtilizationRatio: 25.0,
                        overallHealth: CreditUtilizationHealth.optimal,
                        activeCardsCount: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Accounts & Cards'), findsOneWidget);
        expect(find.text('Transfer'), findsOneWidget);
        expect(find.text('Pay Card'), findsOneWidget);
      },
    );

    testWidgets(
      'InteractiveDonutChart renders safely within center hole on compact screen with 1.25x textScale',
      (tester) async {
        tester.view.physicalSize = const Size(300, 500);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        const categories = [
          CategorySpendingSummary(
            category: 'Food & Dining Out',
            amount: 8500.0,
            percentage: 55.0,
            count: 10,
          ),
          CategorySpendingSummary(
            category: 'Entertainment & Fun',
            amount: 4500.0,
            percentage: 30.0,
            count: 5,
          ),
          CategorySpendingSummary(
            category: 'Utilities & Bills',
            amount: 2000.0,
            percentage: 15.0,
            count: 2,
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const MediaQuery(
              data: MediaQueryData(
                size: Size(300, 500),
                textScaler: TextScaler.linear(1.25),
              ),
              child: Scaffold(
                body: Center(
                  child: InteractiveDonutChart(categories: categories),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('TOTAL SPENT'), findsOneWidget);
        expect(find.text('3 Categories'), findsOneWidget);
      },
    );

    testWidgets(
      'TransactionsScreen month selector renders without overflow on compact 320dp width screen with 1.25x font scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final inMemoryTxRepo = InMemoryTransactionRepository();
        final inMemoryBankRepo = InMemoryBankAccountRepository();
        final inMemoryCardRepo = InMemoryCreditCardRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              transactionRepositoryProvider.overrideWithValue(inMemoryTxRepo),
              bankAccountRepositoryProvider.overrideWithValue(inMemoryBankRepo),
              creditCardRepositoryProvider.overrideWithValue(inMemoryCardRepo),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const MediaQuery(
                data: MediaQueryData(
                  size: Size(320, 600),
                  textScaler: TextScaler.linear(1.25),
                ),
                child: Scaffold(body: TransactionsScreen()),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byIcon(Icons.calendar_month_rounded), findsOneWidget);
      },
    );

    testWidgets(
      'TransactionsScreen renders date group headers without overflow on 320dp screen with 1.25x font scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final inMemoryTxRepo = InMemoryTransactionRepository();
        final inMemoryBankRepo = InMemoryBankAccountRepository();
        final inMemoryCardRepo = InMemoryCreditCardRepository();

        final now = DateTime.now();
        await inMemoryTxRepo.addTransaction(
          TransactionEntity(
            id: 'tx_today',
            title: 'Grocery Supermarket',
            amount: 1250.0,
            type: TransactionType.expense,
            category: 'Groceries',
            date: now,
            paymentSource: 'Cash',
            createdAt: now,
            updatedAt: now,
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              transactionRepositoryProvider.overrideWithValue(inMemoryTxRepo),
              bankAccountRepositoryProvider.overrideWithValue(inMemoryBankRepo),
              creditCardRepositoryProvider.overrideWithValue(inMemoryCardRepo),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const MediaQuery(
                data: MediaQueryData(
                  size: Size(320, 600),
                  textScaler: TextScaler.linear(1.25),
                ),
                child: Scaffold(body: TransactionsScreen()),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.textContaining('Today'), findsOneWidget);
        expect(find.text('Grocery Supermarket'), findsOneWidget);
      },
    );

    testWidgets(
      'TransactionDetailSheet scales large amounts gracefully without overflow on 320dp width with 1.35x font scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final inMemoryTxRepo = InMemoryTransactionRepository();
        final inMemoryBankRepo = InMemoryBankAccountRepository();
        final inMemoryCardRepo = InMemoryCreditCardRepository();

        final now = DateTime.now();
        final largeTx = TransactionEntity(
          id: 'large_tx_1',
          title: 'Emergency Medical Surgery Bill Super Long Name',
          amount: 99999999.99,
          type: TransactionType.expense,
          category: 'Health & Medical',
          date: now,
          paymentSource: 'HDFC Salary Account',
          createdAt: now,
          updatedAt: now,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              transactionRepositoryProvider.overrideWithValue(inMemoryTxRepo),
              bankAccountRepositoryProvider.overrideWithValue(inMemoryBankRepo),
              creditCardRepositoryProvider.overrideWithValue(inMemoryCardRepo),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: MediaQuery(
                data: const MediaQueryData(
                  size: Size(320, 600),
                  textScaler: TextScaler.linear(1.35),
                ),
                child: Scaffold(
                  body: TransactionDetailSheet(transaction: largeTx),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          find.text('Emergency Medical Surgery Bill Super Long Name'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'SharedSplitsTab with loan card wraps gracefully without overflow on 320dp width with 1.35x font scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final inMemoryTxRepo = InMemoryTransactionRepository();
        final inMemoryBankRepo = InMemoryBankAccountRepository();
        final inMemoryCardRepo = InMemoryCreditCardRepository();

        final now = DateTime.now();
        final loan = LoanShareData(
          borrowerName: 'Suresh Kumar Sharma Junior',
          principalAmount: 50000.0,
          expectedInterest: 2500.0,
          expectedReturnDate: now.add(const Duration(days: 30)),
        );

        await inMemoryTxRepo.addTransaction(
          TransactionEntity(
            id: 'tx_loan_1',
            title: 'Money Lent to Suresh',
            amount: 50000.0,
            type: TransactionType.expense,
            category: 'Money Lent / Helping Friend',
            date: now,
            paymentSource: 'Cash',
            isShared: true,
            sharedWith: jsonEncode(loan.toMap()),
            createdAt: now,
            updatedAt: now,
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              transactionRepositoryProvider.overrideWithValue(inMemoryTxRepo),
              bankAccountRepositoryProvider.overrideWithValue(inMemoryBankRepo),
              creditCardRepositoryProvider.overrideWithValue(inMemoryCardRepo),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const MediaQuery(
                data: MediaQueryData(
                  size: Size(320, 600),
                  textScaler: TextScaler.linear(1.35),
                ),
                child: Scaffold(body: SharedSplitsTab()),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.textContaining('Suresh'), findsAtLeastNWidgets(1));
      },
    );

    testWidgets(
      'DashboardHeaderBar and streak dialog render without overflow on 320dp width with 1.35x font scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [loggingStreakProvider.overrideWithValue(14)],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const MediaQuery(
                data: MediaQueryData(
                  size: Size(320, 600),
                  textScaler: TextScaler.linear(1.35),
                ),
                child: Scaffold(
                  body: DashboardHeaderBar(
                    todayFormatted: 'Saturday, 20 September',
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('EmptyPocket'), findsOneWidget);
        expect(find.text('14 Days'), findsOneWidget);

        // Tap streak badge to open dialog
        await tester.tap(find.text('14 Days'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.textContaining('14-Day Streak!'), findsOneWidget);
        expect(find.text('Keep It Up'), findsOneWidget);

        // Close dialog
        await tester.tap(find.text('Keep It Up'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  });
}
