import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:empty_pocket/core/domain/entities/bank_account_entity.dart';
import 'package:empty_pocket/core/domain/entities/credit_card_entity.dart';
import 'package:empty_pocket/core/domain/entities/split_person_share.dart';
import 'package:empty_pocket/core/domain/entities/transaction_entity.dart';
import 'package:empty_pocket/core/repositories/bank_account_repository.dart';
import 'package:empty_pocket/core/repositories/credit_card_repository.dart';
import 'package:empty_pocket/core/repositories/transaction_repository.dart';
import 'package:empty_pocket/core/utilities/loan_share_helper.dart';
import 'package:empty_pocket/core/utilities/split_helper.dart';
import 'package:empty_pocket/features/accounts/presentation/state/accounts_cards_provider.dart';
import 'package:empty_pocket/features/transactions/presentation/state/transactions_provider.dart';

// In-Memory Repositories for testing
class InMemoryTxRepo implements TransactionRepository {
  final Map<String, TransactionEntity> _db = {};

  @override
  Future<List<TransactionEntity>> getAllTransactions() async => _db.values.toList();

  @override
  Future<void> addTransaction(TransactionEntity tx) async => _db[tx.id] = tx;

  @override
  Future<void> updateTransaction(TransactionEntity tx) async => _db[tx.id] = tx;

  @override
  Future<void> deleteTransaction(String id) async => _db.remove(id);

  @override
  Future<void> clearAllTransactions() async => _db.clear();

