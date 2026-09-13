import 'package:empty_pocket/core/domain/entities/recurring_expense_entity.dart';
import 'package:empty_pocket/core/services/notification_service.dart';
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

    test('DailyStreakReminderNotifier loads initial preference and toggles', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Initial state is true
      expect(container.read(dailyStreakReminderNotifierProvider), isTrue);

      // Set to false
      await container.read(dailyStreakReminderNotifierProvider.notifier).setEnabled(false);
      expect(container.read(dailyStreakReminderNotifierProvider), isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(kPrefDailyStreakReminder), isFalse);

      // Set back to true
      await container.read(dailyStreakReminderNotifierProvider.notifier).setEnabled(true);
      expect(container.read(dailyStreakReminderNotifierProvider), isTrue);
      expect(prefs.getBool(kPrefDailyStreakReminder), isTrue);
    });

    test('BillDueAlertNotifier loads initial preference and toggles', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Initial state is true
      expect(container.read(billDueAlertNotifierProvider), isTrue);

      // Set to false
      await container.read(billDueAlertNotifierProvider.notifier).setEnabled(false);
      expect(container.read(billDueAlertNotifierProvider), isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(kPrefBillDueAlert), isFalse);

      // Set back to true
      await container.read(billDueAlertNotifierProvider.notifier).setEnabled(true);
      expect(container.read(billDueAlertNotifierProvider), isTrue);
      expect(prefs.getBool(kPrefBillDueAlert), isTrue);
    });

    test('checkAndNotifyBillsDueToday handles empty or non-due bills safely', () async {
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

      // Should not throw
      await service.checkAndNotifyBillsDueToday(bills);
      await service.checkAndNotifyBillsDueToday(<RecurringExpenseEntity>[]);
    });
  });
}
