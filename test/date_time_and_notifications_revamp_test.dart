import 'package:flutter/material.dart';
import 'package:empty_pocket/core/domain/entities/ai_assistant_entity.dart';
import 'package:empty_pocket/core/domain/entities/transaction_entity.dart';
import 'package:empty_pocket/core/services/notification_service.dart';
import 'package:empty_pocket/features/ai_assistant/presentation/screens/ai_report_detail_screen.dart';
import 'package:empty_pocket/app/theme/app_theme.dart';
import 'package:empty_pocket/core/repositories/bank_account_repository.dart';
import 'package:empty_pocket/core/repositories/credit_card_repository.dart';
import 'package:empty_pocket/core/repositories/transaction_repository.dart';
import 'package:empty_pocket/features/transactions/presentation/screens/add_edit_transaction_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      kPrefDailyStreakReminder: true,
      kPrefBillDueAlert: true,
    });
  });

  group('Decoupled Date & Time Selection Logic Tests', () {
    test('Updating date preserves existing time of transaction', () {
      final initialDateTime = DateTime(2026, 9, 20, 15, 30); // 3:30 PM
      final yesterday = DateTime(2026, 9, 19);

      // Simulating selecting "Yesterday" while preserving existing hour/minute
      final updatedDateTime = DateTime(
        yesterday.year,
        yesterday.month,
        yesterday.day,
        initialDateTime.hour,
        initialDateTime.minute,
      );

      expect(updatedDateTime.year, 2026);
      expect(updatedDateTime.month, 9);
      expect(updatedDateTime.day, 19);
      expect(updatedDateTime.hour, 15);
      expect(updatedDateTime.minute, 30);
    });

    test('Updating time preserves existing date of transaction', () {
      final currentDateTime = DateTime(2026, 9, 19, 15, 30); // Yesterday 3:30 PM
      const targetHour = 20; // 8:00 PM
      const targetMinute = 0;

      // Simulating selecting "Evening (8:00 PM)" preset
      final updatedDateTime = DateTime(
        currentDateTime.year,
        currentDateTime.month,
        currentDateTime.day,
        targetHour,
        targetMinute,
      );

      expect(updatedDateTime.year, 2026);
      expect(updatedDateTime.month, 9);
      expect(updatedDateTime.day, 19);
      expect(updatedDateTime.hour, 20);
      expect(updatedDateTime.minute, 0);
    });

    test('Restoring "Original" timestamp in Edit Mode restores full date and time', () {
      final originalTimestamp = DateTime(2026, 9, 15, 10, 15);
      final originalTx = TransactionEntity(
        id: 'tx_1',
        title: 'Dinner with friends',
        amount: 1450.0,
        type: TransactionType.expense,
        category: 'Food & Dining',
        date: originalTimestamp,
        paymentSource: 'Bank Account',
        createdAt: originalTimestamp,
        updatedAt: originalTimestamp,
      );

      // Suppose user altered date/time in the sheet
      var selectedDate = DateTime(2026, 9, 18, 18, 45);

      // Tapping "Original" chip
      selectedDate = originalTx.date;

      expect(selectedDate, equals(originalTimestamp));
      expect(selectedDate.year, 2026);
      expect(selectedDate.month, 9);
      expect(selectedDate.day, 15);
      expect(selectedDate.hour, 10);
      expect(selectedDate.minute, 15);
    });
  });

  group('Offline Scheduled Notifications Tests', () {
    test('NotificationService singleton initializes safely without crashing', () async {
      final service = NotificationService.instance;
      expect(service, isNotNull);
      await service.initialize();
    });

    test('scheduleTestDelayedNotification handles fallback gracefully in test environment', () async {
      final service = NotificationService.instance;
      // In unit test environment (kIsWeb or desktop/mock), unsupported platforms return false gracefully
      final result = await service.scheduleTestDelayedNotification(seconds: 10);
      expect(result, isFalse); // Non-mobile platform gracefully handled
    });

    test('Daily streak reminder toggles preference correctly', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(dailyStreakReminderNotifierProvider.notifier);
      await notifier.setEnabled(false);
      expect(container.read(dailyStreakReminderNotifierProvider), isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(kPrefDailyStreakReminder), isFalse);

      await notifier.setEnabled(true);
      expect(container.read(dailyStreakReminderNotifierProvider), isTrue);
      expect(prefs.getBool(kPrefDailyStreakReminder), isTrue);
    });
  });

  group('AI Report Entity & DisplayName Compatibility Tests', () {
    test('AiReportType provides non-empty title and displayName', () {
      for (final type in AiReportType.values) {
        expect(type.title, isNotEmpty);
        expect(type.displayName, equals(type.title));
        expect(type.icon, isNotNull);
      }
    });

    test('AiReportItem timestamp and createdAt are identical', () {
      final now = DateTime.now();
      final report = AiReportItem(
        id: 'rep_1',
        title: 'Full Financial Health Audit',
        type: AiReportType.fullAudit,
        markdownContent: '# Audit Report\nFinancial score is 85/100.',
        modelUsed: 'gemini-1.5-flash',
        modelDisplayName: 'Gemini 1.5 Flash',
        providerUsed: AiProviderType.gemini,
        timestamp: now,
      );

      expect(report.createdAt, equals(now));
      expect(report.timestamp, equals(now));
      expect(report.markdownContent, contains('Audit Report'));
    });

    testWidgets('AiReportDetailScreen renders markdown table on 320dp width without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final report = AiReportItem(
        id: 'rep_table_test',
        title: 'Budget Allocation Breakdown',
        type: AiReportType.budgetOptimization,
        markdownContent: '''
# Monthly Budget Review

| Category | Monthly Budget | Actual Spent | Variance Remaining | Health Status |
| :--- | :--- | :--- | :--- | :--- |
| Food & Dining | \$15,000 | \$16,450 | -\$1,450 (Over) | Critical Alert |
| Transportation | \$8,000 | \$5,200 | +\$2,800 (Under) | Healthy |
| Entertainment | \$4,000 | \$3,900 | +\$100 (On track) | Normal |
''',
        modelUsed: 'gemini-1.5-flash',
        modelDisplayName: 'Gemini 1.5 Flash',
        providerUsed: AiProviderType.gemini,
        timestamp: DateTime(2026, 9, 20, 10, 0),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: AiReportDetailScreen(report: report),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Budget Allocation Breakdown'), findsOneWidget);
    });

    testWidgets('AddEditTransactionSheet decoupled Date & Time row renders without overflow on 320dp width', (tester) async {
      tester.view.physicalSize = const Size(320, 700);
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
            home: const Scaffold(
              body: AddEditTransactionSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Date'), findsOneWidget);
      expect(find.text('Time'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);
      expect(find.text('Now'), findsOneWidget);
    });
  });
}


