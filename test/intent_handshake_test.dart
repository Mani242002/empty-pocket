import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:empty_pocket/app/presentation/screens/main_navigation_scaffold.dart';
import 'package:empty_pocket/core/repositories/bank_account_repository.dart';
import 'package:empty_pocket/core/repositories/credit_card_repository.dart';
import 'package:empty_pocket/core/repositories/transaction_repository.dart';
import 'package:empty_pocket/core/repositories/budget_repository.dart';
import 'package:empty_pocket/core/repositories/savings_goal_repository.dart';
import 'package:empty_pocket/core/repositories/debt_repository.dart';
import 'package:empty_pocket/core/repositories/investment_repository.dart';
import 'package:empty_pocket/core/repositories/recurring_repository.dart';
import 'package:empty_pocket/core/utilities/currency_formatter.dart';
import 'package:empty_pocket/features/transactions/presentation/screens/add_edit_transaction_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({'selected_currency': 'USD'});
    await CurrencyFormatter.init();
  });

  group('Intent Handshake & Scaffold Lifecycle Tests', () {
    testWidgets(
      'MainNavigationScaffold invokes clientReady on channel and handles triggerQuickAdd',
      (tester) async {
        final List<MethodCall> channelCalls = [];
        const channel = MethodChannel('dev.emptypocket.app/overlay');

        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (MethodCall methodCall) async {
            channelCalls.add(methodCall);
            return null;
          },
        );

        final container = ProviderContainer(
          overrides: [
            bankAccountRepositoryProvider.overrideWithValue(
              InMemoryBankAccountRepository(),
            ),
            creditCardRepositoryProvider.overrideWithValue(
              InMemoryCreditCardRepository(),
            ),
            transactionRepositoryProvider.overrideWithValue(
              InMemoryTransactionRepository(),
            ),
            budgetRepositoryProvider.overrideWithValue(
              InMemoryBudgetRepository(),
            ),
            savingsGoalRepositoryProvider.overrideWithValue(
              InMemorySavingsGoalRepository(),
            ),
            debtRepositoryProvider.overrideWithValue(InMemoryDebtRepository()),
            investmentRepositoryProvider.overrideWithValue(
              InMemoryInvestmentRepository(),
            ),
            recurringRepositoryProvider.overrideWithValue(
              InMemoryRecurringRepository(),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: MainNavigationScaffold()),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Verify clientReady handshake was sent to native Android host
        expect(
          channelCalls.any((call) => call.method == 'clientReady'),
          isTrue,
        );

        // 2. Verify screen dimensions were cached in SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getDouble('device_screen_width_dp'), isNotNull);
        expect(prefs.getDouble('device_screen_height_dp'), isNotNull);

        // 3. Simulate native host firing triggerQuickAdd intent
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          'dev.emptypocket.app/overlay',
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('triggerQuickAdd'),
          ),
          (ByteData? data) {},
        );
        await tester.pumpAndSettle();

        // Verify AddEditTransactionSheet is displayed
        expect(find.byType(AddEditTransactionSheet), findsOneWidget);
      },
    );
  });
}
