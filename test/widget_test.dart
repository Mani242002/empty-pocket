import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:empty_pocket/app/app.dart';
import 'package:empty_pocket/core/domain/entities/transaction_entity.dart';
import 'package:empty_pocket/core/repositories/transaction_repository.dart';

void main() {
  testWidgets('Full flow: adds transaction, updates balance, and displays in history',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final now = DateTime.now();
    final inMemoryRepo = InMemoryTransactionRepository([
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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(inMemoryRepo),
        ],
        child: const EmptyPocketApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify brand and header
    expect(find.text('EmptyPocket'), findsOneWidget);

    // Verify calculated Net Balance (50,000 - 5,000 = 45,000)
    expect(find.text('₹45,000.00'), findsOneWidget);

    // Verify Income and Expense metrics
    expect(find.text('Income (1)'), findsOneWidget);
    expect(find.text('Expenses (1)'), findsOneWidget);
    expect(find.text('₹50,000.00'), findsOneWidget);
    expect(find.text('₹5,000.00'), findsOneWidget);

    // Verify Recent Activity shows initial items
    expect(find.text('Monthly Salary'), findsOneWidget);
    expect(find.text('Grocery Supplies'), findsOneWidget);

    // Tap Floating Action Button to open Quick Action Bottom Sheet
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // Tap "Add Expense" from quick actions
    expect(find.text('Add Expense'), findsWidgets);
    await tester.tap(find.text('Add Expense').last);
    await tester.pumpAndSettle();

    // Verify Add Transaction Sheet opened
    expect(find.text('New Transaction'), findsOneWidget);
    expect(find.text('AMOUNT'), findsOneWidget);

    // Enter Amount: 1200
    await tester.enterText(find.byType(TextFormField).first, '1200');
    await tester.pumpAndSettle();

    // Enter Title: Dinner with Friends
    await tester.enterText(find.byType(TextFormField).at(1), 'Dinner with Friends');
    await tester.pumpAndSettle();

    // Tap Record Transaction
    await tester.tap(find.text('Record Transaction'));
    await tester.pumpAndSettle();

    // Verify new balance updated (45,000 - 1,200 = 43,800)
    expect(find.text('₹43,800.00'), findsOneWidget);
    expect(find.text('Dinner with Friends'), findsOneWidget);

    // Switch to Transactions Tab
    await tester.tap(find.text('Transactions'));
    await tester.pumpAndSettle();

    // Verify all 3 transactions appear in the Transactions screen
    expect(find.text('Dinner with Friends'), findsOneWidget);
    expect(find.text('Grocery Supplies'), findsOneWidget);
    expect(find.text('Monthly Salary'), findsOneWidget);

    // Test Search filter
    await tester.enterText(find.byType(TextField).first, 'Dinner');
    await tester.pumpAndSettle();

    expect(find.text('Dinner with Friends'), findsOneWidget);
    expect(find.text('Monthly Salary'), findsNothing);
  });
}
