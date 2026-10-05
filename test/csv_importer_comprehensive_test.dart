import 'package:flutter_test/flutter_test.dart';
import 'package:empty_pocket/core/domain/entities/transaction_entity.dart';
import 'package:empty_pocket/core/services/backup_service.dart';

void main() {
  late BackupService backupService;

  setUp(() {
    backupService = BackupService();
  });

  group('CSV Export & OWASP Formula Injection Neutralization (CWE-1236)', () {
    test(
      'neutralizes formula injection triggers in titles, categories, and notes',
      () {
        final now = DateTime(2026, 10, 4, 12, 0, 0);
        final transactions = [
          TransactionEntity(
            id: 'tx-001',
            title: '=cmd|\' /C calc\'!A0',
            amount: 50.0,
            type: TransactionType.expense,
            category: '+SUM(1+2)',
            date: now,
            paymentSource: '@AdminPay',
            notes: '\t=HYPERLINK("http://attacker.com")',
            createdAt: now,
            updatedAt: now,
          ),
          TransactionEntity(
            id: '=danger-id',
            title: '   =1+2 with leading spaces',
            amount: 100.0,
            type: TransactionType.income,
            category: '-DDE("server")',
            date: now,
            paymentSource: '+500',
            notes: 'Safe Note',
            createdAt: now,
            updatedAt: now,
          ),
        ];

        final csv = backupService.exportTransactionsToCsv(transactions);
        final lines = csv
            .split('\n')
            .where((l) => l.trim().isNotEmpty)
            .toList();

        expect(lines.length, 3); // 1 header + 2 rows

        // Row 1 assertions
        expect(lines[1], contains('"\'=cmd|\' /C calc\'!A0"'));
        expect(
          lines[1],
          anyOf(
            contains('"\' +SUM(1+2)"'),
            contains('"\'\u002bSUM(1+2)"'),
            contains("'+SUM(1+2)"),
          ),
        );
        expect(lines[1], contains('"\'@AdminPay"'));
        expect(
          lines[1],
          anyOf(contains('"\t=HYPERLINK'), contains('"\'\t=HYPERLINK')),
        );

        // Row 2 assertions
        expect(lines[2], contains('"\'=danger-id"')); // ID itself neutralized
        expect(
          lines[2],
          contains('"\'   =1+2 with leading spaces"'),
        ); // leading space before formula
        expect(lines[2], anyOf(contains("'-DDE"), contains('"\' -DDE')));
      },
    );

    test('quotes all fields consistently according to RFC 4180', () {
      final now = DateTime(2026, 10, 4, 12, 0, 0);
      final transactions = [
        TransactionEntity(
          id: 'id-normal',
          title: 'Grocery, Market & Deli',
          amount: 75.25,
          type: TransactionType.expense,
          category: 'Food',
          date: now,
          paymentSource: 'Credit Card',
          notes: 'Fresh veggies\nOrganic milk',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final csv = backupService.exportTransactionsToCsv(transactions);
      expect(csv, contains('"id-normal"'));
      expect(csv, contains('"Grocery, Market & Deli"'));
      expect(csv, contains('"Fresh veggies\nOrganic milk"'));
    });
  });

  group('CSV Number Parsing Modes & Format Ambiguity Resolution', () {
    test('parses Indian Numbering format (Lakhs and Crores) accurately', () {
      final csv = '''
Date,Title,Amount,Type,Category
2026-10-04,Salary Inflow,"12,34,567.89",Income,Salary
2026-10-04,Mutual Fund Lumpsum,"1,00,000",Expense,Investments
2026-10-04,House Purchase Deposit,"1,50,00,000.50",Expense,Real Estate
''';

      final result = backupService.parseTransactionsFromCsvWithResult(csv);
      expect(result.requiresFormatConfirmation, false);
      expect(result.transactions.length, 3);
      expect(result.transactions[0].amount, 1234567.89);
      expect(result.transactions[1].amount, 100000.0);
      expect(result.transactions[2].amount, 15000000.50);
    });

    test('parses Western format with repeated comma groupings and comma decimal correctly', () {
      final csv = '''
Date,Title,Amount,Type,Category
2026-10-04,US Stock Transfer,"1,234,567.89",Income,Stocks
2026-10-04,Single Comma Thousand,"1,234.50",Expense,Electronics
''';

      final result = backupService.parseTransactionsFromCsvWithResult(csv);
      expect(result.requiresFormatConfirmation, false);
      expect(result.transactions.length, 2);
      expect(result.transactions[0].amount, 1234567.89);
      expect(result.transactions[1].amount, 1234.50);
    });

    test('parses European format with repeated dot groupings and comma decimals correctly', () {
      final csv = '''
Date,Title,Amount,Type,Category
2026-10-04,Euro Salary,"1.234.567,89",Income,Salary
2026-10-04,European Grocery,"1.234,50",Expense,Groceries
2026-10-04,Small European Item,"45,50",Expense,Coffee
''';

      final result = backupService.parseTransactionsFromCsvWithResult(csv);
      expect(result.requiresFormatConfirmation, false);
      expect(result.transactions.length, 3);
      expect(result.transactions[0].amount, 1234567.89);
      expect(result.transactions[1].amount, 1234.50);
      expect(result.transactions[2].amount, 45.50);
    });

    test(
      'flags isolated single-group 3-digit values as ambiguous in auto mode',
      () {
        final csv = '''
Date,Title,Amount,Type,Category
2026-10-04,Ambiguous Item A,"1.234",Expense,Shopping
2026-10-04,Ambiguous Item B,"1,234",Expense,Shopping
''';

        final result = backupService.parseTransactionsFromCsvWithResult(
          csv,
          formatMode: NumberFormatMode.auto,
        );
        expect(result.requiresFormatConfirmation, true);
        expect(result.ambiguousAmountCount, 2);
      },
    );

    test('resolves ambiguous numbers unambiguously when user selects explicit format mode', () {
      final csv = '''
Date,Title,Amount,Type,Category
2026-10-04,Item A,"1.234",Expense,Shopping
2026-10-04,Item B,"1,234",Expense,Shopping
''';

      // User selects Western:
      final westernResult = backupService.parseTransactionsFromCsvWithResult(
        csv,
        formatMode: NumberFormatMode.western,
      );
      expect(westernResult.requiresFormatConfirmation, false);
      expect(westernResult.transactions[0].amount, 1.234);
      expect(westernResult.transactions[1].amount, 1234.0);

      // User selects European:
      final europeanResult = backupService.parseTransactionsFromCsvWithResult(
        csv,
        formatMode: NumberFormatMode.european,
      );
      expect(europeanResult.requiresFormatConfirmation, false);
      expect(europeanResult.transactions[0].amount, 1234.0);
      expect(europeanResult.transactions[1].amount, 1.234);
    });

    test('rejects malformed number groupings like 1,23,4 and records invalidRowsCount', () {
      final csv = '''
Date,Title,Amount,Type,Category
2026-10-04,Valid Item,50.00,Expense,Shopping
2026-10-04,Malformed Auto,"1,23,4",Expense,Shopping
2026-10-04,Malformed Dot,"1.23.4",Expense,Shopping
''';

      final result = backupService.parseTransactionsFromCsvWithResult(
        csv,
        formatMode: NumberFormatMode.auto,
      );
      expect(result.transactions.length, 1);
      expect(result.transactions[0].amount, 50.0);
      expect(result.invalidRowsCount, 2);

      // Verify Indian mode also rejects 1,23,4
      final indianResult = backupService.parseTransactionsFromCsvWithResult(
        csv,
        formatMode: NumberFormatMode.indian,
      );
      expect(indianResult.transactions.length, 1);
      expect(indianResult.invalidRowsCount, 2);

      // Verify Western mode also rejects 1,23,4
      final westernResult = backupService.parseTransactionsFromCsvWithResult(
        csv,
        formatMode: NumberFormatMode.western,
      );
      expect(westernResult.transactions.length, 1);
      expect(westernResult.invalidRowsCount, 2);
    });

    test('preserves negative amounts and maps them to expenses with positive magnitude', () {
      final csv = '''
Date,Title,Amount,Category
2026-10-04,Grocery Store,-45.50,Groceries
2026-10-04,Coffee Shop,"(12.00)",Dining
2026-10-04,Salary Inflow,2500.00,Salary
''';

      final result = backupService.parseTransactionsFromCsvWithResult(csv);
      expect(result.transactions.length, 3);
      expect(result.invalidRowsCount, 0);

      expect(result.transactions[0].title, 'Grocery Store');
      expect(result.transactions[0].amount, 45.50);
      expect(result.transactions[0].type, TransactionType.expense);

      expect(result.transactions[1].title, 'Coffee Shop');
      expect(result.transactions[1].amount, 12.00);
      expect(result.transactions[1].type, TransactionType.expense);

      expect(result.transactions[2].title, 'Salary Inflow');
      expect(result.transactions[2].amount, 2500.00);
    });
  });
}
