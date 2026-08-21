import 'package:flutter_test/flutter_test.dart';
import 'package:empty_pocket/core/domain/entities/savings_goal_entity.dart';
import 'package:empty_pocket/core/repositories/savings_goal_repository.dart';

void main() {
  group('SavingsGoalRepository (In-Memory)', () {
    late InMemorySavingsGoalRepository repository;
    final now = DateTime.now();

    setUp(() {
      repository = InMemorySavingsGoalRepository();
    });

    test('saveGoal and getAllGoals works properly', () async {
      final goal = SavingsGoalEntity(
        id: 'g1',
        title: 'Emergency Fund',
        targetAmount: 150000.0,
        currentAmount: 20000.0,
        category: 'Emergency Fund',
        targetDate: now.add(const Duration(days: 365)),
        isEmergencyFund: true,
        status: GoalStatus.active,
        createdAt: now,
        updatedAt: now,
      );

      await repository.saveGoal(goal);
      final list = await repository.getAllGoals();

      expect(list.length, 1);
      expect(list.first.title, 'Emergency Fund');
      expect(list.first.isEmergencyFund, isTrue);
    });

    test('addContribution and getContributionsForGoal works properly', () async {
      final contribution = GoalContributionEntity(
        id: 'c1',
        goalId: 'g1',
        amount: 10000.0,
        date: now,
        notes: 'Monthly allocation',
        createdAt: now,
      );

      await repository.addContribution(contribution);
      final list = await repository.getContributionsForGoal('g1');

      expect(list.length, 1);
      expect(list.first.amount, 10000.0);
      expect(list.first.notes, 'Monthly allocation');
    });

    test('deleteGoal removes goal and associated contributions', () async {
      final goal = SavingsGoalEntity(
        id: 'g1',
        title: 'Emergency Fund',
        targetAmount: 150000.0,
        currentAmount: 20000.0,
        category: 'Emergency Fund',
        targetDate: now.add(const Duration(days: 365)),
        isEmergencyFund: true,
        status: GoalStatus.active,
        createdAt: now,
        updatedAt: now,
      );

      await repository.saveGoal(goal);
      await repository.addContribution(
        GoalContributionEntity(
          id: 'c1',
          goalId: 'g1',
          amount: 5000,
          date: now,
          createdAt: now,
        ),
      );

      expect((await repository.getAllGoals()).length, 1);
      expect((await repository.getContributionsForGoal('g1')).length, 1);

      await repository.deleteGoal('g1');

      expect((await repository.getAllGoals()).isEmpty, isTrue);
      expect((await repository.getContributionsForGoal('g1')).isEmpty, isTrue);
    });
  });
}
