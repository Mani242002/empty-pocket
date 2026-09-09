import 'dart:convert';
import '../domain/entities/split_person_share.dart';
import '../domain/entities/transaction_entity.dart';
import 'currency_formatter.dart';
import 'loan_share_helper.dart';

/// Summary of all pending reimbursements owed by a single person
class PersonPendingSummary {
  final String personName;
  final double totalPending;
  final int expenseCount;
  final List<TransactionEntity> transactions;

  const PersonPendingSummary({
    required this.personName,
    required this.totalPending,
    required this.expenseCount,
    required this.transactions,
  });
}

/// Helper for encoding, decoding, formatting, and aggregating per-person splits
class SplitHelper {
  /// Encodes a list of [SplitPersonShare] into a compact JSON string for storage in `shared_with`
  static String encodeShares(List<SplitPersonShare> shares) {
    if (shares.isEmpty) return '';
    return jsonEncode(shares.map((s) => s.toMap()).toList());
  }

  /// Parses JSON array from `sharedWith` into a structured list of [SplitPersonShare].
  /// Returns an empty list if null, empty, or not a JSON array.
  static List<SplitPersonShare> parseShares(String? sharedWith) {
    if (sharedWith == null || sharedWith.trim().isEmpty) return [];

    final trimmed = sharedWith.trim();
    if (!trimmed.startsWith('[') || !trimmed.endsWith(']')) {
      return [];
    }

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map((m) => SplitPersonShare.fromMap(m))
            .toList();
      }
    } catch (_) {
      // Not a valid JSON array
    }

    return [];
  }

  /// Returns a clean human-readable representation of split shares, e.g. "Raji: ₹100, Susmitha: ₹50"
  static String formatDisplay(List<SplitPersonShare> shares, [String? fallbackText]) {
    if (shares.isEmpty) return fallbackText ?? '';

    return shares
        .map((s) => '${s.personName}: ${CurrencyFormatter.format(s.amount)}')
        .join(', ');
  }

  /// Returns a human-friendly display string for `sharedWith`, properly decoding both
  /// structured person split arrays and money lent loan objects without ever exposing raw JSON.
  static String formatSharedWithDisplay(String? sharedWith) {
    if (sharedWith == null || sharedWith.trim().isEmpty) return '';

    final loan = LoanShareHelper.parseLoan(sharedWith);
    if (loan != null) {
      final interestStr = loan.expectedInterest > 0
          ? ' (+${CurrencyFormatter.format(loan.expectedInterest)} interest)'
          : '';
      return 'Lent to ${loan.borrowerName}$interestStr';
    }

    final shares = parseShares(sharedWith);
    if (shares.isNotEmpty) {
      return formatDisplay(shares);
    }

    final trimmed = sharedWith.trim();
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      return '';
    }
    return trimmed;
  }

  /// Aggregates all pending reimbursement balances grouped by person name across transactions
  static List<PersonPendingSummary> groupPendingByPerson(
    List<TransactionEntity> transactions,
  ) {
    final Map<String, _PersonAccumulator> accumulators = {};

    for (final tx in transactions) {
      if (!tx.isShared || tx.isSettled || tx.pendingReimbursement <= 0) {
        continue;
      }

      // 1. Check if this transaction is a Money Lent / Personal Help loan
      final loan = LoanShareHelper.parseLoan(tx.sharedWith);
      if (loan != null) {
        final borrower = loan.borrowerName.trim();
        final pending = loan.pendingAmount > 0 ? loan.pendingAmount : tx.pendingReimbursement;
        if (borrower.isNotEmpty && pending > 0) {
          final lookupKey = borrower.toLowerCase();
          final acc = accumulators.putIfAbsent(
            lookupKey,
            () => _PersonAccumulator(personName: borrower),
          );
          acc.totalPending += pending;
          if (!acc.transactions.any((t) => t.id == tx.id)) {
            acc.transactions.add(tx);
          }
        }
        continue;
      }

      // 2. Structured split shares array
      final shares = parseShares(tx.sharedWith);
      if (shares.isNotEmpty) {
        for (final share in shares) {
          final pending = share.pendingAmount;
          final trimmed = share.personName.trim();
          if (pending > 0 && trimmed.isNotEmpty) {
            final lookupKey = trimmed.toLowerCase();
            final acc = accumulators.putIfAbsent(
              lookupKey,
              () => _PersonAccumulator(personName: trimmed),
            );
            acc.totalPending += pending;
            if (!acc.transactions.any((t) => t.id == tx.id)) {
              acc.transactions.add(tx);
            }
          }
        }
      } else if (tx.sharedWith != null && tx.sharedWith!.trim().isNotEmpty) {
        // Fallback for simple plain text friend names (strictly protect against raw JSON)
        final trimmed = tx.sharedWith!.trim();
        if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) {
          final lookupKey = trimmed.toLowerCase();
          final acc = accumulators.putIfAbsent(
            lookupKey,
            () => _PersonAccumulator(personName: trimmed),
          );
          acc.totalPending += tx.pendingReimbursement;
          if (!acc.transactions.any((t) => t.id == tx.id)) {
            acc.transactions.add(tx);
          }
        }
      }
    }

    final result = accumulators.values
        .map(
          (acc) => PersonPendingSummary(
            personName: acc.personName,
            totalPending: acc.totalPending,
            expenseCount: acc.transactions.length,
            transactions: acc.transactions,
          ),
        )
        .toList();

    // Sort descending by highest pending amount
    result.sort((a, b) => b.totalPending.compareTo(a.totalPending));
    return result;
  }
}

class _PersonAccumulator {
  final String personName;
  double totalPending = 0.0;
  final List<TransactionEntity> transactions = [];

  _PersonAccumulator({required this.personName});
}
