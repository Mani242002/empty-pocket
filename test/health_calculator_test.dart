import 'package:flutter_test/flutter_test.dart';
import 'package:empty_pocket/core/calculation/financial_calculator.dart';
import 'package:empty_pocket/core/domain/entities/financial_health_entity.dart';
import 'package:empty_pocket/core/domain/entities/transaction_entity.dart';

void main() {
  group('Net Worth & Financial Health Calculator Tests', () {
    test('calculateNetWorthComposition computes total assets, liabilities, and net worth correctly', () {
      final comp = FinancialCalculator.calculateNetWorthComposition(
        cashBalance: 40000.0,
        savingsGoalsAmount: 25000.0,
        investmentsAmount: 60000.0,
        totalLiabilities: 25000.0,
      );

      expect(comp.totalAssets, 125000.0);
      expect(comp.totalLiabilities, 25000.0);
      expect(comp.netWorth, 100000.0);
      expect(comp.debtToAssetRatio, 20.0);
      expect(comp.isPositive, isTrue);
      expect(comp.cashPercentage, 32.0); // 40,000 / 125,000 * 100
      expect(comp.savingsPercentage, 20.0); // 25,000 / 125,000 * 100
      expect(comp.investmentsPercentage, 48.0); // 60,000 / 125,000 * 100
    });

    test('calculateNetWorthComposition treats negative cash balance as overdraft liability without dropping it', () {
      final comp = FinancialCalculator.calculateNetWorthComposition(
        cashBalance: -10000.0, // Overdrawn bank account
        savingsGoalsAmount: 20000.0,
        investmentsAmount: 50000.0,
        totalLiabilities: 30000.0,
      );

      // Effective cash is clamped to 0 in assets, so totalAssets = 20k + 50k = 70k
      expect(comp.totalAssets, 70000.0);
      // Overdraft is added to liabilities: 30k + 10k = 40k
      expect(comp.totalLiabilities, 40000.0);
      // Net worth = 70k - 40k = 30k
      expect(comp.netWorth, 30000.0);
      expect(comp.debtToAssetRatio, closeTo(57.14, 0.01));
    });

    test('calculateWealthBuildingSummary accurately separates debt payoffs from general savings and pure expenses', () {
      final now = DateTime.now();
      final txs = [
        TransactionEntity(
          id: '1',
          title: 'Salary',
          amount: 100000.0,
          type: TransactionType.income,
          category: 'Salary',
          date: now,
          paymentSource: 'Bank',
          createdAt: now,
          updatedAt: now,
        ),
        TransactionEntity(
          id: '2',
          title: 'Index Fund SIP',
          amount: 20000.0,
          type: TransactionType.expense,
          category: 'Mutual Fund Investment',
          date: now,
          paymentSource: 'Bank',
          createdAt: now,
          updatedAt: now,
        ),
        TransactionEntity(
          id: '3',
          title: 'Home Loan EMI',
          amount: 15000.0,
          type: TransactionType.expense,
          category: 'Home Loan EMI Debt',
          date: now,
          paymentSource: 'Bank',
          createdAt: now,
          updatedAt: now,
        ),
        TransactionEntity(
          id: '4',
          title: 'Emergency Fund Goal',
          amount: 10000.0,
          type: TransactionType.expense,
          category: 'Savings Deposit',
          date: now,
          paymentSource: 'Bank',
          createdAt: now,
          updatedAt: now,
        ),
        TransactionEntity(
          id: '5',
          title: 'Groceries',
          amount: 5000.0,
          type: TransactionType.expense,
          category: 'Food & Groceries',
          date: now,
          paymentSource: 'Bank',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final summary = FinancialCalculator.calculateWealthBuildingSummary(txs);
      expect(summary.totalInflow, 100000.0);
      expect(summary.investmentOutflow, 20000.0);
      expect(summary.debtRepayment, 15000.0);
      expect(summary.savingsTransfer, 10000.0);
      expect(summary.pureExpense, 5000.0);
      // Wealth allocated = 20k + 15k + 10k = 45k -> 45%
      expect(summary.wealthBuildingRate, 45.0);
    });

    test('calculateFinancialHealthSummary awards top score for excellent financial discipline', () {
      final summary = FinancialCalculator.calculateFinancialHealthSummary(
        cashBalance: 50000.0,
        monthlyIncome: 100000.0,
        monthlyExpense: 30000.0,
        savingsGoalsAmount: 180000.0, // 6 months emergency buffer (180k / 30k = 6)
        emergencyFundSaved: 180000.0,
        investmentsAmount: 300000.0,
        distinctAssetClassesCount: 3, // Equity, Gold, Debt
        totalLiabilities: 0.0, // 0 debt
        totalMonthlyEmi: 0.0,
      );

      expect(summary.emergencyBufferPillar.score, 25);
      expect(summary.savingsRatePillar.score, 25);
      expect(summary.debtBurdenPillar.score, 25);
      expect(summary.diversificationPillar.score, 25);
      expect(summary.overallScore, 100);
      expect(summary.grade, HealthGrade.excellent);
    });

    test('calculateFinancialHealthSummary identifies risk areas and generates targeted tips', () {
      final summary = FinancialCalculator.calculateFinancialHealthSummary(
        cashBalance: 5000.0,
        monthlyIncome: 50000.0,
        monthlyExpense: 48000.0, // 96% expense ratio (< 10% savings)
        savingsGoalsAmount: 0.0,
        emergencyFundSaved: 0.0, // 0 emergency buffer
        investmentsAmount: 0.0, // 0 investments
        distinctAssetClassesCount: 0,
        totalLiabilities: 400000.0, // High debt
        totalMonthlyEmi: 28000.0, // > 50% DTI
      );

      expect(summary.emergencyBufferPillar.score, 5);
      expect(summary.savingsRatePillar.score, 5);
      expect(summary.debtBurdenPillar.score, 4);
      expect(summary.diversificationPillar.score, 8);
      expect(summary.overallScore, 22);
      expect(summary.grade, HealthGrade.needsAttention);
      expect(summary.actionableTips.length, greaterThanOrEqualTo(3));
    });
  });
}
