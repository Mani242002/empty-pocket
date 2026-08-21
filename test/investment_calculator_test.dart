import 'package:flutter_test/flutter_test.dart';
import 'package:empty_pocket/core/calculation/financial_calculator.dart';
import 'package:empty_pocket/core/domain/entities/investment_entity.dart';

void main() {
  group('Investments & Asset Allocation Calculator Tests', () {
    final now = DateTime.now();

    test('calculateInvestmentMetrics calculates profit and return % accurately', () {
      final inv = InvestmentEntity(
        id: 'i1',
        name: 'Parag Parikh Flexi Cap',
        assetClass: AssetClass.equity,
        investedAmount: 100000.0,
        currentValue: 125000.0,
        createdAt: now,
        updatedAt: now,
      );

      final metrics = FinancialCalculator.calculateInvestmentMetrics(inv);

      expect(metrics.unrealizedProfitLoss, 25000.0);
      expect(metrics.returnPercentage, 25.0);
      expect(metrics.isProfit, isTrue);
    });

    test('calculateInvestmentMetrics calculates loss accurately', () {
      final inv = InvestmentEntity(
        id: 'i2',
        name: 'Crypto Asset',
        assetClass: AssetClass.crypto,
        investedAmount: 50000.0,
        currentValue: 40000.0,
        createdAt: now,
        updatedAt: now,
      );

      final metrics = FinancialCalculator.calculateInvestmentMetrics(inv);

      expect(metrics.unrealizedProfitLoss, -10000.0);
      expect(metrics.returnPercentage, -20.0);
      expect(metrics.isProfit, isFalse);
    });

    test('calculateAssetAllocation calculates accurate percentage weights', () {
      final holdings = [
        InvestmentEntity(
          id: 'i1',
          name: 'Nifty 50 Index',
          assetClass: AssetClass.equity,
          investedAmount: 50000.0,
          currentValue: 60000.0, // 60% of 1,00,000
          createdAt: now,
          updatedAt: now,
        ),
        InvestmentEntity(
          id: 'i2',
          name: 'Sovereign Gold Bond',
          assetClass: AssetClass.gold,
          investedAmount: 15000.0,
          currentValue: 20000.0, // 20% of 1,00,000
          createdAt: now,
          updatedAt: now,
        ),
        InvestmentEntity(
          id: 'i3',
          name: 'SBI Fixed Deposit',
          assetClass: AssetClass.debt,
          investedAmount: 20000.0,
          currentValue: 20000.0, // 20% of 1,00,000
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final allocations = FinancialCalculator.calculateAssetAllocation(holdings);

      expect(allocations.length, 3);
      expect(allocations.first.assetClass, AssetClass.equity);
      expect(allocations.first.percentageOfPortfolio, 60.0);
      expect(allocations[1].percentageOfPortfolio, 20.0);
      expect(allocations[2].percentageOfPortfolio, 20.0);
    });

    test('calculateOverallPortfolioSummary aggregates portfolio totals', () {
      final holdings = [
        InvestmentEntity(
          id: 'i1',
          name: 'Nifty 50 Index',
          assetClass: AssetClass.equity,
          investedAmount: 100000.0,
          currentValue: 120000.0,
          createdAt: now,
          updatedAt: now,
        ),
        InvestmentEntity(
          id: 'i2',
          name: 'HDFC PPF',
          assetClass: AssetClass.retirement,
          investedAmount: 50000.0,
          currentValue: 55000.0,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final summary = FinancialCalculator.calculateOverallPortfolioSummary(holdings);

      expect(summary.totalInvested, 150000.0);
      expect(summary.totalCurrentValue, 175000.0);
      expect(summary.totalProfitLoss, 25000.0);
      expect(summary.overallReturnPercentage, closeTo(16.66, 0.1));
      expect(summary.isProfit, isTrue);
      expect(summary.totalHoldingsCount, 2);
    });
  });
}
