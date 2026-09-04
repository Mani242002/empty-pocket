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

  final bool isShared; // Whether this transaction was shared/split with others
  final double? myShareAmount; // User's personal share (e.g. ₹1,000 of ₹4,000)
  final double reimbursedAmount; // Total amount collected back from friends so far
  final bool isSettled; // Whether all friends' shares have been fully reimbursed
  final String? sharedWith; // Roommates/friends involved (e.g. "Rahul, Amit")
  final String? linkedEntityId; // Traceable link to savings goal, debt, or investment

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
    this.isShared = false,
    this.myShareAmount,
    this.reimbursedAmount = 0.0,
    this.isSettled = false,
    this.sharedWith,
    this.linkedEntityId,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Total portion of the transaction that was paid on behalf of friends/roommates
  double get friendsShare =>
      isShared ? (amount - (myShareAmount ?? amount)).clamp(0.0, double.infinity) : 0.0;

  /// Remaining reimbursement yet to be collected back from friends
  double get pendingReimbursement =>
      isShared ? (friendsShare - reimbursedAmount).clamp(0.0, double.infinity) : 0.0;

  /// The user's true personal expenditure for this transaction
  double get netPersonalAmount =>
      isShared ? (myShareAmount ?? (amount - reimbursedAmount)) : amount;

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
    bool? isShared,
    Object? myShareAmount = _sentinel,
    double? reimbursedAmount,
    bool? isSettled,
    Object? sharedWith = _sentinel,
    Object? linkedEntityId = _sentinel,
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
      isShared: isShared ?? this.isShared,
      myShareAmount: identical(myShareAmount, _sentinel) ? this.myShareAmount : (myShareAmount as double?),
      reimbursedAmount: reimbursedAmount ?? this.reimbursedAmount,
      isSettled: isSettled ?? this.isSettled,
      sharedWith: identical(sharedWith, _sentinel) ? this.sharedWith : (sharedWith as String?),
      linkedEntityId: identical(linkedEntityId, _sentinel) ? this.linkedEntityId : (linkedEntityId as String?),
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
      'is_shared': isShared ? 1 : 0,
      'my_share_amount': myShareAmount,
      'reimbursed_amount': reimbursedAmount,
      'is_settled': isSettled ? 1 : 0,
      'shared_with': sharedWith,
      'linked_entity_id': linkedEntityId,
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
      isShared: (map['is_shared'] as int? ?? 0) == 1,
      myShareAmount: (map['my_share_amount'] as num?)?.toDouble(),
      reimbursedAmount: (map['reimbursed_amount'] as num?)?.toDouble() ?? 0.0,
      isSettled: (map['is_settled'] as int? ?? 0) == 1,
      sharedWith: map['shared_with'] as String?,
      linkedEntityId: map['linked_entity_id'] as String?,
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
          notes == other.notes &&
          isShared == other.isShared &&
          myShareAmount == other.myShareAmount &&
          reimbursedAmount == other.reimbursedAmount &&
          isSettled == other.isSettled &&
          sharedWith == other.sharedWith &&
          linkedEntityId == other.linkedEntityId;

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
        isShared,
        myShareAmount,
        reimbursedAmount,
        isSettled,
        sharedWith,
        linkedEntityId,
      );
}
