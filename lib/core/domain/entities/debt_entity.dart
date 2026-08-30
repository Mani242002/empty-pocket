import 'package:flutter/material.dart';

enum DebtType {
  personalLoan,
  homeLoan,
  carLoan,
  educationLoan,
  creditCard,
  peerBorrowed,
  peerLent,
  other;

  String get displayName {
    switch (this) {
      case DebtType.personalLoan:
        return 'Personal Loan';
      case DebtType.homeLoan:
        return 'Home Loan';
      case DebtType.carLoan:
        return 'Vehicle / Car Loan';
      case DebtType.educationLoan:
        return 'Education Loan';
      case DebtType.creditCard:
        return 'Credit Card Debt';
      case DebtType.peerBorrowed:
        return 'Borrowed from Friend/Family';
      case DebtType.peerLent:
        return 'Lent to Friend/Family';
      case DebtType.other:
        return 'Other Liability';
    }
  }

  IconData get icon {
    switch (this) {
      case DebtType.personalLoan:
        return Icons.account_balance_rounded;
      case DebtType.homeLoan:
        return Icons.home_rounded;
      case DebtType.carLoan:
        return Icons.directions_car_rounded;
      case DebtType.educationLoan:
        return Icons.school_rounded;
      case DebtType.creditCard:
        return Icons.credit_card_rounded;
      case DebtType.peerBorrowed:
        return Icons.call_received_rounded;
      case DebtType.peerLent:
        return Icons.call_made_rounded;
      case DebtType.other:
        return Icons.money_off_rounded;
    }
  }

  static DebtType fromString(String value) {
    return DebtType.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => DebtType.personalLoan,
    );
  }
}

enum DebtStatus {
  active,
  paidOff;

  String get displayName {
    switch (this) {
      case DebtStatus.active:
        return 'Active';
      case DebtStatus.paidOff:
        return 'Paid Off';
    }
  }

  static DebtStatus fromString(String value) {
    return DebtStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => DebtStatus.active,
    );
  }
}

/// Core domain entity representing a loan, liability, or debt obligation
class DebtEntity {
  final String id;
  final String title;
  final DebtType type;
  final double principalAmount;
  final double remainingAmount;
  final double interestRate; // Annual % (e.g. 8.5)
  final int tenureMonths;
  final double monthlyEmi;
  final DateTime startDate;
  final int dueDateDay; // Day of the month (1-31)
  final String? lenderName;
  final DebtStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DebtEntity({
    required this.id,
    required this.title,
    required this.type,
    required this.principalAmount,
    required this.remainingAmount,
    this.interestRate = 0.0,
    this.tenureMonths = 12,
    required this.monthlyEmi,
    required this.startDate,
    this.dueDateDay = 5,
    this.lenderName,
    this.status = DebtStatus.active,
    required this.createdAt,
    required this.updatedAt,
  });

  static const Object _sentinel = Object();

  DebtEntity copyWith({
    String? id,
    String? title,
    DebtType? type,
    double? principalAmount,
    double? remainingAmount,
    double? interestRate,
    int? tenureMonths,
    double? monthlyEmi,
    DateTime? startDate,
    int? dueDateDay,
    Object? lenderName = _sentinel,
    DebtStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DebtEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      principalAmount: principalAmount ?? this.principalAmount,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      interestRate: interestRate ?? this.interestRate,
      tenureMonths: tenureMonths ?? this.tenureMonths,
      monthlyEmi: monthlyEmi ?? this.monthlyEmi,
      startDate: startDate ?? this.startDate,
      dueDateDay: dueDateDay ?? this.dueDateDay,
      lenderName: identical(lenderName, _sentinel) ? this.lenderName : (lenderName as String?),
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'type': type.name,
      'principal_amount': principalAmount,
      'remaining_amount': remainingAmount,
      'interest_rate': interestRate,
      'tenure_months': tenureMonths,
      'monthly_emi': monthlyEmi,
      'start_date': startDate.millisecondsSinceEpoch,
      'due_date_day': dueDateDay,
      'lender_name': lenderName,
      'status': status.name,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory DebtEntity.fromMap(Map<String, dynamic> map) {
    return DebtEntity(
      id: map['id'] as String,
      title: map['title'] as String,
      type: DebtType.fromString(map['type'] as String),
      principalAmount: (map['principal_amount'] as num).toDouble(),
      remainingAmount: (map['remaining_amount'] as num).toDouble(),
      interestRate: (map['interest_rate'] as num?)?.toDouble() ?? 0.0,
      tenureMonths: (map['tenure_months'] as num?)?.toInt() ?? 12,
      monthlyEmi: (map['monthly_emi'] as num).toDouble(),
      startDate: DateTime.fromMillisecondsSinceEpoch(map['start_date'] as int),
      dueDateDay: (map['due_date_day'] as num?)?.toInt() ?? 5,
      lenderName: map['lender_name'] as String?,
      status: DebtStatus.fromString(map['status'] as String),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DebtEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          principalAmount == other.principalAmount &&
          remainingAmount == other.remainingAmount &&
          status == other.status;

  @override
  int get hashCode => Object.hash(
        id,
        title,
        principalAmount,
        remainingAmount,
        status,
      );
}

/// Domain entity representing a payment or prepayment logged against a debt
class DebtPaymentEntity {
  final String id;
  final String debtId;
  final double amount;
  final double principalPortion;
  final double interestPortion;
  final DateTime date;
  final String? notes;
  final DateTime createdAt;

  const DebtPaymentEntity({
    required this.id,
    required this.debtId,
    required this.amount,
    this.principalPortion = 0.0,
    this.interestPortion = 0.0,
    required this.date,
    this.notes,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'debt_id': debtId,
      'amount': amount,
      'principal_portion': principalPortion,
      'interest_portion': interestPortion,
      'date': date.millisecondsSinceEpoch,
      'notes': notes,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory DebtPaymentEntity.fromMap(Map<String, dynamic> map) {
    return DebtPaymentEntity(
      id: map['id'] as String,
      debtId: map['debt_id'] as String,
      amount: (map['amount'] as num).toDouble(),
      principalPortion: (map['principal_portion'] as num?)?.toDouble() ?? 0.0,
      interestPortion: (map['interest_portion'] as num?)?.toDouble() ?? 0.0,
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      notes: map['notes'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
}

/// Calculated metrics for a specific debt
class DebtRepaymentMetrics {
  final DebtEntity debt;
  final double paidAmount;
  final double paidPercentage;
  final bool isPaidOff;
  final int estimatedMonthsRemaining;

  const DebtRepaymentMetrics({
    required this.debt,
    required this.paidAmount,
    required this.paidPercentage,
    required this.isPaidOff,
    required this.estimatedMonthsRemaining,
  });
}

/// Overall liabilities summary across all debts
class OverallLiabilitiesSummary {
  final double totalOutstanding;
  final double totalMonthlyEmi;
  final double totalOriginalPrincipal;
  final double totalPaidOff;
  final int activeDebtsCount;
  final int paidOffDebtsCount;

  const OverallLiabilitiesSummary({
    required this.totalOutstanding,
    required this.totalMonthlyEmi,
    required this.totalOriginalPrincipal,
    required this.totalPaidOff,
    required this.activeDebtsCount,
    required this.paidOffDebtsCount,
  });

  static const OverallLiabilitiesSummary empty = OverallLiabilitiesSummary(
    totalOutstanding: 0.0,
    totalMonthlyEmi: 0.0,
    totalOriginalPrincipal: 0.0,
    totalPaidOff: 0.0,
    activeDebtsCount: 0,
    paidOffDebtsCount: 0,
  );
}
