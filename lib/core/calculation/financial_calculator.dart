import '../domain/entities/transaction_entity.dart';

class CategorySpendingSummary {
  final String category;
  final double amount;
  final double percentage;
  final int count;

  const CategorySpendingSummary({
    required this.category,
    required this.amount,
    required this.percentage,
    required this.count,
  });
}

/// Pure financial calculation engine for EmptyPocket
abstract class FinancialCalculator {
  /// Calculate total income from list of transactions
  static double calculateTotalIncome(List<TransactionEntity> transactions) {
    return transactions
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  /// Calculate total expense from list of transactions
  static double calculateTotalExpense(List<TransactionEntity> transactions) {
    return transactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  /// Calculate net balance (Total Income - Total Expense)
  static double calculateNetBalance(List<TransactionEntity> transactions) {
    return calculateTotalIncome(transactions) - calculateTotalExpense(transactions);
  }

  /// Calculate savings rate as a percentage: ((income - expense) / income) * 100
  /// Clamped between 0% and 100% for standard financial representation.
  static double calculateSavingsRate(double income, double expense) {
    if (income <= 0) return 0.0;
    final rate = ((income - expense) / income) * 100;
    return rate < 0 ? 0.0 : (rate > 100 ? 100.0 : rate);
  }

  /// Filter transactions for a given month and year
  static List<TransactionEntity> filterByMonth(
    List<TransactionEntity> transactions,
    DateTime month,
  ) {
    return transactions.where((t) {
      return t.date.year == month.year && t.date.month == month.month;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date)); // newest first
  }

  /// Filter transactions by TransactionType (null returns all)
  static List<TransactionEntity> filterByType(
    List<TransactionEntity> transactions,
    TransactionType? type,
  ) {
    if (type == null) return transactions;
    return transactions.where((t) => t.type == type).toList();
  }

  /// Search transactions by query (matches title, category, notes, or amount string)
  static List<TransactionEntity> searchTransactions(
    List<TransactionEntity> transactions,
    String query,
  ) {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) return transactions;

    return transactions.where((t) {
      final matchesTitle = t.title.toLowerCase().contains(cleanQuery);
      final matchesCategory = t.category.toLowerCase().contains(cleanQuery);
      final matchesNotes = t.notes?.toLowerCase().contains(cleanQuery) ?? false;
      final matchesSource = t.paymentSource.toLowerCase().contains(cleanQuery);
      final matchesAmount = t.amount.toString().contains(cleanQuery);

      return matchesTitle || matchesCategory || matchesNotes || matchesSource || matchesAmount;
    }).toList();
  }

  /// Group transactions by Date for categorized list views (e.g. today, yesterday, earlier)
  static Map<DateTime, List<TransactionEntity>> groupTransactionsByDate(
    List<TransactionEntity> transactions,
  ) {
    final sorted = List<TransactionEntity>.from(transactions)
      ..sort((a, b) => b.date.compareTo(a.date));

    final Map<DateTime, List<TransactionEntity>> grouped = {};

    for (final transaction in sorted) {
      // Normalize date to midnight (00:00:00)
      final dateKey = DateTime(
        transaction.date.year,
        transaction.date.month,
        transaction.date.day,
      );

      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(transaction);
    }

    return grouped;
  }

  /// Calculate breakdown of expenses grouped by category
  static List<CategorySpendingSummary> calculateCategoryBreakdown(
    List<TransactionEntity> transactions,
  ) {
    final expenses = transactions.where((t) => t.type == TransactionType.expense).toList();
    final totalExpense = expenses.fold(0.0, (sum, t) => sum + t.amount);

    if (totalExpense == 0) return [];

    final Map<String, List<TransactionEntity>> groupedByCategory = {};
    for (final item in expenses) {
      groupedByCategory.putIfAbsent(item.category, () => []).add(item);
    }

    final List<CategorySpendingSummary> summary = [];
    groupedByCategory.forEach((category, items) {
      final catAmount = items.fold(0.0, (sum, t) => sum + t.amount);
      final percentage = (catAmount / totalExpense) * 100;
      summary.add(
        CategorySpendingSummary(
          category: category,
          amount: catAmount,
          percentage: percentage,
          count: items.length,
        ),
      );
    });

    summary.sort((a, b) => b.amount.compareTo(a.amount));
    return summary;
  }
}
