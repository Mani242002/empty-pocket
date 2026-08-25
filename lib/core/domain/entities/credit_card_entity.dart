import 'dart:math';
import 'package:flutter/material.dart';

enum CardNetwork {
  visa,
  mastercard,
  rupay,
  amex,
  diners,
  other;

  String get displayName {
    switch (this) {
      case CardNetwork.visa:
        return 'Visa';
      case CardNetwork.mastercard:
        return 'Mastercard';
      case CardNetwork.rupay:
        return 'RuPay';
      case CardNetwork.amex:
        return 'American Express';
      case CardNetwork.diners:
        return 'Diners Club';
      case CardNetwork.other:
        return 'Other';
    }
  }

  static CardNetwork fromString(String value) {
    return CardNetwork.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => CardNetwork.visa,
    );
  }
}

enum CreditUtilizationHealth {
  optimal, // < 30%
  moderate, // 30% - 50%
  highRisk; // > 50%

  String get displayName {
    switch (this) {
      case CreditUtilizationHealth.optimal:
        return 'Optimal (<30%)';
      case CreditUtilizationHealth.moderate:
        return 'Moderate (30-50%)';
      case CreditUtilizationHealth.highRisk:
        return 'High Risk (>50%)';
    }
  }

  Color get color {
    switch (this) {
      case CreditUtilizationHealth.optimal:
        return const Color(0xFF10B981); // Emerald Green
      case CreditUtilizationHealth.moderate:
        return const Color(0xFFF59E0B); // Amber / Yellow
      case CreditUtilizationHealth.highRisk:
        return const Color(0xFFEF4444); // Red
    }
  }
}

/// Core domain entity representing a Credit Card
class CreditCardEntity {
  final String id;
  final String cardName;
  final String bankName;
  final CardNetwork cardNetwork;
  final double creditLimit;
  final double usedAmount;
  final int statementDateDay; // 1 to 31
  final int gracePeriodDays; // e.g. 20 days
  final String cardTheme; // 'obsidian', 'emerald', 'midnightBlue', 'roseGold', 'royalPurple'
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CreditCardEntity({
    required this.id,
    required this.cardName,
    required this.bankName,
    this.cardNetwork = CardNetwork.visa,
    required this.creditLimit,
    this.usedAmount = 0.0,
    required this.statementDateDay,
    this.gracePeriodDays = 20,
    this.cardTheme = 'obsidian',
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
  });

  double get availableLimit => max(0.0, creditLimit - usedAmount);

  double get utilizationRatio =>
      creditLimit > 0 ? (usedAmount / creditLimit) * 100 : 0.0;

  CreditUtilizationHealth get utilizationHealth {
    if (utilizationRatio <= 30.0) return CreditUtilizationHealth.optimal;
    if (utilizationRatio <= 50.0) return CreditUtilizationHealth.moderate;
    return CreditUtilizationHealth.highRisk;
  }

  /// Calculates upcoming statement generation date relative to a base date
  DateTime getNextStatementDate([DateTime? relativeTo]) {
    final now = relativeTo ?? DateTime.now();
    final clampedDay = min(statementDateDay, _daysInMonth(now.year, now.month));
    final candidateThisMonth = DateTime(now.year, now.month, clampedDay);

    if (now.isBefore(candidateThisMonth) || now.isAtSameMomentAs(candidateThisMonth)) {
      return candidateThisMonth;
    } else {
      final nextMonthYear = now.month == 12 ? now.year + 1 : now.year;
      final nextMonth = now.month == 12 ? 1 : now.month + 1;
      final nextClampedDay = min(statementDateDay, _daysInMonth(nextMonthYear, nextMonth));
      return DateTime(nextMonthYear, nextMonth, nextClampedDay);
    }
  }

  /// Calculates upcoming bill payment due date (Statement Date + Grace Period Days)
  DateTime getNextDueDate([DateTime? relativeTo]) {
    final statementDate = getNextStatementDate(relativeTo);
    return statementDate.add(Duration(days: gracePeriodDays));
  }

  /// Days remaining until upcoming statement generation
  int daysUntilStatement([DateTime? relativeTo]) {
    final now = relativeTo ?? DateTime.now();
    final nextStatement = getNextStatementDate(now);
    final diff = nextStatement.difference(DateTime(now.year, now.month, now.day)).inDays;
    return max(0, diff);
  }

  /// Days remaining until upcoming bill due date
  int daysUntilDue([DateTime? relativeTo]) {
    final now = relativeTo ?? DateTime.now();
    final nextDue = getNextDueDate(now);
    final diff = nextDue.difference(DateTime(now.year, now.month, now.day)).inDays;
    return max(0, diff);
  }

  static int _daysInMonth(int year, int month) {
    final beginningNextMonth = (month < 12)
        ? DateTime(year, month + 1, 1)
        : DateTime(year + 1, 1, 1);
    return beginningNextMonth.subtract(const Duration(days: 1)).day;
  }

  CreditCardEntity copyWith({
    String? id,
    String? cardName,
    String? bankName,
    CardNetwork? cardNetwork,
    double? creditLimit,
    double? usedAmount,
    int? statementDateDay,
    int? gracePeriodDays,
    String? cardTheme,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CreditCardEntity(
      id: id ?? this.id,
      cardName: cardName ?? this.cardName,
      bankName: bankName ?? this.bankName,
      cardNetwork: cardNetwork ?? this.cardNetwork,
      creditLimit: creditLimit ?? this.creditLimit,
      usedAmount: usedAmount ?? this.usedAmount,
      statementDateDay: statementDateDay ?? this.statementDateDay,
      gracePeriodDays: gracePeriodDays ?? this.gracePeriodDays,
      cardTheme: cardTheme ?? this.cardTheme,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'card_name': cardName,
      'bank_name': bankName,
      'card_network': cardNetwork.name,
      'credit_limit': creditLimit,
      'used_amount': usedAmount,
      'statement_date_day': statementDateDay,
      'grace_period_days': gracePeriodDays,
      'card_theme': cardTheme,
      'is_archived': isArchived ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory CreditCardEntity.fromMap(Map<String, dynamic> map) {
    return CreditCardEntity(
      id: map['id'] as String,
      cardName: map['card_name'] as String,
      bankName: map['bank_name'] as String? ?? 'Credit Card',
      cardNetwork: CardNetwork.fromString(map['card_network'] as String? ?? 'visa'),
      creditLimit: (map['credit_limit'] as num).toDouble(),
      usedAmount: (map['used_amount'] as num?)?.toDouble() ?? 0.0,
      statementDateDay: (map['statement_date_day'] as num?)?.toInt() ?? 1,
      gracePeriodDays: (map['grace_period_days'] as num?)?.toInt() ?? 20,
      cardTheme: map['card_theme'] as String? ?? 'obsidian',
      isArchived: (map['is_archived'] as int?) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreditCardEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          cardName == other.cardName &&
          bankName == other.bankName &&
          cardNetwork == other.cardNetwork &&
          creditLimit == other.creditLimit &&
          usedAmount == other.usedAmount &&
          statementDateDay == other.statementDateDay &&
          gracePeriodDays == other.gracePeriodDays &&
          cardTheme == other.cardTheme &&
          isArchived == other.isArchived;

  @override
  int get hashCode => Object.hash(
        id,
        cardName,
        bankName,
        cardNetwork,
        creditLimit,
        usedAmount,
        statementDateDay,
        gracePeriodDays,
        cardTheme,
        isArchived,
      );
}
