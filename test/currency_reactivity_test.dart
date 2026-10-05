import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:empty_pocket/core/utilities/currency_formatter.dart';
import 'package:empty_pocket/features/settings/presentation/state/backup_provider.dart';
import 'package:empty_pocket/features/accounts/presentation/screens/accounts_cards_screen.dart';
import 'package:empty_pocket/features/debts/presentation/screens/debts_screen.dart';
import 'package:empty_pocket/features/budgets/presentation/widgets/monthly_budgets_tab.dart';
import 'package:empty_pocket/core/repositories/bank_account_repository.dart';
import 'package:empty_pocket/core/repositories/credit_card_repository.dart';
import 'package:empty_pocket/core/repositories/savings_goal_repository.dart';
import 'package:empty_pocket/core/repositories/debt_repository.dart';
import 'package:empty_pocket/core/repositories/transaction_repository.dart';
import 'package:empty_pocket/core/repositories/budget_repository.dart';
import 'package:empty_pocket/core/repositories/investment_repository.dart';
import 'package:empty_pocket/core/domain/entities/bank_account_entity.dart';
import 'package:empty_pocket/core/domain/entities/savings_goal_entity.dart';
import 'package:empty_pocket/core/domain/entities/debt_entity.dart';
import 'package:empty_pocket/core/domain/entities/budget_entity.dart';
import 'package:empty_pocket/core/domain/entities/transaction_entity.dart';
import 'package:empty_pocket/features/net_worth/presentation/screens/financial_health_screen.dart';
import 'package:empty_pocket/features/savings/presentation/screens/add_contribution_sheet.dart';
import 'package:empty_pocket/features/debts/presentation/screens/add_edit_debt_sheet.dart';
import 'package:empty_pocket/features/transactions/presentation/screens/pending_shared_expenses_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({'app_currency_code': 'USD'});
    CurrencyFormatter.setCurrencyByCode('USD');
    await CurrencyFormatter.init();
  });

  group('Currency Reactivity & Decimal Integrity Tests', () {
    test('CurrencyFormatter formats with correct symbols and JPY 0-decimal precision', () async {
      CurrencyFormatter.setCurrencyByCode('USD');
      expect(CurrencyFormatter.format(1234.56), '\$1,234.56');

      CurrencyFormatter.setCurrencyByCode('EUR');
      expect(CurrencyFormatter.format(1234.56), '€1,234.56');

      CurrencyFormatter.setCurrencyByCode('INR');
      expect(CurrencyFormatter.format(1234.56), '₹1,234.56');

      CurrencyFormatter.setCurrencyByCode('JPY');
      // JPY has decimalDigits: 0
      expect(CurrencyFormatter.format(1234.56), '¥1,235');
      expect(CurrencyFormatter.format(5000), '¥5,000');
    });

    testWidgets(
      'AccountsCardsScreen reactively updates currency symbols on currencyProvider change',
      (tester) async {
        final now = DateTime.now();
        final bankRepo = InMemoryBankAccountRepository();
        await bankRepo.saveAccount(
          BankAccountEntity(
            id: 'acc-curr-1',
            accountName: 'Main Checking',
            bankName: 'Chase',
            accountType: AccountType.savings,
            usedFor: AccountPurposeTags.dailySpending,
            initialBalance: 1250.0,
            currentBalance: 1250.0,
            isDefault: true,
            createdAt: now,
            updatedAt: now,
          ),
        );

        final container = ProviderContainer(
          overrides: [
            bankAccountRepositoryProvider.overrideWithValue(bankRepo),
            creditCardRepositoryProvider.overrideWithValue(
              InMemoryCreditCardRepository(),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(body: AccountsCardsScreen()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // USD initial verification: rendered symbol is $
        expect(find.textContaining(r'$1,250.00'), findsWidgets);

        final eur = CurrencyFormatter.supportedCurrencies.firstWhere(
          (c) => c.code == 'EUR',
        );
        final inr = CurrencyFormatter.supportedCurrencies.firstWhere(
          (c) => c.code == 'INR',
        );
        final jpy = CurrencyFormatter.supportedCurrencies.firstWhere(
          (c) => c.code == 'JPY',
        );

        // Change currency to EUR: rendered symbol changes to €
        container.read(currencyProvider.notifier).setCurrency(eur);
        await tester.pumpAndSettle();
        expect(find.textContaining('€1,250.00'), findsWidgets);
        expect(find.textContaining(r'$1,250.00'), findsNothing);

        // Change currency to INR: rendered symbol changes to ₹
        container.read(currencyProvider.notifier).setCurrency(inr);
        await tester.pumpAndSettle();
        expect(find.textContaining('₹1,250.00'), findsWidgets);
        expect(find.textContaining('€1,250.00'), findsNothing);

        // Change currency to JPY: rendered symbol changes to ¥ without decimals
        container.read(currencyProvider.notifier).setCurrency(jpy);
        await tester.pumpAndSettle();
        expect(find.textContaining('¥1,250'), findsWidgets);
        expect(find.textContaining('₹1,250.00'), findsNothing);
      },
    );

    testWidgets(
      'DebtsScreen reactively updates currency symbols on currencyProvider change',
      (tester) async {
        final now = DateTime.now();
        final debtRepo = InMemoryDebtRepository();
        await debtRepo.saveDebt(
          DebtEntity(
            id: 'debt-curr-1',
            title: 'Car Loan',
            principalAmount: 2500.0,
            remainingAmount: 2500.0,
            interestRate: 5.0,
            monthlyEmi: 250.0,
            startDate: now,
            type: DebtType.carLoan,
            status: DebtStatus.active,
            createdAt: now,
            updatedAt: now,
          ),
        );

        final container = ProviderContainer(
          overrides: [debtRepositoryProvider.overrideWithValue(debtRepo)],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: Scaffold(body: DebtsScreen())),
          ),
        );
        await tester.pumpAndSettle();

        // Initially USD: rendered debt amount contains $
        expect(find.textContaining(r'$2,500.00'), findsWidgets);

        final eur = CurrencyFormatter.supportedCurrencies.firstWhere(
          (c) => c.code == 'EUR',
        );
        // Change currency to EUR: rendered debt amount contains €
        container.read(currencyProvider.notifier).setCurrency(eur);
        await tester.pumpAndSettle();
        expect(find.byType(DebtsScreen), findsOneWidget);
        expect(find.textContaining('€2,500.00'), findsWidgets);
        expect(find.textContaining(r'$2,500.00'), findsNothing);
      },
    );

    testWidgets(
      'MonthlyBudgetsTab and SavingsGoalsTab react to currency changes without recreating keys',
      (tester) async {
        final now = DateTime.now();
        final budgetRepo = InMemoryBudgetRepository();
        await budgetRepo.saveBudget(
          BudgetEntity(
            id: 'budget-curr-1',
            category: 'Dining Out',
            limitAmount: 800.0,
            month: DateTime(now.year, now.month, 1),
            createdAt: now,
            updatedAt: now,
          ),
        );

        final container = ProviderContainer(
          overrides: [
            budgetRepositoryProvider.overrideWithValue(budgetRepo),
            creditCardRepositoryProvider.overrideWithValue(
              InMemoryCreditCardRepository(),
            ),
            savingsGoalRepositoryProvider.overrideWithValue(
              InMemorySavingsGoalRepository(),
            ),
            bankAccountRepositoryProvider.overrideWithValue(
              InMemoryBankAccountRepository(),
            ),
            transactionRepositoryProvider.overrideWithValue(
              InMemoryTransactionRepository(),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(
                body: SizedBox(height: 800, child: MonthlyBudgetsTab()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // USD budget allowance
        expect(find.textContaining(r'$800.00'), findsWidgets);

        final gbp = CurrencyFormatter.supportedCurrencies.firstWhere(
          (c) => c.code == 'GBP',
        );
        container.read(currencyProvider.notifier).setCurrency(gbp);
        await tester.pumpAndSettle();
        expect(find.byType(MonthlyBudgetsTab), findsOneWidget);
        // GBP budget allowance
        expect(find.textContaining('£800.00'), findsWidgets);
        expect(find.textContaining(r'$800.00'), findsNothing);
      },
    );

    testWidgets(
      'FinancialHealthScreen, AddContributionSheet, AddEditDebtSheet, and PendingSharedExpensesSheet react dynamically to currency changes',
      (tester) async {
        final now = DateTime.now();
        final bankRepo = InMemoryBankAccountRepository();
        await bankRepo.saveAccount(
          BankAccountEntity(
            id: 'bank-acc-fh',
            accountName: 'Primary Savings',
            bankName: 'Ally',
            accountType: AccountType.savings,
            usedFor: AccountPurposeTags.emergencyFund,
            initialBalance: 1000.0,
            currentBalance: 1000.0,
            isDefault: true,
            createdAt: now,
            updatedAt: now,
          ),
        );

        final container = ProviderContainer(
          overrides: [
            bankAccountRepositoryProvider.overrideWithValue(bankRepo),
            creditCardRepositoryProvider.overrideWithValue(
              InMemoryCreditCardRepository(),
            ),
            savingsGoalRepositoryProvider.overrideWithValue(
              InMemorySavingsGoalRepository(),
            ),
            debtRepositoryProvider.overrideWithValue(InMemoryDebtRepository()),
            investmentRepositoryProvider.overrideWithValue(
              InMemoryInvestmentRepository(),
            ),
            budgetRepositoryProvider.overrideWithValue(
              InMemoryBudgetRepository(),
            ),
            transactionRepositoryProvider.overrideWithValue(
              InMemoryTransactionRepository(),
            ),
          ],
        );
        addTearDown(container.dispose);

        // 1. Mount FinancialHealthScreen
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: FinancialHealthScreen()),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(FinancialHealthScreen), findsOneWidget);
        expect(find.textContaining(r'$1,000.00'), findsWidgets);

        final eur = CurrencyFormatter.supportedCurrencies.firstWhere(
          (c) => c.code == 'EUR',
        );
        container.read(currencyProvider.notifier).setCurrency(eur);
        await tester.pumpAndSettle();
        expect(find.byType(FinancialHealthScreen), findsOneWidget);
        // Rendered net worth must now show €
        expect(find.textContaining('€1,000.00'), findsWidgets);
        expect(find.textContaining(r'$1,000.00'), findsNothing);

        // 2. Mount AddContributionSheet
        final goal = SavingsGoalEntity(
          id: 'test-goal-currency',
          title: 'New Car',
          targetAmount: 5000.0,
          currentAmount: 1000.0,
          category: 'Vehicles',
          targetDate: DateTime.now().add(const Duration(days: 120)),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(body: AddContributionSheet(goal: goal)),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AddContributionSheet), findsOneWidget);

        final inr = CurrencyFormatter.supportedCurrencies.firstWhere(
          (c) => c.code == 'INR',
        );
        container.read(currencyProvider.notifier).setCurrency(inr);
        await tester.pumpAndSettle();
        expect(find.byType(AddContributionSheet), findsOneWidget);
        // Rendered goal target and saved amounts now show ₹
        expect(find.textContaining('₹1,000.00'), findsWidgets);
        expect(find.textContaining('₹5,000.00'), findsWidgets);
        expect(find.textContaining('₹ '), findsWidgets);

        // 3. Mount AddEditDebtSheet
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: Scaffold(body: AddEditDebtSheet())),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AddEditDebtSheet), findsOneWidget);

        final jpy = CurrencyFormatter.supportedCurrencies.firstWhere(
          (c) => c.code == 'JPY',
        );
        container.read(currencyProvider.notifier).setCurrency(jpy);
        await tester.pumpAndSettle();
        expect(find.byType(AddEditDebtSheet), findsOneWidget);
        // TextField prefix shows ¥
        expect(find.textContaining('¥ '), findsWidgets);

        // 4. Mount PendingSharedExpensesSheet with a preselected transaction
        final sharedTx = TransactionEntity(
          id: 'tx-shared-curr',
          title: 'Dinner with Alex',
          amount: 200.0,
          type: TransactionType.expense,
          category: 'Food',
          date: now,
          paymentSource: 'Primary Savings',
          accountId: 'bank-acc-fh',
          isShared: true,
          myShareAmount: 50.0,
          reimbursedAmount: 0.0,
          isSettled: false,
          sharedWith: 'Alex',
          createdAt: now,
          updatedAt: now,
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: PendingSharedExpensesSheet(
                  preselectedTransaction: sharedTx,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(PendingSharedExpensesSheet), findsOneWidget);

        final usd = CurrencyFormatter.supportedCurrencies.firstWhere(
          (c) => c.code == 'USD',
        );
        container.read(currencyProvider.notifier).setCurrency(usd);
        await tester.pumpAndSettle();
        expect(find.byType(PendingSharedExpensesSheet), findsOneWidget);
        // Rendered pending amount and input prefix show $
        expect(find.textContaining(r'$150.00'), findsWidgets);
        expect(find.textContaining(r'$ '), findsWidgets);
      },
    );
  });
}
