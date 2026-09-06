/// Model representing an individual person's share in a split/shared expense
class SplitPersonShare {
  final String personName;
  final double amount;
  final double reimbursedAmount;
  final bool isSettled;

  const SplitPersonShare({
    required this.personName,
    required this.amount,
    this.reimbursedAmount = 0.0,
    this.isSettled = false,
  });

  /// Pending amount this specific person still owes
  double get pendingAmount =>
      isSettled ? 0.0 : (amount - reimbursedAmount).clamp(0.0, double.infinity);

  Map<String, dynamic> toMap() => {
        'name': personName,
        'amount': amount,
        if (reimbursedAmount > 0) 'reimbursed': reimbursedAmount,
        if (isSettled) 'settled': true,
      };

  factory SplitPersonShare.fromMap(Map<String, dynamic> map) => SplitPersonShare(
        personName: (map['name'] ?? map['personName'] ?? '') as String,
        amount: ((map['amount'] ?? 0) as num).toDouble(),
        reimbursedAmount:
            ((map['reimbursed'] ?? map['reimbursedAmount'] ?? 0) as num).toDouble(),
        isSettled: map['settled'] == true || map['isSettled'] == true,
      );

  SplitPersonShare copyWith({
    String? personName,
    double? amount,
    double? reimbursedAmount,
    bool? isSettled,
  }) {
    return SplitPersonShare(
      personName: personName ?? this.personName,
      amount: amount ?? this.amount,
      reimbursedAmount: reimbursedAmount ?? this.reimbursedAmount,
      isSettled: isSettled ?? this.isSettled,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SplitPersonShare &&
          runtimeType == other.runtimeType &&
          personName == other.personName &&
          amount == other.amount &&
          reimbursedAmount == other.reimbursedAmount &&
          isSettled == other.isSettled;

  @override
  int get hashCode => Object.hash(personName, amount, reimbursedAmount, isSettled);
}
