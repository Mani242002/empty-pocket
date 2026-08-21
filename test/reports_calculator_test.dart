import 'package:flutter_test/flutter_test.dart';
import 'package:empty_pocket/core/calculation/financial_calculator.dart';
import 'package:empty_pocket/core/domain/entities/transaction_entity.dart';

void main() {
  group('Reports & Analytics Calculator Tests', () {
    final now = DateTime.now();

    test('calculateMonthlyTrends computes historical trends accurately', () {
      final txs = [
        TransactionEntity(
          id: 't1',
          title: 'Salary',
          amount: 60000.0,
          type: TransactionType.income,
          category: 'Salary',
          date: now,
          paymentSource: 'Bank Account',
          createdAt: now,
          updatedAt: now,
        ),
        TransactionEntity(
          id: 't2',
          title: 'Rent',
          amount: 20000.0,
          type: TransactionType.expense,
          category: 'Rent & Housing',
          date: now,
          paymentSource: 'UPI / Wallet',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final trends = FinancialCalculator.calculateMonthlyTrends(txs, monthsCount: 6);

      expect(trends.length, 6);
      final currentMonthTrend = trends.last;
      expect(currentMonthTrend.totalIncome, 60000.0);
      expect(currentMonthTrend.totalExpense, 20000.0);
      expect(currentMonthTrend.netSavings, 40000.0);
      expect(currentMonthTrend.savingsRate, closeTo(66.66, 0.1));
      expect(currentMonthTrend.isPositive, isTrue);
    });

    test('calculateCashFlowForecast projects 3-month balances correctly', () {
      final forecast = FinancialCalculator.calculateCashFlowForecast(
        currentCashBalance: 50000.0,
        estimatedMonthlyIncome: 80000.0,
        totalMonthlyRecurringExpenses: 5000.0,
        totalMonthlyDebtEmi: 15000.0,
        forecastMonths: 3,
      );

      expect(forecast.length, 3);
      // Fixed expenses: 5k + 15k = 20k
      // Net Cash / mo: 80k - 20k = 60k
      expect(forecast[0].projectedFixedExpenses, 20000.0);
      expect(forecast[0].projectedNetCash, 60000.0);
      expect(forecast[0].projectedCumulativeBalance, 110000.0); // 50k + 60k

      expect(forecast[1].projectedCumulativeBalance, 170000.0); // 110k + 60k
      expect(forecast[2].projectedCumulativeBalance, 230000.0); // 170k + 60k
    });

    test('calculatePaymentSourceBreakdown groups expenses by payment method', () {
      final txs = [
        TransactionEntity(
          id: 't1',
          title: 'Grocery',
          amount: 3000.0,
          type: TransactionType.expense,
          category: 'Groceries',
          date: now,
          paymentSource: 'UPI / Wallet',
          createdAt: now,
          updatedAt: now,
        ),
        TransactionEntity(
          id: 't2',
          title: 'Dining',
          amount: 2000.0,
          type: TransactionType.expense,
          category: 'Food & Dining',
          date: now,
          paymentSource: 'Credit Card',
          createdAt: now,
          updatedAt: now,
        ),
        TransactionEntity(
          id: 't3',
          title: 'Coffee',
          amount: 500.0,
          type: TransactionType.expense,
          category: 'Food & Dining',
          date: now,
          paymentSource: 'UPI / Wallet',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final breakdown = FinancialCalculator.calculatePaymentSourceBreakdown(txs);

      expect(breakdown.length, 2);
      expect(breakdown.first.source, 'UPI / Wallet');
      expect(breakdown.first.amount, 3500.0);
      expect(breakdown.first.count, 2);
      expect(breakdown[1].source, 'Credit Card');
      expect(breakdown[1].amount, 2000.0);
    });
  });
}
