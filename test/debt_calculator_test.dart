import 'package:flutter_test/flutter_test.dart';
import 'package:empty_pocket/core/calculation/financial_calculator.dart';
import 'package:empty_pocket/core/domain/entities/debt_entity.dart';

void main() {
  group('Debt & EMI Calculator Tests', () {
    final now = DateTime.now();

    test('calculateStandardEmi calculates accurate EMI for standard interest loan', () {
      // Principal: 10,00,000, Interest: 8.5% p.a., Tenure: 240 months (20 yrs)
      final emi = FinancialCalculator.calculateStandardEmi(1000000.0, 8.5, 240);
      expect(emi, closeTo(8678.23, 0.5));
    });

    test('calculateStandardEmi calculates simple division for 0% interest loan', () {
      final emi = FinancialCalculator.calculateStandardEmi(60000.0, 0.0, 12);
      expect(emi, 5000.0);
    });

    test('calculateTotalInterest calculates total interest over tenure', () {
      // Principal: 1,00,000, EMI: 9,000, Tenure: 12 months -> Total Paid: 1,08,000 -> Interest: 8,000
      final interest = FinancialCalculator.calculateTotalInterest(100000.0, 9000.0, 12);
      expect(interest, 8000.0);
    });

    test('calculateDebtProgress computes progress metrics', () {
      final debt = DebtEntity(
        id: 'd1',
        title: 'Axis Car Loan',
        type: DebtType.carLoan,
        principalAmount: 500000.0,
        remainingAmount: 200000.0,
        monthlyEmi: 12000.0,
        startDate: now,
        createdAt: now,
        updatedAt: now,
      );

      final metrics = FinancialCalculator.calculateDebtProgress(debt);

      expect(metrics.paidAmount, 300000.0);
      expect(metrics.paidPercentage, 60.0);
      expect(metrics.isPaidOff, isFalse);
      expect(metrics.estimatedMonthsRemaining, 17); // 200000 / 12000 = 16.66 -> 17
    });

    test('calculateOverallLiabilitiesSummary aggregates active and paid off debts', () {
      final debts = [
        DebtEntity(
          id: 'd1',
          title: 'Car Loan',
          type: DebtType.carLoan,
          principalAmount: 400000.0,
          remainingAmount: 200000.0,
          monthlyEmi: 10000.0,
          status: DebtStatus.active,
          startDate: now,
          createdAt: now,
          updatedAt: now,
        ),
        DebtEntity(
          id: 'd2',
          title: 'Old Credit Card',
          type: DebtType.creditCard,
          principalAmount: 50000.0,
          remainingAmount: 0.0,
          monthlyEmi: 0.0,
          status: DebtStatus.paidOff,
          startDate: now,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final summary = FinancialCalculator.calculateOverallLiabilitiesSummary(debts);

      expect(summary.totalOutstanding, 200000.0);
      expect(summary.totalMonthlyEmi, 10000.0);
      expect(summary.totalOriginalPrincipal, 450000.0);
      expect(summary.totalPaidOff, 250000.0);
      expect(summary.activeDebtsCount, 1);
      expect(summary.paidOffDebtsCount, 1);
    });

    test('calculateDebtToIncomeRatio computes DTI percentage', () {
      final dti = FinancialCalculator.calculateDebtToIncomeRatio(25000.0, 100000.0);
      expect(dti, 25.0);
    });
  });
}
