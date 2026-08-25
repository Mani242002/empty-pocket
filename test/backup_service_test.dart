import 'package:flutter_test/flutter_test.dart';
import 'package:empty_pocket/core/domain/entities/budget_entity.dart';
import 'package:empty_pocket/core/domain/entities/debt_entity.dart';
import 'package:empty_pocket/core/domain/entities/investment_entity.dart';
import 'package:empty_pocket/core/domain/entities/recurring_expense_entity.dart';
import 'package:empty_pocket/core/domain/entities/savings_goal_entity.dart';
import 'package:empty_pocket/core/domain/entities/transaction_entity.dart';
import 'package:empty_pocket/core/repositories/budget_repository.dart';
import 'package:empty_pocket/core/repositories/debt_repository.dart';
import 'package:empty_pocket/core/repositories/investment_repository.dart';
import 'package:empty_pocket/core/repositories/recurring_repository.dart';
import 'package:empty_pocket/core/repositories/savings_goal_repository.dart';
import 'package:empty_pocket/core/repositories/transaction_repository.dart';
import 'package:empty_pocket/core/services/backup_service.dart';

void main() {
  group('Backup & Data Portability Service Tests', () {
    late BackupService backupService;
    final now = DateTime.now();

    setUp(() {
      backupService = BackupService();
    });

    test('exportTransactionsToCsv formats transactions correctly with escaping', () {
      final txs = [
        TransactionEntity(
          id: 't1',
          title: 'Grocery, Market "Organic"',
          amount: 1500.50,
          type: TransactionType.expense,
          category: 'Groceries',
          date: DateTime(2026, 8, 15, 10, 30),
          paymentSource: 'UPI / Wallet',
          notes: 'Special "sale"',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final csv = backupService.exportTransactionsToCsv(txs);

      expect(csv, contains('ID,Date,Type,Category,Title,Amount,Payment Method,Notes,Created At'));
      expect(csv, contains('"Grocery, Market ""Organic"""'));
      expect(csv, contains('1500.50'));
      expect(csv, contains('"Special ""sale"""'));
    });

    test('exportFullDatabaseJson and parseBackupJson perform lossless round-trip', () {
      final tx = TransactionEntity(
        id: 't1',
        title: 'Salary',
        amount: 80000.0,
        type: TransactionType.income,
        category: 'Salary',
        date: now,
        paymentSource: 'Bank Account',
        createdAt: now,
        updatedAt: now,
      );

      final budget = BudgetEntity(
        id: 'b1',
        category: 'Groceries',
        limitAmount: 12000.0,
        month: DateTime(now.year, now.month),
        createdAt: now,
        updatedAt: now,
      );

      final goal = SavingsGoalEntity(
        id: 'g1',
        title: 'Emergency Fund',
        targetAmount: 100000.0,
        currentAmount: 40000.0,
        category: 'Emergency',
        targetDate: now.add(const Duration(days: 180)),
        isEmergencyFund: true,
        createdAt: now,
        updatedAt: now,
      );

      final debt = DebtEntity(
        id: 'd1',
        title: 'Auto Loan',
        type: DebtType.carLoan,
        principalAmount: 300000.0,
        remainingAmount: 250000.0,
        interestRate: 8.5,
        monthlyEmi: 8000.0,
        startDate: now,
        createdAt: now,
        updatedAt: now,
      );

      final investment = InvestmentEntity(
        id: 'i1',
        name: 'Nifty 50 Index Fund',
        assetClass: AssetClass.equity,
        investedAmount: 50000.0,
        currentValue: 65000.0,
        createdAt: now,
        updatedAt: now,
      );

      final recurring = RecurringExpenseEntity(
        id: 'r1',
        title: 'Netflix Subscription',
        amount: 649.0,
        category: 'Entertainment',
        frequency: RecurringFrequency.monthly,
        startDate: now,
        nextDueDate: now.add(const Duration(days: 15)),
        paymentSource: 'Credit Card',
        createdAt: now,
        updatedAt: now,
      );

      final jsonStr = backupService.exportFullDatabaseJson(
        transactions: [tx],
        budgets: [budget],
        savingsGoals: [goal],
        savingsContributions: [],
        debts: [debt],
        debtPayments: [],
        investments: [investment],
        recurringExpenses: [recurring],
      );

      expect(jsonStr, contains('"schemaVersion": 8'));
      expect(jsonStr, contains('"transactionsCount": 1'));

      final parsed = backupService.parseBackupJson(jsonStr);

      expect(parsed.transactions.length, 1);
      expect(parsed.transactions.first.title, 'Salary');
      expect(parsed.budgets.length, 1);
      expect(parsed.savingsGoals.length, 1);
      expect(parsed.debts.length, 1);
      expect(parsed.investments.length, 1);
      expect(parsed.recurringExpenses.length, 1);
    });

    test('restoreAll and wipeAllData work accurately with repositories', () async {
      final txRepo = InMemoryTransactionRepository();
      final budgetRepo = InMemoryBudgetRepository();
      final savingsRepo = InMemorySavingsGoalRepository();
      final debtRepo = InMemoryDebtRepository();
      final investRepo = InMemoryInvestmentRepository();
      final recurRepo = InMemoryRecurringRepository();

      final tx = TransactionEntity(
        id: 'tx_restore',
        title: 'Freelance Design',
        amount: 15000.0,
        type: TransactionType.income,
        category: 'Other Income',
        date: now,
        paymentSource: 'Bank Account',
        createdAt: now,
        updatedAt: now,
      );

      final jsonStr = backupService.exportFullDatabaseJson(
        transactions: [tx],
        budgets: [],
        savingsGoals: [],
        savingsContributions: [],
        debts: [],
        debtPayments: [],
        investments: [],
        recurringExpenses: [],
      );

      final parsedBackup = backupService.parseBackupJson(jsonStr);

      await backupService.restoreAll(
        backup: parsedBackup,
        transactionRepo: txRepo,
        budgetRepo: budgetRepo,
        savingsRepo: savingsRepo,
        debtRepo: debtRepo,
        investmentRepo: investRepo,
        recurringRepo: recurRepo,
      );

      final restoredTxs = await txRepo.getAllTransactions();
      expect(restoredTxs.length, 1);
      expect(restoredTxs.first.title, 'Freelance Design');

      // Test wipeAllData
      await backupService.wipeAllData(
        transactionRepo: txRepo,
        budgetRepo: budgetRepo,
        savingsRepo: savingsRepo,
        debtRepo: debtRepo,
        investmentRepo: investRepo,
        recurringRepo: recurRepo,
      );

      final wipedTxs = await txRepo.getAllTransactions();
      expect(wipedTxs.isEmpty, isTrue);
    });
  });
}
