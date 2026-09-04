enum RecurringFrequency {
  daily,
  weekly,
  monthly,
  yearly;

  String get displayName {
    switch (this) {
      case RecurringFrequency.daily:
        return 'Daily';
      case RecurringFrequency.weekly:
        return 'Weekly';
      case RecurringFrequency.monthly:
        return 'Monthly';
      case RecurringFrequency.yearly:
        return 'Yearly';
    }
  }

  static RecurringFrequency fromString(String value) {
    switch (value.toLowerCase()) {
      case 'daily':
        return RecurringFrequency.daily;
      case 'weekly':
        return RecurringFrequency.weekly;
      case 'yearly':
        return RecurringFrequency.yearly;
      case 'monthly':
      default:
        return RecurringFrequency.monthly;
    }
  }
}

/// Core domain entity for recurring subscriptions, rent, EMIs, and bills
class RecurringExpenseEntity {
  final String id;
  final String title;
  final double amount;
  final String category;
  final RecurringFrequency frequency;
  final String paymentSource;
  final String? accountId;
  final String? creditCardId;
  final DateTime startDate;
  final DateTime nextDueDate;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  static const Object _sentinel = Object();

  const RecurringExpenseEntity({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.frequency,
    required this.paymentSource,
    this.accountId,
    this.creditCardId,
    required this.startDate,
    required this.nextDueDate,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  RecurringExpenseEntity copyWith({
    String? id,
    String? title,
    double? amount,
    String? category,
    RecurringFrequency? frequency,
    String? paymentSource,
    Object? accountId = _sentinel,
    Object? creditCardId = _sentinel,
    DateTime? startDate,
    DateTime? nextDueDate,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RecurringExpenseEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      frequency: frequency ?? this.frequency,
      paymentSource: paymentSource ?? this.paymentSource,
      accountId: identical(accountId, _sentinel) ? this.accountId : (accountId as String?),
      creditCardId: identical(creditCardId, _sentinel) ? this.creditCardId : (creditCardId as String?),
      startDate: startDate ?? this.startDate,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'category': category,
      'frequency': frequency.name,
      'payment_source': paymentSource,
      'account_id': accountId,
      'credit_card_id': creditCardId,
      'start_date': startDate.millisecondsSinceEpoch,
      'next_due_date': nextDueDate.millisecondsSinceEpoch,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory RecurringExpenseEntity.fromMap(Map<String, dynamic> map) {
    return RecurringExpenseEntity(
      id: map['id'] as String,
      title: map['title'] as String,
      amount: (map['amount'] as num).toDouble(),
      category: map['category'] as String,
      frequency: RecurringFrequency.fromString(map['frequency'] as String),
      paymentSource: map['payment_source'] as String? ?? 'Bank Account',
      accountId: map['account_id'] as String?,
      creditCardId: map['credit_card_id'] as String?,
      startDate: DateTime.fromMillisecondsSinceEpoch(map['start_date'] as int),
      nextDueDate: DateTime.fromMillisecondsSinceEpoch(map['next_due_date'] as int),
      isActive: (map['is_active'] as int) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  int get daysUntilDue => daysUntilDueFrom(DateTime.now());

  int daysUntilDueFrom(DateTime fromDate) {
    final today = DateTime(fromDate.year, fromDate.month, fromDate.day);
    final due = DateTime(nextDueDate.year, nextDueDate.month, nextDueDate.day);
    return due.difference(today).inDays;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecurringExpenseEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          amount == other.amount &&
          category == other.category &&
          frequency == other.frequency &&
          accountId == other.accountId &&
          creditCardId == other.creditCardId &&
          startDate == other.startDate &&
          nextDueDate == other.nextDueDate &&
          isActive == other.isActive;

  @override
  int get hashCode => Object.hash(
        id,
        title,
        amount,
        category,
        frequency,
        accountId,
        creditCardId,
        startDate,
        nextDueDate,
        isActive,
      );
}
