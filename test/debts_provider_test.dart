import 'package:flutter_test/flutter_test.dart';
import 'package:empty_pocket/core/domain/entities/debt_entity.dart';
import 'package:empty_pocket/core/repositories/debt_repository.dart';

void main() {
  group('DebtRepository (In-Memory)', () {
    late InMemoryDebtRepository repository;
    final now = DateTime.now();

    setUp(() {
      repository = InMemoryDebtRepository();
    });

    test('saveDebt and getAllDebts works properly', () async {
      final debt = DebtEntity(
        id: 'd1',
        title: 'HDFC Home Loan',
        type: DebtType.homeLoan,
        principalAmount: 2500000.0,
        remainingAmount: 2400000.0,
        interestRate: 8.5,
        tenureMonths: 240,
        monthlyEmi: 21696.0,
        startDate: now,
        dueDateDay: 5,
        lenderName: 'HDFC Bank',
        createdAt: now,
        updatedAt: now,
      );

      await repository.saveDebt(debt);
      final list = await repository.getAllDebts();

      expect(list.length, 1);
      expect(list.first.title, 'HDFC Home Loan');
      expect(list.first.principalAmount, 2500000.0);
      expect(list.first.lenderName, 'HDFC Bank');
    });

    test('addPayment and getPaymentsForDebt works properly', () async {
      final payment = DebtPaymentEntity(
        id: 'p1',
        debtId: 'd1',
        amount: 21696.0,
        principalPortion: 4696.0,
        interestPortion: 17000.0,
        date: now,
        notes: 'Monthly EMI Auto-debit',
        createdAt: now,
      );

      await repository.addPayment(payment);
      final list = await repository.getPaymentsForDebt('d1');

      expect(list.length, 1);
      expect(list.first.amount, 21696.0);
      expect(list.first.notes, 'Monthly EMI Auto-debit');
    });

    test('deleteDebt removes debt and associated payments', () async {
      final debt = DebtEntity(
        id: 'd1',
        title: 'Car Loan',
        type: DebtType.carLoan,
        principalAmount: 500000.0,
        remainingAmount: 500000.0,
        monthlyEmi: 15000.0,
        startDate: now,
        createdAt: now,
        updatedAt: now,
      );

      await repository.saveDebt(debt);
      await repository.addPayment(
        DebtPaymentEntity(
          id: 'p1',
          debtId: 'd1',
          amount: 15000,
          date: now,
          createdAt: now,
        ),
      );

      expect((await repository.getAllDebts()).length, 1);
      expect((await repository.getPaymentsForDebt('d1')).length, 1);

      await repository.deleteDebt('d1');

      expect((await repository.getAllDebts()).isEmpty, isTrue);
      expect((await repository.getPaymentsForDebt('d1')).isEmpty, isTrue);
    });
  });
}
