import 'package:flutter_test/flutter_test.dart';
import 'package:empty_pocket/core/calculation/financial_calculator.dart';
import 'package:empty_pocket/core/domain/entities/transaction_entity.dart';
import 'package:empty_pocket/core/services/overlay_service.dart';
import 'package:empty_pocket/core/utilities/category_matcher.dart';
import 'package:empty_pocket/core/utilities/math_expression_parser.dart';

void main() {
  group('CategoryMatcher Tests', () {
    test('Detects Food & Dining from food keywords', () {
      expect(CategoryMatcher.detectCategory('Swiggy Order #1234'), 'Food & Dining');
      expect(CategoryMatcher.detectCategory('Dinner at Starbucks cafe'), 'Food & Dining');
      expect(CategoryMatcher.detectCategory('McDonalds burger'), 'Food & Dining');
      expect(CategoryMatcher.detectCategory('Morning Coffee & Snack'), 'Food & Dining');
    });

    test('Detects Transportation from travel keywords', () {
      expect(CategoryMatcher.detectCategory('Uber trip to airport'), 'Transportation');
      expect(CategoryMatcher.detectCategory('Ola auto ride'), 'Transportation');
      expect(CategoryMatcher.detectCategory('HP Petrol pump fuel'), 'Transportation');
      expect(CategoryMatcher.detectCategory('Metro card recharge'), 'Transportation');
    });

    test('Detects Groceries from grocery keywords', () {
      expect(CategoryMatcher.detectCategory('Blinkit fast delivery'), 'Groceries');
      expect(CategoryMatcher.detectCategory('Zepto fresh veggies'), 'Groceries');
      expect(CategoryMatcher.detectCategory('Supermarket ration & milk'), 'Groceries');
    });

    test('Detects Shopping and Entertainment', () {
      expect(CategoryMatcher.detectCategory('Amazon Prime purchase'), 'Shopping');
      expect(CategoryMatcher.detectCategory('Netflix monthly subscription'), 'Entertainment');
      expect(CategoryMatcher.detectCategory('Spotify Family plan'), 'Entertainment');
    });

    test('Detects Bills & Utilities and Medical', () {
      expect(CategoryMatcher.detectCategory('Airtel wifi broadband bill'), 'Bills & Utilities');
      expect(CategoryMatcher.detectCategory('Electricity bescom bill'), 'Bills & Utilities');
      expect(CategoryMatcher.detectCategory('Apollo pharmacy medicine'), 'Health & Medical');
    });

    test('Returns null for unrecognized or empty keywords', () {
      expect(CategoryMatcher.detectCategory(''), isNull);
      expect(CategoryMatcher.detectCategory('   '), isNull);
      expect(CategoryMatcher.detectCategory('Random unique phrase 999'), isNull);
    });
  });

  group('MathExpressionParser Tests', () {
    test('Parses plain numbers directly', () {
      expect(MathExpressionParser.tryEvaluate('450'), 450.0);
      expect(MathExpressionParser.tryEvaluate('1250.75'), 1250.75);
      expect(MathExpressionParser.tryEvaluate('0'), 0.0);
    });

    test('Evaluates addition and subtraction', () {
      expect(MathExpressionParser.tryEvaluate('500 + 250'), 750.0);
      expect(MathExpressionParser.tryEvaluate('1000 - 350.50'), 649.50);
      expect(MathExpressionParser.tryEvaluate('100 + 200 + 300 - 50'), 550.0);
    });

    test('Evaluates multiplication and division with correct operator precedence', () {
      expect(MathExpressionParser.tryEvaluate('50 + 20 * 2'), 90.0);
      expect(MathExpressionParser.tryEvaluate('100 - 40 / 2'), 80.0);
      expect(MathExpressionParser.tryEvaluate('1200 / 3'), 400.0);
      expect(MathExpressionParser.tryEvaluate('25 * 4 + 10'), 110.0);
      expect(MathExpressionParser.tryEvaluate('25 x 4'), 100.0); // 'x' as multiply
      expect(MathExpressionParser.tryEvaluate('25 X 4'), 100.0); // 'X' as multiply
    });

    test('Safely handles division by zero and invalid inputs', () {
      expect(MathExpressionParser.tryEvaluate('100 / 0'), isNull);
      expect(MathExpressionParser.tryEvaluate('abc + 20'), isNull);
      expect(MathExpressionParser.tryEvaluate('++'), isNull);
      expect(MathExpressionParser.tryEvaluate(''), isNull);
      expect(MathExpressionParser.tryEvaluate('-500'), isNull); // negative amounts rejected
    });
  });

  group('FinancialCalculator Daily Safe to Spend Tests', () {
    test('Calculates safe to spend limit for remaining days in month', () {
      final testDate = DateTime(2026, 3, 15); // 31 days in March, 17 days remaining (15..31)
      final safeSpend = FinancialCalculator.calculateDailySafeToSpend(
        31000,
        14000,
        testDate,
      );
      // Remaining budget = 17000. Remaining days = 17. Safe to spend = 1000/day
      expect(safeSpend, 1000.0);
    });

    test('Handles 0 budget and overspent status', () {
      expect(FinancialCalculator.calculateDailySafeToSpend(0, 500), 0.0);
      expect(FinancialCalculator.calculateDailySafeToSpend(10000, 15000), 0.0);
    });
  });

  group('Overlay Service Sizing Tests', () {
    test('Standardizes window size across densities', () {
      expect(OverlayService.bubbleWindowSize, 60);
      expect(OverlayService.expandedWidth, 360);
      expect(OverlayService.expandedHeight, 640);
    });
  });

  group('Safe Financial Division Tests', () {
    test('Handles division by zero and invalid values safely', () {
      expect(FinancialCalculator.safeDivide(100, 0), 0.0);
      expect(FinancialCalculator.safeDivide(100, 0, -1.0), -1.0);
      expect(FinancialCalculator.safeDivide(100, 4), 25.0);
      expect(FinancialCalculator.safeDivide(10, 3), 3.33);
    });
  });

  group('Transfer vs Expense Double Counting Tests', () {
    test('Excludes transfer transactions from total expense calculations', () {
      final now = DateTime.now();
      final txs = [
        TransactionEntity(
          id: '1',
          title: 'Grocery',
          amount: 500,
          type: TransactionType.expense,
          category: 'Groceries',
          date: now,
          paymentSource: 'Credit Card',
          creditCardId: 'card_1',
          createdAt: now,
          updatedAt: now,
        ),
        TransactionEntity(
          id: '2',
          title: 'Credit Card Bill Pay',
          amount: 500,
          type: TransactionType.transfer,
          category: 'Credit Card Bill Pay',
          date: now,
          paymentSource: 'HDFC Bank',
          accountId: 'acc_1',
          creditCardId: 'card_1',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final totalExpense = FinancialCalculator.calculateTotalExpense(txs);
      expect(totalExpense, 500.0); // Only the actual expense is counted, NOT the bill payoff transfer!
    });
  });
}
