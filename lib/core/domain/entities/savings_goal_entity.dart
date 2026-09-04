enum GoalStatus {
  active,
  completed,
  paused;

  String get displayName {
    switch (this) {
      case GoalStatus.active:
        return 'Active';
      case GoalStatus.completed:
        return 'Completed';
      case GoalStatus.paused:
        return 'Paused';
    }
  }

  static GoalStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'completed':
        return GoalStatus.completed;
      case 'paused':
        return GoalStatus.paused;
      case 'active':
      default:
        return GoalStatus.active;
    }
  }
}

/// Core domain entity for savings goals & emergency funds
class SavingsGoalEntity {
  final String id;
  final String title;
  final double targetAmount;
  final double currentAmount;
  final String category;
  final DateTime targetDate;
  final bool isEmergencyFund;
  final GoalStatus status;
  final String? linkedAccountId;
  final double allocationPercentage;
  final bool autoSyncAccount;
  final DateTime createdAt;
  final DateTime updatedAt;

  static const Object _sentinel = Object();

  const SavingsGoalEntity({
    required this.id,
    required this.title,
    required this.targetAmount,
    required this.currentAmount,
    required this.category,
    required this.targetDate,
    this.isEmergencyFund = false,
    this.status = GoalStatus.active,
    this.linkedAccountId,
    this.allocationPercentage = 100.0,
    this.autoSyncAccount = false,
    required this.createdAt,
    required this.updatedAt,
  });

  SavingsGoalEntity copyWith({
    String? id,
    String? title,
    double? targetAmount,
    double? currentAmount,
    String? category,
    DateTime? targetDate,
    bool? isEmergencyFund,
    GoalStatus? status,
    Object? linkedAccountId = _sentinel,
    double? allocationPercentage,
    bool? autoSyncAccount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SavingsGoalEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      category: category ?? this.category,
      targetDate: targetDate ?? this.targetDate,
      isEmergencyFund: isEmergencyFund ?? this.isEmergencyFund,
      status: status ?? this.status,
      linkedAccountId: identical(linkedAccountId, _sentinel)
          ? this.linkedAccountId
          : (linkedAccountId as String?),
      allocationPercentage: allocationPercentage ?? this.allocationPercentage,
      autoSyncAccount: autoSyncAccount ?? this.autoSyncAccount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'target_amount': targetAmount,
      'current_amount': currentAmount,
      'category': category,
      'target_date': targetDate.millisecondsSinceEpoch,
      'is_emergency_fund': isEmergencyFund ? 1 : 0,
      'status': status.name,
      'linked_account_id': linkedAccountId,
      'allocation_percentage': allocationPercentage,
      'auto_sync_account': autoSyncAccount ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory SavingsGoalEntity.fromMap(Map<String, dynamic> map) {
    return SavingsGoalEntity(
      id: map['id'] as String,
      title: map['title'] as String,
      targetAmount: (map['target_amount'] as num).toDouble(),
      currentAmount: (map['current_amount'] as num).toDouble(),
      category: map['category'] as String,
      targetDate: DateTime.fromMillisecondsSinceEpoch(map['target_date'] as int),
      isEmergencyFund: (map['is_emergency_fund'] as int) == 1,
      status: GoalStatus.fromString(map['status'] as String),
      linkedAccountId: map['linked_account_id'] as String?,
      allocationPercentage: (map['allocation_percentage'] as num?)?.toDouble() ?? 100.0,
      autoSyncAccount: (map['auto_sync_account'] as int? ?? 0) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavingsGoalEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          targetAmount == other.targetAmount &&
          currentAmount == other.currentAmount &&
          category == other.category &&
          status == other.status &&
          linkedAccountId == other.linkedAccountId &&
          allocationPercentage == other.allocationPercentage &&
          autoSyncAccount == other.autoSyncAccount;

  @override
  int get hashCode => Object.hash(
        id,
        title,
        targetAmount,
        currentAmount,
        category,
        status,
        linkedAccountId,
        allocationPercentage,
        autoSyncAccount,
      );
}

/// Domain entity representing a contribution entry towards a goal
class GoalContributionEntity {
  final String id;
  final String goalId;
  final double amount;
  final DateTime date;
  final String? notes;
  final String? sourceAccountId;
  final DateTime createdAt;

  const GoalContributionEntity({
    required this.id,
    required this.goalId,
    required this.amount,
    required this.date,
    this.notes,
    this.sourceAccountId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'goal_id': goalId,
      'amount': amount,
      'date': date.millisecondsSinceEpoch,
      'notes': notes,
      'source_account_id': sourceAccountId,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory GoalContributionEntity.fromMap(Map<String, dynamic> map) {
    return GoalContributionEntity(
      id: map['id'] as String,
      goalId: map['goal_id'] as String,
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      notes: map['notes'] as String?,
      sourceAccountId: map['source_account_id'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
}

/// Calculated metrics for a specific savings goal
class GoalProgressMetrics {
  final SavingsGoalEntity goal;
  final double percentage;
  final double remainingAmount;
  final bool isCompleted;
  final int monthsRemaining;
  final double recommendedMonthlySavings;

  const GoalProgressMetrics({
    required this.goal,
    required this.percentage,
    required this.remainingAmount,
    required this.isCompleted,
    required this.monthsRemaining,
    required this.recommendedMonthlySavings,
  });
}

/// Overall savings summary across all goals
class OverallSavingsSummary {
  final double totalTarget;
  final double totalSaved;
  final double totalRemaining;
  final double overallPercentage;
  final int activeGoalsCount;
  final int completedGoalsCount;
  final double emergencyFundSaved;

  const OverallSavingsSummary({
    required this.totalTarget,
    required this.totalSaved,
    required this.totalRemaining,
    required this.overallPercentage,
    required this.activeGoalsCount,
    required this.completedGoalsCount,
    this.emergencyFundSaved = 0.0,
  });

  static const OverallSavingsSummary empty = OverallSavingsSummary(
    totalTarget: 0.0,
    totalSaved: 0.0,
    totalRemaining: 0.0,
    overallPercentage: 0.0,
    activeGoalsCount: 0,
    completedGoalsCount: 0,
    emergencyFundSaved: 0.0,
  );
}
