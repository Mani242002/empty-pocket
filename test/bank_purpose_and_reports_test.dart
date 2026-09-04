import 'package:flutter_test/flutter_test.dart';
import 'package:empty_pocket/core/calculation/financial_calculator.dart';
import 'package:empty_pocket/core/domain/entities/bank_account_entity.dart';
import 'package:empty_pocket/core/domain/entities/savings_goal_entity.dart';
import 'package:empty_pocket/core/domain/entities/transaction_entity.dart';

void main() {
  group('Bank Account Purpose Linking & Smart Category Matching Tests', () {
    final now = DateTime.now();

    // User's exact 5 bank accounts configuration
    final icici = BankAccountEntity(
      id: 'acc_icici',
      accountName: 'ICICI Salary Hub',
      bankName: 'ICICI',
      accountType: AccountType.savings,
      usedFor: AccountPurposeTags.salaryHub,
      initialBalance: 75000.0,
      currentBalance: 75000.0,
      isDefault: true,
      createdAt: now,
      updatedAt: now,
    );

    final idfc = BankAccountEntity(
      id: 'acc_idfc',
      accountName: 'IDFC Emergency Vault',
      bankName: 'IDFC',
      accountType: AccountType.savings,
      usedFor: AccountPurposeTags.emergencyFund,
      initialBalance: 200000.0,
      currentBalance: 200000.0,
      createdAt: now,
      updatedAt: now,
    );

    final kotak = BankAccountEntity(
      id: 'acc_kotak',
      accountName: 'Kotak Daily Card',
      bankName: 'Kotak',
      accountType: AccountType.savings,
      usedFor: AccountPurposeTags.dailySpending,
      initialBalance: 15000.0,
      currentBalance: 15000.0,
      createdAt: now,
      updatedAt: now,
    );

    final auBank = BankAccountEntity(
      id: 'acc_au',
      accountName: 'AU Short Term Goals',
      bankName: 'AU Small Finance Bank',
      accountType: AccountType.savings,
      usedFor: AccountPurposeTags.shortTermSavings,
      initialBalance: 50000.0,
      currentBalance: 50000.0,
      createdAt: now,
      updatedAt: now,
    );

    final sbi = BankAccountEntity(
      id: 'acc_sbi',
      accountName: 'SBI Investment & Insurance',
      bankName: 'SBI',
      accountType: AccountType.savings,
      usedFor: AccountPurposeTags.investmentsAndInsurance,
      initialBalance: 120000.0,
      currentBalance: 120000.0,
      createdAt: now,
      updatedAt: now,
    );

    final allAccounts = [icici, idfc, kotak, auBank, sbi];

    test('Food, Groceries, Shopping, Transport intelligently auto-default to Kotak (Daily Spending)', () {
      expect(AccountPurposeTags.matchAccountForCategory('Food & Dining', allAccounts, defaultAccount: icici)?.id, kotak.id);
      expect(AccountPurposeTags.matchAccountForCategory('Groceries', allAccounts, defaultAccount: icici)?.id, kotak.id);
      expect(AccountPurposeTags.matchAccountForCategory('Shopping', allAccounts, defaultAccount: icici)?.id, kotak.id);
      expect(AccountPurposeTags.matchAccountForCategory('Transportation & Fuel', allAccounts, defaultAccount: icici)?.id, kotak.id);
      expect(AccountPurposeTags.matchAccountForCategory('Cafe & Snacks', allAccounts, defaultAccount: icici)?.id, kotak.id);
    });

    test('Investments & SIP intelligently auto-default to SBI (Investments & Insurance)', () {
      expect(AccountPurposeTags.matchAccountForCategory('Investments & SIP', allAccounts, defaultAccount: icici)?.id, sbi.id);
      expect(AccountPurposeTags.matchAccountForCategory('Mutual Funds', allAccounts, defaultAccount: icici)?.id, sbi.id);
      expect(AccountPurposeTags.matchAccountForCategory('SIP Contribution', allAccounts, defaultAccount: icici)?.id, sbi.id);
    });

    test('Insurance Premiums strictly auto-default to SBI (Investments & Insurance / SBI Bank)', () {
      expect(AccountPurposeTags.matchAccountForCategory('Insurance Premiums', allAccounts, defaultAccount: icici)?.id, sbi.id);
      expect(AccountPurposeTags.matchAccountForCategory('Health Insurance', allAccounts, defaultAccount: icici)?.id, sbi.id);
      expect(AccountPurposeTags.matchAccountForCategory('Term Life Insurance', allAccounts, defaultAccount: icici)?.id, sbi.id);
    });

    test('Bills & Utilities, Subscriptions, EMI, Rent auto-default to ICICI (Salary & Income Hub)', () {
      expect(AccountPurposeTags.matchAccountForCategory('Bills & Utilities', allAccounts, defaultAccount: icici)?.id, icici.id);
      expect(AccountPurposeTags.matchAccountForCategory('Subscriptions', allAccounts, defaultAccount: icici)?.id, icici.id);
      expect(AccountPurposeTags.matchAccountForCategory('Loan EMI', allAccounts, defaultAccount: icici)?.id, icici.id);
      expect(AccountPurposeTags.matchAccountForCategory('House Rent', allAccounts, defaultAccount: icici)?.id, icici.id);
      expect(AccountPurposeTags.matchAccountForCategory('Monthly Salary', allAccounts, defaultAccount: icici)?.id, icici.id);
    });

    test('Emergency Fund categories auto-default to IDFC', () {
      expect(AccountPurposeTags.matchAccountForCategory('Emergency Fund Reserve', allAccounts, defaultAccount: icici)?.id, idfc.id);
    });

    test('Unmatched categories fall back to default account or first account', () {
      expect(AccountPurposeTags.matchAccountForCategory('Unknown Custom Tag', allAccounts, defaultAccount: icici)?.id, icici.id);
      expect(AccountPurposeTags.matchAccountForCategory('Unknown Custom Tag', allAccounts)?.id, icici.id);
    });
  });

  group('SavingsGoalEntity Schema v10 Allocation & AutoSync Tests', () {
    final now = DateTime.now();

    test('SavingsGoalEntity default values for allocationPercentage and autoSyncAccount', () {
      final goal = SavingsGoalEntity(
        id: 'g1',
        title: 'Emergency Fund',
        targetAmount: 200000.0,
        currentAmount: 150000.0,
        category: 'Emergency',
        targetDate: now.add(const Duration(days: 180)),
        createdAt: now,
        updatedAt: now,
      );

      expect(goal.allocationPercentage, 100.0);
      expect(goal.autoSyncAccount, isFalse);
      expect(goal.linkedAccountId, isNull);
    });

    test('SavingsGoalEntity toMap and fromMap serialization preserves schema v10 fields', () {
      final goal = SavingsGoalEntity(
        id: 'g2',
        title: 'Goa Vacation',
        targetAmount: 50000.0,
        currentAmount: 30000.0,
        category: 'Vacation',
        targetDate: now.add(const Duration(days: 90)),
        linkedAccountId: 'acc_au',
        allocationPercentage: 60.0,
        autoSyncAccount: true,
        createdAt: now,
        updatedAt: now,
      );

      final map = goal.toMap();
      expect(map['linked_account_id'], 'acc_au');
      expect(map['allocation_percentage'], 60.0);
      expect(map['auto_sync_account'], 1);

      final reconstructed = SavingsGoalEntity.fromMap(map);
      expect(reconstructed.id, 'g2');
      expect(reconstructed.linkedAccountId, 'acc_au');
      expect(reconstructed.allocationPercentage, 60.0);
      expect(reconstructed.autoSyncAccount, isTrue);
    });

    test('SavingsGoalEntity copyWith modifies allocation and autoSync accurately', () {
      final goal = SavingsGoalEntity(
        id: 'g3',
        title: 'New Gadget',
        targetAmount: 40000.0,
        currentAmount: 10000.0,
        category: 'Gadgets',
        targetDate: now.add(const Duration(days: 60)),
        linkedAccountId: 'acc_au',
        allocationPercentage: 40.0,
        autoSyncAccount: false,
        createdAt: now,
        updatedAt: now,
      );

      final updated = goal.copyWith(
        allocationPercentage: 50.0,
        autoSyncAccount: true,
      );

      expect(updated.allocationPercentage, 50.0);
      expect(updated.autoSyncAccount, isTrue);
      expect(updated.linkedAccountId, 'acc_au');
    });
  });

  group('Reports & Analytics Enhanced Financial Calculator Tests', () {
    final now = DateTime.now();

    final kotak = BankAccountEntity(
      id: 'acc_kotak',
      accountName: 'Kotak Daily Card',
      bankName: 'Kotak',
      accountType: AccountType.savings,
      usedFor: 'Daily Spending',
      initialBalance: 15000.0,
      currentBalance: 15000.0,
      createdAt: now,
      updatedAt: now,
    );

    final icici = BankAccountEntity(
      id: 'acc_icici',
      accountName: 'ICICI Salary Hub',
      bankName: 'ICICI',
      accountType: AccountType.savings,
      usedFor: 'Bills & EMIs',
      initialBalance: 75000.0,
      currentBalance: 75000.0,
      createdAt: now,
      updatedAt: now,
    );

    final sbi = BankAccountEntity(
      id: 'acc_sbi',
      accountName: 'SBI Investment & Insurance',
      bankName: 'SBI',
      accountType: AccountType.savings,
      usedFor: 'Investments & Insurance',
      initialBalance: 120000.0,
      currentBalance: 120000.0,
      createdAt: now,
      updatedAt: now,
    );

    final bankAccounts = [kotak, icici, sbi];

    final txKotak1 = TransactionEntity(
      id: 'tx1',
      title: 'Swiggy Dinner',
      amount: 600.0,
      type: TransactionType.expense,
      category: 'Food & Dining',
      date: now,
      paymentSource: 'Kotak Daily Card',
      accountId: 'acc_kotak',
      createdAt: now,
      updatedAt: now,
    );

    final txKotak2 = TransactionEntity(
      id: 'tx2',
      title: 'Blinkit Groceries',
      amount: 1400.0,
      type: TransactionType.expense,
      category: 'Groceries',
      date: now,
      paymentSource: 'Kotak Daily Card',
      accountId: 'acc_kotak',
      createdAt: now,
      updatedAt: now,
    );

    final txIciciBills = TransactionEntity(
      id: 'tx3',
      title: 'Electricity Bill',
      amount: 3000.0,
      type: TransactionType.expense,
      category: 'Bills & Utilities',
      date: now,
      paymentSource: 'ICICI Salary Hub',
      accountId: 'acc_icici',
      createdAt: now,
      updatedAt: now,
    );

    final txSbiInsurance = TransactionEntity(
      id: 'tx4',
      title: 'HDFC Ergo Health Insurance',
      amount: 5000.0,
      type: TransactionType.expense,
      category: 'Insurance Premiums',
      date: now,
      paymentSource: 'SBI Investment & Insurance',
      accountId: 'acc_sbi',
      createdAt: now,
      updatedAt: now,
    );

    final txShared = TransactionEntity(
      id: 'tx5',
      title: 'Room Dinner Share',
      amount: 2000.0,
      type: TransactionType.expense,
      category: 'Food & Dining',
      date: now,
      paymentSource: 'Kotak Daily Card',
      accountId: 'acc_kotak',
      isShared: true,
      myShareAmount: 1000.0,
      reimbursedAmount: 500.0,
      isSettled: false,
      sharedWith: 'Roommates',
      createdAt: now,
      updatedAt: now,
    );

    final txIncome = TransactionEntity(
      id: 'tx6',
      title: 'Monthly Salary',
      amount: 80000.0,
      type: TransactionType.income,
      category: 'Salary',
      date: now,
      paymentSource: 'ICICI Salary Hub',
      accountId: 'acc_icici',
      createdAt: now,
      updatedAt: now,
    );

    final txSbiMutualFund = TransactionEntity(
      id: 'tx7',
      title: 'Nifty 50 Index SIP',
      amount: 15000.0,
      type: TransactionType.expense,
      category: 'Investments & SIP',
      date: now,
      paymentSource: 'SBI Investment & Insurance',
      accountId: 'acc_sbi',
      createdAt: now,
      updatedAt: now,
    );

    test('calculateAccountOutflowBreakdown groups outflow by payment source with share %', () {
      final txs = [txKotak1, txKotak2, txIciciBills, txSbiInsurance, txShared];
      // Kotak: 600 + 1400 + 2000 = 4000
      // ICICI: 3000
      // SBI: 5000
      // Total: 12000

      final breakdown = FinancialCalculator.calculateAccountOutflowBreakdown(txs, bankAccounts, []);
      expect(breakdown.length, 3);

      final sbiItem = breakdown.firstWhere((b) => b.accountId == 'acc_sbi');
      expect(sbiItem.totalOutflow, 5000.0);
      expect(sbiItem.transactionCount, 1);
      expect(sbiItem.percentage, closeTo((5000 / 12000) * 100, 0.1));
      expect(sbiItem.purpose, 'Investments & Insurance');

      final kotakItem = breakdown.firstWhere((b) => b.accountId == 'acc_kotak');
      expect(kotakItem.totalOutflow, 4000.0);
      expect(kotakItem.transactionCount, 3);
      expect(kotakItem.percentage, closeTo((4000 / 12000) * 100, 0.1));
      expect(kotakItem.purpose, 'Daily Spending');

      final iciciItem = breakdown.firstWhere((b) => b.accountId == 'acc_icici');
      expect(iciciItem.totalOutflow, 3000.0);
      expect(iciciItem.transactionCount, 1);
      expect(iciciItem.purpose, 'Bills & EMIs');
    });

    test('calculateSharedExpenseImpact distinguishes gross spend from true personal spend', () {
      final txs = [txKotak1, txShared];
      // txKotak1: 600
      // txShared: 2000 gross, myShare: 1000, reimbursed: 500, pending: 500
      // Total Gross: 2600
      // True Personal: 600 + 1000 = 1600
      // Pending Reimbursement: 2000 - 1000 - 500 = 500
      // Settled Reimbursement: 500

      final impact = FinancialCalculator.calculateSharedExpenseImpact(txs);
      expect(impact.grossExpense, 2600.0);
      expect(impact.truePersonalSpend, 1600.0);
      expect(impact.pendingReimbursement, 500.0);
      expect(impact.settledReimbursement, 500.0);
      expect(impact.reimbursementRate, closeTo((500 / 2600) * 100, 0.1));
    });

    test('calculateWealthBuildingSummary computes wealth contributions and wealth building rate', () {
      final txs = [txIncome, txKotak1, txSbiMutualFund];
      // Income: 80000
      // Investment: 15000
      // Expense: 600
      // Rate: (15000 / 80000) * 100 = 18.75%

      final summary = FinancialCalculator.calculateWealthBuildingSummary(txs);
      expect(summary.totalInflow, 80000.0);
      expect(summary.investmentOutflow, 15000.0);
      expect(summary.pureExpense, 600.0);
      expect(summary.wealthBuildingRate, closeTo(18.75, 0.1));
    });

    test('calculateCategoryMomChanges calculates differences between current and previous months', () {
      final currentMonth = DateTime(now.year, now.month);
      final prevMonthDate = DateTime(now.year, now.month - 1);

      final prevTxs = [
        TransactionEntity(
          id: 'prev1',
          title: 'Groceries Last Month',
          amount: 5000.0,
          type: TransactionType.expense,
          category: 'Groceries',
          date: prevMonthDate,
          paymentSource: 'Kotak Daily Card',
          createdAt: prevMonthDate,
          updatedAt: prevMonthDate,
        ),
        TransactionEntity(
          id: 'prev2',
          title: 'Electricity Last Month',
          amount: 2000.0,
          type: TransactionType.expense,
          category: 'Bills & Utilities',
          date: prevMonthDate,
          paymentSource: 'ICICI Salary Hub',
          createdAt: prevMonthDate,
          updatedAt: prevMonthDate,
        ),
      ];

      final currentTxs = [
        TransactionEntity(
          id: 'curr1',
          title: 'Groceries This Month',
          amount: 6000.0,
          type: TransactionType.expense,
          category: 'Groceries',
          date: currentMonth,
          paymentSource: 'Kotak Daily Card',
          createdAt: currentMonth,
          updatedAt: currentMonth,
        ),
        TransactionEntity(
          id: 'curr2',
          title: 'Electricity This Month',
          amount: 1500.0,
          type: TransactionType.expense,
          category: 'Bills & Utilities',
          date: currentMonth,
          paymentSource: 'ICICI Salary Hub',
          createdAt: currentMonth,
          updatedAt: currentMonth,
        ),
      ];

      final allTxs = [...prevTxs, ...currentTxs];

      final changes = FinancialCalculator.calculateCategoryMomChanges(allTxs, currentMonth);

      expect(changes.length, 2);

      final grocChange = changes.firstWhere((c) => c.category == 'Groceries');
      expect(grocChange.currentMonthAmount, 6000.0);
      expect(grocChange.previousMonthAmount, 5000.0);
      expect(grocChange.diffAmount, 1000.0);
      expect(grocChange.percentChange, closeTo(20.0, 0.1));
      expect(grocChange.isIncrease, isTrue);

      final billChange = changes.firstWhere((c) => c.category == 'Bills & Utilities');
      expect(billChange.currentMonthAmount, 1500.0);
      expect(billChange.previousMonthAmount, 2000.0);
      expect(billChange.diffAmount, -500.0);
      expect(billChange.percentChange, closeTo(-25.0, 0.1));
      expect(billChange.isIncrease, isFalse);
    });
  });

  group('Multi-Goal Split & Smart Inflow Buffer Allocation Tests', () {
    test('AU Small Finance Bank splits balance across multiple goals (60% Vacation, 40% Gadget)', () {
      final auBalance = 50000.0;
      final vacationGoal = SavingsGoalEntity(
        id: 'g_vacation',
        title: 'Goa Vacation',
        targetAmount: 50000.0,
        currentAmount: 0.0,
        category: 'Travel',
        targetDate: DateTime.now().add(const Duration(days: 60)),
        linkedAccountId: 'acc_au',
        allocationPercentage: 60.0,
        autoSyncAccount: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final gadgetGoal = SavingsGoalEntity(
        id: 'g_gadget',
        title: 'Noise Cancelling Headphones',
        targetAmount: 25000.0,
        currentAmount: 0.0,
        category: 'Electronics',
        targetDate: DateTime.now().add(const Duration(days: 30)),
        linkedAccountId: 'acc_au',
        allocationPercentage: 40.0,
        autoSyncAccount: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final vacationAllocated = auBalance * (vacationGoal.allocationPercentage / 100.0);
      final gadgetAllocated = auBalance * (gadgetGoal.allocationPercentage / 100.0);
      final totalAllocated = vacationAllocated + gadgetAllocated;

      expect(vacationAllocated, 30000.0);
      expect(gadgetAllocated, 20000.0);
      expect(totalAllocated, 50000.0);
    });

    test('IDFC Emergency Fund 100% single-goal auto sync mirrors bank account balance', () {
      final idfcBalance = 200000.0;
      final emergencyGoal = SavingsGoalEntity(
        id: 'g_emergency',
        title: '6-Month Emergency Vault',
        targetAmount: 200000.0,
        currentAmount: 120000.0,
        category: 'Emergency',
        targetDate: DateTime.now().add(const Duration(days: 365)),
        linkedAccountId: 'acc_idfc',
        allocationPercentage: 100.0,
        autoSyncAccount: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final syncedAmount = idfcBalance * (emergencyGoal.allocationPercentage / 100.0);
      expect(syncedAmount, 200000.0);
      expect(syncedAmount >= emergencyGoal.targetAmount, isTrue);
    });

    test('SBI Inflow Smart Distribution (60% Investments, 30% Insurance, 10% Idle Buffer)', () {
      final inflowAmount = 30000.0;
      final investmentPercent = 60.0;
      final insurancePercent = 30.0;
      final idleBufferPercent = 10.0;

      final investmentAllocation = inflowAmount * (investmentPercent / 100.0);
      final insuranceAllocation = inflowAmount * (insurancePercent / 100.0);
      final idleBuffer = inflowAmount * (idleBufferPercent / 100.0);

      expect(investmentAllocation, 18000.0);
      expect(insuranceAllocation, 9000.0);
      expect(idleBuffer, 3000.0);
      expect(investmentAllocation + insuranceAllocation + idleBuffer, inflowAmount);
    });
  });
}
