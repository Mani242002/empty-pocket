import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'log_service.dart';
import '../database/app_database.dart';
import '../domain/entities/ai_assistant_entity.dart';
import '../domain/entities/backup_entity.dart';
import '../domain/entities/bank_account_entity.dart';
import '../domain/entities/budget_entity.dart';
import '../domain/entities/credit_card_entity.dart';
import '../domain/entities/debt_entity.dart';
import '../domain/entities/investment_entity.dart';
import '../domain/entities/recurring_expense_entity.dart';
import '../domain/entities/savings_goal_entity.dart';
import '../domain/entities/transaction_entity.dart';
import '../repositories/ai_chat_repository.dart';
import '../repositories/ai_reports_repository.dart';
import '../repositories/bank_account_repository.dart';
import '../repositories/budget_repository.dart';
import '../repositories/credit_card_repository.dart';
import '../repositories/debt_repository.dart';
import '../repositories/investment_repository.dart';
import '../repositories/recurring_repository.dart';
import '../repositories/savings_goal_repository.dart';
import '../repositories/transaction_repository.dart';

enum NumberFormatMode { auto, western, european, indian }

class CsvAmbiguousNumberException implements Exception {
  final int ambiguousCount;
  final int defaultedDates;
  final String csvContent;

  const CsvAmbiguousNumberException({
    required this.ambiguousCount,
    required this.defaultedDates,
    required this.csvContent,
  });

  @override
  String toString() =>
      'Found $ambiguousCount ambiguous number(s) (e.g. "1.234" or "1,234"). Format selection required.';
}

class CsvParseResult {
  final List<TransactionEntity> transactions;
  final int defaultedDateCount;
  final bool requiresFormatConfirmation;
  final int ambiguousAmountCount;
  final int invalidRowsCount;

  const CsvParseResult({
    required this.transactions,
    this.defaultedDateCount = 0,
    this.requiresFormatConfirmation = false,
    this.ambiguousAmountCount = 0,
    this.invalidRowsCount = 0,
  });
}

class _AmountParseOutcome {
  final double amount;
  final bool isNegative;
  final bool isValid;
  final bool isAmbiguous;

  const _AmountParseOutcome(
    this.amount, {
    this.isNegative = false,
    this.isValid = true,
    this.isAmbiguous = false,
  });

  static const invalid = _AmountParseOutcome(0.0, isValid: false);
}

