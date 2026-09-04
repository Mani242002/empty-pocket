import 'package:flutter_test/flutter_test.dart';
import 'package:empty_pocket/core/calculation/financial_calculator.dart';
import 'package:empty_pocket/core/domain/entities/bank_account_entity.dart';
import 'package:empty_pocket/core/domain/entities/credit_card_entity.dart';
import 'package:empty_pocket/core/repositories/bank_account_repository.dart';
import 'package:empty_pocket/core/repositories/credit_card_repository.dart';
import 'package:empty_pocket/core/services/backup_service.dart';

void main() {
  group('Bank Accounts Domain & Repository Tests', () {
    late BankAccountRepository repo;
    final now = DateTime.now();

    setUp(() {
      repo = InMemoryBankAccountRepository();
    });

    test('BankAccountEntity serialization and copyWith', () {
      final account = BankAccountEntity(
        id: 'acc-1',
        accountName: 'Salary Main',
        bankName: 'HDFC Bank',
        accountType: AccountType.salary,
        usedFor: AccountPurposeTags.dailySpending,
        initialBalance: 50000.0,
        currentBalance: 75000.0,
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      );

      final map = account.toMap();
      expect(map['id'], 'acc-1');
      expect(map['account_name'], 'Salary Main');
      expect(map['bank_name'], 'HDFC Bank');
      expect(map['account_type'], 'salary');
      expect(map['used_for'], 'Daily Spending');
      expect(map['initial_balance'], 50000.0);
      expect(map['current_balance'], 75000.0);
      expect(map['is_default'], 1);

      final restored = BankAccountEntity.fromMap(map);
      expect(restored.id, 'acc-1');
      expect(restored.accountName, 'Salary Main');
      expect(restored.bankName, 'HDFC Bank');
      expect(restored.accountType, AccountType.salary);
      expect(restored.usedFor, 'Daily Spending');
      expect(restored.currentBalance, 75000.0);
      expect(restored.isDefault, isTrue);

      final updated = account.copyWith(currentBalance: 82000.0, usedFor: AccountPurposeTags.emergencyFund);
      expect(updated.currentBalance, 82000.0);
      expect(updated.usedFor, 'Emergency Fund');
    });

    test('BankAccountRepository CRUD operations', () async {
      final acc1 = BankAccountEntity(
        id: 'a1',
        accountName: 'HDFC Savings',
        bankName: 'HDFC Bank',
        accountType: AccountType.savings,
        usedFor: AccountPurposeTags.dailySpending,
        initialBalance: 10000.0,
        currentBalance: 10000.0,
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      );

      final acc2 = BankAccountEntity(
        id: 'a2',
        accountName: 'Emergency Stash',
        bankName: 'SBI',
        accountType: AccountType.savings,
        usedFor: AccountPurposeTags.emergencyFund,
        initialBalance: 150000.0,
        currentBalance: 150000.0,
        isDefault: false,
        createdAt: now,
        updatedAt: now,
      );

      await repo.saveAccount(acc1);
      await repo.saveAccount(acc2);

      final all = await repo.getAllAccounts();
      expect(all.length, 2);

      final fetched = await repo.getAccountById('a1');
      expect(fetched?.accountName, 'HDFC Savings');

      final updatedAcc = acc1.copyWith(currentBalance: 25000.0);
      await repo.updateAccount(updatedAcc);

      final refreshed = await repo.getAccountById('a1');
      expect(refreshed?.currentBalance, 25000.0);

      await repo.deleteAccount('a2');
      final remaining = await repo.getAllAccounts();
      expect(remaining.length, 1);
      expect(remaining.first.id, 'a1');
    });
  });

  group('Credit Cards Domain & Repository Tests', () {
    late CreditCardRepository repo;
    final now = DateTime.now();

    setUp(() {
      repo = InMemoryCreditCardRepository();
    });

    test('CreditCardEntity serialization, utilization and billing cycle dates', () {
      final card = CreditCardEntity(
        id: 'card-1',
        cardName: 'Millennia',
        bankName: 'HDFC Bank',
        cardNetwork: CardNetwork.visa,
        creditLimit: 200000.0,
        usedAmount: 40000.0,
        statementDateDay: 15,
        gracePeriodDays: 20,
        cardTheme: 'obsidian',
        createdAt: now,
        updatedAt: now,
      );

      expect(card.availableLimit, 160000.0);
      expect(card.utilizationRatio, 20.0);
      expect(card.utilizationHealth, CreditUtilizationHealth.optimal);

      final nextStatement = card.getNextStatementDate();
      expect(nextStatement.day, 15);

      final nextDue = card.getNextDueDate();
      expect(nextDue.isAfter(nextStatement), isTrue);

      final map = card.toMap();
      expect(map['id'], 'card-1');
      expect(map['card_name'], 'Millennia');
      expect(map['credit_limit'], 200000.0);
      expect(map['used_amount'], 40000.0);
      expect(map['statement_date_day'], 15);
      expect(map['grace_period_days'], 20);

      final restored = CreditCardEntity.fromMap(map);
      expect(restored.id, 'card-1');
      expect(restored.cardName, 'Millennia');
      expect(restored.creditLimit, 200000.0);
      expect(restored.usedAmount, 40000.0);
    });

    test('CreditCard utilization health thresholds', () {
      final safeCard = CreditCardEntity(
        id: 'c1',
        cardName: 'Safe Card',
        bankName: 'ICICI',
        cardNetwork: CardNetwork.mastercard,
        creditLimit: 100000.0,
        usedAmount: 25000.0, // 25% <= 30%
        statementDateDay: 10,
        gracePeriodDays: 20,
        createdAt: now,
        updatedAt: now,
      );
      expect(safeCard.utilizationHealth, CreditUtilizationHealth.optimal);

      final moderateCard = safeCard.copyWith(usedAmount: 45000.0); // 45% > 30% && <= 50%
      expect(moderateCard.utilizationHealth, CreditUtilizationHealth.moderate);

      final highRiskCard = safeCard.copyWith(usedAmount: 85000.0); // 85% > 50%
      expect(highRiskCard.utilizationHealth, CreditUtilizationHealth.highRisk);
    });

    test('CreditCardRepository CRUD operations', () async {
      final card = CreditCardEntity(
        id: 'c1',
        cardName: 'Amazon Pay ICICI',
        bankName: 'ICICI Bank',
        cardNetwork: CardNetwork.visa,
        creditLimit: 150000.0,
        usedAmount: 12000.0,
        statementDateDay: 5,
        gracePeriodDays: 20,
        createdAt: now,
        updatedAt: now,
      );

      await repo.saveCard(card);
      final all = await repo.getAllCards();
      expect(all.length, 1);

      final updated = card.copyWith(usedAmount: 30000.0);
      await repo.updateCard(updated);

      final fetched = await repo.getCardById('c1');
      expect(fetched?.usedAmount, 30000.0);

      await repo.deleteCard('c1');
      final remaining = await repo.getAllCards();
      expect(remaining.isEmpty, isTrue);
    });
  });

  group('FinancialCalculator Accounts & Cards Aggregation Tests', () {
    final now = DateTime.now();

    test('calculateCombinedLiquidCash sums active accounts and ignores archived', () {
      final accounts = [
        BankAccountEntity(
          id: 'a1',
          accountName: 'Salary Account',
          bankName: 'HDFC',
          accountType: AccountType.salary,
          usedFor: AccountPurposeTags.dailySpending,
          initialBalance: 50000.0,
          currentBalance: 65000.0,
          createdAt: now,
          updatedAt: now,
        ),
        BankAccountEntity(
          id: 'a2',
          accountName: 'Emergency Savings',
          bankName: 'SBI',
          accountType: AccountType.savings,
          usedFor: AccountPurposeTags.emergencyFund,
          initialBalance: 200000.0,
          currentBalance: 215000.0,
          createdAt: now,
          updatedAt: now,
        ),
        BankAccountEntity(
          id: 'a3',
          accountName: 'Old Closed Account',
          bankName: 'Axis',
          accountType: AccountType.savings,
          usedFor: AccountPurposeTags.miscellaneous,
          initialBalance: 0.0,
          currentBalance: 5000.0,
          isArchived: true,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final liquidCash = FinancialCalculator.calculateCombinedLiquidCash(accounts);
      expect(liquidCash, 280000.0); // 65,000 + 215,000
    });

    test('calculateCombinedCreditSummary aggregates total limits, dues, and ratios correctly', () {
      final cards = [
        CreditCardEntity(
          id: 'c1',
          cardName: 'HDFC Millennia',
          bankName: 'HDFC',
          cardNetwork: CardNetwork.visa,
          creditLimit: 200000.0,
          usedAmount: 30000.0,
          statementDateDay: 15,
          gracePeriodDays: 20,
          createdAt: now,
          updatedAt: now,
        ),
        CreditCardEntity(
          id: 'c2',
          cardName: 'ICICI Amazon Pay',
          bankName: 'ICICI',
          cardNetwork: CardNetwork.visa,
          creditLimit: 100000.0,
          usedAmount: 15000.0,
          statementDateDay: 1,
          gracePeriodDays: 18,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final summary = FinancialCalculator.calculateCombinedCreditSummary(cards);

      expect(summary.totalLimit, 300000.0);
      expect(summary.totalUsed, 45000.0);
      expect(summary.totalAvailable, 255000.0);
      expect(summary.overallUtilizationRatio, 15.0);
      expect(summary.overallHealth, CreditUtilizationHealth.optimal);
      expect(summary.activeCardsCount, 2);
      expect(summary.nextDueCard != null, isTrue);
    });
  });

  group('FullDatabaseBackup Schema Version 8 Tests', () {
    test('Export and restore full backup with Bank Accounts and Credit Cards', () {
      final backupService = BackupService();
      final now = DateTime.now();

      final account = BankAccountEntity(
        id: 'acc-backup-1',
        accountName: 'Main Hub',
        bankName: 'HDFC',
        accountType: AccountType.savings,
        usedFor: AccountPurposeTags.dailySpending,
        initialBalance: 50000.0,
        currentBalance: 50000.0,
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      );

      final card = CreditCardEntity(
        id: 'card-backup-1',
        cardName: 'Tata Neu Infinity',
        bankName: 'HDFC',
        cardNetwork: CardNetwork.rupay,
        creditLimit: 300000.0,
        usedAmount: 12500.0,
        statementDateDay: 20,
        gracePeriodDays: 20,
        createdAt: now,
        updatedAt: now,
      );

      final jsonStr = backupService.exportFullDatabaseJson(
        transactions: [],
        budgets: [],
        savingsGoals: [],
        savingsContributions: [],
        debts: [],
        debtPayments: [],
        investments: [],
        recurringExpenses: [],
        bankAccounts: [account],
        creditCards: [card],
      );

      expect(jsonStr, contains('"schemaVersion": 10'));
      expect(jsonStr, contains('"bankAccountsCount": 1'));
      expect(jsonStr, contains('"creditCardsCount": 1'));
      expect(jsonStr, contains('Main Hub'));
      expect(jsonStr, contains('Tata Neu Infinity'));

      final parsed = backupService.parseBackupJson(jsonStr);
      expect(parsed.metadata.schemaVersion, 10);
      expect(parsed.bankAccounts.length, 1);
      expect(parsed.bankAccounts.first.accountName, 'Main Hub');
      expect(parsed.creditCards.length, 1);
      expect(parsed.creditCards.first.cardName, 'Tata Neu Infinity');
    });
  });
}
