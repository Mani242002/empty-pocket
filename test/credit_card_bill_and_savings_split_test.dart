import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:empty_pocket/core/calculation/financial_calculator.dart';
import 'package:empty_pocket/core/domain/entities/bank_account_entity.dart';
import 'package:empty_pocket/core/domain/entities/budget_entity.dart';
import 'package:empty_pocket/core/domain/entities/credit_card_entity.dart';
import 'package:empty_pocket/core/domain/entities/savings_goal_entity.dart';
import 'package:empty_pocket/core/domain/entities/transaction_entity.dart';
import 'package:empty_pocket/core/repositories/bank_account_repository.dart';
import 'package:empty_pocket/core/repositories/credit_card_repository.dart';
import 'package:empty_pocket/core/repositories/savings_goal_repository.dart';
import 'package:empty_pocket/core/repositories/transaction_repository.dart';
import 'package:empty_pocket/features/accounts/presentation/state/accounts_cards_provider.dart';
import 'package:empty_pocket/features/savings/presentation/state/savings_goals_provider.dart';
import 'package:empty_pocket/features/transactions/presentation/state/transactions_provider.dart';

class InMemoryTxRepo implements TransactionRepository {
  final Map<String, TransactionEntity> _db = {};

  @override
  Future<List<TransactionEntity>> getAllTransactions() async => _db.values.toList();

  @override
  Future<void> addTransaction(TransactionEntity tx) async => _db[tx.id] = tx;

  @override
  Future<void> addTransactions(List<TransactionEntity> transactions) async {
    for (final tx in transactions) {
      _db[tx.id] = tx;
    }
  }

  @override
  Future<void> updateTransaction(TransactionEntity tx) async => _db[tx.id] = tx;

  @override
  Future<void> deleteTransaction(String id) async => _db.remove(id);

  @override
  Future<void> clearAllTransactions() async => _db.clear();

  @override
  Future<List<TransactionEntity>> getTransactionsPaginated({int limit = 50, int offset = 0}) async {
    final all = _db.values.toList();
    if (offset >= all.length) return [];
    return all.skip(offset).take(limit).toList();
  }

  @override
  Future<void> saveTransactionAtomic({
    required TransactionEntity transaction,
    TransactionEntity? previousTransaction,
  }) async {
    if (previousTransaction != null) {
      _db.remove(previousTransaction.id);
    }
    _db[transaction.id] = transaction;
  }

