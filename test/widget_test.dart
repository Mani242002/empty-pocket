import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:empty_pocket/app/app.dart';
import 'package:empty_pocket/core/domain/entities/transaction_entity.dart';
import 'package:empty_pocket/core/repositories/budget_repository.dart';
import 'package:empty_pocket/core/repositories/debt_repository.dart';
import 'package:empty_pocket/core/repositories/investment_repository.dart';
import 'package:empty_pocket/core/repositories/recurring_repository.dart';
import 'package:empty_pocket/core/repositories/savings_goal_repository.dart';
import 'package:empty_pocket/core/repositories/transaction_repository.dart';

void main() {
  testWidgets('Complete flow: transactions, budgeting, recurring, savings, debts, and investments',
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
    final inMemorySavingsRepo = InMemorySavingsGoalRepository();
    final inMemoryDebtRepo = InMemoryDebtRepository();
    final inMemoryInvestmentRepo = InMemoryInvestmentRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(inMemoryTxRepo),
          budgetRepositoryProvider.overrideWithValue(inMemoryBudgetRepo),
          recurringRepositoryProvider.overrideWithValue(inMemoryRecurringRepo),
          savingsGoalRepositoryProvider.overrideWithValue(inMemorySavingsRepo),
          debtRepositoryProvider.overrideWithValue(inMemoryDebtRepo),
          investmentRepositoryProvider.overrideWithValue(inMemoryInvestmentRepo),
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

    // --- STEP 2: TEST SAVINGS & GOALS ---
    // Switch to Savings & Goals tab
    await tester.tap(find.text('Savings & Goals'));
    await tester.pumpAndSettle();

    // Verify Savings Goals empty state
    expect(find.text('Create First Goal'), findsOneWidget);

    // Tap "Create First Goal"
    await tester.tap(find.text('Create First Goal'));
    await tester.pumpAndSettle();

    // Enter Goal Title: MacBook Pro M3
    await tester.enterText(find.byType(TextFormField).first, 'MacBook Pro M3');
    await tester.pumpAndSettle();

    // Enter Target Amount: 100000
    await tester.enterText(find.byType(TextFormField).at(1), '100000');
    await tester.pumpAndSettle();

    // Save Goal
    await tester.tap(find.text('Create Savings Goal'));
    await tester.pumpAndSettle();

    // Verify goal card appeared
    expect(find.text('MacBook Pro M3'), findsOneWidget);
    expect(find.text('0% Reached'), findsOneWidget);

    // Tap "Add Funds" on MacBook Pro card
    await tester.tap(find.text('Add Funds'));
    await tester.pumpAndSettle();

    // Enter Contribution Amount: 25000
    await tester.enterText(find.byType(TextFormField).first, '25000');
    await tester.pumpAndSettle();

    // Submit contribution
    await tester.tap(find.text('Add Funds to Goal'));
    await tester.pumpAndSettle();

    // Verify goal progress updated to 25%
    expect(find.text('25% Reached'), findsOneWidget);
    expect(find.text('₹25,000.00'), findsWidgets);

    // --- STEP 3: TEST RECURRING EXPENSES ---
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

    // --- STEP 4: VERIFY DASHBOARD UPDATES ---
    // Switch to Dashboard
    await tester.tap(find.text('Dashboard'));
    await tester.pumpAndSettle();

    // Balance updated: 50,000 - 5,000 - 25,000 (goal) - 649 (netflix) = 19,351
    expect(find.text('₹19,351.00'), findsOneWidget);
    expect(find.text('Netflix Standard'), findsOneWidget);
    expect(find.text('Goal: MacBook Pro M3'), findsOneWidget);
    expect(find.text('25% Saved'), findsOneWidget);

    // --- STEP 5: TEST LOANS & LIABILITIES ---
    // Tap "Add Loan" on Dashboard
    await tester.tap(find.text('Add Loan'));
    await tester.pumpAndSettle();

    // Enter Loan Title: Axis Car Loan
    await tester.enterText(find.byType(TextFormField).first, 'Axis Car Loan');
    await tester.pumpAndSettle();

    // Enter Principal: 300000
    await tester.enterText(find.byType(TextFormField).at(1), '300000');
    await tester.pumpAndSettle();

    // Save Loan Record
    await tester.tap(find.text('Save Loan Record'));
    await tester.pumpAndSettle();

    // Verify Dashboard updated with loan
    expect(find.text('Outstanding: ₹3,00,000.00'), findsOneWidget);

    // Tap "Manage" on Loans card
    await tester.tap(find.text('Manage').first);
    await tester.pumpAndSettle();

    // In DebtsScreen, verify loan card
    expect(find.text('Loans & Liabilities'), findsOneWidget);
    expect(find.text('Axis Car Loan'), findsOneWidget);

    // Tap "Pay EMI" on Axis Car Loan
    await tester.tap(find.text('Pay EMI'));
    await tester.pumpAndSettle();

    // Enter Payment Amount: 10000
    await tester.enterText(find.byType(TextFormField).first, '10000');
    await tester.pumpAndSettle();

    // Submit payment
    await tester.tap(find.text('Record Debt Payment'));
    await tester.pumpAndSettle();

    // Verify remaining balance updated: 300,000 - 10,000 = 290,000
    expect(find.text('₹2,90,000.00'), findsWidgets);

    // Pop back to Dashboard
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Verify final updated balance: 19,351 - 10,000 = 9,351
    expect(find.text('₹9,351.00'), findsOneWidget);
    expect(find.text('EMI: Axis Car Loan'), findsOneWidget);

    // --- STEP 6: TEST INVESTMENTS & ASSET ALLOCATION ---
    // Tap "Add Asset" on Dashboard
    await tester.tap(find.text('Add Asset'));
    await tester.pumpAndSettle();

    // Enter Holding Name: Nifty 50 Index Fund
    await tester.enterText(find.byType(TextFormField).first, 'Nifty 50 Index Fund');
    await tester.pumpAndSettle();

    // Enter Invested: 50000
    await tester.enterText(find.byType(TextFormField).at(1), '50000');
    await tester.pumpAndSettle();

    // Enter Current Value: 60000
    await tester.enterText(find.byType(TextFormField).at(2), '60000');
    await tester.pumpAndSettle();

    // Save Holding
    await tester.tap(find.text('Save Investment Holding'));
    await tester.pumpAndSettle();

    // Verify Dashboard updated with investment portfolio
    expect(find.text('₹60,000.00'), findsOneWidget);
    expect(find.text('+₹10,000.00 (20.0%)'), findsOneWidget);

    // Tap "Manage" on Investments card
    await tester.tap(find.text('Manage').first);
    await tester.pumpAndSettle();

    // In InvestmentsScreen, verify portfolio details
    expect(find.text('Investments & Assets'), findsOneWidget);
    expect(find.text('Nifty 50 Index Fund'), findsOneWidget);
    expect(find.text('Asset Allocation'), findsOneWidget);

    // Tap "Update Value" on Nifty 50 card
    await tester.tap(find.text('Update Value'));
    await tester.pumpAndSettle();

    // Update value to 65000
    await tester.enterText(find.byType(TextFormField).first, '65000');
    await tester.pumpAndSettle();

    // Submit valuation update
    await tester.tap(find.text('Update Valuation'));
    await tester.pumpAndSettle();

    // Verify updated portfolio value
    expect(find.text('₹65,000.00'), findsWidgets);
    expect(find.text('+30.0%'), findsOneWidget);

    // Pop back to Dashboard
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Verify Dashboard reflects updated portfolio value
    expect(find.text('₹65,000.00'), findsOneWidget);
  });
}
