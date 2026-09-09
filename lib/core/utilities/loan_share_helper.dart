import 'dart:convert';
import 'currency_formatter.dart';

/// Structured metadata for a personal financial loan / assistance given to a friend or relative
class LoanShareData {
  final String borrowerName;
  final double principalAmount;
  final double expectedInterest;
  final double? interestRate; // Annual or agreed % rate (optional)
  final DateTime? expectedReturnDate;
  final double repaidAmount;
  final bool isRepaid;
  final String? paymentSource;

  const LoanShareData({
    required this.borrowerName,
    required this.principalAmount,
    this.expectedInterest = 0.0,
    this.interestRate,
    this.expectedReturnDate,
    this.repaidAmount = 0.0,
    this.isRepaid = false,
    this.paymentSource,
  });

  /// Total amount expected back (Principal + Expected Interest)
  double get totalExpected => principalAmount + expectedInterest;

  /// Remaining amount yet to be received back from the borrower
  double get pendingAmount =>
      isRepaid ? 0.0 : (totalExpected - repaidAmount).clamp(0.0, double.infinity);

  /// Whether the expected return date has passed without being repaid
  bool get isOverdue {
    if (isRepaid || expectedReturnDate == null) return false;
    final now = DateTime.now();
    final endOfDueDay = DateTime(
      expectedReturnDate!.year,
      expectedReturnDate!.month,
      expectedReturnDate!.day,
      23,
      59,
      59,
    );
    return now.isAfter(endOfDueDay);
  }

  Map<String, dynamic> toMap() => {
        'type': 'loan',
        'borrower': borrowerName,
        'principal': principalAmount,
        if (expectedInterest > 0) 'interest': expectedInterest,
        if (interestRate != null) 'interestRate': interestRate,
        if (expectedReturnDate != null)
          'dueDate': expectedReturnDate!.toIso8601String(),
        if (repaidAmount > 0) 'repaid': repaidAmount,
        if (isRepaid) 'settled': true,
        if (paymentSource != null) 'source': paymentSource,
      };

  factory LoanShareData.fromMap(Map<String, dynamic> map) {
    DateTime? dueDate;
    if (map['dueDate'] != null) {
      dueDate = DateTime.tryParse(map['dueDate'] as String);
    }
    final principal = ((map['principal'] ?? map['amount'] ?? 0) as num).toDouble();
    final interest = ((map['interest'] ?? 0) as num).toDouble();
    final rate = map['interestRate'] != null ? (map['interestRate'] as num).toDouble() : null;
    final repaid = ((map['repaid'] ?? 0) as num).toDouble();
    final settled = map['settled'] == true || map['isSettled'] == true;

    return LoanShareData(
      borrowerName: (map['borrower'] ?? map['name'] ?? 'Friend') as String,
      principalAmount: principal,
      expectedInterest: interest,
      interestRate: rate,
      expectedReturnDate: dueDate,
      repaidAmount: repaid,
      isRepaid: settled || (principal > 0 && repaid >= (principal + interest)),
      paymentSource: map['source'] as String?,
    );
  }

  LoanShareData copyWith({
    String? borrowerName,
    double? principalAmount,
    double? expectedInterest,
    double? interestRate,
    DateTime? expectedReturnDate,
    double? repaidAmount,
    bool? isRepaid,
    String? paymentSource,
  }) {
    return LoanShareData(
      borrowerName: borrowerName ?? this.borrowerName,
      principalAmount: principalAmount ?? this.principalAmount,
      expectedInterest: expectedInterest ?? this.expectedInterest,
      interestRate: interestRate ?? this.interestRate,
      expectedReturnDate: expectedReturnDate ?? this.expectedReturnDate,
      repaidAmount: repaidAmount ?? this.repaidAmount,
      isRepaid: isRepaid ?? this.isRepaid,
      paymentSource: paymentSource ?? this.paymentSource,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoanShareData &&
          runtimeType == other.runtimeType &&
          borrowerName == other.borrowerName &&
          principalAmount == other.principalAmount &&
          expectedInterest == other.expectedInterest &&
          expectedReturnDate == other.expectedReturnDate &&
          repaidAmount == other.repaidAmount &&
          isRepaid == other.isRepaid;

  @override
  int get hashCode => Object.hash(
        borrowerName,
        principalAmount,
        expectedInterest,
        expectedReturnDate,
        repaidAmount,
        isRepaid,
      );
}

/// Helper for encoding, decoding, and formatting money lent metadata
class LoanShareHelper {
  /// Encodes a [LoanShareData] object into a compact JSON string for storage in `shared_with`
  static String encodeLoan(LoanShareData loan) {
    return jsonEncode(loan.toMap());
  }

  /// Checks whether a `sharedWith` string represents a structured loan
  static bool isLoan(String? sharedWith) {
    if (sharedWith == null || sharedWith.trim().isEmpty) return false;
    final trimmed = sharedWith.trim();
    if (!trimmed.startsWith('{') || !trimmed.endsWith('}')) return false;
    try {
      final decoded = jsonDecode(trimmed);
      return decoded is Map && decoded['type'] == 'loan';
    } catch (_) {
      return false;
    }
  }

  /// Parses JSON map from `sharedWith` into [LoanShareData].
  /// Returns null if null, empty, or not a valid loan JSON.
  static LoanShareData? parseLoan(String? sharedWith) {
    if (sharedWith == null || sharedWith.trim().isEmpty) return null;
    final trimmed = sharedWith.trim();
    if (!trimmed.startsWith('{') || !trimmed.endsWith('}')) return null;

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic> && decoded['type'] == 'loan') {
        return LoanShareData.fromMap(decoded);
      } else if (decoded is Map && decoded['type'] == 'loan') {
        return LoanShareData.fromMap(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      // Not a valid JSON map
    }

    return null;
  }

  /// Formats display string, e.g. "Lent to Rahul • ₹10,000 + ₹500 interest"
  static String formatDisplay(LoanShareData loan) {
    if (loan.expectedInterest > 0) {
      return 'Lent to ${loan.borrowerName} • ${CurrencyFormatter.format(loan.principalAmount)} + ${CurrencyFormatter.format(loan.expectedInterest)} interest';
    }
    return 'Lent to ${loan.borrowerName} • ${CurrencyFormatter.format(loan.principalAmount)}';
  }
}