  @override
  Future<void> deleteTransactionAtomic(String id) async {
    _db.remove(id);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Issue 1: Credit Card Bill Payment & Edit/Ledger Sync Tests', () {
    late ProviderContainer container;
    late InMemoryTxRepo txRepo;
    late InMemoryBankAccountRepository bankRepo;
    late InMemoryCreditCardRepository cardRepo;
    late InMemorySavingsGoalRepository goalRepo;

    final now = DateTime.now();

    setUp(() async {
      txRepo = InMemoryTxRepo();
      bankRepo = InMemoryBankAccountRepository();
      cardRepo = InMemoryCreditCardRepository();
      goalRepo = InMemorySavingsGoalRepository();

      container = ProviderContainer(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(txRepo),
          bankAccountRepositoryProvider.overrideWithValue(bankRepo),
          creditCardRepositoryProvider.overrideWithValue(cardRepo),
          savingsGoalRepositoryProvider.overrideWithValue(goalRepo),
        ],
      );

      // Seed bank account (ICICI: 50,000 balance)
      await bankRepo.saveAccount(
        BankAccountEntity(
          id: 'acc_icici',
          accountName: 'ICICI Salary Account',
          bankName: 'ICICI Bank',
          accountType: AccountType.salary,
          usedFor: 'Salary',
          initialBalance: 50000.0,
          currentBalance: 50000.0,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Seed second bank account (HDFC: 20,000 balance)
      await bankRepo.saveAccount(
        BankAccountEntity(
          id: 'acc_hdfc',
          accountName: 'HDFC Savings',
          bankName: 'HDFC Bank',
          accountType: AccountType.savings,
          usedFor: 'Emergency Fund',
          initialBalance: 20000.0,
          currentBalance: 20000.0,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Seed credit card (Amazon Pay ICICI: 15,000 used dues)
      await cardRepo.saveCard(
        CreditCardEntity(
          id: 'card_amazon',
          cardName: 'Amazon Pay ICICI',
          bankName: 'ICICI Bank',
          creditLimit: 100000.0,
          usedAmount: 15000.0,
          statementDateDay: 15,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Pre-warm notifiers
      await container.read(bankAccountListProvider.future);
      await container.read(creditCardListProvider.future);
      await container.read(transactionListNotifierProvider.future);
    });

    tearDown(() => container.dispose());

    test('Paying credit card bill updates bank balance and credit card usedAmount correctly', () async {
      final billTx = TransactionEntity(
        id: 'tx_bill_1',
        title: 'Credit Card Bill Pay: Amazon Pay ICICI',
        amount: 10000.0,
        type: TransactionType.transfer,
        category: 'Credit Card Bill Pay',
        date: now,
        paymentSource: 'ICICI Salary Account',
        accountId: 'acc_icici',
        toAccountId: null, // Critical: toAccountId must be null for card bill pay
        creditCardId: 'card_amazon',
        createdAt: now,
        updatedAt: now,
      );

      await container
          .read(transactionListNotifierProvider.notifier)
          .saveTransactionWithLedgerImpact(transaction: billTx);

      final icici = (await bankRepo.getAllAccounts()).firstWhere((a) => a.id == 'acc_icici');
      final hdfc = (await bankRepo.getAllAccounts()).firstWhere((a) => a.id == 'acc_hdfc');
      final card = (await cardRepo.getAllCards()).firstWhere((c) => c.id == 'card_amazon');

      // Bank account deducted by 10,000
      expect(icici.currentBalance, 40000.0);
      // HDFC untouched
      expect(hdfc.currentBalance, 20000.0);
      // Card usedAmount decreased from 15,000 to 5,000
      expect(card.usedAmount, 5000.0);
    });

    test('Editing credit card bill payoff properly adjusts card balance and does not corrupt bank accounts', () async {
      final initialBillTx = TransactionEntity(
        id: 'tx_bill_1',
        title: 'Credit Card Bill Pay: Amazon Pay ICICI',
        amount: 10000.0,
        type: TransactionType.transfer,
        category: 'Credit Card Bill Pay',
        date: now,
        paymentSource: 'ICICI Salary Account',
        accountId: 'acc_icici',
        toAccountId: null,
        creditCardId: 'card_amazon',
        createdAt: now,
        updatedAt: now,
      );

      await container
          .read(transactionListNotifierProvider.notifier)
          .saveTransactionWithLedgerImpact(transaction: initialBillTx);

      // Verify intermediate balances: Bank: 40,000, Card: 5,000
      expect((await bankRepo.getAllAccounts()).firstWhere((a) => a.id == 'acc_icici').currentBalance, 40000.0);
      expect((await cardRepo.getAllCards()).firstWhere((c) => c.id == 'card_amazon').usedAmount, 5000.0);

      // Now edit the bill payment: change amount from 10,000 to 12,000
      final updatedBillTx = initialBillTx.copyWith(
        amount: 12000.0,
        notes: 'Updated bill payoff amount',
      );

      await container
          .read(transactionListNotifierProvider.notifier)
          .saveTransactionWithLedgerImpact(
            transaction: updatedBillTx,
            previousTransaction: initialBillTx,
          );

      final icici = (await bankRepo.getAllAccounts()).firstWhere((a) => a.id == 'acc_icici');
      final hdfc = (await bankRepo.getAllAccounts()).firstWhere((a) => a.id == 'acc_hdfc');
      final card = (await cardRepo.getAllCards()).firstWhere((c) => c.id == 'card_amazon');

      // ICICI balance should reflect 12,000 deduction: 50,000 - 12,000 = 38,000
      expect(icici.currentBalance, 38000.0);
      // HDFC balance should remain completely untouched
      expect(hdfc.currentBalance, 20000.0);
      // Card usedAmount should reflect 12,000 payoff: 15,000 - 12,000 = 3,000
      expect(card.usedAmount, 3000.0);
    });
  });

  group('Issue 2: Account Transfer Linked Goals & Split Savings Tests', () {
    late ProviderContainer container;
    late InMemoryTxRepo txRepo;
    late InMemoryBankAccountRepository bankRepo;
    late InMemoryCreditCardRepository cardRepo;
    late InMemorySavingsGoalRepository goalRepo;

    final now = DateTime.now();

    setUp(() async {
      txRepo = InMemoryTxRepo();
      bankRepo = InMemoryBankAccountRepository();
      cardRepo = InMemoryCreditCardRepository();
      goalRepo = InMemorySavingsGoalRepository();

      container = ProviderContainer(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(txRepo),
          bankAccountRepositoryProvider.overrideWithValue(bankRepo),
          creditCardRepositoryProvider.overrideWithValue(cardRepo),
          savingsGoalRepositoryProvider.overrideWithValue(goalRepo),
        ],
      );

      // AU Small Finance Bank account (balance: 30,000)
      await bankRepo.saveAccount(
        BankAccountEntity(
          id: 'acc_au',
          accountName: 'AU Small Finance Bank',
          bankName: 'AU Bank',
          accountType: AccountType.savings,
          usedFor: 'Short Term Goals',
          initialBalance: 30000.0,
          currentBalance: 30000.0,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Seed 2 goals linked to AU Small Finance Bank
      await goalRepo.saveGoal(
        SavingsGoalEntity(
          id: 'goal_ring',
          title: 'Engagement Ring',
          targetAmount: 100000.0,
          currentAmount: 25000.0,
          category: 'Shopping & Luxuries',
          targetDate: now.add(const Duration(days: 180)),
          linkedAccountId: 'acc_au',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await goalRepo.saveGoal(
        SavingsGoalEntity(
          id: 'goal_dishwasher',
          title: 'Dishwasher',
          targetAmount: 40000.0,
          currentAmount: 5000.0,
          category: 'Appliances',
          targetDate: now.add(const Duration(days: 120)),
          linkedAccountId: 'acc_au',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await container.read(savingsGoalsListNotifierProvider.future);
    });

    tearDown(() => container.dispose());

    test('Splitting transfer amount across multiple linked goals updates progress without creating expenses', () async {
      final notifier = container.read(savingsGoalsListNotifierProvider.notifier);

      // Transfer 10,000 to AU Small Finance Bank: 8,000 for ring, 2,000 for dishwasher
      await notifier.allocateToMultipleGoals(
        goalAllocations: {
          'goal_ring': 8000.0,
          'goal_dishwasher': 2000.0,
        },
        sourceAccountId: 'acc_au',
        transactionTitle: 'Salary Transfer',
      );

      final goals = await goalRepo.getAllGoals();
      final ring = goals.firstWhere((g) => g.id == 'goal_ring');
      final dishwasher = goals.firstWhere((g) => g.id == 'goal_dishwasher');

      // Verify Ring progress: 25,000 + 8,000 = 33,000
      expect(ring.currentAmount, 33000.0);
      // Verify Dishwasher progress: 5,000 + 2,000 = 7,000
      expect(dishwasher.currentAmount, 7000.0);

      // Verify contributions were recorded
      final ringContribs = await goalRepo.getContributionsForGoal('goal_ring');
      expect(ringContribs.length, 1);
      expect(ringContribs.first.amount, 8000.0);

      final dishContribs = await goalRepo.getContributionsForGoal('goal_dishwasher');
      expect(dishContribs.length, 1);
      expect(dishContribs.first.amount, 2000.0);

      // Verify NO expense transactions were added
      final allTxs = await txRepo.getAllTransactions();
      expect(FinancialCalculator.calculateTotalExpense(allTxs), 0.0);
    });

    test('Single linked goal (e.g. IDFC Emergency Fund) allocates 100% cleanly without expense', () async {
      final notifier = container.read(savingsGoalsListNotifierProvider.notifier);

      await notifier.saveGoal(
        SavingsGoalEntity(
          id: 'goal_emergency',
          title: 'Emergency Fund',
          targetAmount: 150000.0,
          currentAmount: 20000.0,
          category: 'Emergency Fund',
          targetDate: now.add(const Duration(days: 365)),
          linkedAccountId: 'acc_idfc',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await notifier.allocateToMultipleGoals(
        goalAllocations: {'goal_emergency': 15000.0},
        sourceAccountId: 'acc_idfc',
        transactionTitle: 'Emergency Fund Transfer',
      );

      final goals = await goalRepo.getAllGoals();
      final emergency = goals.firstWhere((g) => g.id == 'goal_emergency');

      // 20,000 + 15,000 = 35,000
      expect(emergency.currentAmount, 35000.0);

      // Check contributions
      final contribs = await goalRepo.getContributionsForGoal('goal_emergency');
      expect(contribs.length, 1);
      expect(contribs.first.amount, 15000.0);

      // Check expenses remain 0
      final allTxs = await txRepo.getAllTransactions();
      expect(FinancialCalculator.calculateTotalExpense(allTxs), 0.0);
    });
  });

  group('BudgetEntity Account Linking & Serialization Tests', () {
    test('BudgetEntity supports optional accountId with proper serialization and copyWith', () {
      final now = DateTime.now();

      // 1. Instantiation with accountId
      final budget = BudgetEntity(
        id: 'b1',
        category: 'Food & Dining',
        limitAmount: 10000.0,
        month: DateTime(2026, 9),
        accountId: 'acc_hdfc',
        createdAt: now,
        updatedAt: now,
      );

      expect(budget.accountId, 'acc_hdfc');

      // 2. toMap serialization
      final map = budget.toMap();
      expect(map['account_id'], 'acc_hdfc');

      // 3. fromMap deserialization
      final restored = BudgetEntity.fromMap(map);
      expect(restored.accountId, 'acc_hdfc');
      expect(restored.category, 'Food & Dining');
      expect(restored.limitAmount, 10000.0);

      // 4. copyWith preserves accountId when not passed
      final updatedLimit = budget.copyWith(limitAmount: 12000.0);
      expect(updatedLimit.accountId, 'acc_hdfc');
      expect(updatedLimit.limitAmount, 12000.0);

      // 5. copyWith allows clearing accountId to null
      final clearedAccount = budget.copyWith(accountId: null);
      expect(clearedAccount.accountId, isNull);

      // 6. copyWith allows updating accountId
      final changedAccount = budget.copyWith(accountId: 'acc_icici');
      expect(changedAccount.accountId, 'acc_icici');
    });

    test('FinancialCalculator.calculateCategoryBudgetStatus respects budget accountId filtering', () {
      final now = DateTime.now();

      final accountSpecificBudget = BudgetEntity(
        id: 'b_groceries_hdfc',
        category: 'Groceries',
        limitAmount: 8000.0,
        month: now,
        accountId: 'acc_hdfc',
        createdAt: now,
        updatedAt: now,
      );

      final transactions = [
        // Grocery expense from HDFC (should count)
        TransactionEntity(
          id: 'tx_1',
          title: 'Supermarket HDFC',
          amount: 2500.0,
          type: TransactionType.expense,
          category: 'Groceries',
          date: now,
          paymentSource: 'HDFC Bank',
          accountId: 'acc_hdfc',
          createdAt: now,
          updatedAt: now,
        ),
        // Grocery expense from ICICI (different account - should NOT count towards HDFC-linked budget)
        TransactionEntity(
          id: 'tx_2',
          title: 'Kirana ICICI',
          amount: 1500.0,
          type: TransactionType.expense,
          category: 'Groceries',
          date: now,
          paymentSource: 'ICICI Bank',
          accountId: 'acc_icici',
          createdAt: now,
          updatedAt: now,
        ),
        // Grocery expense in cash (accountId is null - should NOT count towards HDFC-linked budget)
        TransactionEntity(
          id: 'tx_3',
          title: 'Vegetables Cash',
          amount: 500.0,
          type: TransactionType.expense,
          category: 'Groceries',
          date: now,
          paymentSource: 'Cash',
          accountId: null,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final status = FinancialCalculator.calculateCategoryBudgetStatus(
        accountSpecificBudget,
        transactions,
      );

      // Only tx_1 (2500.0) from HDFC should be counted (ICICI and Cash excluded)
      expect(status.spentAmount, 2500.0);
      expect(status.remainingAmount, 5500.0);

      // Verify general budget without accountId counts all grocery expenses
      final generalBudget = accountSpecificBudget.copyWith(accountId: null);
      final generalStatus = FinancialCalculator.calculateCategoryBudgetStatus(
        generalBudget,
        transactions,
      );
      // All 3 transactions count: 2500 + 1500 + 500 = 4500
      expect(generalStatus.spentAmount, 4500.0);
      expect(generalStatus.remainingAmount, 3500.0);
    });
  });
}
