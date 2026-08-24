import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../database/app_database.dart';
import '../domain/entities/ai_assistant_entity.dart';
import '../domain/entities/backup_entity.dart';
import '../domain/entities/budget_entity.dart';
import '../domain/entities/debt_entity.dart';
import '../domain/entities/investment_entity.dart';
import '../domain/entities/recurring_expense_entity.dart';
import '../domain/entities/savings_goal_entity.dart';
import '../domain/entities/transaction_entity.dart';
import '../repositories/budget_repository.dart';
import '../repositories/debt_repository.dart';
import '../repositories/investment_repository.dart';
import '../repositories/recurring_repository.dart';
import '../repositories/savings_goal_repository.dart';
import '../repositories/transaction_repository.dart';

class BackupService {
  /// Generate a full structured JSON backup string
  String exportFullDatabaseJson({
    required List<TransactionEntity> transactions,
    required List<BudgetEntity> budgets,
    required List<SavingsGoalEntity> savingsGoals,
    required List<GoalContributionEntity> savingsContributions,
    required List<DebtEntity> debts,
    required List<DebtPaymentEntity> debtPayments,
    required List<InvestmentEntity> investments,
    required List<RecurringExpenseEntity> recurringExpenses,
    List<AiChatSession> chatSessions = const [],
    List<AiChatMessage> chatMessages = const [],
  }) {
    final metadata = BackupMetadata(
      schemaVersion: 7,
      exportedAt: DateTime.now(),
      transactionsCount: transactions.length,
      budgetsCount: budgets.length,
      savingsGoalsCount: savingsGoals.length,
      savingsContributionsCount: savingsContributions.length,
      debtsCount: debts.length,
      debtPaymentsCount: debtPayments.length,
      investmentsCount: investments.length,
      recurringExpensesCount: recurringExpenses.length,
      chatSessionsCount: chatSessions.length,
      chatMessagesCount: chatMessages.length,
    );

    final backup = FullDatabaseBackup(
      metadata: metadata,
      transactions: transactions,
      budgets: budgets,
      savingsGoals: savingsGoals,
      savingsContributions: savingsContributions,
      debts: debts,
      debtPayments: debtPayments,
      investments: investments,
      recurringExpenses: recurringExpenses,
      chatSessions: chatSessions,
      chatMessages: chatMessages,
    );

    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(backup.toJson());
  }

  /// Parse and validate JSON backup string
  FullDatabaseBackup parseBackupJson(String jsonContent) {
    try {
      final decoded = jsonDecode(jsonContent) as Map<String, dynamic>;
      return FullDatabaseBackup.fromJson(decoded);
    } catch (e) {
      throw FormatException('Invalid or corrupted backup JSON file: $e');
    }
  }

  /// Generate RFC 4180 CSV export of transactions
  String exportTransactionsToCsv(List<TransactionEntity> transactions) {
    final buffer = StringBuffer();
    // CSV Header
    buffer.writeln('ID,Date,Type,Category,Title,Amount,Payment Method,Notes,Created At');

    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    for (final tx in transactions) {
      final escapedTitle = _escapeCsvField(tx.title);
      final escapedCategory = _escapeCsvField(tx.category);
      final escapedSource = _escapeCsvField(tx.paymentSource);
      final escapedNotes = _escapeCsvField(tx.notes ?? '');
      final formattedDate = dateFormat.format(tx.date);
      final formattedCreatedAt = dateFormat.format(tx.createdAt);

      buffer.writeln(
        '${tx.id},"$formattedDate",${tx.type.name},"$escapedCategory","$escapedTitle",${tx.amount.toStringAsFixed(2)},"$escapedSource","$escapedNotes","$formattedCreatedAt"',
      );
    }

    return buffer.toString();
  }

  String _escapeCsvField(String field) {
    return field.replaceAll('"', '""');
  }

