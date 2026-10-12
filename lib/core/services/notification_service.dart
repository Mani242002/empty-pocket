import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../domain/entities/budget_entity.dart';
import '../domain/entities/recurring_expense_entity.dart';
import '../domain/entities/savings_goal_entity.dart';
import '../domain/entities/transaction_entity.dart';
import '../utilities/currency_formatter.dart';
import 'log_service.dart';

const String kPrefDailyStreakReminder = 'notifications_daily_streak_enabled';
const String kPrefBillDueAlert = 'notifications_bill_due_enabled';
const String kPrefMonthlyMoneyCheckIn = 'notifications_monthly_checkin_enabled';
const String kPrefRoutineReminderFrequency = 'notifications_routine_frequency';
const String kPrefQuietHoursEnabled = 'notifications_quiet_hours_enabled';
const String kPrefQuietHoursStart = 'notifications_quiet_hours_start';
const String kPrefQuietHoursEnd = 'notifications_quiet_hours_end';
const String kPrefHideNotificationAmounts =
    'notifications_hide_amounts_on_lock_screen';
const String kPrefBudgetAlertsEnabled = 'notifications_budget_alerts_enabled';
const String kPrefBudgetAlertThreshold = 'notifications_budget_alert_threshold';

const String kNotificationActionLogExpense = 'log_expense';
const String kNotificationActionMarkBillPaid = 'mark_bill_paid';
const String kNotificationActionReviewBudget = 'review_budget';
const String kNotificationActionRemindLater = 'remind_later';

final ValueNotifier<NotificationIntent?> notificationIntentEvents =
    ValueNotifier(null);

class NotificationIntent {
  final String payload;
  final String? actionId;

  const NotificationIntent({required this.payload, this.actionId});
}

class RoutineReminderSettings {
  final int remindersPerDay;
  final bool quietHoursEnabled;
  final int quietHoursStartMinute;
  final int quietHoursEndMinute;

  const RoutineReminderSettings({
    this.remindersPerDay = 3,
    this.quietHoursEnabled = false,
    this.quietHoursStartMinute = 22 * 60 + 30,
    this.quietHoursEndMinute = 7 * 60 + 30,
  });

  RoutineReminderSettings copyWith({
    int? remindersPerDay,
    bool? quietHoursEnabled,
    int? quietHoursStartMinute,
    int? quietHoursEndMinute,
  }) => RoutineReminderSettings(
    remindersPerDay: remindersPerDay ?? this.remindersPerDay,
    quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
    quietHoursStartMinute: quietHoursStartMinute ?? this.quietHoursStartMinute,
    quietHoursEndMinute: quietHoursEndMinute ?? this.quietHoursEndMinute,
  );
}

final routineReminderSettingsProvider =
    StateNotifierProvider<
      RoutineReminderSettingsNotifier,
      RoutineReminderSettings
    >((ref) => RoutineReminderSettingsNotifier());

class RoutineReminderSettingsNotifier
    extends StateNotifier<RoutineReminderSettings> {
  RoutineReminderSettingsNotifier() : super(const RoutineReminderSettings()) {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = RoutineReminderSettings(
        remindersPerDay: prefs.getInt(kPrefRoutineReminderFrequency) == 1
            ? 1
            : 3,
        quietHoursEnabled: prefs.getBool(kPrefQuietHoursEnabled) ?? false,
        quietHoursStartMinute: _validMinute(
          prefs.getInt(kPrefQuietHoursStart),
          22 * 60 + 30,
        ),
        quietHoursEndMinute: _validMinute(
          prefs.getInt(kPrefQuietHoursEnd),
          7 * 60 + 30,
        ),
      );
    } catch (e) {
      LogService.warning(
        'RoutineReminderSettings',
        'Preference load failed: $e',
      );
    }
  }

  Future<void> setRemindersPerDay(int value) async {
    if (value != 1 && value != 3) return;
    await _save(state.copyWith(remindersPerDay: value));
  }

  Future<void> setQuietHoursEnabled(bool enabled) async {
    await _save(state.copyWith(quietHoursEnabled: enabled));
  }

  Future<void> setQuietHours({
    required int startMinute,
    required int endMinute,
  }) async {
    if (startMinute < 0 ||
        startMinute >= 1440 ||
        endMinute < 0 ||
        endMinute >= 1440) {
      return;
    }
    await _save(
      state.copyWith(
        quietHoursStartMinute: startMinute,
        quietHoursEndMinute: endMinute,
      ),
    );
  }

  Future<void> _save(RoutineReminderSettings next) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(kPrefRoutineReminderFrequency, next.remindersPerDay);
      await prefs.setBool(kPrefQuietHoursEnabled, next.quietHoursEnabled);
      await prefs.setInt(kPrefQuietHoursStart, next.quietHoursStartMinute);
      await prefs.setInt(kPrefQuietHoursEnd, next.quietHoursEndMinute);
      state = next;
    } catch (e) {
      LogService.error('RoutineReminderSettings', 'Preference save failed: $e');
    }
  }
}

int _validMinute(int? value, int fallback) =>
    value != null && value >= 0 && value < 1440 ? value : fallback;

final hideNotificationAmountsProvider =
    StateNotifierProvider<HideNotificationAmountsNotifier, bool>(
      (ref) => HideNotificationAmountsNotifier(),
    );

class HideNotificationAmountsNotifier extends StateNotifier<bool> {
  HideNotificationAmountsNotifier() : super(false) {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getBool(kPrefHideNotificationAmounts) ?? false;
    } catch (e) {
      LogService.warning('NotificationPrivacy', 'Preference load failed: $e');
    }
  }

  Future<void> setEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kPrefHideNotificationAmounts, enabled);
      state = enabled;
    } catch (e) {
      LogService.error('NotificationPrivacy', 'Preference save failed: $e');
    }
  }
}

class BudgetAlertSettings {
  final bool enabled;
  final int approachThreshold;

  const BudgetAlertSettings({
    this.enabled = false,
    this.approachThreshold = 80,
  });
}

final budgetAlertSettingsProvider =
    StateNotifierProvider<BudgetAlertSettingsNotifier, BudgetAlertSettings>(
      (ref) => BudgetAlertSettingsNotifier(),
    );

class BudgetAlertSettingsNotifier extends StateNotifier<BudgetAlertSettings> {
  BudgetAlertSettingsNotifier() : super(const BudgetAlertSettings()) {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final threshold = prefs.getInt(kPrefBudgetAlertThreshold) ?? 80;
      state = BudgetAlertSettings(
        enabled: prefs.getBool(kPrefBudgetAlertsEnabled) ?? false,
        approachThreshold: const [70, 80, 90].contains(threshold)
            ? threshold
            : 80,
      );
    } catch (e) {
      LogService.warning('BudgetAlerts', 'Preference load failed: $e');
    }
  }

  Future<void> setEnabled(bool enabled) async => _save(
    BudgetAlertSettings(
      enabled: enabled,
      approachThreshold: state.approachThreshold,
    ),
  );

  Future<void> setApproachThreshold(int threshold) async {
    if (!const [70, 80, 90].contains(threshold)) return;
    await _save(
      BudgetAlertSettings(enabled: state.enabled, approachThreshold: threshold),
    );
  }

  Future<void> _save(BudgetAlertSettings next) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kPrefBudgetAlertsEnabled, next.enabled);
      await prefs.setInt(kPrefBudgetAlertThreshold, next.approachThreshold);
      state = next;
    } catch (e) {
      LogService.error('BudgetAlerts', 'Preference save failed: $e');
    }
  }
}

