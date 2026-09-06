import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:empty_pocket/core/domain/entities/bank_account_entity.dart';
import 'package:empty_pocket/core/domain/entities/split_person_share.dart';
import 'package:empty_pocket/core/domain/entities/transaction_entity.dart';
import 'package:empty_pocket/core/repositories/bank_account_repository.dart';
import 'package:empty_pocket/core/repositories/credit_card_repository.dart';
import 'package:empty_pocket/core/repositories/debt_repository.dart';
import 'package:empty_pocket/core/repositories/investment_repository.dart';
import 'package:empty_pocket/core/repositories/recurring_repository.dart';
import 'package:empty_pocket/core/repositories/savings_goal_repository.dart';
import 'package:empty_pocket/core/repositories/transaction_repository.dart';
import 'package:empty_pocket/core/services/saved_friends_service.dart';
import 'package:empty_pocket/core/utilities/split_helper.dart';
import 'package:empty_pocket/features/accounts/presentation/state/accounts_cards_provider.dart';
import 'package:empty_pocket/features/transactions/presentation/state/transactions_provider.dart';

void main() {
  group('SplitPersonShare & SplitHelper Unit Tests', () {
    test('SplitPersonShare serialization & copyWith', () {
      final share = SplitPersonShare(
        personName: 'Raji',
        amount: 250.0,
        reimbursedAmount: 50.0,
        isSettled: false,
      );

      expect(share.pendingAmount, 200.0);
      expect(share.isSettled, isFalse);

      final map = share.toMap();
      final fromMap = SplitPersonShare.fromMap(map);

      expect(fromMap.personName, 'Raji');
      expect(fromMap.amount, 250.0);
      expect(fromMap.reimbursedAmount, 50.0);
      expect(fromMap.pendingAmount, 200.0);
      expect(fromMap.isSettled, isFalse);

      final settled = share.copyWith(reimbursedAmount: 250.0, isSettled: true);
      expect(settled.pendingAmount, 0.0);
      expect(settled.isSettled, isTrue);
    });

    test('SplitHelper encodeShares and parseShares round-trip', () {
      final shares = [
        SplitPersonShare(personName: 'Raji', amount: 150.0),
        SplitPersonShare(personName: 'Susmitha', amount: 200.0, reimbursedAmount: 50.0),
      ];

      final encoded = SplitHelper.encodeShares(shares);
      expect(encoded, contains('"name":"Raji"'));
      expect(encoded, contains('"amount":150.0'));

      final parsed = SplitHelper.parseShares(encoded);
      expect(parsed.length, 2);
      expect(parsed[0].personName, 'Raji');
      expect(parsed[0].amount, 150.0);
      expect(parsed[0].pendingAmount, 150.0);
      expect(parsed[1].personName, 'Susmitha');
      expect(parsed[1].amount, 200.0);
      expect(parsed[1].pendingAmount, 150.0);
    });

    test('SplitHelper parseShares returns empty on plain text or invalid JSON', () {
      expect(SplitHelper.parseShares(null), isEmpty);
      expect(SplitHelper.parseShares(''), isEmpty);
      expect(SplitHelper.parseShares('Raji, Susmitha, Riya'), isEmpty);
      expect(SplitHelper.parseShares('{not an array}'), isEmpty);
    });

    test('SplitHelper formatDisplay returns clean names with amounts', () {
      final shares = [
        SplitPersonShare(personName: 'Raji', amount: 100.0),
        SplitPersonShare(personName: 'Susmitha', amount: 250.0),
      ];
      final display = SplitHelper.formatDisplay(shares);
      expect(display, contains('Raji'));
      expect(display, contains('Susmitha'));
    });

    test('SplitHelper groupPendingByPerson computes accurate summaries across multiple transactions', () {
      final now = DateTime.now();
      final tx1 = TransactionEntity(
        id: 'tx1',
        title: 'Dinner at Bawarchi',
        amount: 500.0,
        type: TransactionType.expense,
        category: 'Food & Dining',
        date: now,
        paymentSource: 'HDFC Savings',
        isShared: true,
        myShareAmount: 100.0,
        reimbursedAmount: 0.0,
        isSettled: false,
        sharedWith: SplitHelper.encodeShares([
          SplitPersonShare(personName: 'Raji', amount: 200.0),
          SplitPersonShare(personName: 'Susmitha', amount: 200.0),
        ]),
        createdAt: now,
        updatedAt: now,
      );

      final tx2 = TransactionEntity(
        id: 'tx2',
        title: 'Groceries',
        amount: 300.0,
        type: TransactionType.expense,
        category: 'Groceries',
        date: now,
        paymentSource: 'HDFC Savings',
        isShared: true,
        myShareAmount: 100.0,
        reimbursedAmount: 0.0,
        isSettled: false,
        sharedWith: SplitHelper.encodeShares([
          SplitPersonShare(personName: 'Raji', amount: 100.0),
          SplitPersonShare(personName: 'Susmitha', amount: 100.0),
        ]),
        createdAt: now,
        updatedAt: now,
      );

      final tx3Settled = TransactionEntity(
        id: 'tx3',
        title: 'Uber',
        amount: 200.0,
        type: TransactionType.expense,
        category: 'Transport',
        date: now,
        paymentSource: 'HDFC Savings',
        isShared: true,
        myShareAmount: 100.0,
        reimbursedAmount: 100.0,
        isSettled: true,
        sharedWith: SplitHelper.encodeShares([
          SplitPersonShare(personName: 'Raji', amount: 100.0, reimbursedAmount: 100.0, isSettled: true),
        ]),
        createdAt: now,
        updatedAt: now,
      );

      final summaries = SplitHelper.groupPendingByPerson([tx1, tx2, tx3Settled]);
      expect(summaries.length, 2);

      final raji = summaries.firstWhere((s) => s.personName == 'Raji');
      expect(raji.totalPending, 300.0); // 200 from tx1 + 100 from tx2
      expect(raji.expenseCount, 2);
      expect(raji.transactions.map((t) => t.id), containsAll(['tx1', 'tx2']));

      final susmitha = summaries.firstWhere((s) => s.personName == 'Susmitha');
      expect(susmitha.totalPending, 300.0); // 200 from tx1 + 100 from tx2
      expect(susmitha.expenseCount, 2);
    });
  });

  group('SavedFriendsService Unit Tests', () {
    test('addFriend, removeFriend, and default list', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SavedFriendsService();

      final initial = await service.getSavedFriends();
      expect(initial, isEmpty);

      await service.addFriend('  Rohan  ');
      final updated = await service.getSavedFriends();
      expect(updated, contains('Rohan'));

      // Duplicate should not be added
      await service.addFriend('rohan');
      final afterDup = await service.getSavedFriends();
      expect(afterDup.where((f) => f.toLowerCase() == 'rohan').length, 1);

      await service.removeFriend('Rohan');
      final afterRemove = await service.getSavedFriends();
      expect(afterRemove.contains('Rohan'), isFalse);
    });
  });

  group('TransactionsProvider Bulk Settlement Integration Tests', () {
    late InMemoryTransactionRepository txRepo;
    late InMemoryBankAccountRepository bankRepo;
    late ProviderContainer container;

    final now = DateTime.now();
    final testAccount = BankAccountEntity(
      id: 'acc1',
      accountName: 'HDFC Savings',
      bankName: 'HDFC',
      accountType: AccountType.savings,
      usedFor: AccountPurposeTags.dailySpending,
      initialBalance: 1000.0,
      currentBalance: 1000.0,
      isDefault: true,
      createdAt: now,
      updatedAt: now,
    );

    setUp(() {
      txRepo = InMemoryTransactionRepository();
      bankRepo = InMemoryBankAccountRepository([testAccount]);

      container = ProviderContainer(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(txRepo),
          bankAccountRepositoryProvider.overrideWithValue(bankRepo),
          creditCardRepositoryProvider.overrideWithValue(InMemoryCreditCardRepository()),
          savingsGoalRepositoryProvider.overrideWithValue(InMemorySavingsGoalRepository()),
          debtRepositoryProvider.overrideWithValue(InMemoryDebtRepository()),
          investmentRepositoryProvider.overrideWithValue(InMemoryInvestmentRepository()),
          recurringRepositoryProvider.overrideWithValue(InMemoryRecurringRepository()),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('settlePersonReimbursements clears that person across multiple bills and credits account', () async {
      final tx1 = TransactionEntity(
        id: 'tx1',
        title: 'Dinner at BBQ',
        amount: 600.0,
        type: TransactionType.expense,
        category: 'Food & Dining',
        date: now,
        accountId: 'acc1',
        paymentSource: 'HDFC Savings',
        isShared: true,
        myShareAmount: 200.0,
        reimbursedAmount: 0.0,
        isSettled: false,
        sharedWith: SplitHelper.encodeShares([
          SplitPersonShare(personName: 'Raji', amount: 200.0),
          SplitPersonShare(personName: 'Susmitha', amount: 200.0),
        ]),
        createdAt: now,
        updatedAt: now,
      );

      final tx2 = TransactionEntity(
        id: 'tx2',
        title: 'Movie Tickets',
        amount: 400.0,
        type: TransactionType.expense,
        category: 'Entertainment',
        date: now,
        accountId: 'acc1',
        paymentSource: 'HDFC Savings',
        isShared: true,
        myShareAmount: 200.0,
        reimbursedAmount: 0.0,
        isSettled: false,
        sharedWith: SplitHelper.encodeShares([
          SplitPersonShare(personName: 'Raji', amount: 200.0),
        ]),
        createdAt: now,
        updatedAt: now,
      );

      await txRepo.addTransaction(tx1);
      await txRepo.addTransaction(tx2);

      // Load transactions into notifier
      await container.read(transactionListNotifierProvider.future);
      await container.read(bankAccountListProvider.future);

      // Total owed by Raji across tx1 and tx2 is 400.0
      await container.read(transactionListNotifierProvider.notifier).settlePersonReimbursements(
        personName: 'Raji',
        destinationAccountId: 'acc1',
        notes: 'Raji settled via PhonePe',
      );

      // 1. Check Bank Account balance increased by 400.0 (1000 + 400 = 1400)
      final accounts = await bankRepo.getAllAccounts();
      final updatedAcc = accounts.firstWhere((a) => a.id == 'acc1');
      expect(updatedAcc.currentBalance, 1400.0);

      // 2. Check updated transactions in repository
      final allUpdated = await txRepo.getAllTransactions();
      final updatedTx1 = allUpdated.firstWhere((t) => t.id == 'tx1');
      expect(updatedTx1.reimbursedAmount, 200.0);
      expect(updatedTx1.isSettled, isFalse); // Susmitha still owes 200
      final tx1Shares = SplitHelper.parseShares(updatedTx1.sharedWith);
      final rajiShare1 = tx1Shares.firstWhere((s) => s.personName == 'Raji');
      expect(rajiShare1.isSettled, isTrue);
      expect(rajiShare1.pendingAmount, 0.0);

      final updatedTx2 = allUpdated.firstWhere((t) => t.id == 'tx2');
      expect(updatedTx2.reimbursedAmount, 200.0);
      expect(updatedTx2.isSettled, isTrue); // Raji was the only friend in tx2

      // 3. Check settlement income transaction was recorded
      final allTxs = await txRepo.getAllTransactions();
      final settlementTx = allTxs.firstWhere((t) => t.category == 'Shared Expense Reimbursement');
      expect(settlementTx.amount, 400.0);
      expect(settlementTx.type, TransactionType.income);
      expect(settlementTx.accountId, 'acc1');
      expect(settlementTx.title, contains('Raji'));
    });

    test('settleAllPendingSharedExpenses clears all pending reimbursements at once', () async {
      final tx1 = TransactionEntity(
        id: 'tx1',
        title: 'Electricity Bill',
        amount: 450.0,
        type: TransactionType.expense,
        category: 'Bills & Utilities',
        date: now,
        accountId: 'acc1',
        paymentSource: 'HDFC Savings',
        isShared: true,
        myShareAmount: 150.0,
        reimbursedAmount: 0.0,
        isSettled: false,
        sharedWith: SplitHelper.encodeShares([
          SplitPersonShare(personName: 'Raji', amount: 150.0),
          SplitPersonShare(personName: 'Susmitha', amount: 150.0),
        ]),
        createdAt: now,
        updatedAt: now,
      );

      final tx2 = TransactionEntity(
        id: 'tx2',
        title: 'WiFi Bill',
        amount: 300.0,
        type: TransactionType.expense,
        category: 'Bills & Utilities',
        date: now,
        accountId: 'acc1',
        paymentSource: 'HDFC Savings',
        isShared: true,
        myShareAmount: 100.0,
        reimbursedAmount: 0.0,
        isSettled: false,
        sharedWith: SplitHelper.encodeShares([
          SplitPersonShare(personName: 'Raji', amount: 100.0),
          SplitPersonShare(personName: 'Susmitha', amount: 100.0),
        ]),
        createdAt: now,
        updatedAt: now,
      );

      await txRepo.addTransaction(tx1);
      await txRepo.addTransaction(tx2);

      await container.read(transactionListNotifierProvider.future);
      await container.read(bankAccountListProvider.future);

      // Pending total across tx1 (300) and tx2 (200) = 500.0
      await container.read(transactionListNotifierProvider.notifier).settleAllPendingSharedExpenses(
        destinationAccountId: 'acc1',
        notes: 'Roommates cleared all pending balances',
      );

      // 1. Check Bank Account balance increased by 500.0 (1000 + 500 = 1500)
      final accounts = await bankRepo.getAllAccounts();
      final updatedAcc = accounts.firstWhere((a) => a.id == 'acc1');
      expect(updatedAcc.currentBalance, 1500.0);

      // 2. Both transactions are now fully settled
      final allUpdated = await txRepo.getAllTransactions();
      final updatedTx1 = allUpdated.firstWhere((t) => t.id == 'tx1');
      expect(updatedTx1.isSettled, isTrue);
      expect(updatedTx1.reimbursedAmount, 300.0);

      final updatedTx2 = allUpdated.firstWhere((t) => t.id == 'tx2');
      expect(updatedTx2.isSettled, isTrue);
      expect(updatedTx2.reimbursedAmount, 200.0);

      // 3. Single bulk income transaction was generated
      final allTxs = await txRepo.getAllTransactions();
      final settlementTx = allTxs.firstWhere((t) => t.category == 'Shared Expense Reimbursement');
      expect(settlementTx.amount, 500.0);
      expect(settlementTx.title, contains('All'));
    });

    test('settlePersonReimbursements with offset records net bank deposit and logs offset expense', () async {
      final tx1 = TransactionEntity(
        id: 'tx_offset_1',
        title: 'Dinner at Olive Garden',
        amount: 500.0,
        type: TransactionType.expense,
        category: 'Food & Dining',
        date: now,
        accountId: 'acc1',
        paymentSource: 'HDFC Savings',
        isShared: true,
        myShareAmount: 200.0,
        reimbursedAmount: 0.0,
        isSettled: false,
        sharedWith: SplitHelper.encodeShares([
          SplitPersonShare(personName: 'Raji', amount: 300.0),
        ]),
        createdAt: now,
        updatedAt: now,
      );

      await txRepo.addTransaction(tx1);
      await container.read(transactionListNotifierProvider.future);
      await container.read(bankAccountListProvider.future);

      // Raji owes 300, but user owed Raji 250 for previous outing.
      // Net cash received: 50. Offset expense: 250 (Food & Dining).
      await container.read(transactionListNotifierProvider.notifier).settlePersonReimbursements(
        personName: 'Raji',
        destinationAccountId: 'acc1',
        customAmount: 50.0,
        offsetExpenseAmount: 250.0,
        offsetExpenseCategory: 'Food & Dining',
        notes: 'Net settlement after offset',
      );

      // 1. Bank account balance increased by ONLY net received 50.0 (1000 + 50 = 1050)
      final accounts = await bankRepo.getAllAccounts();
      final updatedAcc = accounts.firstWhere((a) => a.id == 'acc1');
      expect(updatedAcc.currentBalance, 1050.0);

      // 2. Original split is 100% settled
      final allUpdated = await txRepo.getAllTransactions();
      final updatedTx1 = allUpdated.firstWhere((t) => t.id == 'tx_offset_1');
      expect(updatedTx1.isSettled, isTrue);

      // 3. Reimbursement income transaction was generated for 50.0
      final reimbursement = allUpdated.firstWhere(
        (t) => t.category == 'Shared Expense Reimbursement' && t.amount == 50.0,
      );
      expect(reimbursement.title, contains('Raji'));

      // 4. Offset expense transaction was generated for 250.0 under Food & Dining
      final offsetExpense = allUpdated.firstWhere(
        (t) => t.type == TransactionType.expense && t.amount == 250.0 && t.title.contains('Offset'),
      );
      expect(offsetExpense.category, 'Food & Dining');
      expect(offsetExpense.accountId, isNull); // no phantom double-deduction from bank
    });
  });
}