class BackupService {
  /// The current schema version supported by this version of EmptyPocket.
  static const int currentSchemaVersion = 12;

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
    List<BankAccountEntity> bankAccounts = const [],
    List<CreditCardEntity> creditCards = const [],
    List<AiReportItem> aiReports = const [],
  }) {
    final metadata = BackupMetadata(
      schemaVersion: currentSchemaVersion,
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
      bankAccountsCount: bankAccounts.length,
      creditCardsCount: creditCards.length,
      aiReportsCount: aiReports.length,
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
      bankAccounts: bankAccounts,
      creditCards: creditCards,
      aiReports: aiReports,
    );

    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(backup.toJson());
  }

  /// Parse and validate JSON backup string
  FullDatabaseBackup parseBackupJson(String jsonContent) {
    try {
      final decoded = jsonDecode(jsonContent) as Map<String, dynamic>;
      final backup = FullDatabaseBackup.fromJson(decoded);
      if (backup.metadata.schemaVersion > currentSchemaVersion) {
        throw FormatException(
          'Backup schema version (${backup.metadata.schemaVersion}) is newer than supported ($currentSchemaVersion). '
          'Please update EmptyPocket to the latest version to restore this backup.',
        );
      }
      return backup;
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('Invalid or corrupted backup JSON file: $e');
    }
  }

  /// Generate RFC 4180 CSV export of transactions with OWASP formula injection protection
  String exportTransactionsToCsv(List<TransactionEntity> transactions) {
    final buffer = StringBuffer();
    // CSV Header (cleanly quoted)
    final headers = [
      'ID',
      'Date',
      'Type',
      'Category',
      'Title',
      'Amount',
      'Payment Method',
      'Notes',
      'Created At',
    ];
    buffer.writeln(headers.join(','));

    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    for (final tx in transactions) {
      final formattedDate = dateFormat.format(tx.date);
      final formattedCreatedAt = dateFormat.format(tx.createdAt);

      final cells = [
        _sanitizeCsvCell(tx.id),
        _sanitizeCsvCell(formattedDate),
        _sanitizeCsvCell(tx.type.name),
        _sanitizeCsvCell(tx.category),
        _sanitizeCsvCell(tx.title),
        tx.amount.toStringAsFixed(2),
        _sanitizeCsvCell(tx.paymentSource),
        _sanitizeCsvCell(tx.notes ?? ''),
        _sanitizeCsvCell(formattedCreatedAt),
      ];
      buffer.writeln(cells.map((c) => '"$c"').join(','));
    }

    return buffer.toString();
  }

  /// Sanitizes text cells against spreadsheet formula injection (OWASP CWE-1236)
  /// and escapes internal quotes. Returns an unquoted string ready for enclosing quotes.
  String _sanitizeCsvCell(String field) {
    if (field.isEmpty) return '';
    String escaped = field.replaceAll('"', '""');
    final trimmed = escaped.trimLeft();
    if (trimmed.startsWith('=') ||
        trimmed.startsWith('+') ||
        trimmed.startsWith('-') ||
        trimmed.startsWith('@') ||
        trimmed.startsWith('\t') ||
        trimmed.startsWith('\r') ||
        trimmed.startsWith('\n')) {
      escaped = "'$escaped";
    }
    return escaped;
  }

  /// Parse CSV content into a list of [TransactionEntity].
  /// Supports EmptyPocket's export format as well as generic financial app CSV formats.
  List<TransactionEntity> parseTransactionsFromCsv(
    String csvContent, {
    NumberFormatMode formatMode = NumberFormatMode.auto,
  }) {
    return parseTransactionsFromCsvWithResult(
      csvContent,
      formatMode: formatMode,
    ).transactions;
  }

  /// Parse CSV content with granular details including count of unparsed dates and ambiguous numbers.
  CsvParseResult parseTransactionsFromCsvWithResult(
    String csvContent, {
    NumberFormatMode formatMode = NumberFormatMode.auto,
  }) {
    final cleanContent = csvContent.startsWith('\uFEFF')
        ? csvContent.substring(1)
        : csvContent;
    final rows = _parseCsvRows(cleanContent);
    if (rows.isEmpty) return const CsvParseResult(transactions: []);

    final headerRow = rows.first;
    int idIdx = -1;
    int dateIdx = -1;
    int typeIdx = -1;
    int categoryIdx = -1;
    int titleIdx = -1;
    int amountIdx = -1;
    int paymentSourceIdx = -1;
    int notesIdx = -1;
    int createdAtIdx = -1;

    for (int i = 0; i < headerRow.length; i++) {
      final col = headerRow[i].toLowerCase().trim();
      if (col == 'id') {
        idIdx = i;
      } else if (col.contains('date') && !col.contains('created')) {
        dateIdx = i;
      } else if (col == 'created at' ||
          col == 'created_at' ||
          col.contains('create')) {
        createdAtIdx = i;
      } else if (col == 'type' || col.contains('transaction type')) {
        typeIdx = i;
      } else if (col.contains('category')) {
        categoryIdx = i;
      } else if (col.contains('title') ||
          col.contains('desc') ||
          col.contains('payee') ||
          col == 'name') {
        titleIdx = i;
      } else if (col.contains('amount') ||
          col == 'sum' ||
          col == 'value' ||
          col == 'cost') {
        amountIdx = i;
      } else if (col.contains('payment') ||
          col.contains('source') ||
          col.contains('method') ||
          col.contains('account') ||
          col.contains('wallet')) {
        paymentSourceIdx = i;
      } else if (col.contains('note') ||
          col.contains('memo') ||
          col.contains('remark')) {
        notesIdx = i;
      }
    }

    final hasRecognizedHeader =
        (dateIdx != -1 || amountIdx != -1 || titleIdx != -1);
    final dataRows = hasRecognizedHeader ? rows.sublist(1) : rows;

    // Fallback column positions if standard EmptyPocket header was positional or headerless
    if (dateIdx == -1 && dataRows.isNotEmpty && dataRows.first.length >= 6) {
      dateIdx = 1;
      typeIdx = 2;
      categoryIdx = 3;
      titleIdx = 4;
      amountIdx = 5;
      paymentSourceIdx = 6 < dataRows.first.length ? 6 : -1;
      notesIdx = 7 < dataRows.first.length ? 7 : -1;
    }

    final transactions = <TransactionEntity>[];
    int defaultedDateCount = 0;
    int ambiguousAmountCount = 0;
    int invalidRowsCount = 0;

    final dateTimeFormats = [
      DateFormat('yyyy-MM-dd HH:mm:ss'),
      DateFormat('yyyy-MM-dd'),
      DateFormat('yyyy/MM/dd HH:mm:ss'),
      DateFormat('yyyy/MM/dd'),
      DateFormat('dd-MM-yyyy HH:mm:ss'),
      DateFormat('dd-MM-yyyy'),
      DateFormat('dd/MM/yyyy HH:mm:ss'),
      DateFormat('dd/MM/yyyy'),
      DateFormat('dd.MM.yyyy HH:mm:ss'),
      DateFormat('dd.MM.yyyy'),
      DateFormat('d/M/yyyy HH:mm:ss'),
      DateFormat('d/M/yyyy'),
      DateFormat('d-M-yyyy HH:mm:ss'),
      DateFormat('d-M-yyyy'),
      DateFormat('MM/dd/yyyy HH:mm:ss'),
      DateFormat('MM/dd/yyyy'),
      DateFormat('dd-MMM-yyyy'),
      DateFormat('dd MMM yyyy'),
      DateFormat('MMM dd, yyyy'),
      DateFormat('yyyy-MM-ddTHH:mm:ss'),
    ];

    for (final row in dataRows) {
      if (row.isEmpty || (row.length == 1 && row[0].isEmpty)) continue;

      // Extract amount
      double amount = 0.0;
      bool isNegativeAmount = false;
      if (amountIdx != -1 && amountIdx < row.length) {
        final rawAmt = row[amountIdx].trim();
        final outcome = _parseAmount(rawAmt, formatMode);
        if (!outcome.isValid) {
          invalidRowsCount++;
          continue; // Malformed grouping or invalid number format
        }
        amount = outcome.amount.abs();
        isNegativeAmount = outcome.isNegative;
        if (outcome.isAmbiguous) {
          ambiguousAmountCount++;
        }
      }
      if (amount <= 0) continue; // Skip zero-amount lines

      // Extract Date
      DateTime date = DateTime.now();
      if (dateIdx != -1 && dateIdx < row.length) {
        final rawDate = row[dateIdx].trim();
        if (rawDate.isNotEmpty) {
          DateTime? parsedDate = DateTime.tryParse(rawDate);
          if (parsedDate == null) {
            for (final fmt in dateTimeFormats) {
              try {
                parsedDate = fmt.parse(rawDate);
                break;
              } catch (_) {}
            }
          }
          if (parsedDate != null) {
            date = parsedDate;
          } else {
            defaultedDateCount++;
          }
        }
      }

      // Extract Type
      TransactionType type = isNegativeAmount
          ? TransactionType.expense
          : TransactionType.expense;
      if (typeIdx != -1 && typeIdx < row.length) {
        final rawType = row[typeIdx].toLowerCase().trim();
        if (rawType.contains('inc') || rawType.contains('credit')) {
          type = TransactionType.income;
        } else if (rawType.contains('trans')) {
          type = TransactionType.transfer;
        } else {
          type = TransactionType.expense;
        }
      } else if (isNegativeAmount) {
        type = TransactionType.expense;
      }

      // Extract Title
      String title = 'Transaction';
      if (titleIdx != -1 &&
          titleIdx < row.length &&
          row[titleIdx].trim().isNotEmpty) {
        title = row[titleIdx].trim();
      }

      // Extract Category
      String category = 'General';
      if (categoryIdx != -1 &&
          categoryIdx < row.length &&
          row[categoryIdx].trim().isNotEmpty) {
        category = row[categoryIdx].trim();
      } else if (title != 'Transaction') {
        category = title;
      }

      // Extract Payment Source
      String paymentSource = 'Cash';
      if (paymentSourceIdx != -1 &&
          paymentSourceIdx < row.length &&
          row[paymentSourceIdx].trim().isNotEmpty) {
        paymentSource = row[paymentSourceIdx].trim();
      }

      // Extract Notes
      String? notes;
      if (notesIdx != -1 &&
          notesIdx < row.length &&
          row[notesIdx].trim().isNotEmpty) {
        notes = row[notesIdx].trim();
      }

      // Extract CreatedAt
      DateTime createdAt = date;
      if (createdAtIdx != -1 && createdAtIdx < row.length) {
        final rawCreated = row[createdAtIdx].trim();
        final parsed = DateTime.tryParse(rawCreated);
        if (parsed != null) createdAt = parsed;
      }

      // Extract ID
      String id = const Uuid().v4();
      if (idIdx != -1 && idIdx < row.length && row[idIdx].trim().isNotEmpty) {
        final rawId = row[idIdx].trim();
        if (rawId.length >= 8) {
          id = rawId;
        }
      }

      transactions.add(
        TransactionEntity(
          id: id,
          title: title,
          amount: amount,
          type: type,
          category: category,
          date: date,
          paymentSource: paymentSource,
          notes: notes,
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      );
    }

    return CsvParseResult(
      transactions: transactions,
      defaultedDateCount: defaultedDateCount,
      requiresFormatConfirmation:
          formatMode == NumberFormatMode.auto && ambiguousAmountCount > 0,
      ambiguousAmountCount: ambiguousAmountCount,
      invalidRowsCount: invalidRowsCount,
    );
  }

  _AmountParseOutcome _parseAmount(String raw, NumberFormatMode mode) {
    var trimmed = raw.trim();
    if (trimmed.isEmpty) return const _AmountParseOutcome(0.0);

    bool isNegative = false;
    if (trimmed.startsWith('(') && trimmed.endsWith(')')) {
      isNegative = true;
      trimmed = trimmed.substring(1, trimmed.length - 1).trim();
    } else if (trimmed.startsWith('-')) {
      isNegative = true;
      trimmed = trimmed.substring(1).trim();
    } else if (trimmed.endsWith('-')) {
      isNegative = true;
      trimmed = trimmed.substring(0, trimmed.length - 1).trim();
    }

    final clean = trimmed.replaceAll(RegExp(r'[^0-9.,]'), '').trim();
    if (clean.isEmpty || clean == '.' || clean == ',') {
      return const _AmountParseOutcome(0.0);
    }

    if (mode == NumberFormatMode.indian) {
      if (clean.contains(',')) {
        if (!RegExp(r'^\d{1,2}(,\d{2})*(,\d{3})(\.\d+)?$').hasMatch(clean)) {
          return _AmountParseOutcome.invalid;
        }
        final stripped = clean.replaceAll(',', '');
        final parsed = double.tryParse(stripped);
        if (parsed == null) return _AmountParseOutcome.invalid;
        return _AmountParseOutcome(
          isNegative ? -parsed : parsed,
          isNegative: isNegative,
        );
      } else {
        if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(clean)) {
          return _AmountParseOutcome.invalid;
        }
        final parsed = double.tryParse(clean);
        if (parsed == null) return _AmountParseOutcome.invalid;
        return _AmountParseOutcome(
          isNegative ? -parsed : parsed,
          isNegative: isNegative,
        );
      }
    }

    if (mode == NumberFormatMode.western) {
      if (clean.contains(',')) {
        if (!RegExp(r'^\d{1,3}(,\d{3})+(\.\d+)?$').hasMatch(clean)) {
          return _AmountParseOutcome.invalid;
        }
        final stripped = clean.replaceAll(',', '');
        final parsed = double.tryParse(stripped);
        if (parsed == null) return _AmountParseOutcome.invalid;
        return _AmountParseOutcome(
          isNegative ? -parsed : parsed,
          isNegative: isNegative,
        );
      } else {
        if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(clean)) {
          return _AmountParseOutcome.invalid;
        }
        final parsed = double.tryParse(clean);
        if (parsed == null) return _AmountParseOutcome.invalid;
        return _AmountParseOutcome(
          isNegative ? -parsed : parsed,
          isNegative: isNegative,
        );
      }
    }

    if (mode == NumberFormatMode.european) {
      if (clean.contains('.')) {
        if (!RegExp(r'^\d{1,3}(\.\d{3})+(,\d+)?$').hasMatch(clean)) {
          return _AmountParseOutcome.invalid;
        }
        final stripped = clean.replaceAll('.', '').replaceAll(',', '.');
        final parsed = double.tryParse(stripped);
        if (parsed == null) return _AmountParseOutcome.invalid;
        return _AmountParseOutcome(
          isNegative ? -parsed : parsed,
          isNegative: isNegative,
        );
      } else {
        if (!RegExp(r'^\d+(,\d+)?$').hasMatch(clean)) {
          return _AmountParseOutcome.invalid;
        }
        final stripped = clean.replaceAll(',', '.');
        final parsed = double.tryParse(stripped);
        if (parsed == null) return _AmountParseOutcome.invalid;
        return _AmountParseOutcome(
          isNegative ? -parsed : parsed,
          isNegative: isNegative,
        );
      }
    }

    // mode == NumberFormatMode.auto
    final hasDot = clean.contains('.');
    final hasComma = clean.contains(',');

    // 1. Both '.' and ',' present
    if (hasDot && hasComma) {
      final lastDot = clean.lastIndexOf('.');
      final lastComma = clean.lastIndexOf(',');
      if (lastComma > lastDot) {
        // European: 1.234,50 or 1.234.567,89
        if (!RegExp(r'^\d{1,3}(\.\d{3})+(,\d+)?$').hasMatch(clean)) {
          return _AmountParseOutcome.invalid;
        }
        final stripped = clean.replaceAll('.', '').replaceAll(',', '.');
        final parsed = double.tryParse(stripped);
        if (parsed == null) return _AmountParseOutcome.invalid;
        return _AmountParseOutcome(
          isNegative ? -parsed : parsed,
          isNegative: isNegative,
        );
      } else {
        // Western or Indian
        if (RegExp(r'^\d{1,2}(,\d{2})+(,\d{3})(\.\d+)?$').hasMatch(clean)) {
          final stripped = clean.replaceAll(',', '');
          final parsed = double.tryParse(stripped);
          if (parsed == null) return _AmountParseOutcome.invalid;
          return _AmountParseOutcome(
            isNegative ? -parsed : parsed,
            isNegative: isNegative,
          );
        } else if (RegExp(r'^\d{1,3}(,\d{3})+(\.\d+)?$').hasMatch(clean)) {
          final stripped = clean.replaceAll(',', '');
          final parsed = double.tryParse(stripped);
          if (parsed == null) return _AmountParseOutcome.invalid;
          return _AmountParseOutcome(
            isNegative ? -parsed : parsed,
            isNegative: isNegative,
          );
        } else {
          return _AmountParseOutcome.invalid;
        }
      }
    }

    // 2. Only comma present (no dot)
    if (hasComma && !hasDot) {
      // Indian multi-group integer: 1,00,000 or 12,34,567
      if (RegExp(r'^\d{1,2}(,\d{2})+(,\d{3})$').hasMatch(clean)) {
        final stripped = clean.replaceAll(',', '');
        final parsed = double.tryParse(stripped);
        if (parsed == null) return _AmountParseOutcome.invalid;
        return _AmountParseOutcome(
          isNegative ? -parsed : parsed,
          isNegative: isNegative,
        );
      }
      // Western repeated group integer: 1,234,567
      if (RegExp(r'^\d{1,3}(,\d{3}){2,}$').hasMatch(clean)) {
        final stripped = clean.replaceAll(',', '');
        final parsed = double.tryParse(stripped);
        if (parsed == null) return _AmountParseOutcome.invalid;
        return _AmountParseOutcome(
          isNegative ? -parsed : parsed,
          isNegative: isNegative,
        );
      }
      // European decimal: 1234,50 or 45,5
      if (RegExp(r'^\d+,\d{1,2}$').hasMatch(clean)) {
        final stripped = clean.replaceAll(',', '.');
        final parsed = double.tryParse(stripped);
        if (parsed == null) return _AmountParseOutcome.invalid;
        return _AmountParseOutcome(
          isNegative ? -parsed : parsed,
          isNegative: isNegative,
        );
      }
      // Exactly 3 digits after comma: 1,234 -> Ambiguous!
      if (RegExp(r'^\d{1,3},\d{3}$').hasMatch(clean)) {
        final stripped = clean.replaceAll(',', '');
        final parsed = double.tryParse(stripped);
        if (parsed == null) return _AmountParseOutcome.invalid;
        return _AmountParseOutcome(
          isNegative ? -parsed : parsed,
          isNegative: isNegative,
          isAmbiguous: true,
        );
      }
      return _AmountParseOutcome.invalid;
    }

    // 3. Only dot present (no comma)
    if (hasDot && !hasComma) {
      // European repeated group integer: 1.234.567
      if (RegExp(r'^\d{1,3}(\.\d{3}){2,}$').hasMatch(clean)) {
        final stripped = clean.replaceAll('.', '');
        final parsed = double.tryParse(stripped);
        if (parsed == null) return _AmountParseOutcome.invalid;
        return _AmountParseOutcome(
          isNegative ? -parsed : parsed,
          isNegative: isNegative,
        );
      }
      // Western decimal: 12.34 or 1234.50
      if (RegExp(r'^\d+\.\d{1,2}$').hasMatch(clean)) {
        final parsed = double.tryParse(clean);
        if (parsed == null) return _AmountParseOutcome.invalid;
        return _AmountParseOutcome(
          isNegative ? -parsed : parsed,
          isNegative: isNegative,
        );
      }
      // Exactly 3 digits after dot: 1.234 -> Ambiguous!
      if (RegExp(r'^\d{1,3}\.\d{3}$').hasMatch(clean)) {
        final parsed = double.tryParse(clean);
        if (parsed == null) return _AmountParseOutcome.invalid;
        return _AmountParseOutcome(
          isNegative ? -parsed : parsed,
          isNegative: isNegative,
          isAmbiguous: true,
        );
      }
      // Western multi-decimal: 12.3456
      if (RegExp(r'^\d+\.\d{3,}$').hasMatch(clean)) {
        final parsed = double.tryParse(clean);
        if (parsed == null) return _AmountParseOutcome.invalid;
        return _AmountParseOutcome(
          isNegative ? -parsed : parsed,
          isNegative: isNegative,
        );
      }
      return _AmountParseOutcome.invalid;
    }

    // 4. Plain integer without separators
    if (RegExp(r'^\d+$').hasMatch(clean)) {
      final parsed = double.tryParse(clean);
      if (parsed == null) return _AmountParseOutcome.invalid;
      return _AmountParseOutcome(
        isNegative ? -parsed : parsed,
        isNegative: isNegative,
      );
    }

    return _AmountParseOutcome.invalid;
  }

  List<List<String>> _parseCsvRows(String content) {
    final rows = <List<String>>[];
    final currentField = StringBuffer();
    final currentRow = <String>[];
    bool inQuotes = false;

    for (int i = 0; i < content.length; i++) {
      final char = content[i];
      if (inQuotes) {
        if (char == '"') {
          if (i + 1 < content.length && content[i + 1] == '"') {
            currentField.write('"');
            i++; // skip escaped quote
          } else {
            inQuotes = false;
          }
        } else {
          currentField.write(char);
        }
      } else {
        if (char == '"') {
          inQuotes = true;
        } else if (char == ',') {
          currentRow.add(currentField.toString().trim());
          currentField.clear();
        } else if (char == '\r') {
          if (i + 1 < content.length && content[i + 1] == '\n') {
            i++;
          }
          currentRow.add(currentField.toString().trim());
          currentField.clear();
          if (currentRow.isNotEmpty &&
              (currentRow.length > 1 || currentRow[0].isNotEmpty)) {
            rows.add(List.from(currentRow));
          }
          currentRow.clear();
        } else if (char == '\n') {
          currentRow.add(currentField.toString().trim());
          currentField.clear();
          if (currentRow.isNotEmpty &&
              (currentRow.length > 1 || currentRow[0].isNotEmpty)) {
            rows.add(List.from(currentRow));
          }
          currentRow.clear();
        } else {
          currentField.write(char);
        }
      }
    }
    if (currentField.isNotEmpty || currentRow.isNotEmpty) {
      currentRow.add(currentField.toString().trim());
      if (currentRow.isNotEmpty &&
          (currentRow.length > 1 || currentRow[0].isNotEmpty)) {
        rows.add(currentRow);
      }
    }
    return rows;
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
    BankAccountRepository? bankAccountRepo,
    CreditCardRepository? creditCardRepo,
    AiChatRepository? aiChatRepo,
    AiReportsRepository? aiReportsRepo,
  }) async {
    final isSqlite = transactionRepo is SqliteTransactionRepository;

    if (isSqlite) {
      // Perform atomic wipe + restore inside a single ACID SQLite transaction
      await AppDatabase.instance.atomicRestoreBackup(backup);
      return;
    }

    // 1. Wipe existing records to prevent conflicts (in-memory mock repos)
    await wipeAllData(
      transactionRepo: transactionRepo,
      budgetRepo: budgetRepo,
      savingsRepo: savingsRepo,
      debtRepo: debtRepo,
      investmentRepo: investmentRepo,
      recurringRepo: recurringRepo,
      bankAccountRepo: bankAccountRepo,
      creditCardRepo: creditCardRepo,
      aiChatRepo: aiChatRepo,
      aiReportsRepo: aiReportsRepo,
    );

    // 2. Restore Bank Accounts (in-memory mock repos)
    if (bankAccountRepo != null) {
      for (final a in backup.bankAccounts) {
        await bankAccountRepo.saveAccount(a);
      }
    }

    // 3. Restore Credit Cards
    if (creditCardRepo != null) {
      for (final c in backup.creditCards) {
        await creditCardRepo.saveCard(c);
      }
    }

    // 4. Restore transactions
    for (final tx in backup.transactions) {
      await transactionRepo.addTransaction(tx);
    }

    // 5. Restore budgets
    for (final b in backup.budgets) {
      await budgetRepo.saveBudget(b);
    }

    // 6. Restore savings goals & contributions
    for (final g in backup.savingsGoals) {
      await savingsRepo.saveGoal(g);
    }

    for (final c in backup.savingsContributions) {
      await savingsRepo.addContribution(c);
    }

    // 7. Restore debts & payments
    for (final d in backup.debts) {
      await debtRepo.saveDebt(d);
    }

    for (final p in backup.debtPayments) {
      await debtRepo.addPayment(p);
    }

    // 8. Restore investments
    for (final i in backup.investments) {
      await investmentRepo.saveInvestment(i);
    }

    // 9. Restore recurring expenses
    for (final r in backup.recurringExpenses) {
      await recurringRepo.saveRecurringExpense(r);
    }

    // 10. Restore AI chat history
    if (aiChatRepo != null) {
      if (backup.chatSessions.isNotEmpty) {
        await aiChatRepo.batchSaveSessions(backup.chatSessions);
      }
      if (backup.chatMessages.isNotEmpty) {
        await aiChatRepo.batchSaveMessages(backup.chatMessages);
      }
    }

    // 11. Restore AI reports
    if (aiReportsRepo != null) {
      for (final report in backup.aiReports) {
        await aiReportsRepo.saveReport(report);
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
    BankAccountRepository? bankAccountRepo,
    CreditCardRepository? creditCardRepo,
    AiChatRepository? aiChatRepo,
    AiReportsRepository? aiReportsRepo,
  }) async {
    if (transactionRepo is SqliteTransactionRepository) {
      try {
        await AppDatabase.instance.clearAllData();
        return;
      } catch (e, st) {
        LogService.warning(
          'BackupService',
          'Atomic clearAllData failed, falling back to individual repository deletes: $e',
        );
        LogService.error(
          'BackupService',
          'clearAllData failure details',
          e,
          st,
        );
      }
    }

    try {
      await transactionRepo.clearAllTransactions();
    } catch (err, st) {
      LogService.error('BackupService', 'clearAllTransactions error', err, st);
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

    if (bankAccountRepo != null) {
      final allAccounts = await bankAccountRepo.getAllAccounts();
      for (final a in allAccounts) {
        await bankAccountRepo.deleteAccount(a.id);
      }
    }

    if (creditCardRepo != null) {
      final allCards = await creditCardRepo.getAllCards();
      for (final c in allCards) {
        await creditCardRepo.deleteCard(c.id);
      }
    }

    if (aiChatRepo != null) {
      try {
        await aiChatRepo.clearAllChatHistory();
      } catch (err, st) {
        LogService.error('BackupService', 'clearAllChatHistory error', err, st);
      }
    }

    if (aiReportsRepo != null) {
      try {
        await aiReportsRepo.clearAllReports();
      } catch (err, st) {
        LogService.error('BackupService', 'clearAllReports error', err, st);
      }
    }
  }
}