  /// Restore all data into repositories (with batch optimization for SQLite)
  Future<void> restoreAll({
    required FullDatabaseBackup backup,
    required TransactionRepository transactionRepo,
    required BudgetRepository budgetRepo,
    required SavingsGoalRepository savingsRepo,
    required DebtRepository debtRepo,
    required InvestmentRepository investmentRepo,
    required RecurringRepository recurringRepo,
  }) async {
    // 1. Wipe existing records to prevent conflicts
    await wipeAllData(
      transactionRepo: transactionRepo,
      budgetRepo: budgetRepo,
      savingsRepo: savingsRepo,
      debtRepo: debtRepo,
      investmentRepo: investmentRepo,
      recurringRepo: recurringRepo,
    );

    final isSqlite = transactionRepo is SqliteTransactionRepository;

    // 2. Restore transactions
    if (isSqlite && backup.transactions.isNotEmpty) {
      try {
        await AppDatabase.instance.batchInsertTransactions(backup.transactions);
      } catch (e) {
        debugPrint('[BackupService] Batch insert transactions failed: $e, falling back to repository');
        for (final tx in backup.transactions) {
          await transactionRepo.addTransaction(tx);
        }
      }
    } else {
      for (final tx in backup.transactions) {
        await transactionRepo.addTransaction(tx);
      }
    }

    // 3. Restore budgets
    if (isSqlite && backup.budgets.isNotEmpty) {
      try {
        await AppDatabase.instance.batchInsertBudgets(backup.budgets);
      } catch (e) {
        debugPrint('[BackupService] Batch insert budgets failed: $e, falling back to repository');
        for (final b in backup.budgets) {
          await budgetRepo.saveBudget(b);
        }
      }
    } else {
      for (final b in backup.budgets) {
        await budgetRepo.saveBudget(b);
      }
    }

    // 4. Restore savings goals & contributions
    if (isSqlite && backup.savingsGoals.isNotEmpty) {
      try {
        await AppDatabase.instance.batchInsertSavingsGoals(backup.savingsGoals);
      } catch (e) {
        debugPrint('[BackupService] Batch insert goals failed: $e, falling back to repository');
        for (final g in backup.savingsGoals) {
          await savingsRepo.saveGoal(g);
        }
      }
    } else {
      for (final g in backup.savingsGoals) {
        await savingsRepo.saveGoal(g);
      }
    }

    if (isSqlite && backup.savingsContributions.isNotEmpty) {
      try {
        await AppDatabase.instance.batchInsertGoalContributions(backup.savingsContributions);
      } catch (e) {
        debugPrint('[BackupService] Batch insert contributions failed: $e, falling back to repository');
        for (final c in backup.savingsContributions) {
          await savingsRepo.addContribution(c);
        }
      }
    } else {
      for (final c in backup.savingsContributions) {
        await savingsRepo.addContribution(c);
      }
    }

    // 5. Restore debts & payments
    if (isSqlite && backup.debts.isNotEmpty) {
      try {
        await AppDatabase.instance.batchInsertDebts(backup.debts);
      } catch (e) {
        debugPrint('[BackupService] Batch insert debts failed: $e, falling back to repository');
        for (final d in backup.debts) {
          await debtRepo.saveDebt(d);
        }
      }
    } else {
      for (final d in backup.debts) {
        await debtRepo.saveDebt(d);
      }
    }

    if (isSqlite && backup.debtPayments.isNotEmpty) {
      try {
        await AppDatabase.instance.batchInsertDebtPayments(backup.debtPayments);
      } catch (e) {
        debugPrint('[BackupService] Batch insert payments failed: $e, falling back to repository');
        for (final p in backup.debtPayments) {
          await debtRepo.addPayment(p);
        }
      }
    } else {
      for (final p in backup.debtPayments) {
        await debtRepo.addPayment(p);
      }
    }

    // 6. Restore investments
    if (isSqlite && backup.investments.isNotEmpty) {
      try {
        await AppDatabase.instance.batchInsertInvestments(backup.investments);
      } catch (e) {
        debugPrint('[BackupService] Batch insert investments failed: $e, falling back to repository');
        for (final i in backup.investments) {
          await investmentRepo.saveInvestment(i);
        }
      }
    } else {
      for (final i in backup.investments) {
        await investmentRepo.saveInvestment(i);
      }
    }

    // 7. Restore recurring expenses
    if (isSqlite && backup.recurringExpenses.isNotEmpty) {
      try {
        await AppDatabase.instance.batchInsertRecurringExpenses(backup.recurringExpenses);
      } catch (e) {
        debugPrint('[BackupService] Batch insert recurring failed: $e, falling back to repository');
        for (final r in backup.recurringExpenses) {
          await recurringRepo.saveRecurringExpense(r);
        }
      }
    } else {
      for (final r in backup.recurringExpenses) {
        await recurringRepo.saveRecurringExpense(r);
      }
    }

    // 8. Restore AI chat history
    if (isSqlite) {
      if (backup.chatSessions.isNotEmpty) {
        try {
          await AppDatabase.instance.batchInsertChatSessions(backup.chatSessions);
        } catch (e) {
          debugPrint('[BackupService] Batch insert chat sessions failed: $e');
        }
      }
      if (backup.chatMessages.isNotEmpty) {
        try {
          await AppDatabase.instance.batchInsertChatMessages(backup.chatMessages);
        } catch (e) {
          debugPrint('[BackupService] Batch insert chat messages failed: $e');
        }
      }
    }
  }

  /// Complete privacy factory reset: wipes all local records
  Future<void> wipeAllData({
    required TransactionRepository transactionRepo,
    required BudgetRepository budgetRepo,
    required SavingsGoalRepository savingsRepo,
    required DebtRepository debtRepo,
    required InvestmentRepository investmentRepo,
    required RecurringRepository recurringRepo,
  }) async {
    if (transactionRepo is SqliteTransactionRepository) {
      try {
        await AppDatabase.instance.clearAllData();
        return;
      } catch (e) {
        debugPrint('[BackupService] Atomic clearAllData failed: $e, falling back to individual repository deletes');
      }
    }

    try {
      await transactionRepo.clearAllTransactions();
    } catch (err) {
      debugPrint('[BackupService] clearAllTransactions error: $err');
    }

    final allBudgets = await budgetRepo.getAllBudgets();
    for (final b in allBudgets) {
      await budgetRepo.deleteBudget(b.id);
    }

    final allGoals = await savingsRepo.getAllGoals();
    for (final g in allGoals) {
      await savingsRepo.deleteGoal(g.id);
    }

    final allDebts = await debtRepo.getAllDebts();
    for (final d in allDebts) {
      await debtRepo.deleteDebt(d.id);
    }

    final allInvestments = await investmentRepo.getAllInvestments();
    for (final i in allInvestments) {
      await investmentRepo.deleteInvestment(i.id);
    }

    final allRecurring = await recurringRepo.getAllRecurringExpenses();
    for (final r in allRecurring) {
      await recurringRepo.deleteRecurringExpense(r.id);
    }
  }
}