final dailyStreakReminderNotifierProvider =
    StateNotifierProvider<DailyStreakReminderNotifier, bool>((ref) {
      return DailyStreakReminderNotifier(ref);
    });

class DailyStreakReminderNotifier extends StateNotifier<bool> {
  final Ref _ref;
  DailyStreakReminderNotifier(this._ref) : super(true) {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getBool(kPrefDailyStreakReminder) ?? true;
    } catch (_) {
      state = true;
    }
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kPrefDailyStreakReminder, enabled);
      final service = _ref.read(notificationServiceProvider);
      if (enabled) {
        await service.scheduleDailyStreakReminder();
      } else {
        await service.cancelDailyStreakReminder();
      }
    } catch (e) {
      LogService.error(
        'DailyStreakReminderNotifier',
        'Preference update failed: $e',
      );
    }
  }
}

final billDueAlertNotifierProvider =
    StateNotifierProvider<BillDueAlertNotifier, bool>((ref) {
      return BillDueAlertNotifier(ref);
    });

class BillDueAlertNotifier extends StateNotifier<bool> {
  final Ref _ref;
  BillDueAlertNotifier(this._ref) : super(true) {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getBool(kPrefBillDueAlert) ?? true;
    } catch (_) {
      state = true;
    }
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kPrefBillDueAlert, enabled);
      if (!enabled) {
        await _ref.read(notificationServiceProvider).cancelBillDueAlerts();
      }
    } catch (e) {
      LogService.error('BillDueAlertNotifier', 'Preference update failed: $e');
    }
  }
}

final monthlyMoneyCheckInNotifierProvider =
    StateNotifierProvider<MonthlyMoneyCheckInNotifier, bool>((ref) {
      return MonthlyMoneyCheckInNotifier(ref);
    });

class MonthlyMoneyCheckInNotifier extends StateNotifier<bool> {
  final Ref _ref;
  MonthlyMoneyCheckInNotifier(this._ref) : super(true) {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getBool(kPrefMonthlyMoneyCheckIn) ?? true;
    } catch (_) {
      state = true;
    }
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kPrefMonthlyMoneyCheckIn, enabled);
      if (!enabled) {
        await _ref
            .read(notificationServiceProvider)
            .cancelMonthlyMoneyCheckIns();
      }
    } catch (e) {
      LogService.error(
        'MonthlyMoneyCheckInNotifier',
        'Preference update failed: $e',
      );
    }
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService.instance;
});

class NotificationService {
  static const String _tag = 'NotificationService';
  static final NotificationService instance = NotificationService._internal();
  NotificationService._internal();

  FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  Future<void> _queue = Future<void>.value();
  bool _initialized = false;
  bool _launchDetailsRead = false;
  String? _dailyWindowStart;
  String? _dailySummarySignature;
  String? _billSignature;
  String? _monthlySignature;

  @visibleForTesting
  set pluginForTesting(FlutterLocalNotificationsPlugin plugin) {
    _plugin = plugin;
  }

  @visibleForTesting
  static bool? debugPermissionOverride;

  @visibleForTesting
  void resetForTesting() {
    _initialized = false;
    _dailyWindowStart = null;
    _dailySummarySignature = null;
    _billSignature = null;
    _monthlySignature = null;
    debugSupportedOverride = null;
    debugPermissionOverride = null;
    _plugin = FlutterLocalNotificationsPlugin();
  }

  static const int streakNotificationId = 1001; // old ID, retained for cleanup
  static const int billNotificationIdBase =
      2000; // old IDs, retained for cleanup
  static const int testNotificationId = 9999;

  static const String streakChannelId = 'emptypocket_daily_checkins_v2';
  static const String streakChannelName = 'Daily Money Reminders';
  static const String streakChannelDesc = 'Prompts to record spending each day';
  static const String billChannelId = 'emptypocket_bill_alerts';
  static const String billChannelName = 'Bills and Payments';
  static const String billChannelDesc =
      'Reminders before and after scheduled payments';
  static const String planningChannelId = 'emptypocket_monthly_planning';
  static const String planningChannelName = 'Monthly Money Check-ins';
  static const String planningChannelDesc =
      'Reminders to review budgets and savings goals';
  static const String budgetChannelId = 'emptypocket_budget_alerts';
  static const String budgetChannelName = 'Budget Alerts';
  static const String budgetChannelDesc =
      'Optional alerts when spending approaches a budget limit';

  @visibleForTesting
  static bool? debugSupportedOverride;

  bool get _supported {
    if (debugSupportedOverride != null) return debugSupportedOverride!;
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  int get _dailyHorizonDays => Platform.isIOS ? 7 : 30;
  int get _monthlyHorizonMonths => Platform.isIOS ? 2 : 6;

  static const List<String> _morningMessages = [
    'Good morning! Start fresh today and add each expense as it happens.',
    'Good morning ☀️ A quick expense note now makes tonight’s recap useful.',
    'Morning! Remember to log your spending as you go today.',
    'Good morning! Your money plan starts with the first expense you record.',
    'A new day, a fresh start. Add today’s expenses whenever you can.',
    'Good morning! Keep your day on track by noting each purchase.',
    'Morning check-in: remember to record your expenses today.',
    'Good morning 🌤️ Small updates make your money picture clearer.',
    'Start the day feeling organized—log expenses when they happen.',
    'Good morning! EmptyPocket is ready when you are; note today’s spending.',
  ];
  static const List<String> _afternoonMessages = [
    'Afternoon check-in: did you remember to add this morning’s spending?',
    'Take a quick pause and catch up on any expenses from today.',
    'A small reminder to log anything you spent since morning.',
    'How is your day going? Add purchases you have not recorded yet.',
    'Quick money check: note any expenses from your morning.',
    'If anything slipped your mind, take a moment to add it now.',
    'Keep your records current—log today’s spending when you have a minute.',
    'Afternoon nudge: capture little purchases before they are forgotten.',
    'Have you added today’s expenses? A quick update keeps totals useful.',
    'Take a breath, then record any spending from earlier today.',
  ];
  static const List<String> _eveningMessages = [
    'Evening check-in: add any expenses from the second half of your day.',
    'Before the day gets busy, note spending you have not logged yet.',
    'A quick evening update can make tomorrow’s money picture clearer.',
    'Did you make purchases this afternoon? Add them when you can.',
    'Take a moment to catch up on today’s expenses.',
    'Evening reminder: record any payments or purchases from today.',
    'Your day is winding down—add spending while it is still fresh.',
    'One quick check: are all of today’s expenses in EmptyPocket?',
    'Log this evening’s expenses so your records stay up to date.',
    'Before you settle in, capture any spending you made today.',
  ];

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      tz_data.initializeTimeZones();
      try {
        final localTimezone = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(localTimezone.identifier));
      } catch (e) {
        LogService.warning(_tag, 'Timezone lookup failed; using UTC: $e');
        tz.setLocalLocation(tz.UTC);
      }
      if (!_supported) {
        _initialized = true;
        return;
      }

