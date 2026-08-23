enum BudgetHealth {
  safe, // < 80%
  warning, // 80% - 100%
  exceeded; // > 100%

  String get displayName {
    switch (this) {
      case BudgetHealth.safe:
        return 'On Track';
      case BudgetHealth.warning:
        return 'Near Limit';
      case BudgetHealth.exceeded:
        return 'Over Budget';
    }
  }
}

/// Core domain entity representing a category spending budget
class BudgetEntity {
  final String id;
  final String category;
  final double limitAmount;
  final DateTime month; // year and month indicator
  final DateTime createdAt;
  final DateTime updatedAt;

  const BudgetEntity({
    required this.id,
    required this.category,
    required this.limitAmount,
    required this.month,
    required this.createdAt,
    required this.updatedAt,
  });

  BudgetEntity copyWith({
    String? id,
    String? category,
    double? limitAmount,
    DateTime? month,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BudgetEntity(
      id: id ?? this.id,
      category: category ?? this.category,
      limitAmount: limitAmount ?? this.limitAmount,
      month: month ?? this.month,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'limit_amount': limitAmount,
      'month': DateTime(month.year, month.month, 1).millisecondsSinceEpoch,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory BudgetEntity.fromMap(Map<String, dynamic> map) {
    return BudgetEntity(
      id: map['id'] as String,
      category: map['category'] as String,
      limitAmount: (map['limit_amount'] as num).toDouble(),
      month: DateTime.fromMillisecondsSinceEpoch(map['month'] as int),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BudgetEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          category == other.category &&
          limitAmount == other.limitAmount &&
          month.year == other.month.year &&
          month.month == other.month.month;

  @override
  int get hashCode => Object.hash(
        id,
        category,
        limitAmount,
        month.year,
        month.month,
      );
}

/// Calculated status for a category budget
class CategoryBudgetStatus {
  final BudgetEntity budget;
  final double spentAmount;
  final double remainingAmount;
  final double overspentAmount;
  final double spentPercentage;
  final BudgetHealth health;

  const CategoryBudgetStatus({
    required this.budget,
    required this.spentAmount,
    required this.remainingAmount,
    required this.overspentAmount,
    required this.spentPercentage,
    required this.health,
  });

  String get category => budget.category;
  double get limitAmount => budget.limitAmount;
}

/// Aggregated budget summary across all budgeted categories for a month
class OverallBudgetSummary {
  final double totalLimit;
  final double totalSpent;
  final double totalRemaining;
  final double totalOverspent;
  final double overallPercentage;
  final BudgetHealth health;
  final int budgetedCategoriesCount;

  const OverallBudgetSummary({
    required this.totalLimit,
    required this.totalSpent,
    required this.totalRemaining,
    required this.totalOverspent,
    required this.overallPercentage,
    required this.health,
    required this.budgetedCategoriesCount,
  });

  static const OverallBudgetSummary empty = OverallBudgetSummary(
    totalLimit: 0.0,
    totalSpent: 0.0,
    totalRemaining: 0.0,
    totalOverspent: 0.0,
    overallPercentage: 0.0,
    health: BudgetHealth.safe,
    budgetedCategoriesCount: 0,
  );
}
