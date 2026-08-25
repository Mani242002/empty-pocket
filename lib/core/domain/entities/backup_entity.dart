import 'ai_assistant_entity.dart';
import 'bank_account_entity.dart';
import 'budget_entity.dart';
import 'credit_card_entity.dart';
import 'debt_entity.dart';
import 'investment_entity.dart';
import 'recurring_expense_entity.dart';
import 'savings_goal_entity.dart';
import 'transaction_entity.dart';

class BackupMetadata {
  final int schemaVersion;
  final DateTime exportedAt;
  final int transactionsCount;
  final int budgetsCount;
  final int savingsGoalsCount;
  final int savingsContributionsCount;
  final int debtsCount;
  final int debtPaymentsCount;
  final int investmentsCount;
  final int recurringExpensesCount;
  final int chatSessionsCount;
  final int chatMessagesCount;
  final int bankAccountsCount;
  final int creditCardsCount;

  const BackupMetadata({
    required this.schemaVersion,
    required this.exportedAt,
    required this.transactionsCount,
    required this.budgetsCount,
    required this.savingsGoalsCount,
    required this.savingsContributionsCount,
    required this.debtsCount,
    required this.debtPaymentsCount,
    required this.investmentsCount,
    required this.recurringExpensesCount,
    this.chatSessionsCount = 0,
    this.chatMessagesCount = 0,
    this.bankAccountsCount = 0,
    this.creditCardsCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'exportedAt': exportedAt.toIso8601String(),
        'transactionsCount': transactionsCount,
        'budgetsCount': budgetsCount,
        'savingsGoalsCount': savingsGoalsCount,
        'savingsContributionsCount': savingsContributionsCount,
        'debtsCount': debtsCount,
        'debtPaymentsCount': debtPaymentsCount,
        'investmentsCount': investmentsCount,
        'recurringExpensesCount': recurringExpensesCount,
        'chatSessionsCount': chatSessionsCount,
        'chatMessagesCount': chatMessagesCount,
        'bankAccountsCount': bankAccountsCount,
        'creditCardsCount': creditCardsCount,
      };

  factory BackupMetadata.fromJson(Map<String, dynamic> json) => BackupMetadata(
        schemaVersion: json['schemaVersion'] as int? ?? 1,
        exportedAt: DateTime.tryParse(json['exportedAt'] as String? ?? '') ?? DateTime.now(),
        transactionsCount: json['transactionsCount'] as int? ?? 0,
        budgetsCount: json['budgetsCount'] as int? ?? 0,
        savingsGoalsCount: json['savingsGoalsCount'] as int? ?? 0,
        savingsContributionsCount: json['savingsContributionsCount'] as int? ?? 0,
        debtsCount: json['debtsCount'] as int? ?? 0,
        debtPaymentsCount: json['debtPaymentsCount'] as int? ?? 0,
        investmentsCount: json['investmentsCount'] as int? ?? 0,
        recurringExpensesCount: json['recurringExpensesCount'] as int? ?? 0,
        chatSessionsCount: json['chatSessionsCount'] as int? ?? 0,
        chatMessagesCount: json['chatMessagesCount'] as int? ?? 0,
        bankAccountsCount: json['bankAccountsCount'] as int? ?? 0,
        creditCardsCount: json['creditCardsCount'] as int? ?? 0,
      );
}

class FullDatabaseBackup {
  final BackupMetadata metadata;
  final List<TransactionEntity> transactions;
  final List<BudgetEntity> budgets;
  final List<SavingsGoalEntity> savingsGoals;
  final List<GoalContributionEntity> savingsContributions;
  final List<DebtEntity> debts;
  final List<DebtPaymentEntity> debtPayments;
  final List<InvestmentEntity> investments;
  final List<RecurringExpenseEntity> recurringExpenses;
  final List<AiChatSession> chatSessions;
  final List<AiChatMessage> chatMessages;
  final List<BankAccountEntity> bankAccounts;
  final List<CreditCardEntity> creditCards;

