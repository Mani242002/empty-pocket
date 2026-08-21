import 'package:flutter_test/flutter_test.dart';
import 'package:empty_pocket/core/domain/entities/transaction_entity.dart';
import 'package:empty_pocket/core/repositories/transaction_repository.dart';

void main() {
  group('TransactionRepository (In-Memory)', () {
    late InMemoryTransactionRepository repository;
    final now = DateTime.now();

    setUp(() {
      repository = InMemoryTransactionRepository();
    });

    test('add and getAllTransactions returns inserted transactions', () async {
      final tx = TransactionEntity(
        id: 'tx-1',
        title: 'Dinner',
        amount: 450.0,
        type: TransactionType.expense,
        category: 'Food & Dining',
        date: now,
        paymentSource: 'UPI / Wallet',
        createdAt: now,
        updatedAt: now,
      );

      await repository.addTransaction(tx);
      final list = await repository.getAllTransactions();

      expect(list.length, 1);
      expect(list.first.id, 'tx-1');
      expect(list.first.title, 'Dinner');
      expect(list.first.amount, 450.0);
    });

    test('updateTransaction modifies existing record', () async {
      final tx = TransactionEntity(
        id: 'tx-1',
        title: 'Dinner',
        amount: 450.0,
        type: TransactionType.expense,
        category: 'Food & Dining',
        date: now,
        paymentSource: 'UPI / Wallet',
        createdAt: now,
        updatedAt: now,
      );

      await repository.addTransaction(tx);
      final updated = tx.copyWith(title: 'Fancy Dinner', amount: 900.0);
      await repository.updateTransaction(updated);

      final list = await repository.getAllTransactions();
      expect(list.length, 1);
      expect(list.first.title, 'Fancy Dinner');
      expect(list.first.amount, 900.0);
    });

    test('deleteTransaction removes record', () async {
      final tx = TransactionEntity(
        id: 'tx-1',
        title: 'Coffee',
        amount: 120.0,
        type: TransactionType.expense,
        category: 'Food & Dining',
        date: now,
        paymentSource: 'Cash',
        createdAt: now,
        updatedAt: now,
      );

      await repository.addTransaction(tx);
      expect((await repository.getAllTransactions()).length, 1);

      await repository.deleteTransaction('tx-1');
      expect((await repository.getAllTransactions()).isEmpty, isTrue);
    });

    test('clearAllTransactions wipes all records', () async {
      await repository.addTransaction(
        TransactionEntity(
          id: '1',
          title: 'A',
          amount: 10,
          type: TransactionType.expense,
          category: 'Food',
          date: now,
          paymentSource: 'Cash',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await repository.addTransaction(
        TransactionEntity(
          id: '2',
          title: 'B',
          amount: 20,
          type: TransactionType.income,
          category: 'Salary',
          date: now,
          paymentSource: 'Bank',
          createdAt: now,
          updatedAt: now,
        ),
      );

      expect((await repository.getAllTransactions()).length, 2);
      await repository.clearAllTransactions();
      expect((await repository.getAllTransactions()).isEmpty, isTrue);
    });
  });
}
