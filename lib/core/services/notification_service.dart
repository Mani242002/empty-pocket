import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../domain/entities/recurring_expense_entity.dart';
import '../utilities/currency_formatter.dart';
import 'log_service.dart';

/// Preferences keys
const String kPrefDailyStreakReminder = 'notifications_daily_streak_enabled';
const String kPrefBillDueAlert = 'notifications_bill_due_enabled';

/// StateNotifier for Daily Streak Reminder toggle
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
      LogService.error('DailyStreakReminderNotifier', 'Failed to update streak pref: $e');
    }
  }
}

/// StateNotifier for Bill Due Alerts toggle
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
      final service = _ref.read(notificationServiceProvider);
      if (!enabled) {
        await service.cancelBillDueAlerts();
      }
    } catch (e) {
      LogService.error('BillDueAlertNotifier', 'Failed to update bill alert pref: $e');
    }
  }
}

/// Singleton Provider for NotificationService
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService.instance;
});

class NotificationService {
  static const String _tag = 'NotificationService';
  static final NotificationService instance = NotificationService._internal();

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  bool get _isSupportedPlatform {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  static const int streakNotificationId = 1001;
  static const int billNotificationIdBase = 2000;
  static const int testNotificationId = 9999;

  static const String streakChannelId = 'emptypocket_streak_reminders';
  static const String streakChannelName = 'Daily Streak Reminders';
  static const String streakChannelDesc =
      'Reminders to log daily expenses and preserve your tracking streak';

  static const String billChannelId = 'emptypocket_bill_alerts';
  static const String billChannelName = 'Bill Due Alerts';
  static const String billChannelDesc =
      'Notifications when recurring bills, subscriptions, and EMIs are due';

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize timezone database
      tz_data.initializeTimeZones();
      try {
        final tzInfo = await FlutterTimezone.getLocalTimezone();
        final String timeZoneName = tzInfo.identifier;
        tz.setLocalLocation(tz.getLocation(timeZoneName));
        LogService.debug(_tag, 'Notification local timezone configured: $timeZoneName');
      } catch (e) {
        LogService.debug(_tag, 'Could not determine local timezone via FlutterTimezone: $e');
      }

      if (!_isSupportedPlatform) {
        LogService.debug(_tag, 'NotificationService skipped on unsupported/test platform.');
        _isInitialized = true;
        return;
      }

      // Configure Android initialization settings
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);

      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (response) {
          LogService.debug(_tag, 'Notification tapped: ${response.payload}');
        },
      );

      _isInitialized = true;
      LogService.debug(_tag, 'NotificationService initialized successfully.');
    } catch (e, stack) {
      LogService.error(_tag, 'NotificationService init failed (graceful fallback): $e', e, stack);
    }
  }

  /// Request runtime permission (Android 13+)
  Future<bool> requestPermission() async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final androidImplementation = _notificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        final granted = await androidImplementation?.requestNotificationsPermission();
        return granted ?? false;
      }
      return true;
    } catch (e) {
      LogService.debug(_tag, 'Permission request error: $e');
      return false;
    }
  }

  /// Schedule the repeating 8:00 PM daily streak prompt
  Future<void> scheduleDailyStreakReminder({int hour = 20, int minute = 0}) async {
    if (!_isInitialized) await initialize();
    if (!_isSupportedPlatform) return;

    try {
      final scheduledTime = _nextInstanceOfTime(hour, minute);

      const androidDetails = AndroidNotificationDetails(
        streakChannelId,
        streakChannelName,
        channelDescription: streakChannelDesc,
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
      );

      const notificationDetails = NotificationDetails(android: androidDetails);

      await _notificationsPlugin.zonedSchedule(
        id: streakNotificationId,
        title: '🔥 Keep your financial streak alive!',
        body: 'Take 30 seconds to log today\'s expenses and review your budget limits.',
        scheduledDate: scheduledTime,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      LogService.debug(_tag, 'Scheduled daily streak reminder for $hour:$minute repeating daily.');
    } catch (e, stack) {
      LogService.error(_tag, 'Failed to schedule streak reminder: $e', e, stack);
    }
  }

  /// Cancel the daily streak reminder
  Future<void> cancelDailyStreakReminder() async {
    if (!_isSupportedPlatform) return;
    try {
      await _notificationsPlugin.cancel(id: streakNotificationId);
      LogService.debug(_tag, 'Daily streak reminder cancelled.');
    } catch (e) {
      LogService.error(_tag, 'Failed to cancel streak reminder: $e');
    }
  }

  /// Check recurring bills and notify if any are due today
  Future<void> checkAndNotifyBillsDueToday(List<RecurringExpenseEntity> items) async {
    if (!_isInitialized) await initialize();
    if (!_isSupportedPlatform) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(kPrefBillDueAlert) ?? true;
      if (!enabled) return;

      final dueToday = items.where((i) => i.isActive && i.daysUntilDue == 0).toList();
      if (dueToday.isEmpty) return;

      for (int i = 0; i < dueToday.length; i++) {
        final bill = dueToday[i];
        await showBillDueNotification(
          notificationId: billNotificationIdBase + i,
          title: '📅 Bill Due Today: ${bill.title}',
          body: '${CurrencyFormatter.format(bill.amount)} is scheduled for payment today. Tap to view or log.',
        );
      }
    } catch (e) {
      LogService.error(_tag, 'Error checking bills due today: $e');
    }
  }

  /// Display an immediate bill due notification
  Future<void> showBillDueNotification({
    int notificationId = billNotificationIdBase,
    required String title,
    required String body,
  }) async {
    if (!_isInitialized) await initialize();
    if (!_isSupportedPlatform) return;

    try {
      const androidDetails = AndroidNotificationDetails(
        billChannelId,
        billChannelName,
        channelDescription: billChannelDesc,
        importance: Importance.max,
        priority: Priority.max,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
      );

      const notificationDetails = NotificationDetails(android: androidDetails);

      await _notificationsPlugin.show(
        id: notificationId,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
      );
    } catch (e) {
      LogService.error(_tag, 'Failed to show bill due notification: $e');
    }
  }

  /// Cancel all bill due alerts
  Future<void> cancelBillDueAlerts() async {
    if (!_isSupportedPlatform) return;
    try {
      for (int i = 0; i < 20; i++) {
        await _notificationsPlugin.cancel(id: billNotificationIdBase + i);
      }
      LogService.debug(_tag, 'Bill alerts cancelled.');
    } catch (e) {
      LogService.error(_tag, 'Failed to cancel bill alerts: $e');
    }
  }

  /// Send an immediate test notification to verify channel setup
  Future<void> sendTestNotification() async {
    if (!_isInitialized) await initialize();
    if (!_isSupportedPlatform) return;

    try {
      const androidDetails = AndroidNotificationDetails(
        streakChannelId,
        streakChannelName,
        channelDescription: streakChannelDesc,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const notificationDetails = NotificationDetails(android: androidDetails);

      await _notificationsPlugin.show(
        id: testNotificationId,
        title: '✨ EmptyPocket Notifications Active',
        body: 'Daily streak prompts and bill due alerts are properly configured!',
        notificationDetails: notificationDetails,
      );
    } catch (e) {
      LogService.error(_tag, 'Failed to send test notification: $e');
    }
  }

  /// Compute next TZDateTime occurrence for a given hour and minute
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
