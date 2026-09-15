import 'package:flutter_test/flutter_test.dart';
import 'package:empty_pocket/core/calculation/financial_calculator.dart';
import 'package:empty_pocket/core/domain/entities/debt_entity.dart';
import 'package:empty_pocket/core/domain/entities/savings_goal_entity.dart';

void main() {
  group('Net Worth Calculation & Auto-Sync Deduplication Tests', () {
    test('calculateOverallLiabilitiesSummary separates real debts from peerLent receivables', () {
      final now = DateTime.now();
      final debts = [
        DebtEntity(
          id: 'debt-1',
          title: 'Home Loan',
          type: DebtType.homeLoan,
          principalAmount: 5000000.0,
          remainingAmount: 4500000.0,
          interestRate: 8.5,
          monthlyEmi: 42000.0,
          startDate: now,
          lenderName: 'HDFC Bank',
          createdAt: now,
          updatedAt: now,
        ),
        DebtEntity(
          id: 'debt-2',
          title: 'Personal Loan to Rahul',
          type: DebtType.peerLent,
          principalAmount: 100000.0,
          remainingAmount: 60000.0,
          monthlyEmi: 0.0,
          startDate: now,
          lenderName: 'Rahul Sharma',
          createdAt: now,
          updatedAt: now,
        ),
        DebtEntity(
          id: 'debt-3',
          title: 'Credit Card Debt',
          type: DebtType.creditCard,
          principalAmount: 50000.0,
          remainingAmount: 30000.0,
          monthlyEmi: 5000.0,
          startDate: now,
          lenderName: 'SBI Card',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final summary = FinancialCalculator.calculateOverallLiabilitiesSummary(debts);

      // Real liabilities: Home Loan (4,500,000) + Credit Card (30,000) = 4,530,000
      expect(summary.totalOutstanding, 4530000.0);
      expect(summary.activeDebtsCount, 2);
      expect(summary.totalMonthlyEmi, 47000.0);

      // Receivables: Personal Loan to Rahul (60,000)
      expect(summary.totalReceivables, 60000.0);
    });

    test('calculateNetWorthComposition includes receivables in totalAssets and computes correct net worth', () {
      final comp = FinancialCalculator.calculateNetWorthComposition(
        cashBalance: 200000.0,
        savingsGoalsAmount: 300000.0,
        investmentsAmount: 1000000.0,
        totalLiabilities: 500000.0,
        receivablesAmount: 100000.0,
      );

      // totalAssets = 200k (cash) + 300k (savings) + 1,000k (investments) + 100k (receivables) = 1,600,000
      expect(comp.totalAssets, 1600000.0);
      expect(comp.totalLiabilities, 500000.0);
      // netWorth = 1,600,000 - 500,000 = 1,100,000
      expect(comp.netWorth, 1100000.0);
      expect(comp.receivablesAmount, 100000.0);
      // receivablesPercentage = (100k / 1.6M) * 100 = 6.25%
      expect(comp.receivablesPercentage, closeTo(6.25, 0.01));
    });

    test('Auto-synced savings goals linked to active bank accounts are distinguished from standalone goals', () {
      final now = DateTime.now();
      final goals = [
        SavingsGoalEntity(
          id: 'goal-1',
          title: 'Emergency Fund in HDFC',
          targetAmount: 300000.0,
          currentAmount: 150000.0,
          autoSyncAccount: true,
          linkedAccountId: 'acc-hdfc-1',
          category: 'Emergency',
          targetDate: now.add(const Duration(days: 365)),
          createdAt: now,
          updatedAt: now,
        ),
        SavingsGoalEntity(
          id: 'goal-2',
          title: 'Cash in Vault (Standalone)',
          targetAmount: 50000.0,
          currentAmount: 25000.0,
          autoSyncAccount: false,
          linkedAccountId: null,
          category: 'General',
          targetDate: now.add(const Duration(days: 180)),
          createdAt: now,
          updatedAt: now,
        ),
      ];

      // Standalone goals amount (not linked to any auto-synced bank account)
      final standaloneGoalsAmount = goals
          .where((g) => !(g.autoSyncAccount && g.linkedAccountId != null))
          .fold<double>(0.0, (sum, g) => sum + g.currentAmount);

      expect(standaloneGoalsAmount, 25000.0);

      // Simulating bank account balance of 150,000 in HDFC
      const combinedLiquidCash = 150000.0;

      // Net worth calculation without double counting:
      // If we used totalSaved (175,000) + combinedLiquidCash (150,000), total would be 325,000 (wrong, 150k counted twice).
      // With deduplication: combinedLiquidCash (150k) + standaloneGoals (25k) = 175k (accurate real money).
      final composition = FinancialCalculator.calculateNetWorthComposition(
        cashBalance: combinedLiquidCash,
        savingsGoalsAmount: standaloneGoalsAmount,
        investmentsAmount: 0.0,
        totalLiabilities: 0.0,
      );

      expect(composition.totalAssets, 175000.0);
      expect(composition.netWorth, 175000.0);
    });

    test('Financial Health Score avoids double-counting liquid runway when emergency fund is auto-synced', () {
      final now = DateTime.now();
      final goals = [
        SavingsGoalEntity(
          id: 'goal-emg-1',
          title: 'Emergency Fund in ICICI',
          targetAmount: 200000.0,
          currentAmount: 100000.0,
          isEmergencyFund: true,
          autoSyncAccount: true,
          linkedAccountId: 'acc-icici-1',
          category: 'Emergency',
          targetDate: now.add(const Duration(days: 365)),
          createdAt: now,
          updatedAt: now,
        ),
      ];

      const bankCash = 100000.0;
      const monthlyExpense = 25000.0;

      // Without deduplication, liquid cash = 100k (bank) + 100k (emergency fund) = 200k (8 months, falsely reporting 6+ fully funded).
      // With deduplication:
      final effectiveEmergencyFund = goals
          .where((g) => g.isEmergencyFund && !(g.autoSyncAccount && g.linkedAccountId != null))
          .fold<double>(0.0, (sum, g) => sum + g.currentAmount);

      expect(effectiveEmergencyFund, 0.0);

      final healthSummary = FinancialCalculator.calculateFinancialHealthSummary(
        cashBalance: bankCash,
        monthlyIncome: 60000.0,
        monthlyExpense: monthlyExpense,
        savingsGoalsAmount: 0.0,
        emergencyFundSaved: effectiveEmergencyFund,
        investmentsAmount: 0.0,
        distinctAssetClassesCount: 1,
        totalLiabilities: 0.0,
        totalMonthlyEmi: 0.0,
      );

      // Months covered should be exactly 100,000 / 25,000 = 4.0 months (Healthy buffer), NOT 8.0 months.
      final emergencyPillar = healthSummary.emergencyBufferPillar;
      expect(emergencyPillar.statusText, contains('4.0 months'));
    });
  });
}
