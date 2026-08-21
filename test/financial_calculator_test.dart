import 'package:flutter_test/flutter_test.dart';
import 'package:empty_pocket/core/calculation/financial_calculator.dart';
import 'package:empty_pocket/core/domain/entities/transaction_entity.dart';

void main() {
  group('FinancialCalculator', () {
    final now = DateTime(2026, 8, 21, 14, 30);

    final sampleTransactions = [
      TransactionEntity(
        id: '1',
        title: 'Tech Company Salary',
        amount: 80000.0,
        type: TransactionType.income,
        category: 'Salary',
        date: now,
        paymentSource: 'Bank Account',
        createdAt: now,
        updatedAt: now,
      ),
      TransactionEntity(
        id: '2',
        title: 'Freelance Design',
        amount: 20000.0,
        type: TransactionType.income,
        category: 'Freelance & Gig',
        date: now,
        paymentSource: 'UPI / Wallet',
        createdAt: now,
        updatedAt: now,
      ),
      TransactionEntity(
        id: '3',
        title: 'Apartment Rent',
        amount: 25000.0,
        type: TransactionType.expense,
        category: 'Housing & Rent',
        date: now,
        paymentSource: 'Bank Account',
        createdAt: now,
        updatedAt: now,
      ),
      TransactionEntity(
        id: '4',
        title: 'Organic Groceries',
        amount: 5000.0,
        type: TransactionType.expense,
        category: 'Groceries',
        date: now,
        paymentSource: 'Credit Card',
        createdAt: now,
        updatedAt: now,
      ),
      TransactionEntity(
        id: '5',
        title: 'Old Month Transaction',
        amount: 10000.0,
        type: TransactionType.income,
        category: 'Salary',
        date: DateTime(2026, 7, 15),
        paymentSource: 'Bank Account',
        createdAt: DateTime(2026, 7, 15),
        updatedAt: DateTime(2026, 7, 15),
      ),
    ];

    test('calculateTotalIncome sums only income transactions', () {
      final totalIncome = FinancialCalculator.calculateTotalIncome(sampleTransactions);
      expect(totalIncome, 110000.0);
    });

    test('calculateTotalExpense sums only expense transactions', () {
      final totalExpense = FinancialCalculator.calculateTotalExpense(sampleTransactions);
      expect(totalExpense, 30000.0);
    });

    test('calculateNetBalance calculates income minus expenses', () {
      final netBalance = FinancialCalculator.calculateNetBalance(sampleTransactions);
      expect(netBalance, 80000.0);
    });

    test('calculateSavingsRate calculates correct percentage', () {
      // 100k income, 30k expense = 70% savings rate
      final rate = FinancialCalculator.calculateSavingsRate(100000, 30000);
      expect(rate, 70.0);

      // 0 income returns 0%
      expect(FinancialCalculator.calculateSavingsRate(0, 5000), 0.0);

      // Expense > Income returns 0% (clamped)
      expect(FinancialCalculator.calculateSavingsRate(1000, 2000), 0.0);

      // 0 expense = 100%
      expect(FinancialCalculator.calculateSavingsRate(50000, 0), 100.0);
    });

    test('filterByMonth filters transactions for target month only', () {
      final augustTransactions = FinancialCalculator.filterByMonth(
        sampleTransactions,
        DateTime(2026, 8, 1),
      );
      expect(augustTransactions.length, 4);

      final julyTransactions = FinancialCalculator.filterByMonth(
        sampleTransactions,
        DateTime(2026, 7, 1),
      );
      expect(julyTransactions.length, 1);
      expect(julyTransactions.first.title, 'Old Month Transaction');
    });

    test('filterByType filters income or expense', () {
      final incomeOnly = FinancialCalculator.filterByType(
        sampleTransactions,
        TransactionType.income,
      );
      expect(incomeOnly.length, 3);

      final expenseOnly = FinancialCalculator.filterByType(
        sampleTransactions,
        TransactionType.expense,
      );
      expect(expenseOnly.length, 2);
    });

    test('searchTransactions matches title, category, notes, or payment source', () {
      final titleMatch = FinancialCalculator.searchTransactions(
        sampleTransactions,
        'Rent',
      );
      expect(titleMatch.length, 1);
      expect(titleMatch.first.id, '3');

      final categoryMatch = FinancialCalculator.searchTransactions(
        sampleTransactions,
        'Groceries',
      );
      expect(categoryMatch.length, 1);

      final sourceMatch = FinancialCalculator.searchTransactions(
        sampleTransactions,
        'UPI',
      );
      expect(sourceMatch.length, 1);
    });

    test('groupTransactionsByDate groups by date key', () {
      final grouped = FinancialCalculator.groupTransactionsByDate(sampleTransactions);
      expect(grouped.keys.length, 2); // August 21 and July 15
    });

    test('calculateCategoryBreakdown groups expenses and computes percentages', () {
      final breakdown = FinancialCalculator.calculateCategoryBreakdown(sampleTransactions);
      expect(breakdown.length, 2);
      expect(breakdown.first.category, 'Housing & Rent');
      expect(breakdown.first.amount, 25000.0);
      expect(breakdown.first.percentage, closeTo(83.33, 0.01));
    });
  });
}
