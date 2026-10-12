import 'package:empty_pocket/core/domain/entities/budget_entity.dart';
import 'package:empty_pocket/core/domain/entities/recurring_expense_entity.dart';
import 'package:empty_pocket/core/domain/entities/savings_goal_entity.dart';
import 'package:empty_pocket/core/domain/entities/transaction_entity.dart';
import 'package:empty_pocket/core/services/notification_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

class ScheduledNotificationCall {
  final int id;
  final String? title;
  final String? body;
  final tz.TZDateTime scheduledDate;
  final String? payload;

  const ScheduledNotificationCall({
    required this.id,
    this.title,
    this.body,
    required this.scheduledDate,
    this.payload,
  });
}

class ShownNotificationCall {
  final int id;
  final String? title;
  final String? body;
  final String? payload;

  const ShownNotificationCall({
    required this.id,
    this.title,
    this.body,
    this.payload,
  });
}

class FakeFlutterLocalNotificationsPlugin
    implements FlutterLocalNotificationsPlugin {
  final List<ScheduledNotificationCall> scheduled = [];
  final List<ShownNotificationCall> shown = [];
  final List<int> cancelled = [];
  final Map<int, PendingNotificationRequest> pendingMap = {};

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) async => true;

  @override
  Future<NotificationAppLaunchDetails?>
  getNotificationAppLaunchDetails() async => null;

  bool failZonedSchedule = false;
  int zonedScheduleFailuresRemaining = 0;
  int cancelFailuresRemaining = 0;

  @override
  Future<void> zonedSchedule({
    required int id,
    String? title,
    String? body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required AndroidScheduleMode androidScheduleMode,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    if (failZonedSchedule) {
      throw Exception('Simulated permanent alarm schedule failure');
    }
    if (zonedScheduleFailuresRemaining > 0) {
      zonedScheduleFailuresRemaining--;
      throw Exception('Simulated transient alarm schedule failure');
    }
    scheduled.add(
      ScheduledNotificationCall(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        payload: payload,
      ),
    );
    pendingMap[id] = PendingNotificationRequest(id, title, body, payload);
  }

  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    NotificationDetails? notificationDetails,
    String? payload,
  }) async {
    shown.add(
      ShownNotificationCall(id: id, title: title, body: body, payload: payload),
    );
  }

  @override
  Future<void> cancel({required int id, String? tag}) async {
    if (cancelFailuresRemaining > 0) {
      cancelFailuresRemaining--;
      throw Exception('Simulated transient cancel failure');
    }
    cancelled.add(id);
    pendingMap.remove(id);
  }

  @override
  Future<void> cancelAll() async {
    pendingMap.clear();
  }

  @override
  Future<List<PendingNotificationRequest>>
  pendingNotificationRequests() async => pendingMap.values.toList();

  @override
  Future<List<ActiveNotification>> getActiveNotifications() async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFlutterLocalNotificationsPlugin fakePlugin;

  setUp(() {
    fakePlugin = FakeFlutterLocalNotificationsPlugin();
    NotificationService.instance.pluginForTesting = fakePlugin;
    NotificationService.debugSupportedOverride = true;
    NotificationService.debugPermissionOverride = true;

    SharedPreferences.setMockInitialValues({
      kPrefDailyStreakReminder: true,
      kPrefBillDueAlert: true,
      kPrefMonthlyMoneyCheckIn: true,
      kPrefBudgetAlertsEnabled: true,
      kPrefBudgetAlertThreshold: 80,
      kPrefHideNotificationAmounts: false,
      kPrefRoutineReminderFrequency: 3,
      kPrefQuietHoursEnabled: false,
      kPrefQuietHoursStart: 22 * 60 + 30,
      kPrefQuietHoursEnd: 7 * 60 + 30,
    });
  });

  tearDown(() {
    NotificationService.instance.resetForTesting();
  });

  group('NotificationService Unit Tests', () {
    test('NotificationService singleton instance is not null', () {
      final service = NotificationService.instance;
      expect(service, isNotNull);
    });

    test('Provider yields NotificationService singleton', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final service = container.read(notificationServiceProvider);
      expect(service, isNotNull);
      expect(identical(service, NotificationService.instance), isTrue);
    });

    test(
      'DailyStreakReminderNotifier loads initial preference and toggles',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        expect(container.read(dailyStreakReminderNotifierProvider), isTrue);

        await container
            .read(dailyStreakReminderNotifierProvider.notifier)
            .setEnabled(false);
        expect(container.read(dailyStreakReminderNotifierProvider), isFalse);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool(kPrefDailyStreakReminder), isFalse);

        await container
            .read(dailyStreakReminderNotifierProvider.notifier)
            .setEnabled(true);
        expect(container.read(dailyStreakReminderNotifierProvider), isTrue);
        expect(prefs.getBool(kPrefDailyStreakReminder), isTrue);
      },
    );

    test('BillDueAlertNotifier loads initial preference and toggles', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(billDueAlertNotifierProvider), isTrue);

      await container
          .read(billDueAlertNotifierProvider.notifier)
          .setEnabled(false);
      expect(container.read(billDueAlertNotifierProvider), isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(kPrefBillDueAlert), isFalse);

      await container
          .read(billDueAlertNotifierProvider.notifier)
          .setEnabled(true);
      expect(container.read(billDueAlertNotifierProvider), isTrue);
      expect(prefs.getBool(kPrefBillDueAlert), isTrue);
    });

    test(
      'MonthlyMoneyCheckInNotifier loads initial preference and toggles',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        expect(container.read(monthlyMoneyCheckInNotifierProvider), isTrue);

        await container
            .read(monthlyMoneyCheckInNotifierProvider.notifier)
            .setEnabled(false);
        expect(container.read(monthlyMoneyCheckInNotifierProvider), isFalse);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool(kPrefMonthlyMoneyCheckIn), isFalse);

        await container
            .read(monthlyMoneyCheckInNotifierProvider.notifier)
            .setEnabled(true);
        expect(container.read(monthlyMoneyCheckInNotifierProvider), isTrue);
        expect(prefs.getBool(kPrefMonthlyMoneyCheckIn), isTrue);
      },
    );

    test(
      'HideNotificationAmountsNotifier toggles and persists preference',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        expect(container.read(hideNotificationAmountsProvider), isFalse);

        await container
            .read(hideNotificationAmountsProvider.notifier)
            .setEnabled(true);
        expect(container.read(hideNotificationAmountsProvider), isTrue);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool(kPrefHideNotificationAmounts), isTrue);

        await container
            .read(hideNotificationAmountsProvider.notifier)
            .setEnabled(false);
        expect(container.read(hideNotificationAmountsProvider), isFalse);
        expect(prefs.getBool(kPrefHideNotificationAmounts), isFalse);
      },
    );

    test(
      'BudgetAlertSettingsNotifier manages enabled state and thresholds',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final initial = container.read(budgetAlertSettingsProvider);
        expect(initial.approachThreshold, 80);

        await container
            .read(budgetAlertSettingsProvider.notifier)
            .setEnabled(true);
        expect(container.read(budgetAlertSettingsProvider).enabled, isTrue);

        await container
            .read(budgetAlertSettingsProvider.notifier)
            .setEnabled(false);
        expect(container.read(budgetAlertSettingsProvider).enabled, isFalse);

        await container
            .read(budgetAlertSettingsProvider.notifier)
            .setApproachThreshold(70);
        expect(
          container.read(budgetAlertSettingsProvider).approachThreshold,
          70,
        );

        await container
            .read(budgetAlertSettingsProvider.notifier)
            .setApproachThreshold(90);
        expect(
          container.read(budgetAlertSettingsProvider).approachThreshold,
          90,
        );

        // Invalid threshold ignored
        await container
            .read(budgetAlertSettingsProvider.notifier)
            .setApproachThreshold(50);
        expect(
          container.read(budgetAlertSettingsProvider).approachThreshold,
          90,
        );

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool(kPrefBudgetAlertsEnabled), isFalse);
        expect(prefs.getInt(kPrefBudgetAlertThreshold), 90);
      },
    );

    test(
      'RoutineReminderSettingsNotifier manages frequency and quiet hours',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final initial = container.read(routineReminderSettingsProvider);
        expect(initial.remindersPerDay, 3);
        expect(initial.quietHoursEnabled, isFalse);
        expect(initial.quietHoursStartMinute, 22 * 60 + 30);
        expect(initial.quietHoursEndMinute, 7 * 60 + 30);

        await container
            .read(routineReminderSettingsProvider.notifier)
            .setRemindersPerDay(1);
        expect(
          container.read(routineReminderSettingsProvider).remindersPerDay,
          1,
        );

        // Invalid frequency rejected
        await container
            .read(routineReminderSettingsProvider.notifier)
            .setRemindersPerDay(2);
        expect(
          container.read(routineReminderSettingsProvider).remindersPerDay,
          1,
        );

        await container
            .read(routineReminderSettingsProvider.notifier)
            .setQuietHoursEnabled(true);
        expect(
          container.read(routineReminderSettingsProvider).quietHoursEnabled,
          isTrue,
        );

        await container
            .read(routineReminderSettingsProvider.notifier)
            .setQuietHours(startMinute: 23 * 60, endMinute: 8 * 60);
        final updated = container.read(routineReminderSettingsProvider);
        expect(updated.quietHoursStartMinute, 23 * 60);
        expect(updated.quietHoursEndMinute, 8 * 60);

        // Out-of-bounds rejected
        await container
            .read(routineReminderSettingsProvider.notifier)
            .setQuietHours(startMinute: -1, endMinute: 8 * 60);
        expect(
          container.read(routineReminderSettingsProvider).quietHoursStartMinute,
          23 * 60,
        );
      },
    );

    test(
      'checkAndNotifyBillsDueToday handles empty or non-due bills safely',
      () async {
        final service = NotificationService.instance;
        final now = DateTime.now();
        final bills = [
          RecurringExpenseEntity(
            id: 'rec_1',
            title: 'Internet Fiber',
            amount: 999,
            category: 'Utilities',
            frequency: RecurringFrequency.monthly,
            paymentSource: 'Bank Account',
            startDate: now.subtract(const Duration(days: 30)),
            nextDueDate: now.add(const Duration(days: 5)),
            createdAt: now,
            updatedAt: now,
          ),
        ];

        await service.checkAndNotifyBillsDueToday(bills);
        await service.checkAndNotifyBillsDueToday(<RecurringExpenseEntity>[]);
      },
    );

    test('scheduleRecurringPaymentReminders accurately schedules before, due, and overdue alerts with exact payload segments, scheduled times, and deduping', () async {
      final service = NotificationService.instance;
      final now = DateTime.now();
      final baseDate = DateTime(now.year, now.month, now.day);
      final upcomingDueDate = baseDate.add(const Duration(days: 5));
      final overdueDueDate = baseDate.subtract(const Duration(days: 2));
      final upcomingDateKey = service.dateKey(upcomingDueDate);
      final overdueDateKey = service.dateKey(overdueDueDate);

      final upcomingBill = RecurringExpenseEntity(
        id: 'rec_bill_due_soon',
        title: 'Electricity Bill',
        amount: 1500,
        category: 'Utilities',
        frequency: RecurringFrequency.monthly,
        paymentSource: 'Bank Account',
        startDate: now.subtract(const Duration(days: 60)),
        nextDueDate: upcomingDueDate,
        createdAt: now,
        updatedAt: now,
      );

      final overdueBill = RecurringExpenseEntity(
        id: 'rec_bill_overdue',
        title: 'Water Utility',
        amount: 450,
        category: 'Utilities',
        frequency: RecurringFrequency.monthly,
        paymentSource: 'Bank Account',
        startDate: now.subtract(const Duration(days: 60)),
        nextDueDate: overdueDueDate,
        createdAt: now,
        updatedAt: now,
      );

      await service.scheduleRecurringPaymentReminders([
        upcomingBill,
        overdueBill,
      ]);

      // 1. Assert exact payload segments, scheduled date/time, and ID for 'due' event
      final dueCall = fakePlugin.scheduled.firstWhere(
        (n) => n.payload?.endsWith(':due') == true,
      );
      final dueSegments = dueCall.payload!.split(':');
      expect(
        dueSegments,
        equals(['bill', 'rec_bill_due_soon', upcomingDateKey, 'due']),
      );
      expect(dueCall.scheduledDate.year, equals(upcomingDueDate.year));
      expect(dueCall.scheduledDate.month, equals(upcomingDueDate.month));
      expect(dueCall.scheduledDate.day, equals(upcomingDueDate.day));
      expect(dueCall.scheduledDate.hour, equals(9));
      expect(dueCall.scheduledDate.minute, equals(0));
      expect(dueCall.id, inInclusiveRange(2000000, 5999999));
      expect(dueCall.title, contains('Electricity Bill'));

      // 2. Assert exact payload segments, scheduled date/time, and ID for 'before' event (2 days prior at 10 AM)
      final beforeCall = fakePlugin.scheduled.firstWhere(
        (n) => n.payload?.endsWith(':before') == true,
      );
      final beforeSegments = beforeCall.payload!.split(':');
      expect(
        beforeSegments,
        equals(['bill', 'rec_bill_due_soon', upcomingDateKey, 'before']),
      );
      final twoDaysBefore = upcomingDueDate.subtract(const Duration(days: 2));
      expect(beforeCall.scheduledDate.year, equals(twoDaysBefore.year));
      expect(beforeCall.scheduledDate.month, equals(twoDaysBefore.month));
      expect(beforeCall.scheduledDate.day, equals(twoDaysBefore.day));
      expect(beforeCall.scheduledDate.hour, equals(10));
      expect(beforeCall.scheduledDate.minute, equals(0));
      expect(beforeCall.id, inInclusiveRange(2000000, 5999999));

      // 3. Assert overdue bill triggers overdue catch-up display with exact payload and ID
      final overdueShown = fakePlugin.shown.firstWhere(
        (n) => n.payload?.endsWith(':overdue_catchup') == true,
      );
      final overdueSegments = overdueShown.payload!.split(':');
      expect(
        overdueSegments,
        equals(['bill', 'rec_bill_overdue', overdueDateKey, 'overdue_catchup']),
      );
      expect(overdueShown.id, inInclusiveRange(2000000, 5999999));
      expect(overdueShown.title, contains('Water Utility'));

      // 4. Assert duplicate-scheduling deduping (signature cache prevents redundant reschedules)
      final scheduledCountBefore = fakePlugin.scheduled.length;
      await service.scheduleRecurringPaymentReminders([
        upcomingBill,
        overdueBill,
      ]);
      expect(fakePlugin.scheduled.length, equals(scheduledCountBefore));

      // 5. Assert replacement behavior: scheduling a different bill replaces old plan and evicts from pending
      final replacedBill = upcomingBill.copyWith(
        id: 'rec_bill_replaced',
        title: 'Internet Fiber',
        nextDueDate: baseDate.add(const Duration(days: 8)),
      );
      await service.scheduleRecurringPaymentReminders([replacedBill]);
      expect(fakePlugin.cancelled.contains(dueCall.id), isTrue);
      expect(fakePlugin.pendingMap.containsKey(dueCall.id), isFalse);
      final newDueCall = fakePlugin.scheduled.firstWhere(
        (n) =>
            n.payload?.contains('rec_bill_replaced') == true &&
            n.payload?.endsWith(':due') == true,
      );
      expect(fakePlugin.pendingMap.containsKey(newDueCall.id), isTrue);
    });

    test('scheduleMonthlyMoneyCheckIns creates start and end of month plans with exact payload segments and scheduled times', () async {
      final service = NotificationService.instance;
      final now = DateTime.now();
      final budgets = [
        BudgetEntity(
          id: 'b1',
          category: 'Food',
          limitAmount: 5000,
          month: now,
          createdAt: now,
          updatedAt: now,
        ),
      ];
      final goals = [
        SavingsGoalEntity(
          id: 'g1',
          title: 'Emergency Fund',
          targetAmount: 50000,
          currentAmount: 15000,
          category: 'Emergency Fund',
          targetDate: now.add(const Duration(days: 180)),
          status: GoalStatus.active,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      await service.scheduleMonthlyMoneyCheckIns(
        budgets: budgets,
        goals: goals,
      );

      expect(fakePlugin.scheduled, isNotEmpty);

      // 1. Assert start of month plan with exact payload segments, matching date segment, morning scheduled time (08:00 - 10:00 inclusive), and ID range
      final planCall = fakePlugin.scheduled.firstWhere(
        (n) => n.payload?.endsWith(':plan') == true,
      );
      final planSegments = planCall.payload!.split(':');
      expect(planSegments.length, equals(3));
      expect(planSegments[0], equals('monthly'));
      expect(planSegments[2], equals('plan'));

      // Verify plan payload date segment matches scheduled date and is day 1
      final planDate = DateTime.parse(planSegments[1]);
      expect(planDate.day, equals(1));
      expect(planSegments[1], equals(service.dateKey(planCall.scheduledDate)));
      expect(planCall.scheduledDate.year, equals(planDate.year));
      expect(planCall.scheduledDate.month, equals(planDate.month));
      expect(planCall.scheduledDate.day, equals(1));
      final planTotalMinutes =
          planCall.scheduledDate.hour * 60 + planCall.scheduledDate.minute;
      expect(
        planTotalMinutes,
        inInclusiveRange(
          8 * 60,
          10 * 60,
        ), // 08:00 (480) to 10:00 (600) inclusive
      );
      expect(planCall.id, inInclusiveRange(6000000, 6899999));

      // 2. Assert end of month review with exact payload segments, last-day date segment, evening scheduled time (18:00 - 20:00 inclusive), and ID range
      final reviewCall = fakePlugin.scheduled.firstWhere(
        (n) => n.payload?.endsWith(':review') == true,
      );
      final reviewSegments = reviewCall.payload!.split(':');
      expect(reviewSegments.length, equals(3));
      expect(reviewSegments[0], equals('monthly'));
      expect(reviewSegments[2], equals('review'));

      // Verify date segment is strictly the last day of the corresponding month and matches scheduled date
      final reviewDate = DateTime.parse(reviewSegments[1]);
      final expectedLastDay = DateTime(
        reviewDate.year,
        reviewDate.month + 1,
        0,
      ).day;
      expect(reviewDate.day, equals(expectedLastDay));
      expect(
        reviewSegments[1],
        equals(
          service.dateKey(
            DateTime(reviewDate.year, reviewDate.month, expectedLastDay),
          ),
        ),
      );
      expect(
        reviewSegments[1],
        equals(service.dateKey(reviewCall.scheduledDate)),
      );

      // Verify scheduled date and evening check-in total time is between 18:00 and 20:00 inclusive
      expect(reviewCall.scheduledDate.year, equals(reviewDate.year));
      expect(reviewCall.scheduledDate.month, equals(reviewDate.month));
      expect(reviewCall.scheduledDate.day, equals(expectedLastDay));
      final reviewTotalMinutes =
          reviewCall.scheduledDate.hour * 60 + reviewCall.scheduledDate.minute;
      expect(
        reviewTotalMinutes,
        inInclusiveRange(
          18 * 60,
          20 * 60,
        ), // 18:00 (1080) to 20:00 (1200) inclusive
      );
      expect(reviewCall.id, inInclusiveRange(6000000, 6899999));

      // 3. Assert duplicate scheduling deduping
      final scheduledCountBefore = fakePlugin.scheduled.length;
      await service.scheduleMonthlyMoneyCheckIns(
        budgets: budgets,
        goals: goals,
      );
      expect(fakePlugin.scheduled.length, equals(scheduledCountBefore));
    });

    test('scheduleMonthlyMoneyCheckIns retries transient failures and does not cache signature on permanent failure', () async {
      final service = NotificationService.instance;
      final now = DateTime.now();

      final budgets = [
        BudgetEntity(
          id: 'b_monthly_fail',
          category: 'Groceries',
          limitAmount: 500,
          month: DateTime(now.year, now.month, 1),
          createdAt: now,
          updatedAt: now,
        ),
      ];
      final goals = [
        SavingsGoalEntity(
          id: 'g_monthly_fail',
          title: 'Trip',
          category: 'Travel',
          targetAmount: 1000,
          currentAmount: 200,
          targetDate: DateTime(now.year, now.month + 2, 1),
          status: GoalStatus.active,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      // 1. Transient failure: first attempt fails, second attempt within _replaceGroup retry loop succeeds
      fakePlugin.scheduled.clear();
      fakePlugin.zonedScheduleFailuresRemaining = 1;
      await service.scheduleMonthlyMoneyCheckIns(
        budgets: budgets,
        goals: goals,
      );
      expect(fakePlugin.scheduled, isNotEmpty);
      expect(fakePlugin.zonedScheduleFailuresRemaining, equals(0));

      // 2. Permanent failure: causes _replaceGroup to return false, preventing signature caching
      // First cancel to clear existing signature
      await service.cancelMonthlyMoneyCheckIns();
      fakePlugin.scheduled.clear();
      fakePlugin.failZonedSchedule = true;

      await service.scheduleMonthlyMoneyCheckIns(
        budgets: budgets,
        goals: goals,
      );
      // Scheduling failed completely, so nothing scheduled
      expect(fakePlugin.scheduled, isEmpty);

      // 3. Recovery: next invocation with SAME signature retries instead of skipping
      fakePlugin.failZonedSchedule = false;
      await service.scheduleMonthlyMoneyCheckIns(
        budgets: budgets,
        goals: goals,
      );
      // Because signature was NOT cached on failure, scheduling succeeded on retry!
      expect(fakePlugin.scheduled, isNotEmpty);

      // 4. Once successful, signature is cached and duplicate calls are safely skipped
      final scheduledCountAfterSuccess = fakePlugin.scheduled.length;
      await service.scheduleMonthlyMoneyCheckIns(
        budgets: budgets,
        goals: goals,
      );
      expect(fakePlugin.scheduled.length, equals(scheduledCountAfterSuccess));
    });

    test('failed replacement evicts stale pending notification with matching ID to prevent delivering outdated content', () async {
      final service = NotificationService.instance;
      final now = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kPrefHideNotificationAmounts, false);

      final initialBudgets = [
        BudgetEntity(
          id: 'b_stale_test',
          category: 'Dining',
          limitAmount: 500,
          month: DateTime(now.year, now.month, 1),
          createdAt: now,
          updatedAt: now,
        ),
      ];

      // 1. Initial successful scheduling puts pending notifications in place
      fakePlugin.scheduled.clear();
      fakePlugin.cancelled.clear();
      fakePlugin.failZonedSchedule = false;

      await service.scheduleMonthlyMoneyCheckIns(
        budgets: initialBudgets,
        goals: const [],
      );
      expect(fakePlugin.scheduled, isNotEmpty);
      final initialPlan = fakePlugin.scheduled.first;
      expect(fakePlugin.pendingMap.containsKey(initialPlan.id), isTrue);
      expect(
        initialPlan.title,
        anyOf(
          equals('A fresh month, a clear plan'),
          equals('Your month-end money check'),
        ),
      );
      expect(
        initialPlan.body,
        anyOf(contains('Review your'), contains('Review this month’s budgets')),
      );

      // 2. User updates privacy setting to hide amounts; signature changes and triggers replacement
      await prefs.setBool(kPrefHideNotificationAmounts, true);

      // Simulate platform scheduling failure during replacement and transient cancel failure
      fakePlugin.failZonedSchedule = true;
      fakePlugin.cancelFailuresRemaining = 1;
      fakePlugin.cancelled.clear();

      await service.scheduleMonthlyMoneyCheckIns(
        budgets: initialBudgets,
        goals: const [],
      );

      // 3. Verify stale pending notification with initialPlan.id was cancelled and evicted
      // (exercising _safeCancel retry loop upon transient cancellation failure)
      expect(fakePlugin.pendingMap.containsKey(initialPlan.id), isFalse);
      expect(fakePlugin.cancelled.contains(initialPlan.id), isTrue);
      expect(fakePlugin.cancelFailuresRemaining, equals(0));

      // 4. Recovery: when failure condition clears, scheduling with the same privacy setting retries and succeeds
      fakePlugin.failZonedSchedule = false;
      fakePlugin.cancelled.clear();

      await service.scheduleMonthlyMoneyCheckIns(
        budgets: initialBudgets,
        goals: const [],
      );

      // New replacement successfully registered with redacted title and body
      expect(fakePlugin.pendingMap.containsKey(initialPlan.id), isTrue);
      final newPlan = fakePlugin.scheduled.lastWhere(
        (n) => n.id == initialPlan.id,
      );
      expect(newPlan.title, equals('Your monthly money check-in'));
      final expectedRedactedBody =
          initialPlan.payload?.endsWith(':review') == true
          ? 'Open EmptyPocket to review this month and plan ahead.'
          : 'Open EmptyPocket to review your budget and savings plan.';
      expect(newPlan.body, equals(expectedRedactedBody));
      expect(newPlan.body, isNot(contains(RegExp(r'\d'))));
    });

    test('scheduleDailySummaries schedules 10 PM daily recap with financial totals, exact payload segments, and deduping', () async {
      final service = NotificationService.instance;
      final now = DateTime.now();
      // Date transactions for tomorrow noon so that 10 PM recap (atTen) is unconditionally in the future
      // regardless of what hour of the day the test runner executes in any timezone
      final targetFutureDate = DateTime(
        now.year,
        now.month,
        now.day + 1,
        12,
        0,
      );
      final targetDateKey = service.dateKey(targetFutureDate);
      final transactions = [
        TransactionEntity(
          id: 'tx_1',
          title: 'Groceries',
          amount: 450,
          type: TransactionType.expense,
          category: 'Food',
          date: targetFutureDate,
          paymentSource: 'UPI',
          createdAt: now,
          updatedAt: now,
        ),
        TransactionEntity(
          id: 'tx_2',
          title: 'Freelance Work',
          amount: 12000,
          type: TransactionType.income,
          category: 'Salary',
          date: targetFutureDate,
          paymentSource: 'Bank Account',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      await service.scheduleDailySummaries(transactions);

      expect(fakePlugin.scheduled, isNotEmpty);
      final summaryCall = fakePlugin.scheduled.firstWhere(
        (n) => n.payload == 'daily_summary:$targetDateKey',
      );
      final summarySegments = summaryCall.payload!.split(':');
      expect(summarySegments.length, equals(2));
      expect(summarySegments[0], equals('daily_summary'));
      expect(summarySegments[1], equals(targetDateKey));
      expect(summaryCall.scheduledDate.year, equals(targetFutureDate.year));
      expect(summaryCall.scheduledDate.month, equals(targetFutureDate.month));
      expect(summaryCall.scheduledDate.day, equals(targetFutureDate.day));
      expect(summaryCall.scheduledDate.hour, equals(22));
      expect(summaryCall.scheduledDate.minute, equals(0));
      expect(summaryCall.id, inInclusiveRange(1000000, 1899999));
      expect(summaryCall.body, contains('450'));
      expect(summaryCall.body, contains('12,000'));

      // Assert duplicate scheduling deduping
      final scheduledCountBefore = fakePlugin.scheduled.length;
      await service.scheduleDailySummaries(transactions);
      expect(fakePlugin.scheduled.length, equals(scheduledCountBefore));
    });

    test('updateBudgetThresholdAlerts calculates milestones and dispatches approaching and reached alerts with exact payload segments and IDs', () async {
      final service = NotificationService.instance;
      final now = DateTime.now();

      final budget = BudgetEntity(
        id: 'b_dining',
        category: 'Dining',
        limitAmount: 1000,
        month: DateTime(now.year, now.month, 1),
        createdAt: now,
        updatedAt: now,
      );

      // 1. Transaction at 85% of budget (approaching 80% threshold)
      final txApproaching = TransactionEntity(
        id: 'tx_approach',
        title: 'Dinner with friends',
        amount: 850,
        type: TransactionType.expense,
        category: 'Dining',
        date: now,
        paymentSource: 'Cash',
        createdAt: now,
        updatedAt: now,
      );

      await service.updateBudgetThresholdAlerts(
        budgets: [budget],
        transactions: [txApproaching],
      );

      expect(fakePlugin.shown, isNotEmpty);
      final approachCall = fakePlugin.shown.firstWhere(
        (n) => n.payload?.endsWith(':approaching') == true,
      );
      final approachSegments = approachCall.payload!.split(':');
      final monthKey =
          '${budget.month.year}-${budget.month.month.toString().padLeft(2, '0')}';
      expect(
        approachSegments,
        equals(['budget', 'b_dining', monthKey, 'approaching']),
      );
      expect(approachCall.id, inInclusiveRange(8000000, 8999999));
      expect(approachCall.title, contains('Dining budget is nearly used'));

      // Clear shown list to test 100% threshold
      fakePlugin.shown.clear();

      // 2. Spending reaches 100%+ (1050 / 1000)
      final txOverLimit = TransactionEntity(
        id: 'tx_limit',
        title: 'Late snack',
        amount: 200,
        type: TransactionType.expense,
        category: 'Dining',
        date: now,
        paymentSource: 'Cash',
        createdAt: now,
        updatedAt: now,
      );

      await service.updateBudgetThresholdAlerts(
        budgets: [budget],
        transactions: [txApproaching, txOverLimit],
      );

      final reachedCall = fakePlugin.shown.firstWhere(
        (n) => n.payload?.endsWith(':reached') == true,
      );
      final reachedSegments = reachedCall.payload!.split(':');
      expect(
        reachedSegments,
        equals(['budget', 'b_dining', monthKey, 'reached']),
      );
      expect(reachedCall.id, inInclusiveRange(8000000, 8999999));
      expect(reachedCall.title, contains('Dining budget reached'));
    });

    test(
      'amount redaction hides numbers when privacy mode is enabled',
      () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(kPrefHideNotificationAmounts, true);

        final service = NotificationService.instance;
        final now = DateTime.now();

        final budget = BudgetEntity(
          id: 'b_privacy',
          category: 'Shopping',
          limitAmount: 2000,
          month: DateTime(now.year, now.month, 1),
          createdAt: now,
          updatedAt: now,
        );

        final tx = TransactionEntity(
          id: 'tx_privacy',
          title: 'Shoes',
          amount: 1800,
          type: TransactionType.expense,
          category: 'Shopping',
          date: now,
          paymentSource: 'Card',
          createdAt: now,
          updatedAt: now,
        );

        await service.updateBudgetThresholdAlerts(
          budgets: [budget],
          transactions: [tx],
        );

        expect(fakePlugin.shown, isNotEmpty);
        final alert = fakePlugin.shown.first;
        expect(alert.title, equals('Budget check-in'));
        expect(
          alert.body,
          equals(
            'A budget reached one of your alert levels. Open EmptyPocket to review it.',
          ),
        );
      },
    );

    group('Notification Calculations & Pure Helpers', () {
      final service = NotificationService.instance;

      test('isInsideQuietHours calculates overnight and daytime windows accurately', () {
        expect(
          service.isInsideQuietHours(
            DateTime(2026, 10, 12, 23, 0),
            enabled: false,
            startMinute: 22 * 60 + 30,
            endMinute: 7 * 60 + 30,
          ),
          isFalse,
        );

        const start = 22 * 60 + 30;
        const end = 7 * 60 + 30;

        expect(
          service.isInsideQuietHours(
            DateTime(2026, 10, 12, 23, 0),
            enabled: true,
            startMinute: start,
            endMinute: end,
          ),
          isTrue,
        );

        expect(
          service.isInsideQuietHours(
            DateTime(2026, 10, 12, 3, 15),
            enabled: true,
            startMinute: start,
            endMinute: end,
          ),
          isTrue,
        );

        expect(
          service.isInsideQuietHours(
            DateTime(2026, 10, 12, 12, 0),
            enabled: true,
            startMinute: start,
            endMinute: end,
          ),
          isFalse,
        );

        expect(
          service.isInsideQuietHours(
            DateTime(2026, 10, 12, 14, 0),
            enabled: true,
            startMinute: 13 * 60,
            endMinute: 15 * 60,
          ),
          isTrue,
        );

        expect(
          service.isInsideQuietHours(
            DateTime(2026, 10, 12, 16, 0),
            enabled: true,
            startMinute: 13 * 60,
            endMinute: 15 * 60,
          ),
          isFalse,
        );
      });

      test(
        'isSupportedNotificationPayload validates recognized payload prefixes',
        () {
          expect(
            service.isSupportedNotificationPayload('daily:2026-10-12:0'),
            isTrue,
          );
          expect(
            service.isSupportedNotificationPayload('daily_summary:2026-10-12'),
            isTrue,
          );
          expect(
            service.isSupportedNotificationPayload('bill:rec_1:2026-10-14:due'),
            isTrue,
          );
          expect(
            service.isSupportedNotificationPayload('monthly:2026-10:start'),
            isTrue,
          );
          expect(
            service.isSupportedNotificationPayload('budget:b1:approach'),
            isTrue,
          );
          expect(
            service.isSupportedNotificationPayload(
              'snooze:bill:rec_1:2026-10-14:due',
            ),
            isTrue,
          );
          expect(
            service.isSupportedNotificationPayload('unsupported:xyz'),
            isFalse,
          );
        },
      );

      test('idForPayload produces stable non-negative 31-bit integers', () {
        final id1 = service.idForPayload('test_payload_1', 1000, 5000);
        final id2 = service.idForPayload('test_payload_1', 1000, 5000);
        final id3 = service.idForPayload('test_payload_2', 1000, 5000);

        expect(id1, equals(id2));
        expect(id1, greaterThanOrEqualTo(1000));
        expect(id1, lessThan(6000));
        expect(id1, isNonNegative);
        expect(id3, isNonNegative);
      });

      test('dateKey formats dates with zero-padded year, month, day', () {
        final date = DateTime(2026, 4, 9);
        expect(service.dateKey(date), equals('2026-04-09'));
      });
    });
  });
}