  const FullDatabaseBackup({
    required this.metadata,
    required this.transactions,
    required this.budgets,
    required this.savingsGoals,
    required this.savingsContributions,
    required this.debts,
    required this.debtPayments,
    required this.investments,
    required this.recurringExpenses,
    this.chatSessions = const [],
    this.chatMessages = const [],
    this.bankAccounts = const [],
    this.creditCards = const [],
  });

  Map<String, dynamic> toJson() => {
        'metadata': metadata.toJson(),
        'transactions': transactions.map((t) => t.toMap()).toList(),
        'budgets': budgets.map((b) => b.toMap()).toList(),
        'savingsGoals': savingsGoals.map((g) => g.toMap()).toList(),
        'savingsContributions': savingsContributions.map((c) => c.toMap()).toList(),
        'debts': debts.map((d) => d.toMap()).toList(),
        'debtPayments': debtPayments.map((p) => p.toMap()).toList(),
        'investments': investments.map((i) => i.toMap()).toList(),
        'recurringExpenses': recurringExpenses.map((r) => r.toMap()).toList(),
        'chatSessions': chatSessions.map((s) => s.toMap()).toList(),
        'chatMessages': chatMessages.map((m) => m.toMap()).toList(),
        'bankAccounts': bankAccounts.map((a) => a.toMap()).toList(),
        'creditCards': creditCards.map((c) => c.toMap()).toList(),
      };

  factory FullDatabaseBackup.fromJson(Map<String, dynamic> json) {
    final metaJson = json['metadata'] as Map<String, dynamic>? ?? {};
    final txList = (json['transactions'] as List<dynamic>? ?? [])
        .map((m) => TransactionEntity.fromMap(m as Map<String, dynamic>))
        .toList();
    final budgetList = (json['budgets'] as List<dynamic>? ?? [])
        .map((m) => BudgetEntity.fromMap(m as Map<String, dynamic>))
        .toList();
    final goalsList = (json['savingsGoals'] as List<dynamic>? ?? [])
        .map((m) => SavingsGoalEntity.fromMap(m as Map<String, dynamic>))
        .toList();
    final contribsList = (json['savingsContributions'] as List<dynamic>? ?? [])
        .map((m) => GoalContributionEntity.fromMap(m as Map<String, dynamic>))
        .toList();
    final debtsList = (json['debts'] as List<dynamic>? ?? [])
        .map((m) => DebtEntity.fromMap(m as Map<String, dynamic>))
        .toList();
    final paymentsList = (json['debtPayments'] as List<dynamic>? ?? [])
        .map((m) => DebtPaymentEntity.fromMap(m as Map<String, dynamic>))
        .toList();
    final investmentsList = (json['investments'] as List<dynamic>? ?? [])
        .map((m) => InvestmentEntity.fromMap(m as Map<String, dynamic>))
        .toList();
    final recurringList = (json['recurringExpenses'] as List<dynamic>? ?? [])
        .map((m) => RecurringExpenseEntity.fromMap(m as Map<String, dynamic>))
        .toList();
    final sessionsList = (json['chatSessions'] as List<dynamic>? ?? [])
        .map((m) => AiChatSession.fromMap(m as Map<String, dynamic>))
        .toList();
    final messagesList = (json['chatMessages'] as List<dynamic>? ?? [])
        .map((m) => AiChatMessage.fromMap(m as Map<String, dynamic>))
        .toList();
    final accountsList = (json['bankAccounts'] as List<dynamic>? ?? [])
        .map((m) => BankAccountEntity.fromMap(m as Map<String, dynamic>))
        .toList();
    final cardsList = (json['creditCards'] as List<dynamic>? ?? [])
        .map((m) => CreditCardEntity.fromMap(m as Map<String, dynamic>))
        .toList();

    return FullDatabaseBackup(
      metadata: BackupMetadata.fromJson(metaJson),
      transactions: txList,
      budgets: budgetList,
      savingsGoals: goalsList,
      savingsContributions: contribsList,
      debts: debtsList,
      debtPayments: paymentsList,
      investments: investmentsList,
      recurringExpenses: recurringList,
      chatSessions: sessionsList,
      chatMessages: messagesList,
      bankAccounts: accountsList,
      creditCards: cardsList,
    );
  }
}
