import 'dart:convert';
import '../domain/entities/split_person_share.dart';
import '../domain/entities/transaction_entity.dart';
import 'currency_formatter.dart';

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

  /// Aggregates all pending reimbursement balances grouped by person name across transactions
  static List<PersonPendingSummary> groupPendingByPerson(
    List<TransactionEntity> transactions,
  ) {
    final Map<String, _PersonAccumulator> accumulators = {};

    for (final tx in transactions) {
      if (!tx.isShared || tx.isSettled || tx.pendingReimbursement <= 0) {
        continue;
      }

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
        // Fallback for transactions with unparsed text
        final trimmed = tx.sharedWith!.trim();
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