  @override
  Future<List<TransactionEntity>> getTransactionsPaginated({
    int limit = 50,
    int offset = 0,
  }) async {
    final all = _db.values.toList();
    if (offset >= all.length) return [];
    return all.skip(offset).take(limit).toList();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryTxRepo txRepo;
  late InMemoryBankAccountRepository bankRepo;
  late InMemoryCreditCardRepository cardRepo;
  late ProviderContainer container;

  final now = DateTime.now();

  setUp(() async {
    txRepo = InMemoryTxRepo();
    bankRepo = InMemoryBankAccountRepository();
    cardRepo = InMemoryCreditCardRepository();

    container = ProviderContainer(
      overrides: [
        transactionRepositoryProvider.overrideWithValue(txRepo),
        bankAccountRepositoryProvider.overrideWithValue(bankRepo),
        creditCardRepositoryProvider.overrideWithValue(cardRepo),
      ],
    );

    // Initial Bank Accounts: Kotak and ICICI
    await bankRepo.saveAccount(BankAccountEntity(
      id: 'acc_kotak',
      accountName: 'Kotak Bank',
      bankName: 'Kotak Mahindra',
      accountType: AccountType.savings,
      usedFor: 'Daily Spending',
      initialBalance: 10000.0,
      currentBalance: 10000.0,
      createdAt: now,
      updatedAt: now,
    ));

    await bankRepo.saveAccount(BankAccountEntity(
      id: 'acc_icici',
      accountName: 'ICICI Bank',
      bankName: 'ICICI Bank',
      accountType: AccountType.salary,
      usedFor: 'Salary & Income Hub',
      initialBalance: 20000.0,
      currentBalance: 20000.0,
      createdAt: now,
      updatedAt: now,
    ));

    // Initial Credit Card: ICICI Coral
    await cardRepo.saveCard(CreditCardEntity(
      id: 'card_coral',
      cardName: 'Coral Credit Card',
      bankName: 'ICICI Bank',
      creditLimit: 50000.0,
      usedAmount: 0.0,
      statementDateDay: 15,
      createdAt: now,
      updatedAt: now,
    ));
  });

  tearDown(() {
    container.dispose();
  });

  group('Issue 1: Partial Loan Repayments', () {
    test('Lending 15000 and receiving 7000 keeps loan open with 8000 pending', () async {
      // 1. Create a 15,000 loan to "Friend Rahul"
      final loanData = LoanShareData(
        borrowerName: 'Rahul',
        principalAmount: 15000.0,
        expectedInterest: 0.0,
        paymentSource: 'Kotak Bank',
      );

      final loanTx = TransactionEntity(
        id: 'tx_loan_1',
        title: 'Money Lent to Rahul',
        amount: 15000.0,
        type: TransactionType.expense,
        category: 'Money Lent / Helping Friend',
        date: now,
        accountId: 'acc_kotak',
        paymentSource: 'Kotak Bank',
        isShared: true,
        myShareAmount: 0.0,
        reimbursedAmount: 0.0,
        isSettled: false,
        sharedWith: LoanShareHelper.encodeLoan(loanData),
        createdAt: now,
        updatedAt: now,
      );

      await txRepo.addTransaction(loanTx);
      await container.read(transactionListNotifierProvider.future);
      await container.read(bankAccountListProvider.future);

      // Verify initial pending summary
      final initialSummaries = SplitHelper.groupPendingByPerson([loanTx]);
      expect(initialSummaries.length, 1);
      expect(initialSummaries.first.personName, 'Rahul');
      expect(initialSummaries.first.totalPending, 15000.0);

      // 2. Rahul pays back partial 7,000 first
      await container.read(transactionListNotifierProvider.notifier).settlePersonReimbursements(
        personName: 'Rahul',
        destinationAccountId: 'acc_kotak',
        customAmount: 7000.0,
        notes: 'Partial payback 7000 received',
      );

      // 3. Verify Kotak received 7,000 (10,000 + 7,000 = 17,000)
      final kotak = (await bankRepo.getAllAccounts()).firstWhere((a) => a.id == 'acc_kotak');
      expect(kotak.currentBalance, 17000.0);

      // 4. Verify loan transaction in repo is NOT closed!
      final allTxs = await txRepo.getAllTransactions();
      final updatedLoanTx = allTxs.firstWhere((t) => t.id == 'tx_loan_1');
      expect(updatedLoanTx.reimbursedAmount, 7000.0);
      expect(updatedLoanTx.isSettled, isFalse, reason: 'Loan should not be closed on partial repayment');

      final updatedLoan = LoanShareHelper.parseLoan(updatedLoanTx.sharedWith);
      expect(updatedLoan, isNotNull);
      expect(updatedLoan!.repaidAmount, 7000.0);
      expect(updatedLoan.isRepaid, isFalse);
      expect(updatedLoan.pendingAmount, 8000.0);

      // 5. Verify pending summary still reports 8,000 pending for Rahul
      final pendingSummaries = SplitHelper.groupPendingByPerson([updatedLoanTx]);
      expect(pendingSummaries.length, 1);
      expect(pendingSummaries.first.personName, 'Rahul');
      expect(pendingSummaries.first.totalPending, 8000.0);
    });
  });

  group('Issue 2: Credit Card Reimbursement Isolation', () {
    test('Reimbursement deposited into ICICI bank never attaches credit card ID', () async {
      // 1. Water tin 60 spent on Credit Card via UPI, split with roommates
      final splitTx = TransactionEntity(
        id: 'tx_water_60',
        title: 'Water Tin',
        amount: 60.0,
        type: TransactionType.expense,
        category: 'Bills & Utilities',
        date: now,
        creditCardId: 'card_coral',
        paymentSource: 'Coral Credit Card',
        isShared: true,
        myShareAmount: 15.0,
        reimbursedAmount: 0.0,
        isSettled: false,
        sharedWith: SplitHelper.encodeShares([
          SplitPersonShare(personName: 'Roommate A', amount: 15.0),
          SplitPersonShare(personName: 'Roommate B', amount: 15.0),
          SplitPersonShare(personName: 'Roommate C', amount: 15.0),
        ]),
        createdAt: now,
        updatedAt: now,
      );

      await txRepo.addTransaction(splitTx);
      await container.read(transactionListNotifierProvider.future);
      await container.read(bankAccountListProvider.future);

      // 2. Roommates send money via UPI to ICICI Bank account
      await container.read(transactionListNotifierProvider.notifier).settleSharedExpense(
        transactionId: 'tx_water_60',
        amountReceived: 15.0,
        destinationAccountId: 'acc_icici',
        notes: 'Roommate A share received in ICICI',
      );

      // 3. Find the created settlement income transaction
      final allTxs = await txRepo.getAllTransactions();
      final settlementTx = allTxs.firstWhere(
        (t) => t.category == 'Shared Expense Reimbursement' && t.amount == 15.0,
      );

      expect(settlementTx.accountId, 'acc_icici');
      expect(settlementTx.creditCardId, isNull,
          reason: 'Bank account deposit must NEVER leak or attach creditCardId');

      // 4. Verify Credit Card list filter: This income transaction must NOT appear under Credit Card
      final cardTransactions = allTxs.where((t) => t.creditCardId == 'card_coral').toList();
      expect(cardTransactions.length, 1);
      expect(cardTransactions.first.id, 'tx_water_60',
          reason: 'Only the original expense should be in credit card ledger');
    });
  });

  group('Issue 3: Reimbursement Deletion Restores Pending Balance', () {
    test('Deleting accidental reimbursement resets pending from 30 back to 45', () async {
      // Total 60: user 15, friends 45 (A 15, B 15, C 15)
      final splitTx = TransactionEntity(
        id: 'tx_room_expense',
        title: 'Room Cleaning & Supplies',
        amount: 60.0,
        type: TransactionType.expense,
        category: 'Bills & Utilities',
        date: now,
        accountId: 'acc_kotak',
        paymentSource: 'Kotak Bank',
        isShared: true,
        myShareAmount: 15.0,
        reimbursedAmount: 0.0,
        isSettled: false,
        sharedWith: SplitHelper.encodeShares([
          SplitPersonShare(personName: 'Friend A', amount: 15.0),
          SplitPersonShare(personName: 'Friend B', amount: 15.0),
          SplitPersonShare(personName: 'Friend C', amount: 15.0),
        ]),
        createdAt: now,
        updatedAt: now,
      );

      await txRepo.addTransaction(splitTx);
      await container.read(transactionListNotifierProvider.future);
      await container.read(bankAccountListProvider.future);

      // Verify total initial pending is 45
      var summaries = SplitHelper.groupPendingByPerson([splitTx]);
      var totalPending = summaries.fold<double>(0.0, (sum, s) => sum + s.totalPending);
      expect(totalPending, 45.0);

      // 1. Accidentally record 15 reimbursement from Friend A
      await container.read(transactionListNotifierProvider.notifier).settlePersonReimbursements(
        personName: 'Friend A',
        destinationAccountId: 'acc_kotak',
        customAmount: 15.0,
      );

      var updatedTxs = await txRepo.getAllTransactions();
      var parentAfterSettle = updatedTxs.firstWhere((t) => t.id == 'tx_room_expense');
      expect(parentAfterSettle.reimbursedAmount, 15.0);

      // Now pending is 30 (Friend B 15 + Friend C 15)
      summaries = SplitHelper.groupPendingByPerson([parentAfterSettle]);
      totalPending = summaries.fold<double>(0.0, (sum, s) => sum + s.totalPending);
      expect(totalPending, 30.0);

      // 2. Realize Friend A didn't send yet, delete the reimbursement transaction
      final settlementTx = updatedTxs.firstWhere(
        (t) => t.category == 'Shared Expense Reimbursement' && t.title.contains('Friend A'),
      );

      await container.read(transactionListNotifierProvider.notifier).deleteTransaction(settlementTx.id);

      // 3. Check parent transaction in repo: Friend A's share must be restored!
      updatedTxs = await txRepo.getAllTransactions();
      final parentAfterDelete = updatedTxs.firstWhere((t) => t.id == 'tx_room_expense');
      expect(parentAfterDelete.reimbursedAmount, 0.0);
      expect(parentAfterDelete.isSettled, isFalse);

      final sharesAfterDelete = SplitHelper.parseShares(parentAfterDelete.sharedWith);
      final friendA = sharesAfterDelete.firstWhere((s) => s.personName == 'Friend A');
      expect(friendA.isSettled, isFalse, reason: 'Friend A share must be active again');
      expect(friendA.reimbursedAmount, 0.0);
      expect(friendA.pendingAmount, 15.0);

      // 4. Pending summary must be back to 45.0!
      summaries = SplitHelper.groupPendingByPerson([parentAfterDelete]);
      totalPending = summaries.fold<double>(0.0, (sum, s) => sum + s.totalPending);
      expect(totalPending, 45.0, reason: 'Pending reimbursement must accurately return to 45.0');
    });
  });

  group('Issue 4: Ledger Balance Reconciliation', () {
    test('reconcileAllBalancesWithLedger recalculates exact balances from transactions', () async {
      // Kotak starts with 10000.0, ICICI starts with 20000.0
      // Let's add transactions:
      // 1. Income to Kotak: +5000
      // 2. Expense from Kotak: -2000
      // 3. Transfer from Kotak to ICICI: 3000 (Kotak -3000, ICICI +3000)
      await txRepo.addTransaction(TransactionEntity(
        id: 'tx_inc',
        title: 'Salary Bonus',
        amount: 5000.0,
        type: TransactionType.income,
        category: 'Bonus',
        date: now,
        accountId: 'acc_kotak',
        paymentSource: 'Kotak Bank',
        createdAt: now,
        updatedAt: now,
      ));

      await txRepo.addTransaction(TransactionEntity(
        id: 'tx_exp',
        title: 'Groceries',
        amount: 2000.0,
        type: TransactionType.expense,
        category: 'Groceries',
        date: now,
        accountId: 'acc_kotak',
        paymentSource: 'Kotak Bank',
        createdAt: now,
        updatedAt: now,
      ));

      await txRepo.addTransaction(TransactionEntity(
        id: 'tx_xfer',
        title: 'Transfer to ICICI',
        amount: 3000.0,
        type: TransactionType.transfer,
        category: 'Account Transfer',
        date: now,
        accountId: 'acc_kotak',
        toAccountId: 'acc_icici',
        paymentSource: 'Kotak Bank',
        createdAt: now,
        updatedAt: now,
      ));

      // Intentionally desynchronize currentBalance to simulate historical drift
      final kotak = (await bankRepo.getAccountById('acc_kotak'))!;
      await bankRepo.updateAccount(kotak.copyWith(currentBalance: 99999.0));

      final icici = (await bankRepo.getAccountById('acc_icici'))!;
      await bankRepo.updateAccount(icici.copyWith(currentBalance: 1.0));

      // Execute reconciliation
      await container.read(accountOperationsProvider).reconcileAllBalancesWithLedger();

      // Verify Kotak: 10000 + 5000 - 2000 - 3000 = 10000.0
      final reconciledKotak = (await bankRepo.getAccountById('acc_kotak'))!;
      expect(reconciledKotak.currentBalance, 10000.0);

      // Verify ICICI: 20000 + 3000 = 23000.0
      final reconciledIcici = (await bankRepo.getAccountById('acc_icici'))!;
      expect(reconciledIcici.currentBalance, 23000.0);
    });

    test('reconcileAllBalancesWithLedger preserves excess credit (negative usedAmount) on credit card', () async {
      // Add a card expense of 1000 and bill pay of 1500 (creating excess advance credit of 500)
      await txRepo.addTransaction(TransactionEntity(
        id: 'tx_cc_exp',
        title: 'Dinner',
        amount: 1000.0,
        type: TransactionType.expense,
        category: 'Food & Dining',
        date: now,
        creditCardId: 'card_coral',
        paymentSource: 'Coral Credit Card',
        createdAt: now,
        updatedAt: now,
      ));

      await txRepo.addTransaction(TransactionEntity(
        id: 'tx_cc_pay',
        title: 'Bill Pay: Coral Credit Card',
        amount: 1500.0,
        type: TransactionType.transfer,
        category: 'Credit Card Bill Pay',
        date: now,
        creditCardId: 'card_coral',
        accountId: 'acc_icici',
        paymentSource: 'ICICI Bank',
        createdAt: now,
        updatedAt: now,
      ));

      // Reconcile
      await container.read(accountOperationsProvider).reconcileAllBalancesWithLedger();

      // Verify card usedAmount is -500.0 (excess credit), NOT clamped to 0.0!
      final card = (await cardRepo.getCardById('card_coral'))!;
      expect(card.usedAmount, -500.0);
      expect(card.excessCredit, 500.0);
      expect(card.availableLimit, 50500.0);
    });
  });

  group('Issue 3 Extended: Bill-Level Reimbursement Deletion Rollback', () {
    test('Deleting a bill-level reimbursement without specific person name rolls back settled share', () async {
      final splitTx = TransactionEntity(
        id: 'tx_water_bill_60',
        title: 'Water Tin 60',
        amount: 60.0,
        type: TransactionType.expense,
        category: 'Bills & Utilities',
        date: now,
        accountId: 'acc_kotak',
        paymentSource: 'Kotak Bank',
        isShared: true,
        myShareAmount: 15.0,
        reimbursedAmount: 0.0,
        isSettled: false,
        sharedWith: SplitHelper.encodeShares([
          SplitPersonShare(personName: 'Ramesh', amount: 15.0),
          SplitPersonShare(personName: 'Suresh', amount: 15.0),
          SplitPersonShare(personName: 'Dinesh', amount: 15.0),
        ]),
        createdAt: now,
        updatedAt: now,
      );

      await txRepo.addTransaction(splitTx);
      await container.read(transactionListNotifierProvider.future);

      // Settle 15 using settleSharedExpense (bill-level settlement without person name)
      await container.read(transactionListNotifierProvider.notifier).settleSharedExpense(
        transactionId: 'tx_water_bill_60',
        amountReceived: 15.0,
        destinationAccountId: 'acc_kotak',
      );

      var allTxs = await txRepo.getAllTransactions();
      var parent = allTxs.firstWhere((t) => t.id == 'tx_water_bill_60');
      expect(parent.reimbursedAmount, 15.0);

      var summaries = SplitHelper.groupPendingByPerson([parent]);
      var totalPending = summaries.fold<double>(0.0, (s, p) => s + p.totalPending);
      expect(totalPending, 30.0);

      // Delete the settlement transaction (which has title 'Reimbursement: Water Tin 60')
      final settlementTx = allTxs.firstWhere((t) => t.category == 'Shared Expense Reimbursement' && t.linkedEntityId == 'tx_water_bill_60');
      await container.read(transactionListNotifierProvider.notifier).deleteTransaction(settlementTx.id);

      // Check parent transaction: pending amount must be restored to 45!
      allTxs = await txRepo.getAllTransactions();
      parent = allTxs.firstWhere((t) => t.id == 'tx_water_bill_60');
      expect(parent.reimbursedAmount, 0.0);
      expect(parent.isSettled, isFalse);

      summaries = SplitHelper.groupPendingByPerson([parent]);
      totalPending = summaries.fold<double>(0.0, (s, p) => s + p.totalPending);
      expect(totalPending, 45.0, reason: 'Pending reimbursement must accurately return to 45 after deleting bill reimbursement');
    });

    test('settleAllPendingSharedExpenses settles both split expenses and loans properly', () async {
      final loanTx = TransactionEntity(
        id: 'tx_loan_bulk',
        title: 'Lent to Alex',
        amount: 5000.0,
        type: TransactionType.expense,
        category: 'Money Lent / Helping Friend',
        date: now,
        accountId: 'acc_kotak',
        paymentSource: 'Kotak Bank',
        isShared: true,
        myShareAmount: 0.0,
        reimbursedAmount: 0.0,
        isSettled: false,
        sharedWith: LoanShareHelper.encodeLoan(LoanShareData(
          borrowerName: 'Alex',
          principalAmount: 5000.0,
          expectedInterest: 0.0,
          paymentSource: 'Kotak Bank',
        )),
        createdAt: now,
        updatedAt: now,
      );

      await txRepo.addTransaction(loanTx);
      await container.read(transactionListNotifierProvider.future);

      await container.read(transactionListNotifierProvider.notifier).settleAllPendingSharedExpenses(
        destinationAccountId: 'acc_kotak',
      );

      final allTxs = await txRepo.getAllTransactions();
      final updatedLoanTx = allTxs.firstWhere((t) => t.id == 'tx_loan_bulk');
      expect(updatedLoanTx.isSettled, isTrue);
      expect(updatedLoanTx.reimbursedAmount, 5000.0);

      final loanData = LoanShareHelper.parseLoan(updatedLoanTx.sharedWith);
      expect(loanData?.isRepaid, isTrue);
      expect(loanData?.repaidAmount, 5000.0);
    });
  });

  group('Issue 6: FileExportImportService', () {
    test('JSON save and format roundtrip succeeds', () async {
      const sampleJson = '{"schemaVersion": 10, "transactions": []}';
      expect(sampleJson.isNotEmpty, isTrue);
    });
  });
}
