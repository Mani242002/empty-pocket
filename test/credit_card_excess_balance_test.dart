import 'package:flutter_test/flutter_test.dart';
import 'package:empty_pocket/core/domain/entities/credit_card_entity.dart';
import 'package:empty_pocket/core/calculation/financial_calculator.dart';

void main() {
  group('Credit Card Excess Balance & Cashback Tests', () {
    final now = DateTime.now();

    test('Zero dues card receiving cashback has negative usedAmount, excess credit, and expanded available limit', () {
      final card = CreditCardEntity(
        id: 'card-1',
        cardName: 'Flipkart Axis',
        bankName: 'Axis Bank',
        creditLimit: 100000.0,
        usedAmount: 0.0,
        statementDateDay: 15,
        gracePeriodDays: 20,
        createdAt: now,
        updatedAt: now,
      );

      expect(card.currentDues, 0.0);
      expect(card.excessCredit, 0.0);
      expect(card.availableLimit, 100000.0);
      expect(card.utilizationRatio, 0.0);

      // Cashback of ₹3,988.00 received on card with zero dues
      // usedAmount becomes -3988.0
      final updatedCard = card.copyWith(usedAmount: -3988.0);

      expect(updatedCard.usedAmount, -3988.0);
      expect(updatedCard.currentDues, 0.0, reason: 'Current dues must remain 0.00 when in excess credit');
      expect(updatedCard.excessCredit, 3988.0, reason: 'Excess credit must be positive 3988.00');
      expect(updatedCard.availableLimit, 103988.0, reason: 'Available limit must expand by the excess credit');
      expect(updatedCard.utilizationRatio, 0.0, reason: 'Utilization ratio must not be negative');
      expect(updatedCard.utilizationHealth, CreditUtilizationHealth.optimal);
    });

    test('Card with partial dues receiving cashback reduces dues or creates excess credit', () {
      final card = CreditCardEntity(
        id: 'card-1',
        cardName: 'Flipkart Axis',
        bankName: 'Axis Bank',
        creditLimit: 100000.0,
        usedAmount: 2000.0,
        statementDateDay: 15,
        gracePeriodDays: 20,
        createdAt: now,
        updatedAt: now,
      );

      // Cashback of ₹5,000 received (delta = -5000)
      final afterCashback = card.copyWith(usedAmount: card.usedAmount - 5000.0);

      expect(afterCashback.usedAmount, -3000.0);
      expect(afterCashback.currentDues, 0.0);
      expect(afterCashback.excessCredit, 3000.0);
      expect(afterCashback.availableLimit, 103000.0);

      // Subsequent purchase of ₹1,000 draws down from excess credit
      final afterPurchase = afterCashback.copyWith(usedAmount: afterCashback.usedAmount + 1000.0);
      expect(afterPurchase.usedAmount, -2000.0);
      expect(afterPurchase.currentDues, 0.0);
      expect(afterPurchase.excessCredit, 2000.0);
      expect(afterPurchase.availableLimit, 102000.0);

      // Another purchase of ₹3,000 completely exhausts excess credit and creates ₹1,000 in dues
      final afterSecondPurchase = afterPurchase.copyWith(usedAmount: afterPurchase.usedAmount + 3000.0);
      expect(afterSecondPurchase.usedAmount, 1000.0);
      expect(afterSecondPurchase.currentDues, 1000.0);
      expect(afterSecondPurchase.excessCredit, 0.0);
      expect(afterSecondPurchase.availableLimit, 99000.0);
      expect(afterSecondPurchase.utilizationRatio, 1.0);
    });

    test('FinancialCalculator combines multiple cards with excess credit correctly', () {
      final cards = [
        CreditCardEntity(
          id: 'card-1',
          cardName: 'Flipkart Axis',
          bankName: 'Axis Bank',
          creditLimit: 100000.0,
          usedAmount: -3988.0, // Excess credit of 3988
          statementDateDay: 15,
          gracePeriodDays: 20,
          createdAt: now,
          updatedAt: now,
        ),
        CreditCardEntity(
          id: 'card-2',
          cardName: 'HDFC Regalia',
          bankName: 'HDFC Bank',
          creditLimit: 200000.0,
          usedAmount: 15000.0, // Dues of 15000
          statementDateDay: 10,
          gracePeriodDays: 20,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final summary = FinancialCalculator.calculateCombinedCreditSummary(cards);

      expect(summary.totalLimit, 300000.0);
      // Total used must only count actual dues (15000), not negative used
      expect(summary.totalUsed, 15000.0);
      // Available limit: 103988 + 185000 = 288988
      expect(summary.totalAvailable, 288988.0);
    });
  });
}
