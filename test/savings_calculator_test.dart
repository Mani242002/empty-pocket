import 'package:flutter_test/flutter_test.dart';
import 'package:empty_pocket/core/calculation/financial_calculator.dart';
import 'package:empty_pocket/core/domain/entities/savings_goal_entity.dart';

void main() {
  group('Savings Calculator Tests', () {
    final now = DateTime.now();
    final targetDate = DateTime(now.year + 1, now.month, now.day); // 12 months ahead

    test('calculateGoalProgress computes metrics for ongoing goal', () {
      final goal = SavingsGoalEntity(
        id: 'g1',
        title: 'Emergency Fund',
        targetAmount: 120000.0,
        currentAmount: 30000.0,
        category: 'Emergency Fund',
        targetDate: targetDate,
        isEmergencyFund: true,
        status: GoalStatus.active,
        createdAt: now,
        updatedAt: now,
      );

      final metrics = FinancialCalculator.calculateGoalProgress(goal);

      expect(metrics.percentage, 25.0);
      expect(metrics.remainingAmount, 90000.0);
      expect(metrics.isCompleted, isFalse);
      expect(metrics.monthsRemaining, 12);
      expect(metrics.recommendedMonthlySavings, 7500.0); // 90,000 / 12 = 7,500
    });

    test('calculateGoalProgress handles completed goal', () {
      final goal = SavingsGoalEntity(
        id: 'g2',
        title: 'Goa Weekend',
        targetAmount: 25000.0,
        currentAmount: 25000.0,
        category: 'Vacation & Travel',
        targetDate: targetDate,
        status: GoalStatus.completed,
        createdAt: now,
        updatedAt: now,
      );

      final metrics = FinancialCalculator.calculateGoalProgress(goal);

      expect(metrics.percentage, 100.0);
      expect(metrics.remainingAmount, 0.0);
      expect(metrics.isCompleted, isTrue);
      expect(metrics.recommendedMonthlySavings, 0.0);
    });

    test('calculateOverallSavingsSummary aggregates multiple goals', () {
      final goals = [
        SavingsGoalEntity(
          id: 'g1',
          title: 'Emergency Fund',
          targetAmount: 100000.0,
          currentAmount: 50000.0,
          category: 'Emergency Fund',
          targetDate: targetDate,
          createdAt: now,
          updatedAt: now,
        ),
        SavingsGoalEntity(
          id: 'g2',
          title: 'New Laptop',
          targetAmount: 80000.0,
          currentAmount: 80000.0,
          category: 'Gadget & Tech',
          targetDate: targetDate,
          status: GoalStatus.completed,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final summary = FinancialCalculator.calculateOverallSavingsSummary(goals);

      expect(summary.totalTarget, 180000.0);
      expect(summary.totalSaved, 130000.0);
      expect(summary.totalRemaining, 50000.0);
      expect(summary.overallPercentage, closeTo(72.22, 0.01));
      expect(summary.activeGoalsCount, 1);
      expect(summary.completedGoalsCount, 1);
    });

    test('calculateRecommendedEmergencyFund multiplies monthly expense', () {
      const averageMonthlyExpense = 35000.0;
      final recommended6Mo = FinancialCalculator.calculateRecommendedEmergencyFund(
        averageMonthlyExpense,
        months: 6,
      );
      final recommended3Mo = FinancialCalculator.calculateRecommendedEmergencyFund(
        averageMonthlyExpense,
        months: 3,
      );

      expect(recommended6Mo, 210000.0);
      expect(recommended3Mo, 105000.0);
    });
  });
}
