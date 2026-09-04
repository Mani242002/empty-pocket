import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:empty_pocket/core/calculation/financial_calculator.dart';
import 'package:empty_pocket/core/domain/entities/bank_account_entity.dart';
import 'package:empty_pocket/core/domain/entities/category_constants.dart';
import 'package:empty_pocket/core/domain/entities/debt_entity.dart';
import 'package:empty_pocket/core/domain/entities/investment_entity.dart';
import 'package:empty_pocket/core/domain/entities/recurring_expense_entity.dart';
import 'package:empty_pocket/core/domain/entities/savings_goal_entity.dart';
import 'package:empty_pocket/core/domain/entities/transaction_entity.dart';
import 'package:empty_pocket/core/repositories/bank_account_repository.dart';
import 'package:empty_pocket/core/repositories/credit_card_repository.dart';
import 'package:empty_pocket/core/repositories/debt_repository.dart';
import 'package:empty_pocket/core/repositories/investment_repository.dart';
import 'package:empty_pocket/core/repositories/recurring_repository.dart';
import 'package:empty_pocket/core/repositories/savings_goal_repository.dart';
import 'package:empty_pocket/core/repositories/transaction_repository.dart';
import 'package:empty_pocket/core/utilities/category_matcher.dart';
import 'package:empty_pocket/features/accounts/presentation/state/accounts_cards_provider.dart';
import 'package:empty_pocket/features/budgets/presentation/state/recurring_provider.dart';
import 'package:empty_pocket/features/debts/presentation/state/debts_provider.dart';
import 'package:empty_pocket/features/investments/presentation/state/investments_provider.dart';
import 'package:empty_pocket/features/savings/presentation/state/savings_goals_provider.dart';
import 'package:empty_pocket/features/transactions/presentation/state/transactions_provider.dart';