      final settings = InitializationSettings(
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          notificationCategories: [
            DarwinNotificationCategory(
              'empty_pocket_daily_actions',
              actions: [
                DarwinNotificationAction.plain(
                  kNotificationActionLogExpense,
                  'Log expense',
                  options: {DarwinNotificationActionOption.foreground},
                ),
                DarwinNotificationAction.plain(
                  kNotificationActionRemindLater,
                  'Remind me later',
                  options: {DarwinNotificationActionOption.foreground},
                ),
              ],
            ),
            DarwinNotificationCategory(
              'empty_pocket_bill_actions',
              actions: [
                DarwinNotificationAction.plain(
                  kNotificationActionMarkBillPaid,
                  'Mark bill paid',
                  options: {DarwinNotificationActionOption.foreground},
                ),
                DarwinNotificationAction.plain(
                  kNotificationActionRemindLater,
                  'Remind me later',
                  options: {DarwinNotificationActionOption.foreground},
                ),
              ],
            ),
            DarwinNotificationCategory(
              'empty_pocket_budget_actions',
              actions: [
                DarwinNotificationAction.plain(
                  kNotificationActionReviewBudget,
                  'Review budget',
                  options: {DarwinNotificationActionOption.foreground},
                ),
                DarwinNotificationAction.plain(
                  kNotificationActionRemindLater,
                  'Remind me later',
                  options: {DarwinNotificationActionOption.foreground},
                ),
              ],
            ),
          ],
        ),
      );
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (response) {
          _publishNotificationResponse(response);
        },
      );
      _initialized = true;
      unawaited(_readLaunchDetails());
    } catch (e, stack) {
      LogService.error(
        _tag,
        'Notification initialization failed: $e',
        e,
        stack,
      );
    }
  }

  void _publishNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    notificationIntentEvents.value = NotificationIntent(
      payload: payload,
      actionId: response.actionId,
    );
  }

  Future<void> _readLaunchDetails() async {
    if (_launchDetailsRead || !_supported) return;
    _launchDetailsRead = true;
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      final response = details?.didNotificationLaunchApp == true
          ? details?.notificationResponse
          : null;
      if (response != null) _publishNotificationResponse(response);
    } catch (e) {
      LogService.warning(_tag, 'Launch notification could not be read: $e');
    }
  }

  Future<bool> hasNotificationPermission() async {
    if (debugPermissionOverride != null) return debugPermissionOverride!;
    try {
      await initialize();
      if (!_supported) return false;
      if (Platform.isAndroid) {
        final implementation = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        // Older Android releases have no runtime notification permission.
        return await implementation?.areNotificationsEnabled() ?? true;
      }
      if (Platform.isIOS) {
        final implementation = _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        return await implementation?.checkPermissions().then(
              (permissions) => permissions?.isEnabled ?? false,
            ) ??
            false;
      }
      return false;
    } catch (e) {
      LogService.warning(_tag, 'Permission status check failed: $e');
      return false;
    }
  }

  Future<void> openNotificationSettings() async {
    try {
      await initialize();
      if (!_supported) return;
      if (Platform.isAndroid) {
        await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.openAppNotificationSettings();
      } else if (Platform.isIOS) {
        await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.openAppNotificationSettings();
      }
    } catch (e) {
      LogService.warning(_tag, 'Could not open notification settings: $e');
    }
  }

  Future<void> hideSensitiveActiveNotifications() async {
    if (!_supported) return;
    try {
      final active = await _plugin.getActiveNotifications();
      for (final notification in active) {
        final id = notification.id;
        if (id == null) continue;
        final payload = notification.payload;
        final channel =
            payload != null && _isSupportedNotificationPayload(payload)
            ? _channelForPayload(payload)
            : id >= 1000000 && id < 1900000 || (id >= 2000 && id < 2020)
            ? _Channel.daily
            : id >= 2000000 && id < 6000000
            ? _Channel.bill
            : id >= 6000000 && id < 6900000
            ? _Channel.planning
            : id >= 8000000 && id < 9000000
            ? _Channel.budget
            : null;
        if (channel == null) continue;
        final (title, body) = switch (channel) {
          _Channel.daily => (
            'Your day, wrapped up 🌙',
            'Your daily money summary is ready. Open EmptyPocket to see it.',
          ),
          _Channel.bill => (
            'Payment reminder',
            'Open EmptyPocket to review your scheduled payment.',
          ),
          _Channel.planning => (
            'Your monthly money check-in',
            'Open EmptyPocket to review your budget and savings plan.',
          ),
          _Channel.budget => (
            'Budget check-in',
            'A budget reached one of your alert levels. Open EmptyPocket to review it.',
          ),
        };
        try {
          await _plugin.show(
            id: id,
            title: title,
            body: body,
            notificationDetails: _details(channel),
            payload: payload,
          );
        } catch (e) {
          LogService.warning(
            _tag,
            'Notification $id could not be redacted: $e',
          );
        }
      }
    } catch (e) {
      LogService.warning(
        _tag,
        'Could not clear financial notification previews: $e',
      );
    }
  }

  Future<bool> requestPermission() async {
    try {
      await initialize();
      if (!_supported) return false;
      if (Platform.isAndroid) {
        final implementation = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        return await implementation?.requestNotificationsPermission() ?? false;
      }
      if (Platform.isIOS) {
        final implementation = _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        return await implementation?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
      return false;
    } catch (e) {
      LogService.warning(_tag, 'Permission request failed: $e');
      return false;
    }
  }

  /// Keeps a rolling window of daily prompts (30 days on Android and seven
  /// on iOS). Each date has a stable randomized time and varied message.
  /// Inexact alarms avoid requiring special exact-alarm access.
  Future<void> scheduleDailyLogReminders() async {
    await initialize();
    if (!_supported) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool(kPrefDailyStreakReminder) ?? true)) {
        await cancelDailyStreakReminder();
        return;
      }
      final remindersPerDay = prefs.getInt(kPrefRoutineReminderFrequency) == 1
          ? 1
          : 3;
      final quietHoursEnabled = prefs.getBool(kPrefQuietHoursEnabled) ?? false;
      final quietStart = _validMinute(
        prefs.getInt(kPrefQuietHoursStart),
        22 * 60 + 30,
      );
      final quietEnd = _validMinute(
        prefs.getInt(kPrefQuietHoursEnd),
        7 * 60 + 30,
      );
      final now = tz.TZDateTime.now(tz.local);
      final windowStart =
          '${_dateKey(DateTime(now.year, now.month, now.day))}|$remindersPerDay|$quietHoursEnabled|$quietStart|$quietEnd';
      final plans = <_Plan>[];
      for (var offset = 0; offset < _dailyHorizonDays; offset++) {
        final date = DateTime(now.year, now.month, now.day + offset);
        _addDailyPlan(
          plans,
          date,
          offset,
          0,
          'Good morning ☀️',
          _morningMessages,
          8 * 60,
          8 * 60 + 30,
          quietHoursEnabled: quietHoursEnabled,
          quietStartMinute: quietStart,
          quietEndMinute: quietEnd,
        );
        if (remindersPerDay > 1) {
          _addDailyPlan(
            plans,
            date,
            offset,
            1,
            'Afternoon check-in',
            _afternoonMessages,
            12 * 60,
            14 * 60,
            quietHoursEnabled: quietHoursEnabled,
            quietStartMinute: quietStart,
            quietEndMinute: quietEnd,
          );
          _addDailyPlan(
            plans,
            date,
            offset,
            2,
            'Evening expense check-in',
            _eveningMessages,
            17 * 60,
            19 * 60,
            quietHoursEnabled: quietHoursEnabled,
            quietStartMinute: quietStart,
            quietEndMinute: quietEnd,
          );
        }
      }
      await _serial(() async {
        if (_dailyWindowStart == windowStart) return;
        await _safeCancel(streakNotificationId);
        final ok = await _replaceGroup('daily:', plans);
        if (ok) {
          _dailyWindowStart = windowStart;
        } else {
          _dailyWindowStart = null;
        }
      });
    } catch (e, stack) {
      LogService.error(
        _tag,
        'Daily reminders could not be scheduled: $e',
        e,
        stack,
      );
    }
  }

  /// Schedules a 10 PM total for each day in the rolling window. Changes to
  /// transactions refresh these totals, including shared expense net shares.
  Future<void> scheduleDailySummaries(
    List<TransactionEntity> transactions,
  ) async {
    await initialize();
    if (!_supported) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final hideAmounts = prefs.getBool(kPrefHideNotificationAmounts) ?? false;
      final quietHoursEnabled = prefs.getBool(kPrefQuietHoursEnabled) ?? false;
      final quietStart = _validMinute(
        prefs.getInt(kPrefQuietHoursStart),
        22 * 60 + 30,
      );
      final quietEnd = _validMinute(
        prefs.getInt(kPrefQuietHoursEnd),
        7 * 60 + 30,
      );
      if (!(prefs.getBool(kPrefDailyStreakReminder) ?? true)) {
        await _serial(() async {
          await _replaceGroup('daily_summary:', const []);
          _dailySummarySignature = null;
        });
        return;
      }
      final now = tz.TZDateTime.now(tz.local);
      final signature =
          '${_transactionSignature(transactions)}|${CurrencyFormatter.activeCurrency.code}|$hideAmounts|$quietHoursEnabled|$quietStart|$quietEnd|${_dateKey(DateTime(now.year, now.month, now.day))}';
      final plans = <_Plan>[];
      for (var offset = 0; offset < _dailyHorizonDays; offset++) {
        final date = DateTime(now.year, now.month, now.day + offset);
        final atTen = _localTime(date, 22, 0);
        if (!atTen.isAfter(now)) continue;
        if (_isInsideQuietHours(
          atTen,
          enabled: quietHoursEnabled,
          startMinute: quietStart,
          endMinute: quietEnd,
        )) {
          continue;
        }
        var expenses = 0.0;
        var income = 0.0;
        for (final transaction in transactions) {
          final transactionDate = transaction.date.toLocal();
          if (transactionDate.year != date.year ||
              transactionDate.month != date.month ||
              transactionDate.day != date.day) {
            continue;
          }
          if (transaction.type == TransactionType.expense) {
            final amount = transaction.netPersonalAmount;
            if (amount.isFinite && amount > 0) expenses += amount;
          } else if (transaction.type == TransactionType.income &&
              transaction.amount.isFinite &&
              transaction.amount > 0) {
            income += transaction.amount;
          }
        }
        final key = _dateKey(date);
        plans.add(
          _Plan(
            id: _id('summary:$key', 1000000, 900000),
            title: 'Your day, wrapped up 🌙',
            body: hideAmounts
                ? 'Your daily money summary is ready. Open EmptyPocket to see it.'
                : 'Spent: ${_money(expenses)}  •  Income: ${_money(income)}',
            date: atTen,
            payload: 'daily_summary:$key',
            channel: _Channel.daily,
          ),
        );
      }
      await _serial(() async {
        if (_dailySummarySignature == signature) return;
        final ok = await _replaceGroup('daily_summary:', plans);
        if (ok) {
          _dailySummarySignature = signature;
        } else {
          _dailySummarySignature = null;
        }
      });
    } catch (e, stack) {
      LogService.error(
        _tag,
        'Daily summaries could not be scheduled: $e',
        e,
        stack,
      );
    }
  }

  /// Kept for existing callers; now schedules the new daily routine.
  Future<void> scheduleDailyStreakReminder({int hour = 8, int minute = 0}) =>
      scheduleDailyLogReminders();

  Future<void> cancelDailyStreakReminder() async {
    if (!_supported) return;
    try {
      await _serial(() async {
        await _safeCancel(streakNotificationId);
        await _cancelGroup('daily:');
        await _cancelGroup('daily_summary:');
        await _cancelGroup('snooze:daily:');
        await _cancelGroup('snooze:daily_summary:');
        _dailyWindowStart = null;
        _dailySummarySignature = null;
      });
    } catch (e) {
      LogService.error(_tag, 'Daily reminders could not be cancelled: $e');
    }
  }

  Future<void> scheduleRecurringPaymentReminders(
    List<RecurringExpenseEntity> items,
  ) async {
    await initialize();
    if (!_supported) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final hideAmounts = prefs.getBool(kPrefHideNotificationAmounts) ?? false;
      if (!(prefs.getBool(kPrefBillDueAlert) ?? true)) {
        await cancelBillDueAlerts();
        return;
      }
      final now = tz.TZDateTime.now(tz.local);
      final signatureValues =
          items
              .where((item) => item.isActive)
              .map(
                (item) =>
                    '${item.id}:${_dateKey(item.nextDueDate)}:${item.title}:${item.amount}',
              )
              .toList()
            ..sort();
      final signature =
          '${CurrencyFormatter.activeCurrency.code}|$hideAmounts|${_dateKey(DateTime(now.year, now.month, now.day))}|${signatureValues.join('|')}';
      final plans = <_Plan>[];
      final overdueCatchUps = <({String markerKey, _Plan plan})>[];
      final activeBills = items.where((item) => item.isActive).toList()
        ..sort((left, right) => left.nextDueDate.compareTo(right.nextDueDate));
      // iOS retains at most 64 pending local notifications. Daily and monthly
      // schedules use most of that budget, so keep the nearest ten bills there.
      final billsToSchedule = Platform.isIOS
          ? activeBills.take(10)
          : activeBills;
      for (final bill in billsToSchedule) {
        final due = bill.nextDueDate;
        final dueDate = DateTime(due.year, due.month, due.day);
        final dateKey = _dateKey(dueDate);
        final label = bill.title.trim().isEmpty
            ? 'Recurring payment'
            : bill.title;
        final amount = _money(bill.amount);
        final events = <(String, DateTime, int, String, String)>[
          (
            'before',
            DateTime(due.year, due.month, due.day - 2),
            10,
            'Upcoming payment: $label',
            '$amount is due in two days (${DateFormat('d MMM').format(dueDate)}).',
          ),
          (
            'due',
            dueDate,
            9,
            'Payment due today: $label',
            '$amount is scheduled for today. If it was auto-paid, remember to log it.',
          ),
          (
            'overdue',
            DateTime(due.year, due.month, due.day + 1),
            10,
            'Was $label paid?',
            'The due date has passed. Log the payment if it was made, or review it in EmptyPocket.',
          ),
        ];
        for (final event in events) {
          final (kind, date, hour, title, body) = event;
          final at = _localTime(date, hour, 0);
          if (!at.isAfter(now)) continue;
          final payload = 'bill:${Uri.encodeComponent(bill.id)}:$dateKey:$kind';
          plans.add(
            _Plan(
              id: _id(payload, 2000000, 4000000),
              title: hideAmounts ? 'Upcoming payment reminder' : title,
              body: hideAmounts
                  ? 'Open EmptyPocket to review your scheduled payment.'
                  : body,
              date: at,
              payload: payload,
              channel: _Channel.bill,
            ),
          );
        }

        final overdueDate = DateTime(due.year, due.month, due.day + 1);
        final overdueTime = _localTime(overdueDate, 10, 0);
        if (!overdueTime.isAfter(now)) {
          final markerId = _id('${bill.id}:$dateKey', 0, 2000000000);
          final markerKey = 'notifications_bill_overdue_catchup_$markerId';
          final payload =
              'bill:${Uri.encodeComponent(bill.id)}:$dateKey:overdue_catchup';
          overdueCatchUps.add((
            markerKey: markerKey,
            plan: _Plan(
              id: _id(payload, 2000000, 4000000),
              title: hideAmounts ? 'Payment follow-up' : 'Was $label paid?',
              body: hideAmounts
                  ? 'A scheduled payment may be overdue. Open EmptyPocket to review it.'
                  : 'The due date has passed. Log the payment if it was made, or review it in EmptyPocket.',
              date: now,
              payload: payload,
              channel: _Channel.bill,
            ),
          ));
        }
      }
      await _serial(() async {
        if (_billSignature == signature) return;
        for (var i = 0; i < 20; i++) {
          await _safeCancel(billNotificationIdBase + i);
        }
        final ok = await _replaceGroup('bill:', plans);
        for (final candidate in overdueCatchUps) {
          if (prefs.getBool(candidate.markerKey) ?? false) continue;
          try {
            await _plugin.show(
              id: candidate.plan.id,
              title: candidate.plan.title,
              body: candidate.plan.body,
              notificationDetails: _details(candidate.plan.channel),
              payload: candidate.plan.payload,
            );
            await prefs.setBool(candidate.markerKey, true);
          } catch (e) {
            LogService.warning(_tag, 'Overdue catch-up could not be shown: $e');
          }
        }
        if (ok) {
          _billSignature = signature;
        } else {
          _billSignature = null;
        }
      });
    } catch (e, stack) {
      LogService.error(
        _tag,
        'Recurring reminders could not be scheduled: $e',
        e,
        stack,
      );
    }
  }

  /// Compatibility entry point: bills are scheduled ahead of their due dates.
  Future<void> checkAndNotifyBillsDueToday(
    List<RecurringExpenseEntity> items,
  ) => scheduleRecurringPaymentReminders(items);

  Future<void> showBillDueNotification({
    int notificationId = billNotificationIdBase,
    required String title,
    required String body,
  }) async {
    await initialize();
    if (!_supported) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final hideAmounts = prefs.getBool(kPrefHideNotificationAmounts) ?? false;
      await _plugin.show(
        id: notificationId,
        title: hideAmounts ? 'Payment reminder' : title,
        body: hideAmounts
            ? 'Open EmptyPocket to review your scheduled payment.'
            : body,
        notificationDetails: _details(_Channel.bill),
      );
    } catch (e) {
      LogService.error(_tag, 'Bill notification could not be shown: $e');
    }
  }

  Future<void> cancelBillDueAlerts() async {
    if (!_supported) return;
    try {
      await _serial(() async {
        for (var i = 0; i < 20; i++) {
          await _safeCancel(billNotificationIdBase + i);
        }
        await _cancelGroup('bill:');
        await _cancelGroup('snooze:bill:');
        _billSignature = null;
      });
    } catch (e) {
      LogService.error(_tag, 'Bill notifications could not be cancelled: $e');
    }
  }

  Future<void> scheduleMonthlyMoneyCheckIns({
    required List<BudgetEntity> budgets,
    required List<SavingsGoalEntity> goals,
  }) async {
    await initialize();
    if (!_supported) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final hideAmounts = prefs.getBool(kPrefHideNotificationAmounts) ?? false;
      if (!(prefs.getBool(kPrefMonthlyMoneyCheckIn) ?? true)) {
        await cancelMonthlyMoneyCheckIns();
        return;
      }
      final activeGoals = goals
          .where(
            (goal) => goal.status == GoalStatus.active && !goal.isCompleted,
          )
          .toList();
      final now = tz.TZDateTime.now(tz.local);
      final signatureValues = <String>[
        ...budgets.map(
          (budget) =>
              '${budget.id}:${_dateKey(budget.month)}:${budget.limitAmount}',
        ),
        ...activeGoals.map(
          (goal) =>
              '${goal.id}:${goal.title}:${goal.currentAmount}:${goal.targetAmount}',
        ),
      ]..sort();
      final signature =
          '${_dateKey(DateTime(now.year, now.month, 1))}|$hideAmounts|${signatureValues.join('|')}';
      final plans = <_Plan>[];
      if (budgets.isNotEmpty || activeGoals.isNotEmpty) {
        for (var offset = 0; offset < _monthlyHorizonMonths; offset++) {
          final first = DateTime(now.year, now.month + offset, 1);
          final last = DateTime(now.year, now.month + offset + 1, 0);
          final startMinute = _randomMinute(first, 8 * 60, 10 * 60, 11);
          final endMinute = _randomMinute(last, 18 * 60, 20 * 60, 29);
          final monthBudgets = budgets
              .where(
                (budget) =>
                    budget.month.year == first.year &&
                    budget.month.month == first.month,
              )
              .toList();
          final goalTitle = activeGoals.isEmpty
              ? null
              : activeGoals.first.title;
          final monthName = DateFormat('MMMM').format(first);
          String startBody;
          if (monthBudgets.isNotEmpty && goalTitle != null) {
            startBody =
                'Review your ${monthBudgets.length} budget${monthBudgets.length == 1 ? '' : 's'} and plan a contribution to $goalTitle.';
          } else if (monthBudgets.isNotEmpty) {
            startBody =
                'Review your ${monthBudgets.length} budget${monthBudgets.length == 1 ? '' : 's'} and set a spending plan for $monthName.';
          } else if (goalTitle != null) {
            startBody =
                'Make a small contribution to $goalTitle or transfer money toward your savings goal.';
          } else {
            startBody = 'Set up or review your budgets for $monthName.';
          }
          final endBody = goalTitle != null
              ? 'Check this month’s spending and add a little more to $goalTitle if you can.'
              : monthBudgets.isNotEmpty
              ? 'Review this month’s budgets and plan for the next one.'
              : 'Check this month’s spending and plan any budgets for next month.';
          final firstKey = _dateKey(first);
          final lastKey = _dateKey(last);
          final firstPayload = 'monthly:$firstKey:plan';
          final lastPayload = 'monthly:$lastKey:review';
          final firstAt = _localTime(
            first,
            startMinute ~/ 60,
            startMinute % 60,
          );
          if (firstAt.isAfter(now)) {
            plans.add(
              _Plan(
                id: _id(firstPayload, 6000000, 900000),
                title: hideAmounts
                    ? 'Your monthly money check-in'
                    : 'A fresh month, a clear plan',
                body: hideAmounts
                    ? 'Open EmptyPocket to review your budget and savings plan.'
                    : startBody,
                date: firstAt,
                payload: firstPayload,
                channel: _Channel.planning,
              ),
            );
          }
          final lastAt = _localTime(last, endMinute ~/ 60, endMinute % 60);
          if (lastAt.isAfter(now)) {
            plans.add(
              _Plan(
                id: _id(lastPayload, 6000000, 900000),
                title: hideAmounts
                    ? 'Your monthly money check-in'
                    : 'Your month-end money check',
                body: hideAmounts
                    ? 'Open EmptyPocket to review this month and plan ahead.'
                    : endBody,
                date: lastAt,
                payload: lastPayload,
                channel: _Channel.planning,
              ),
            );
          }
        }
      }
      await _serial(() async {
        if (_monthlySignature == signature) return;
        final ok = await _replaceGroup('monthly:', plans);
        if (ok) {
          _monthlySignature = signature;
        } else {
          _monthlySignature = null;
        }
      });
    } catch (e, stack) {
      LogService.error(
        _tag,
        'Monthly check-ins could not be scheduled: $e',
        e,
        stack,
      );
    }
  }

  Future<void> cancelMonthlyMoneyCheckIns() async {
    if (!_supported) return;
    try {
      await _serial(() async {
        await _cancelGroup('monthly:');
        await _cancelGroup('snooze:monthly:');
        _monthlySignature = null;
      });
    } catch (e) {
      LogService.error(_tag, 'Monthly check-ins could not be cancelled: $e');
    }
  }

  /// Sends one heads-up at the selected approach threshold and one at 100%,
  /// at most once per budget and month for each milestone.
  Future<void> updateBudgetThresholdAlerts({
    required List<BudgetEntity> budgets,
    required List<TransactionEntity> transactions,
  }) async {
    await initialize();
    if (!_supported) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool(kPrefBudgetAlertsEnabled) ?? false)) return;
      if (!await hasNotificationPermission()) return;
      final threshold = switch (prefs.getInt(kPrefBudgetAlertThreshold)) {
        70 => 70,
        90 => 90,
        _ => 80,
      };
      final hideAmounts = prefs.getBool(kPrefHideNotificationAmounts) ?? false;
      final now = tz.TZDateTime.now(tz.local);

      for (final budget in budgets) {
        if (budget.month.year != now.year ||
            budget.month.month != now.month ||
            !budget.limitAmount.isFinite ||
            budget.limitAmount <= 0) {
          continue;
        }
        var spent = 0.0;
        for (final transaction in transactions) {
          final date = transaction.date.toLocal();
          if (transaction.type != TransactionType.expense ||
              date.year != budget.month.year ||
              date.month != budget.month.month ||
              transaction.category.trim().toLowerCase() !=
                  budget.category.trim().toLowerCase() ||
              (budget.accountId != null &&
                  transaction.accountId != budget.accountId)) {
            continue;
          }
          final personalAmount = transaction.netPersonalAmount;
          if (personalAmount.isFinite && personalAmount > 0) {
            spent += personalAmount;
          }
        }
        if (!spent.isFinite || spent <= 0) continue;

        final percentage = spent / budget.limitAmount * 100;
        final milestones = <(int, String)>[
          (threshold, 'approaching'),
          (100, 'reached'),
        ];
        for (final (milestone, status) in milestones) {
          if (percentage < milestone ||
              (status == 'approaching' && threshold >= 100)) {
            continue;
          }
          final monthKey =
              '${budget.month.year.toString().padLeft(4, '0')}-${budget.month.month.toString().padLeft(2, '0')}';
          final marker =
              'notifications_budget_${budget.id}_${monthKey}_$status';
          if (prefs.getBool(marker) ?? false) continue;
          final payload = 'budget:${budget.id}:$monthKey:$status';
          final title = hideAmounts
              ? 'Budget check-in'
              : status == 'reached'
              ? '${budget.category} budget reached'
              : '${budget.category} budget is nearly used';
          final body = hideAmounts
              ? 'A budget reached one of your alert levels. Open EmptyPocket to review it.'
              : status == 'reached'
              ? 'You have used ${percentage.toStringAsFixed(0)}% of this month’s ${budget.category} budget. Review your spending in EmptyPocket.'
              : 'You have used ${percentage.toStringAsFixed(0)}% of this month’s ${budget.category} budget. You asked to be notified at $milestone%.';
          try {
            await _plugin.show(
              id: _id(payload, 8000000, 1000000),
              title: title,
              body: body,
              notificationDetails: _details(_Channel.budget),
              payload: payload,
            );
            await prefs.setBool(marker, true);
          } catch (e, stack) {
            LogService.error(
              _tag,
              'Budget milestone notification failed for ${budget.id}: $e',
              e,
              stack,
            );
          }
        }
      }
    } catch (e, stack) {
      LogService.error(
        _tag,
        'Budget alerts could not be updated: $e',
        e,
        stack,
      );
    }
  }

  Future<void> cancelBudgetAlertReminders() async {
    if (!_supported) return;
    try {
      await _serial(() => _cancelGroup('snooze:budget:'));
    } catch (e) {
      LogService.error(_tag, 'Budget alert snoozes could not be cancelled: $e');
    }
  }

  Future<bool> scheduleRemindLater(String originalPayload) async {
    await initialize();
    if (!_supported || !_isSupportedNotificationPayload(originalPayload)) {
      return false;
    }
    try {
      final payload = 'snooze:$originalPayload';
      final channel = _channelForPayload(originalPayload);
      if (!await hasNotificationPermission()) return false;
      final prefs = await SharedPreferences.getInstance();
      final enabled = switch (channel) {
        _Channel.daily => prefs.getBool(kPrefDailyStreakReminder) ?? true,
        _Channel.bill => prefs.getBool(kPrefBillDueAlert) ?? true,
        _Channel.planning => prefs.getBool(kPrefMonthlyMoneyCheckIn) ?? true,
        _Channel.budget => prefs.getBool(kPrefBudgetAlertsEnabled) ?? false,
      };
      if (!enabled) return false;
      final hideAmounts = prefs.getBool(kPrefHideNotificationAmounts) ?? false;
      final title = switch (channel) {
        _Channel.bill => 'Payment reminder',
        _Channel.budget => 'Budget check-in',
        _Channel.planning => 'Money check-in',
        _Channel.daily => 'Expense check-in',
      };
      final body = switch (channel) {
        _Channel.bill =>
          hideAmounts
              ? 'Open EmptyPocket to review your scheduled payment.'
              : 'Here’s the payment reminder you asked to revisit.',
        _Channel.budget => 'Here’s the budget reminder you asked to revisit.',
        _Channel.planning => 'Here’s the money check-in you asked to revisit.',
        _Channel.daily => 'Here’s the expense reminder you asked to revisit.',
      };
      var at = tz.TZDateTime.now(tz.local).add(const Duration(hours: 1));
      if (channel == _Channel.daily) {
        final quietHoursEnabled =
            prefs.getBool(kPrefQuietHoursEnabled) ?? false;
        final quietStart = _validMinute(
          prefs.getInt(kPrefQuietHoursStart),
          22 * 60 + 30,
        );
        final quietEnd = _validMinute(
          prefs.getInt(kPrefQuietHoursEnd),
          7 * 60 + 30,
        );
        if (_isInsideQuietHours(
          at,
          enabled: quietHoursEnabled,
          startMinute: quietStart,
          endMinute: quietEnd,
        )) {
          at = _nextQuietHoursEnd(at, quietStart, quietEnd);
        }
      }
      var scheduled = false;
      await _serial(() async {
        // Repeated taps reset this reminder instead of filling the queue.
        await _cancelGroup(payload);
        if (Platform.isIOS) {
          final pending = (await _plugin.pendingNotificationRequests())
              .toList();
          while (pending.length >= 64) {
            final routinePrompts =
                pending
                    .where(
                      (request) =>
                          request.payload?.startsWith('daily:') == true,
                    )
                    .toList()
                  ..sort(
                    (left, right) => right.payload!.compareTo(left.payload!),
                  );
            final toCancel = routinePrompts.isNotEmpty
                ? routinePrompts.first
                : pending.last;
            await _safeCancel(toCancel.id);
            pending.removeWhere((request) => request.id == toCancel.id);
          }
        }
        await _plugin.zonedSchedule(
          id: _id('$payload:${at.millisecondsSinceEpoch}', 9000000, 900000000),
          title: title,
          body: body,
          scheduledDate: at,
          notificationDetails: _details(channel),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: payload,
        );
        scheduled = true;
      });
      return scheduled;
    } catch (e, stack) {
      LogService.error(
        _tag,
        'Could not schedule a reminder snooze: $e',
        e,
        stack,
      );
      return false;
    }
  }

  Future<void> sendTestNotification() async {
    await initialize();
    if (!_supported) return;
    try {
      await _plugin.show(
        id: testNotificationId,
        title: 'EmptyPocket notifications are on',
        body: 'Daily reminders and payment alerts can appear on this device.',
        notificationDetails: _details(_Channel.daily),
      );
    } catch (e) {
      LogService.error(_tag, 'Test notification could not be sent: $e');
    }
  }

  Future<bool> scheduleTestDelayedNotification({int seconds = 10}) async {
    await initialize();
    if (!_supported) return false;
    try {
      final safeSeconds = seconds.clamp(1, 3600).toInt();
      var canUseExactAlarm = false;
      if (Platform.isAndroid) {
        final implementation = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        canUseExactAlarm =
            await implementation?.canScheduleExactNotifications() ?? false;
      }
      await _plugin.zonedSchedule(
        id: testNotificationId,
        title: 'Scheduled test notification',
        body: 'This notification was scheduled $safeSeconds seconds ago.',
        scheduledDate: tz.TZDateTime.now(tz.local)
            .add(Duration(seconds: safeSeconds)),
        notificationDetails: _details(_Channel.daily),
        androidScheduleMode: canUseExactAlarm
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'test:delayed',
      );
      return true;
    } catch (e, stack) {
      LogService.error(
        _tag,
        'Delayed test could not be scheduled: $e',
        e,
        stack,
      );
      return false;
    }
  }

  void _addDailyPlan(
    List<_Plan> plans,
    DateTime date,
    int dayOffset,
    int slot,
    String title,
    List<String> messages,
    int fromMinute,
    int untilMinute, {
    required bool quietHoursEnabled,
    required int quietStartMinute,
    required int quietEndMinute,
  }) {
    final minute = _randomMinute(date, fromMinute, untilMinute, slot * 101 + 7);
    final at = _localTime(date, minute ~/ 60, minute % 60);
    if (!at.isAfter(tz.TZDateTime.now(tz.local))) return;
    if (_isInsideQuietHours(
      at,
      enabled: quietHoursEnabled,
      startMinute: quietStartMinute,
      endMinute: quietEndMinute,
    )) {
      return;
    }
    var index = Random(_seed(date, 1009 + slot)).nextInt(messages.length);
    if (dayOffset > 0) {
      final yesterday = DateTime(date.year, date.month, date.day - 1);
      if (index ==
          Random(_seed(yesterday, 1009 + slot)).nextInt(messages.length)) {
        index = (index + 1) % messages.length;
      }
    }
    final payload = 'daily:${_dateKey(date)}:$slot';
    plans.add(
      _Plan(
        id: _id(payload, 100000, 800000),
        title: title,
        body: messages[index],
        date: at,
        payload: payload,
        channel: _Channel.daily,
      ),
    );
  }

  int _randomMinute(DateTime date, int start, int end, int salt) =>
      start + Random(_seed(date, salt)).nextInt(end - start + 1);

  int _seed(DateTime date, int salt) =>
      (date.year * 1000003 + date.month * 10007 + date.day * 101 + salt) &
      0x7fffffff;

  tz.TZDateTime _localTime(DateTime date, int hour, int minute) =>
      tz.TZDateTime(tz.local, date.year, date.month, date.day, hour, minute);

  bool _isInsideQuietHours(
    DateTime date, {
    required bool enabled,
    required int startMinute,
    required int endMinute,
  }) {
    if (!enabled || startMinute == endMinute) return false;
    final minute = date.hour * 60 + date.minute;
    if (startMinute < endMinute) {
      return minute >= startMinute && minute < endMinute;
    }
    return minute >= startMinute || minute < endMinute;
  }

  tz.TZDateTime _nextQuietHoursEnd(
    tz.TZDateTime date,
    int startMinute,
    int endMinute,
  ) {
    var endDate = DateTime(date.year, date.month, date.day);
    if (startMinute > endMinute &&
        date.hour * 60 + date.minute >= startMinute) {
      endDate = DateTime(date.year, date.month, date.day + 1);
    }
    var end = _localTime(endDate, endMinute ~/ 60, endMinute % 60);
    if (!end.isAfter(date)) {
      endDate = DateTime(endDate.year, endDate.month, endDate.day + 1);
      end = _localTime(endDate, endMinute ~/ 60, endMinute % 60);
    }
    return end;
  }

  bool _isSupportedNotificationPayload(String payload) {
    final normalized = payload.startsWith('snooze:')
        ? payload.substring('snooze:'.length)
        : payload;
    return normalized.startsWith('daily:') ||
        normalized.startsWith('daily_summary:') ||
        normalized.startsWith('bill:') ||
        normalized.startsWith('monthly:') ||
        normalized.startsWith('budget:');
  }

  _Channel _channelForPayload(String payload) {
    final normalized = payload.startsWith('snooze:')
        ? payload.substring('snooze:'.length)
        : payload;
    if (normalized.startsWith('bill:')) return _Channel.bill;
    if (normalized.startsWith('budget:')) return _Channel.budget;
    if (normalized.startsWith('monthly:')) return _Channel.planning;
    return _Channel.daily;
  }

  String _money(double amount) {
    try {
      return CurrencyFormatter.format(amount);
    } catch (_) {
      return amount.toStringAsFixed(2);
    }
  }

  String _transactionSignature(List<TransactionEntity> transactions) {
    final values =
        transactions
            .map(
              (transaction) =>
                  '${transaction.id}:${transaction.date.millisecondsSinceEpoch}:${transaction.type.name}:${transaction.amount}:${transaction.myShareAmount}:${transaction.reimbursedAmount}',
            )
            .toList()
          ..sort();
    return values.join('|');
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @visibleForTesting
  bool isInsideQuietHours(
    DateTime date, {
    required bool enabled,
    required int startMinute,
    required int endMinute,
  }) => _isInsideQuietHours(
    date,
    enabled: enabled,
    startMinute: startMinute,
    endMinute: endMinute,
  );

  @visibleForTesting
  tz.TZDateTime nextQuietHoursEnd(
    tz.TZDateTime date,
    int startMinute,
    int endMinute,
  ) => _nextQuietHoursEnd(date, startMinute, endMinute);

  @visibleForTesting
  bool isSupportedNotificationPayload(String payload) =>
      _isSupportedNotificationPayload(payload);

  @visibleForTesting
  int idForPayload(String value, int base, int range) =>
      _id(value, base, range);

  @visibleForTesting
  String dateKey(DateTime date) => _dateKey(date);

  int _id(String value, int base, int range) {
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode(value)) {
      hash = ((hash ^ byte) * 0x01000193) & 0x7fffffff;
    }
    return base + hash % range;
  }

  NotificationDetails _details(_Channel channel) {
    final values = switch (channel) {
      _Channel.daily => (
        streakChannelId,
        streakChannelName,
        streakChannelDesc,
        Importance.defaultImportance,
        Priority.defaultPriority,
      ),
      _Channel.bill => (
        billChannelId,
        billChannelName,
        billChannelDesc,
        Importance.high,
        Priority.high,
      ),
      _Channel.planning => (
        planningChannelId,
        planningChannelName,
        planningChannelDesc,
        Importance.defaultImportance,
        Priority.defaultPriority,
      ),
      _Channel.budget => (
        budgetChannelId,
        budgetChannelName,
        budgetChannelDesc,
        Importance.high,
        Priority.high,
      ),
    };
    final actions = switch (channel) {
      _Channel.daily => [
        const AndroidNotificationAction(
          kNotificationActionLogExpense,
          'Log expense',
          showsUserInterface: true,
        ),
        const AndroidNotificationAction(
          kNotificationActionRemindLater,
          'Remind me later',
          showsUserInterface: true,
        ),
      ],
      _Channel.bill => [
        const AndroidNotificationAction(
          kNotificationActionMarkBillPaid,
          'Mark bill paid',
          showsUserInterface: true,
        ),
        const AndroidNotificationAction(
          kNotificationActionRemindLater,
          'Remind me later',
          showsUserInterface: true,
        ),
      ],
      _Channel.budget => [
        const AndroidNotificationAction(
          kNotificationActionReviewBudget,
          'Review budget',
          showsUserInterface: true,
        ),
        const AndroidNotificationAction(
          kNotificationActionRemindLater,
          'Remind me later',
          showsUserInterface: true,
        ),
      ],
      _Channel.planning => [
        const AndroidNotificationAction(
          kNotificationActionReviewBudget,
          'Review',
          showsUserInterface: true,
        ),
      ],
    };
    final categoryIdentifier = switch (channel) {
      _Channel.daily => 'empty_pocket_daily_actions',
      _Channel.bill => 'empty_pocket_bill_actions',
      _Channel.budget => 'empty_pocket_budget_actions',
      _Channel.planning => null,
    };
    return NotificationDetails(
      android: AndroidNotificationDetails(
        values.$1,
        values.$2,
        channelDescription: values.$3,
        importance: values.$4,
        priority: values.$5,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        actions: actions,
        visibility: NotificationVisibility.private,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        categoryIdentifier: categoryIdentifier,
      ),
    );
  }

  Future<bool> _replaceGroup(String prefix, List<_Plan> plans) async {
    List<PendingNotificationRequest> pending = const [];
    try {
      pending = await _plugin.pendingNotificationRequests();
    } catch (e) {
      LogService.warning(_tag, 'Could not inspect pending notifications: $e');
    }
    final otherNotifications = pending
        .where((request) => request.payload?.startsWith(prefix) != true)
        .length;
    final availableSlots = Platform.isIOS
        ? (64 - otherNotifications).clamp(0, 64).toInt()
        : plans.length;
    final schedulablePlans = [...plans]
      ..sort((left, right) => left.date.compareTo(right.date));
    final selectedPlans = schedulablePlans.take(availableSlots).toList();
    final keep = selectedPlans.map((plan) => plan.id).toSet();
    for (final request in pending) {
      if (request.payload?.startsWith(prefix) == true &&
          !keep.contains(request.id)) {
        await _safeCancel(request.id);
      }
    }
    var allSucceeded = true;
    for (final plan in selectedPlans) {
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          await _plugin.zonedSchedule(
            id: plan.id,
            title: plan.title,
            body: plan.body,
            scheduledDate: plan.date,
            notificationDetails: _details(plan.channel),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            payload: plan.payload,
          );
          break;
        } catch (e, stack) {
          if (attempt == 0) {
            continue;
          }
          allSucceeded = false;
          // If replacement failed, evict the stale pending notification with this ID
          // to prevent delivering stale or unredacted content later.
          await _safeCancel(plan.id);
          LogService.error(
            _tag,
            'Could not schedule ${plan.payload} after retry; evicted stale pending ID ${plan.id}: $e',
            e,
            stack,
          );
        }
      }
    }
    return allSucceeded;
  }

  Future<void> _cancelGroup(String prefix) async {
    List<PendingNotificationRequest> pending = const [];
    try {
      pending = await _plugin.pendingNotificationRequests();
    } catch (e) {
      LogService.warning(
        _tag,
        'Could not inspect pending notifications for cancel: $e',
      );
    }
    for (final request in pending) {
      if (request.payload?.startsWith(prefix) == true) {
        await _safeCancel(request.id);
      }
    }
  }

  Future<void> _safeCancel(int id) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await _plugin.cancel(id: id);
        return;
      } catch (e) {
        if (attempt == 0) continue;
        LogService.warning(
          _tag,
          'Could not cancel notification $id after retry: $e',
        );
      }
    }
  }

  Future<void> _serial(Future<void> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.catchError((Object error, StackTrace stack) {
      LogService.error(_tag, 'Notification scheduling failed: $error');
    });
    return result;
  }
}

enum _Channel { daily, bill, planning, budget }

class _Plan {
  final int id;
  final String title;
  final String body;
  final tz.TZDateTime date;
  final String payload;
  final _Channel channel;

  const _Plan({
    required this.id,
    required this.title,
    required this.body,
    required this.date,
    required this.payload,
    required this.channel,
  });
}
