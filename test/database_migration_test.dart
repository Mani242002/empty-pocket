import 'package:flutter_test/flutter_test.dart';
import 'package:empty_pocket/core/database/app_database.dart';
import 'package:empty_pocket/core/domain/entities/transaction_entity.dart';
import 'package:empty_pocket/core/domain/entities/credit_card_entity.dart';
import 'package:empty_pocket/core/domain/entities/bank_account_entity.dart';

void main() {
  group('Database Schema & Migration Contract Tests', () {
    test('AppDatabase table constants match production schema contracts', () {
      expect(AppDatabase.tableTransactions, 'transactions');
      expect(AppDatabase.tableBudgets, 'budgets');
      expect(AppDatabase.tableRecurring, 'recurring_expenses');
      expect(AppDatabase.tableSavingsGoals, 'savings_goals');
      expect(AppDatabase.tableGoalContributions, 'goal_contributions');
      expect(AppDatabase.tableDebts, 'debts');
      expect(AppDatabase.tableDebtPayments, 'debt_payments');
      expect(AppDatabase.tableInvestments, 'investments');
      expect(AppDatabase.tableChatSessions, 'ai_chat_sessions');
      expect(AppDatabase.tableChatMessages, 'ai_chat_messages');
      expect(AppDatabase.tableBankAccounts, 'bank_accounts');
      expect(AppDatabase.tableCreditCards, 'credit_cards');
      expect(AppDatabase.tableAiReports, 'ai_reports');
    });

    test('TransactionEntity serialization supports v12 schema fields seamlessly', () {
      final now = DateTime.now();
      final tx = TransactionEntity(
        id: 'tx_v12_001',
        title: 'Credit Card Bill Payment',
        amount: 25000.0,
        type: TransactionType.transfer,
        category: 'Credit Card Payment',
        date: now,
        paymentSource: 'HDFC Salary Bank',
        accountId: 'acc_001',
        toAccountId: null,
        creditCardId: 'card_001',
        notes: 'Monthly statement payoff',
        isShared: true,
        myShareAmount: 12500.0,
        reimbursedAmount: 12500.0,
        isSettled: true,
        sharedWith: 'Partner',
        linkedEntityId: 'linked_001',
        createdAt: now,
        updatedAt: now,
      );

      final map = tx.toMap();
      expect(map['id'], 'tx_v12_001');
      expect(map['account_id'], 'acc_001');
      expect(map['credit_card_id'], 'card_001');
      expect(map['is_shared'], 1);
      expect(map['my_share_amount'], 12500.0);
      expect(map['reimbursed_amount'], 12500.0);
      expect(map['is_settled'], 1);
      expect(map['shared_with'], 'Partner');
      expect(map['linked_entity_id'], 'linked_001');

      // Round-trip deserialization
      final restored = TransactionEntity.fromMap(map);
      expect(restored.id, tx.id);
      expect(restored.accountId, tx.accountId);
      expect(restored.creditCardId, tx.creditCardId);
      expect(restored.isShared, tx.isShared);
      expect(restored.isSettled, tx.isSettled);
    });

    test('CreditCardEntity supports v12 initial_used_amount migration contract', () {
      final now = DateTime.now();
      final card = CreditCardEntity(
        id: 'card_v12',
        cardName: 'Millennia',
        bankName: 'HDFC',
        cardNetwork: CardNetwork.visa,
        creditLimit: 150000.0,
        usedAmount: 18000.0,
        initialUsedAmount: 18000.0,
        statementDateDay: 20,
        gracePeriodDays: 20,
        cardTheme: 'obsidian',
        createdAt: now,
        updatedAt: now,
      );

      final map = card.toMap();
      expect(map['initial_used_amount'], 18000.0);
      expect(map['used_amount'], 18000.0);

      // Verify deserialization from legacy row missing initial_used_amount falls back safely to used_amount
      final legacyMap = Map<String, dynamic>.from(map)..remove('initial_used_amount');
      final legacyRestored = CreditCardEntity.fromMap(legacyMap);
      expect(legacyRestored.initialUsedAmount, 18000.0);
    });

    test('BankAccountEntity safely serializes and deserializes current ledger balance', () {
      final now = DateTime.now();
      final account = BankAccountEntity(
        id: 'acc_002',
        accountName: 'Emergency Savings',
        bankName: 'ICICI Bank',
        accountType: AccountType.savings,
        usedFor: 'Emergency',
        initialBalance: 120000.0,
        currentBalance: 120000.0,
        colorHex: '#6366F1',
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      );

      final map = account.toMap();
      expect(map['account_name'], 'Emergency Savings');
      expect(map['current_balance'], 120000.0);
      expect(map['is_default'], 1);

      final restored = BankAccountEntity.fromMap(map);
      expect(restored.id, account.id);
      expect(restored.currentBalance, 120000.0);
      expect(restored.isDefault, isTrue);
    });
  });
}
