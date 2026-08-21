import 'package:flutter/material.dart';

enum HealthGrade {
  excellent,
  strong,
  moderate,
  needsAttention;

  String get displayName {
    switch (this) {
      case HealthGrade.excellent:
        return 'Excellent';
      case HealthGrade.strong:
        return 'Strong';
      case HealthGrade.moderate:
        return 'Moderate';
      case HealthGrade.needsAttention:
        return 'Needs Attention';
    }
  }

  Color get color {
    switch (this) {
      case HealthGrade.excellent:
        return const Color(0xFF10B981); // Emerald
      case HealthGrade.strong:
        return const Color(0xFF06B6D4); // Cyan
      case HealthGrade.moderate:
        return const Color(0xFFF59E0B); // Amber
      case HealthGrade.needsAttention:
        return const Color(0xFFEF4444); // Red
    }
  }

  IconData get icon {
    switch (this) {
      case HealthGrade.excellent:
        return Icons.verified_rounded;
      case HealthGrade.strong:
        return Icons.thumb_up_rounded;
      case HealthGrade.moderate:
        return Icons.trending_flat_rounded;
      case HealthGrade.needsAttention:
        return Icons.warning_amber_rounded;
    }
  }
}

class HealthPillarScore {
  final String name;
  final int score; // 0 to 25
  final int maxScore;
  final String statusText;
  final String tip;
  final Color color;
  final IconData icon;

  const HealthPillarScore({
    required this.name,
    required this.score,
    this.maxScore = 25,
    required this.statusText,
    required this.tip,
    required this.color,
    required this.icon,
  });

  double get percentage => maxScore > 0 ? (score / maxScore) * 100 : 0.0;
}

class NetWorthComposition {
  final double cashBalance;
  final double savingsGoalsAmount;
  final double investmentsAmount;
  final double totalAssets;
  final double totalLiabilities;
  final double netWorth;
  final double debtToAssetRatio; // liabilities / assets in %

  const NetWorthComposition({
    required this.cashBalance,
    required this.savingsGoalsAmount,
    required this.investmentsAmount,
    required this.totalAssets,
    required this.totalLiabilities,
    required this.netWorth,
    required this.debtToAssetRatio,
  });

  static const empty = NetWorthComposition(
    cashBalance: 0.0,
    savingsGoalsAmount: 0.0,
    investmentsAmount: 0.0,
    totalAssets: 0.0,
    totalLiabilities: 0.0,
    netWorth: 0.0,
    debtToAssetRatio: 0.0,
  );

  bool get isPositive => netWorth >= 0;
  double get cashPercentage => totalAssets > 0 ? (cashBalance.clamp(0, double.infinity) / totalAssets) * 100 : 0.0;
  double get savingsPercentage => totalAssets > 0 ? (savingsGoalsAmount / totalAssets) * 100 : 0.0;
  double get investmentsPercentage => totalAssets > 0 ? (investmentsAmount / totalAssets) * 100 : 0.0;
}

class FinancialHealthSummary {
  final NetWorthComposition netWorth;
  final int overallScore; // 0 to 100
  final HealthGrade grade;
  final HealthPillarScore emergencyBufferPillar;
  final HealthPillarScore savingsRatePillar;
  final HealthPillarScore debtBurdenPillar;
  final HealthPillarScore diversificationPillar;
  final List<String> actionableTips;

  const FinancialHealthSummary({
    required this.netWorth,
    required this.overallScore,
    required this.grade,
    required this.emergencyBufferPillar,
    required this.savingsRatePillar,
    required this.debtBurdenPillar,
    required this.diversificationPillar,
    required this.actionableTips,
  });

  static const empty = FinancialHealthSummary(
    netWorth: NetWorthComposition.empty,
    overallScore: 50,
    grade: HealthGrade.moderate,
    emergencyBufferPillar: HealthPillarScore(
      name: 'Emergency Buffer',
      score: 10,
      statusText: 'No data',
      tip: 'Build at least 3 months of emergency expenses',
      color: Color(0xFFF59E0B),
      icon: Icons.shield_rounded,
    ),
    savingsRatePillar: HealthPillarScore(
      name: 'Savings Rate',
      score: 10,
      statusText: 'No data',
      tip: 'Aim to save 20%+ of monthly income',
      color: Color(0xFF10B981),
      icon: Icons.savings_rounded,
    ),
    debtBurdenPillar: HealthPillarScore(
      name: 'Debt Burden',
      score: 25,
      statusText: 'Zero debt',
      tip: 'Great job maintaining zero liabilities',
      color: Color(0xFF06B6D4),
      icon: Icons.credit_score_rounded,
    ),
    diversificationPillar: HealthPillarScore(
      name: 'Asset Spread',
      score: 5,
      statusText: 'Single asset',
      tip: 'Diversify across equity, debt, gold & cash',
      color: Color(0xFF8B5CF6),
      icon: Icons.pie_chart_rounded,
    ),
    actionableTips: [],
  );
}
