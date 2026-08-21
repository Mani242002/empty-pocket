import 'package:flutter_test/flutter_test.dart';
import 'package:empty_pocket/core/domain/entities/investment_entity.dart';
import 'package:empty_pocket/core/repositories/investment_repository.dart';

void main() {
  group('InvestmentRepository (In-Memory)', () {
    late InMemoryInvestmentRepository repository;
    final now = DateTime.now();

    setUp(() {
      repository = InMemoryInvestmentRepository();
    });

    test('saveInvestment and getAllInvestments works properly', () async {
      final inv = InvestmentEntity(
        id: 'i1',
        name: 'Tata Consultancy Services',
        assetClass: AssetClass.equity,
        investedAmount: 75000.0,
        currentValue: 90000.0,
        institution: 'Zerodha',
        createdAt: now,
        updatedAt: now,
      );

      await repository.saveInvestment(inv);
      final list = await repository.getAllInvestments();

      expect(list.length, 1);
      expect(list.first.name, 'Tata Consultancy Services');
      expect(list.first.institution, 'Zerodha');
      expect(list.first.currentValue, 90000.0);
    });

    test('deleteInvestment removes record', () async {
      final inv = InvestmentEntity(
        id: 'i1',
        name: 'Fixed Deposit',
        assetClass: AssetClass.debt,
        investedAmount: 50000.0,
        currentValue: 53500.0,
        createdAt: now,
        updatedAt: now,
      );

      await repository.saveInvestment(inv);
      expect((await repository.getAllInvestments()).length, 1);

      await repository.deleteInvestment('i1');
      expect((await repository.getAllInvestments()).isEmpty, isTrue);
    });
  });
}
