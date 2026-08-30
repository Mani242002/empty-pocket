enum TransactionType {
  income,
  expense,
  transfer;

  String get displayName {
    switch (this) {
      case TransactionType.income:
        return 'Income';
      case TransactionType.expense:
        return 'Expense';
      case TransactionType.transfer:
        return 'Transfer';
    }
  }

  static TransactionType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'income':
        return TransactionType.income;
      case 'transfer':
        return TransactionType.transfer;
      case 'expense':
      default:
        return TransactionType.expense;
    }
  }
}

/// Core domain entity representing a financial transaction in EmptyPocket
class TransactionEntity {
  final String id;
  final String title;
  final double amount;
  final TransactionType type;
  final String category;
  final DateTime date;
  final String paymentSource;
  final String? accountId; // Linked Bank Account ID
  final String? toAccountId; // Destination Bank Account ID (for transfers)
  final String? creditCardId; // Linked Credit Card ID
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TransactionEntity({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
    required this.paymentSource,
    this.accountId,
    this.toAccountId,
    this.creditCardId,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  static const Object _sentinel = Object();

  TransactionEntity copyWith({
    String? id,
    String? title,
    double? amount,
    TransactionType? type,
    String? category,
    DateTime? date,
    String? paymentSource,
    Object? accountId = _sentinel,
    Object? toAccountId = _sentinel,
    Object? creditCardId = _sentinel,
    Object? notes = _sentinel,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TransactionEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      category: category ?? this.category,
      date: date ?? this.date,
      paymentSource: paymentSource ?? this.paymentSource,
      accountId: identical(accountId, _sentinel) ? this.accountId : (accountId as String?),
      toAccountId: identical(toAccountId, _sentinel) ? this.toAccountId : (toAccountId as String?),
      creditCardId: identical(creditCardId, _sentinel) ? this.creditCardId : (creditCardId as String?),
      notes: identical(notes, _sentinel) ? this.notes : (notes as String?),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'type': type.name,
      'category': category,
      'date': date.millisecondsSinceEpoch,
      'payment_source': paymentSource,
      'account_id': accountId,
      'to_account_id': toAccountId,
      'credit_card_id': creditCardId,
      'notes': notes,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory TransactionEntity.fromMap(Map<String, dynamic> map) {
    return TransactionEntity(
      id: map['id'] as String,
      title: map['title'] as String,
      amount: (map['amount'] as num).toDouble(),
      type: TransactionType.fromString(map['type'] as String),
      category: map['category'] as String,
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      paymentSource: map['payment_source'] as String? ?? 'Cash',
      accountId: map['account_id'] as String?,
      toAccountId: map['to_account_id'] as String?,
      creditCardId: map['credit_card_id'] as String?,
      notes: map['notes'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          amount == other.amount &&
          type == other.type &&
          category == other.category &&
          date == other.date &&
          paymentSource == other.paymentSource &&
          accountId == other.accountId &&
          toAccountId == other.toAccountId &&
          creditCardId == other.creditCardId &&
          notes == other.notes;

  @override
  int get hashCode => Object.hash(
        id,
        title,
        amount,
        type,
        category,
        date,
        paymentSource,
        accountId,
        toAccountId,
        creditCardId,
        notes,
      );
}
