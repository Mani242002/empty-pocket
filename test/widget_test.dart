import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:empty_pocket/app/app.dart';
import 'package:empty_pocket/core/domain/entities/transaction_entity.dart';
import 'package:empty_pocket/core/repositories/budget_repository.dart';
import 'package:empty_pocket/core/repositories/recurring_repository.dart';
import 'package:empty_pocket/core/repositories/transaction_repository.dart';

void main() {
  testWidgets('Complete flow: transactions, category budgeting, and recurring payment tracking',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final now = DateTime.now();
    final inMemoryTxRepo = InMemoryTransactionRepository([
      TransactionEntity(
        id: 'init-1',
        title: 'Monthly Salary',
        amount: 50000.0,
        type: TransactionType.income,
        category: 'Salary',
        date: now,
        paymentSource: 'Bank Account',
        createdAt: now,
        updatedAt: now,
      ),
      TransactionEntity(
        id: 'init-2',
        title: 'Grocery Supplies',
        amount: 5000.0,
        type: TransactionType.expense,
        category: 'Groceries',
        date: now,
        paymentSource: 'UPI / Wallet',
        createdAt: now,
        updatedAt: now,
      ),
    ]);

    final inMemoryBudgetRepo = InMemoryBudgetRepository();
    final inMemoryRecurringRepo = InMemoryRecurringRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(inMemoryTxRepo),
          budgetRepositoryProvider.overrideWithValue(inMemoryBudgetRepo),
          recurringRepositoryProvider.overrideWithValue(inMemoryRecurringRepo),
        ],
        child: const EmptyPocketApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify brand and header
    expect(find.text('EmptyPocket'), findsOneWidget);

    // Verify calculated Net Balance (50,000 - 5,000 = 45,000)
    expect(find.text('₹45,000.00'), findsOneWidget);

    // --- STEP 1: TEST BUDGETING ---
    // Navigate to Budgets tab
    await tester.tap(find.text('Budgets'));
    await tester.pumpAndSettle();

    // Verify empty state in Monthly Budgets
    expect(find.text('Monthly Budgets'), findsOneWidget);
    expect(find.text('Create Category Budget'), findsOneWidget);

    // Tap "Create Category Budget" button
    await tester.tap(find.text('Create Category Budget'));
    await tester.pumpAndSettle();

    // Set Category Budget Sheet is open
    expect(find.text('Set Category Budget'), findsOneWidget);

    // Enter Budget Limit: 6000
    await tester.enterText(find.byType(TextFormField).first, '6000');
    await tester.pumpAndSettle();

    // Select Groceries category
    await tester.tap(find.text('Groceries').first);
    await tester.pumpAndSettle();

    // Save Budget Limit
    await tester.tap(find.text('Save Budget Limit'));
    await tester.pumpAndSettle();

    // Verify category budget card is created
    expect(find.text('Groceries'), findsWidgets);
    expect(find.text('83% spent'), findsOneWidget); // 5000 / 6000 = 83% (Near Limit)
    expect(find.text('₹1,000.00 left'), findsOneWidget);

    // Verify Overall Budget Allowance Hero Card
    expect(find.text('TOTAL BUDGETED ALLOWANCE'), findsOneWidget);
    expect(find.text('Near Limit'), findsWidgets);

    // --- STEP 2: TEST RECURRING EXPENSES ---
    // Switch to Recurring & Bills tab
    await tester.tap(find.text('Recurring & Bills'));
    await tester.pumpAndSettle();

    // Verify Recurring Tab empty state
    expect(find.text('Add First Subscription'), findsOneWidget);

    // Tap "Add First Subscription"
    await tester.tap(find.text('Add First Subscription'));
    await tester.pumpAndSettle();

    // Enter Title: Netflix Standard
    await tester.enterText(find.byType(TextFormField).first, 'Netflix Standard');
    await tester.pumpAndSettle();

    // Enter Amount: 649
    await tester.enterText(find.byType(TextFormField).at(1), '649');
    await tester.pumpAndSettle();

    // Save Recurring Plan
    await tester.tap(find.text('Save Recurring Plan'));
    await tester.pumpAndSettle();

    // Verify subscription card appeared
    expect(find.text('Netflix Standard'), findsOneWidget);
    expect(find.text('Monthly'), findsOneWidget);

    // Tap "Log Payment" on Netflix card
    await tester.tap(find.text('Log Payment'));
    await tester.pumpAndSettle();

    // --- STEP 3: VERIFY DASHBOARD UPDATES ---
    // Switch to Dashboard
    await tester.tap(find.text('Dashboard'));
    await tester.pumpAndSettle();

    // Balance updated: 45,000 - 649 = 44,351
    expect(find.text('₹44,351.00'), findsOneWidget);
    expect(find.text('Netflix Standard'), findsOneWidget);
  });
}
