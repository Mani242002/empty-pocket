import 'dart:convert';
import 'package:intl/intl.dart';
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
  }) {
    final metadata = BackupMetadata(
      schemaVersion: 5,
      exportedAt: DateTime.now(),
      transactionsCount: transactions.length,
      budgetsCount: budgets.length,
      savingsGoalsCount: savingsGoals.length,
      savingsContributionsCount: savingsContributions.length,
      debtsCount: debts.length,
      debtPaymentsCount: debtPayments.length,
      investmentsCount: investments.length,
      recurringExpensesCount: recurringExpenses.length,
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

  /// Restore all data into SQLite repositories
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

    // 2. Restore transactions
    for (final tx in backup.transactions) {
      await transactionRepo.addTransaction(tx);
    }

    // 3. Restore budgets
    for (final b in backup.budgets) {
      await budgetRepo.saveBudget(b);
    }

    // 4. Restore savings goals & contributions
    for (final g in backup.savingsGoals) {
      await savingsRepo.saveGoal(g);
    }
    for (final c in backup.savingsContributions) {
      await savingsRepo.addContribution(c);
    }

    // 5. Restore debts & payments
    for (final d in backup.debts) {
      await debtRepo.saveDebt(d);
    }
    for (final p in backup.debtPayments) {
      await debtRepo.addPayment(p);
    }

    // 6. Restore investments
    for (final i in backup.investments) {
      await investmentRepo.saveInvestment(i);
    }

    // 7. Restore recurring expenses
    for (final r in backup.recurringExpenses) {
      await recurringRepo.saveRecurringExpense(r);
    }
  }

  /// Complete privacy factory reset: wipes all local SQLite tables
  Future<void> wipeAllData({
    required TransactionRepository transactionRepo,
    required BudgetRepository budgetRepo,
    required SavingsGoalRepository savingsRepo,
    required DebtRepository debtRepo,
    required InvestmentRepository investmentRepo,
    required RecurringRepository recurringRepo,
  }) async {
    await transactionRepo.clearAllTransactions();

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