void main() {
  group('New Expense & Income Categories Tests', () {
    test('Contains all newly requested Expense categories', () {
      final names = CategoryConstants.expenseCategories.map((c) => c.name).toSet();
      expect(names.contains('Family & Home Support'), isTrue);
      expect(names.contains('Investments & SIP'), isTrue);
      expect(names.contains('Insurance Premiums'), isTrue);
      expect(names.contains('Subscriptions & Services'), isTrue);
      expect(names.contains('Personal Care & Wellness'), isTrue);
      expect(names.contains('Donations & Charity'), isTrue);
      expect(names.contains('Taxes & Govt Fees'), isTrue);
    });

    test('Contains all newly requested Income categories', () {
      final names = CategoryConstants.incomeCategories.map((c) => c.name).toSet();
      expect(names.contains('Savings Interest & FD'), isTrue);
      expect(names.contains('Shared Expense Reimbursement'), isTrue);
      expect(names.contains('Cashback & Refunds'), isTrue);
      expect(names.contains('Bonus & Incentives'), isTrue);
    });

    test('CategoryMatcher detects Family & Home Support', () {
      expect(CategoryMatcher.detectCategory('Money sending to home'), 'Family & Home Support');
      expect(CategoryMatcher.detectCategory('Sent money to parents'), 'Family & Home Support');
      expect(CategoryMatcher.detectCategory('Mother monthly allowance'), 'Family & Home Support');
    });

    test('CategoryMatcher detects Investments & SIP', () {
      expect(CategoryMatcher.detectCategory('SIP installment mutual fund'), 'Investments & SIP');
      expect(CategoryMatcher.detectCategory('Bought Zerodha shares'), 'Investments & SIP');
      expect(CategoryMatcher.detectCategory('Groww gold ETF purchase'), 'Investments & SIP');
    });

    test('CategoryMatcher detects Insurance Premiums', () {
      expect(CategoryMatcher.detectCategory('LIC term insurance premium'), 'Insurance Premiums');
      expect(CategoryMatcher.detectCategory('Health insurance policy renewal'), 'Insurance Premiums');
    });

    test('CategoryMatcher detects Subscriptions & Services', () {
      expect(CategoryMatcher.detectCategory('Netflix monthly subscription'), 'Subscriptions & Services');
      expect(CategoryMatcher.detectCategory('Spotify premium plan'), 'Subscriptions & Services');
    });

    test('CategoryMatcher detects Savings Interest & FD', () {
      expect(CategoryMatcher.detectCategory('Fixed deposit interest credited'), 'Savings Interest & FD');
      expect(CategoryMatcher.detectCategory('Quarterly savings interest'), 'Savings Interest & FD');
    });

    test('CategoryMatcher detects Shared Expense Reimbursement', () {
      expect(CategoryMatcher.detectCategory('Roommate payback for dinner'), 'Shared Expense Reimbursement');
      expect(CategoryMatcher.detectCategory('Splitwise settlement from Rahul'), 'Shared Expense Reimbursement');
    });

    test('CategoryMatcher detects Cashback & Refunds', () {
      expect(CategoryMatcher.detectCategory('Google Pay cashback reward'), 'Cashback & Refunds');
      expect(CategoryMatcher.detectCategory('Amazon order refund'), 'Cashback & Refunds');
    });

    test('CategoryMatcher detects Bonus & Incentives', () {
      expect(CategoryMatcher.detectCategory('Diwali annual bonus'), 'Bonus & Incentives');
      expect(CategoryMatcher.detectCategory('Quarterly performance incentive'), 'Bonus & Incentives');
    });
  });

  group('Shared Expenses Domain & Calculations Tests', () {
    final now = DateTime.now();

    test('TransactionEntity getters calculate shares and pending correctly', () {
      final tx = TransactionEntity(
        id: 'tx-shared-1',
        title: 'Flat Grocery & Utensils',
        amount: 3000.0,
        type: TransactionType.expense,
        category: 'Groceries',
        date: now,
        paymentSource: 'SBI Credit Card',
        creditCardId: 'card-1',
        isShared: true,
        myShareAmount: 1000.0,
        sharedWith: 'Aman, Rahul',
        reimbursedAmount: 1200.0,
        isSettled: false,
        createdAt: now,
        updatedAt: now,
      );

      expect(tx.friendsShare, 2000.0);
      expect(tx.netPersonalAmount, 1000.0);
      expect(tx.pendingReimbursement, 800.0); // 2000 - 1200
      expect(tx.isSettled, isFalse);
    });

    test('FinancialCalculator calculates True Personal Expense vs Gross Expense', () {
      final tx1 = TransactionEntity(
        id: 'tx-1',
        title: 'Dinner with Roommates',
        amount: 4000.0,
        type: TransactionType.expense,
        category: 'Food & Dining',
        date: now,
        paymentSource: 'HDFC Credit Card',
        creditCardId: 'card-1',
        isShared: true,
        myShareAmount: 1000.0, // User share is only 1000, friends owe 3000
        sharedWith: 'Roommates',
        reimbursedAmount: 1000.0,
        createdAt: now,
        updatedAt: now,
      );

      final tx2 = TransactionEntity(
        id: 'tx-2',
        title: 'Personal Petrol',
        amount: 500.0,
        type: TransactionType.expense,
        category: 'Transportation',
        date: now,
        paymentSource: 'Cash',
        createdAt: now,
        updatedAt: now,
      );

      final txList = [tx1, tx2];

      // Gross expense is 4000 + 500 = 4500
      expect(FinancialCalculator.calculateGrossExpense(txList), 4500.0);

      // True personal expense is 1000 + 500 = 1500 (Does NOT inflate personal budget!)
      expect(FinancialCalculator.calculateTotalExpense(txList, netPersonalOnly: true), 1500.0);

      // Pending reimbursements: friends owe 3000, 1000 reimbursed = 2000 pending
      expect(FinancialCalculator.calculatePendingReimbursements(txList), 2000.0);

      // Credit card reserve earmark: tx1 was charged to CC, so 1000 collected reimbursement is earmarked for CC bill
      expect(FinancialCalculator.calculateCreditCardEarmarkedReserve(txList), 1000.0);
    });

    test('FinancialCalculator calculateTotalIncome ignores reimbursements by default', () {
      final salaryTx = TransactionEntity(
        id: 'inc-1',
        title: 'Monthly Salary',
        amount: 80000.0,
        type: TransactionType.income,
        category: 'Salary',
        date: now,
        paymentSource: 'Bank Account',
        createdAt: now,
        updatedAt: now,
      );

      final paybackTx = TransactionEntity(
        id: 'inc-2',
        title: 'Roommate Payback',
        amount: 2000.0,
        type: TransactionType.income,
        category: 'Shared Expense Reimbursement',
        date: now,
        paymentSource: 'Bank Account',
        createdAt: now,
        updatedAt: now,
      );

      final incomeList = [salaryTx, paybackTx];

      // With excludeReimbursements: true, user's real monthly income is 80,000 (not 82,000!)
      expect(FinancialCalculator.calculateTotalIncome(incomeList, excludeReimbursements: true), 80000.0);

      // Gross income includes payback
      expect(FinancialCalculator.calculateTotalIncome(incomeList, excludeReimbursements: false), 82000.0);
    });
  });

  group('Deep Account Linking Tests', () {
    test('Savings Goal addFunds with accountId deducts bank account balance', () async {
      final now = DateTime.now();
      final container = ProviderContainer(
        overrides: [
          bankAccountRepositoryProvider.overrideWithValue(InMemoryBankAccountRepository()),
          creditCardRepositoryProvider.overrideWithValue(InMemoryCreditCardRepository()),
          savingsGoalRepositoryProvider.overrideWithValue(InMemorySavingsGoalRepository()),
          transactionRepositoryProvider.overrideWithValue(InMemoryTransactionRepository()),
        ],
      );

      // Setup bank account with ₹50,000
      final account = BankAccountEntity(
        id: 'acc-savings-1',
        accountName: 'Salary Account',
        bankName: 'HDFC',
        accountType: AccountType.savings,
        usedFor: AccountPurposeTags.dailySpending,
        initialBalance: 50000.0,
        currentBalance: 50000.0,
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      );
      await container.read(bankAccountListProvider.notifier).saveAccount(account);

      // Setup goal
      final goal = SavingsGoalEntity(
        id: 'goal-1',
        title: 'Emergency Fund',
        targetAmount: 100000.0,
        currentAmount: 20000.0,
        category: 'Emergency',
        targetDate: now.add(const Duration(days: 180)),
        createdAt: now,
        updatedAt: now,
      );
      await container.read(savingsGoalsListNotifierProvider.notifier).saveGoal(goal);

      // Add ₹10,000 contribution linked to bank account
      await container.read(savingsGoalsListNotifierProvider.notifier).addFunds(
            goal: goal,
            amount: 10000.0,
            logAsTransaction: true,
            accountId: account.id,
            paymentSource: account.accountName,
          );

      // Verify goal amount updated to 30,000
      final goals = container.read(savingsGoalsListNotifierProvider).value!;
      expect(goals.first.currentAmount, 30000.0);

      // Verify bank account balance deducted from 50,000 to 40,000!
      final accounts = container.read(bankAccountListProvider).value!;
      expect(accounts.first.currentBalance, 40000.0);

      // Verify transaction logged in ledger
      final txs = await container.read(transactionRepositoryProvider).getAllTransactions();
      expect(txs.any((t) => t.title == 'Goal: Emergency Fund' && t.amount == 10000.0 && t.accountId == account.id), isTrue);
    });

    test('Investment saveInvestment with accountId deducts bank account balance', () async {
      final now = DateTime.now();
      final container = ProviderContainer(
        overrides: [
          bankAccountRepositoryProvider.overrideWithValue(InMemoryBankAccountRepository()),
          creditCardRepositoryProvider.overrideWithValue(InMemoryCreditCardRepository()),
          investmentRepositoryProvider.overrideWithValue(InMemoryInvestmentRepository()),
          transactionRepositoryProvider.overrideWithValue(InMemoryTransactionRepository()),
        ],
      );

      // Setup bank account with ₹30,000
      final account = BankAccountEntity(
        id: 'acc-inv-1',
        accountName: 'Investment Hub',
        bankName: 'ICICI',
        accountType: AccountType.savings,
        usedFor: AccountPurposeTags.investments,
        initialBalance: 30000.0,
        currentBalance: 30000.0,
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      );
      await container.read(bankAccountListProvider.notifier).saveAccount(account);

      final investment = InvestmentEntity(
        id: 'inv-1',
        name: 'Nifty 50 Index Fund',
        assetClass: AssetClass.equity,
        investedAmount: 15000.0,
        currentValue: 15000.0,
        createdAt: now,
        updatedAt: now,
      );

      // Save investment with funding enabled
      await container.read(investmentListNotifierProvider.notifier).saveInvestment(
            investment,
            logAsTransaction: true,
            accountId: account.id,
            paymentSource: account.accountName,
          );

      // Verify bank account balance deducted from 30,000 to 15,000!
      final accounts = container.read(bankAccountListProvider).value!;
      expect(accounts.first.currentBalance, 15000.0);

      // Verify transaction logged with category Investments & SIP
      final txs = await container.read(transactionRepositoryProvider).getAllTransactions();
      expect(txs.any((t) => t.title == 'Investment: Nifty 50 Index Fund' && t.category == 'Investments & SIP'), isTrue);
    });

    test('Debt recordPayment with accountId deducts bank account balance', () async {
      final now = DateTime.now();
      final container = ProviderContainer(
        overrides: [
          bankAccountRepositoryProvider.overrideWithValue(InMemoryBankAccountRepository()),
          creditCardRepositoryProvider.overrideWithValue(InMemoryCreditCardRepository()),
          debtRepositoryProvider.overrideWithValue(InMemoryDebtRepository()),
          transactionRepositoryProvider.overrideWithValue(InMemoryTransactionRepository()),
        ],
      );

      // Setup bank account with ₹40,000
      final account = BankAccountEntity(
        id: 'acc-debt-1',
        accountName: 'Main Checking',
        bankName: 'SBI',
        accountType: AccountType.savings,
        usedFor: AccountPurposeTags.dailySpending,
        initialBalance: 40000.0,
        currentBalance: 40000.0,
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      );
      await container.read(bankAccountListProvider.notifier).saveAccount(account);

      final debt = DebtEntity(
        id: 'debt-1',
        title: 'Education Loan',
        type: DebtType.personalLoan,
        principalAmount: 200000.0,
        remainingAmount: 150000.0,
        interestRate: 8.5,
        monthlyEmi: 8000.0,
        startDate: now,
        createdAt: now,
        updatedAt: now,
      );
      await container.read(debtListNotifierProvider.notifier).saveDebt(debt);

      // Record EMI payment of ₹8,000 linked to bank account
      await container.read(debtListNotifierProvider.notifier).recordPayment(
            debt: debt,
            amount: 8000.0,
            logAsTransaction: true,
            accountId: account.id,
            paymentSource: account.accountName,
          );

      // Verify debt remaining amount reduced: 150,000 - 8,000 = 142,000
      final debts = container.read(debtListNotifierProvider).value!;
      expect(debts.first.remainingAmount, 142000.0);

      // Verify bank account deducted from 40,000 to 32,000!
      final accounts = container.read(bankAccountListProvider).value!;
      expect(accounts.first.currentBalance, 32000.0);
    });

    test('Recurring logPaymentAsTransaction with linked account deducts bank balance', () async {
      final now = DateTime.now();
      final container = ProviderContainer(
        overrides: [
          bankAccountRepositoryProvider.overrideWithValue(InMemoryBankAccountRepository()),
          creditCardRepositoryProvider.overrideWithValue(InMemoryCreditCardRepository()),
          recurringRepositoryProvider.overrideWithValue(InMemoryRecurringRepository()),
          transactionRepositoryProvider.overrideWithValue(InMemoryTransactionRepository()),
        ],
      );

      // Setup bank account with ₹20,000
      final account = BankAccountEntity(
        id: 'acc-rec-1',
        accountName: 'Kotak Active',
        bankName: 'Kotak',
        accountType: AccountType.savings,
        usedFor: AccountPurposeTags.billsAndEmis,
        initialBalance: 20000.0,
        currentBalance: 20000.0,
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      );
      await container.read(bankAccountListProvider.notifier).saveAccount(account);

      final recurring = RecurringExpenseEntity(
        id: 'rec-1',
        title: 'Airtel Broadband',
        amount: 1180.0,
        category: 'Bills & Utilities',
        frequency: RecurringFrequency.monthly,
        paymentSource: 'Kotak Active',
        startDate: now,
        nextDueDate: now.add(const Duration(days: 2)),
        createdAt: now,
        updatedAt: now,
      );
      await container.read(recurringListNotifierProvider.notifier).saveRecurring(recurring);

      // Log payment with automatic balance deduction
      await container.read(recurringListNotifierProvider.notifier).logPaymentAsTransaction(
            recurring,
            accountId: account.id,
            deductBalance: true,
          );

      // Verify bank balance deducted: 20,000 - 1180 = 18,820
      final accounts = container.read(bankAccountListProvider).value!;
      expect(accounts.first.currentBalance, 18820.0);

      // Verify transaction logged
      final txs = await container.read(transactionRepositoryProvider).getAllTransactions();
      expect(txs.any((t) => t.title == 'Airtel Broadband' && t.amount == 1180.0), isTrue);
    });

    test('createGoalWithInitialDeposit deducts from linked bank account and logs transaction', () async {
      final now = DateTime.now();
      final container = ProviderContainer(
        overrides: [
          bankAccountRepositoryProvider.overrideWithValue(InMemoryBankAccountRepository()),
          creditCardRepositoryProvider.overrideWithValue(InMemoryCreditCardRepository()),
          savingsGoalRepositoryProvider.overrideWithValue(InMemorySavingsGoalRepository()),
          transactionRepositoryProvider.overrideWithValue(InMemoryTransactionRepository()),
        ],
      );
      await container.read(bankAccountListProvider.future);
      await container.read(savingsGoalsListNotifierProvider.future);
      await container.read(transactionListNotifierProvider.future);

      // Setup bank account with ₹1,00,000
      final account = BankAccountEntity(
        id: 'acc-init-goal',
        accountName: 'Main Savings',
        bankName: 'SBI',
        accountType: AccountType.savings,
        usedFor: AccountPurposeTags.emergencyFund,
        initialBalance: 100000.0,
        currentBalance: 100000.0,
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      );
      await container.read(bankAccountListProvider.notifier).saveAccount(account);

      final goal = SavingsGoalEntity(
        id: 'goal-emergency-fund',
        title: 'Emergency Fund 6 Months',
        targetAmount: 200000.0,
        currentAmount: 0.0,
        category: 'Emergency',
        targetDate: now.add(const Duration(days: 365)),
        linkedAccountId: account.id,
        createdAt: now,
        updatedAt: now,
      );

      // Create goal with initial deposit of ₹30,000 deducted from account
      await container.read(savingsGoalsListNotifierProvider.notifier).createGoalWithInitialDeposit(
            goal: goal,
            initialAmount: 30000.0,
            accountId: account.id,
            paymentSource: account.accountName,
            deductFromAccount: true,
          );

      // Verify goal has ₹30,000
      final goals = container.read(savingsGoalsListNotifierProvider).value!;
      expect(goals.first.currentAmount, 30000.0);

      // Verify bank account was deducted: 100,000 - 30,000 = 70,000
      final accounts = container.read(bankAccountListProvider).value!;
      expect(accounts.first.currentBalance, 70000.0);

      // Verify transaction was logged
      final txs = await container.read(transactionRepositoryProvider).getAllTransactions();
      expect(txs.any((t) => t.title == 'Goal: Emergency Fund 6 Months' && t.amount == 30000.0), isTrue);
    });

    test('settleSharedExpense and delete reimbursement rollback original shared expense', () async {
      final now = DateTime.now();
      final container = ProviderContainer(
        overrides: [
          bankAccountRepositoryProvider.overrideWithValue(InMemoryBankAccountRepository()),
          creditCardRepositoryProvider.overrideWithValue(InMemoryCreditCardRepository()),
          transactionRepositoryProvider.overrideWithValue(InMemoryTransactionRepository()),
        ],
      );
      await container.read(bankAccountListProvider.future);
      await container.read(transactionListNotifierProvider.future);

      // Setup bank account with ₹10,000
      final bank = BankAccountEntity(
        id: 'acc-dest-1',
        accountName: 'HDFC Payback',
        bankName: 'HDFC',
        accountType: AccountType.savings,
        usedFor: AccountPurposeTags.dailySpending,
        initialBalance: 10000.0,
        currentBalance: 10000.0,
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      );
      await container.read(bankAccountListProvider.notifier).saveAccount(bank);

      // Setup shared expense: ₹4,000 dinner with roommates (my share ₹1,000, friends owe ₹3,000)
      final sharedExpense = TransactionEntity(
        id: 'tx-dinner-shared',
        title: 'Team Dinner',
        amount: 4000.0,
        type: TransactionType.expense,
        category: 'Food & Dining',
        date: now,
        paymentSource: 'HDFC Payback',
        accountId: bank.id,
        isShared: true,
        myShareAmount: 1000.0,
        reimbursedAmount: 0.0,
        isSettled: false,
        createdAt: now,
        updatedAt: now,
      );
      await container.read(transactionListNotifierProvider.notifier).addTransaction(sharedExpense);

      // Settle ₹3,000 from roommates into HDFC account
      await container.read(transactionListNotifierProvider.notifier).settleSharedExpense(
            transactionId: sharedExpense.id,
            amountReceived: 3000.0,
            destinationAccountId: bank.id,
            notes: 'Roommates paid dinner share',
          );

      // Verify original shared expense is marked settled
      var txList = container.read(transactionListNotifierProvider).value!;
      var updatedOrig = txList.firstWhere((t) => t.id == sharedExpense.id);
      expect(updatedOrig.isSettled, isTrue);
      expect(updatedOrig.reimbursedAmount, 3000.0);

      // Verify bank account increased by ₹3,000: 10,000 + 3,000 = 13,000
      var accounts = container.read(bankAccountListProvider).value!;
      expect(accounts.first.currentBalance, 13000.0);

      // Verify settlement transaction created
      final settlementTx = txList.firstWhere((t) => t.category == 'Shared Expense Reimbursement');
      expect(settlementTx.amount, 3000.0);
      expect(settlementTx.linkedEntityId, sharedExpense.id);

      // Now DELETE the reimbursement transaction: verify rollback!
      await container.read(transactionListNotifierProvider.notifier).deleteTransaction(settlementTx.id);

      // Verify original shared expense is no longer settled and reimbursedAmount is rolled back to 0!
      txList = container.read(transactionListNotifierProvider).value!;
      updatedOrig = txList.firstWhere((t) => t.id == sharedExpense.id);
      expect(updatedOrig.isSettled, isFalse);
      expect(updatedOrig.reimbursedAmount, 0.0);

      // Verify bank account was reversed: 13,000 - 3,000 = 10,000
      accounts = container.read(bankAccountListProvider).value!;
      expect(accounts.first.currentBalance, 10000.0);
    });
  });
}
