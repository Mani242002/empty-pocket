import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:empty_pocket/core/domain/entities/transaction_entity.dart';
import 'package:empty_pocket/core/repositories/transaction_repository.dart';
import 'package:empty_pocket/features/transactions/presentation/state/transactions_provider.dart';

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

    test('getTransactionsPaginated respects limit and offset', () async {
      for (int i = 0; i < 15; i++) {
        await repository.addTransaction(
          TransactionEntity(
            id: 'tx-$i',
            title: 'Item $i',
            amount: (i + 1) * 10.0,
            type: TransactionType.expense,
            category: 'General',
            date: now.subtract(Duration(days: i)),
            paymentSource: 'Cash',
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      final page1 = await repository.getTransactionsPaginated(limit: 5, offset: 0);
      expect(page1.length, 5);
      expect(page1.first.id, 'tx-0');

      final page2 = await repository.getTransactionsPaginated(limit: 5, offset: 5);
      expect(page2.length, 5);
      expect(page2.first.id, 'tx-5');

      final page3 = await repository.getTransactionsPaginated(limit: 10, offset: 10);
      expect(page3.length, 5);
      expect(page3.first.id, 'tx-10');

      final emptyPage = await repository.getTransactionsPaginated(limit: 5, offset: 20);
      expect(emptyPage.isEmpty, isTrue);
    });
  });

  group('TransactionListNotifier & Analytics Integrity', () {
    test('loads complete history to preserve multi-month analytics while supporting chunked loadMore and loadAll', () async {
      final now = DateTime.now();
      final items = List.generate(
        150,
        (i) => TransactionEntity(
          id: 'bulk-$i',
          title: 'Bulk $i',
          amount: 100.0,
          type: TransactionType.expense,
          category: 'Shopping',
          date: now.subtract(Duration(minutes: i)),
          paymentSource: 'UPI',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final mockRepo = InMemoryTransactionRepository(items);
      final container = ProviderContainer(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );

      final notifier = container.read(transactionListNotifierProvider.notifier);
      final initialList = await container.read(transactionListNotifierProvider.future);

      // Verify complete history is loaded so derived monthly analytics and streaks are never truncated
      expect(initialList.length, 150);
      expect(notifier.currentLimit, 150);

      // Load more / custom pagination
      await notifier.loadMore(pageSize: 50);
      final expandedList = container.read(transactionListNotifierProvider).value!;
      expect(expandedList.length, 150);

      // Load all
      await notifier.loadAll();
      final allList = container.read(transactionListNotifierProvider).value!;
      expect(allList.length, 150);
      expect(notifier.hasMore, isFalse);
    });
  });
}

