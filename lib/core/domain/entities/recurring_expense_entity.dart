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
  final DateTime startDate;
  final DateTime nextDueDate;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RecurringExpenseEntity({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.frequency,
    required this.paymentSource,
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
      startDate: DateTime.fromMillisecondsSinceEpoch(map['start_date'] as int),
      nextDueDate: DateTime.fromMillisecondsSinceEpoch(map['next_due_date'] as int),
      isActive: (map['is_active'] as int) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  int get daysUntilDue {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(nextDueDate.year, nextDueDate.month, nextDueDate.day);
    return due.difference(today).inDays;
  }
}
