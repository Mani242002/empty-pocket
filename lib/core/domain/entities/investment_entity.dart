import 'package:flutter/material.dart';

enum AssetClass {
  equity,
  debt,
  retirement,
  gold,
  realEstate,
  crypto,
  cashEquivalent,
  other;

  String get displayName {
    switch (this) {
      case AssetClass.equity:
        return 'Equity & Mutual Funds';
      case AssetClass.debt:
        return 'Fixed Deposits & Bonds';
      case AssetClass.retirement:
        return 'EPF / PPF / NPS';
      case AssetClass.gold:
        return 'Gold & SGB';
      case AssetClass.realEstate:
        return 'Real Estate & Property';
      case AssetClass.crypto:
        return 'Crypto & Digital Assets';
      case AssetClass.cashEquivalent:
        return 'Liquid & Cash';
      case AssetClass.other:
        return 'Other Assets';
    }
  }

  IconData get icon {
    switch (this) {
      case AssetClass.equity:
        return Icons.trending_up_rounded;
      case AssetClass.debt:
        return Icons.account_balance_rounded;
      case AssetClass.retirement:
        return Icons.shield_rounded;
      case AssetClass.gold:
        return Icons.toll_rounded;
      case AssetClass.realEstate:
        return Icons.apartment_rounded;
      case AssetClass.crypto:
        return Icons.currency_bitcoin_rounded;
      case AssetClass.cashEquivalent:
        return Icons.savings_rounded;
      case AssetClass.other:
        return Icons.pie_chart_rounded;
    }
  }

  Color get color {
    switch (this) {
      case AssetClass.equity:
        return const Color(0xFF10B981); // Emerald
      case AssetClass.debt:
        return const Color(0xFF3B82F6); // Blue
      case AssetClass.retirement:
        return const Color(0xFF8B5CF6); // Purple
      case AssetClass.gold:
        return const Color(0xFFF59E0B); // Amber / Gold
      case AssetClass.realEstate:
        return const Color(0xFFEC4899); // Pink / Rose
      case AssetClass.crypto:
        return const Color(0xFF06B6D4); // Cyan
      case AssetClass.cashEquivalent:
        return const Color(0xFF14B8A6); // Teal
      case AssetClass.other:
        return const Color(0xFF64748B); // Slate
    }
  }

  static AssetClass fromString(String value) {
    return AssetClass.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => AssetClass.equity,
    );
  }
}

/// Core domain entity representing an investment or asset holding
class InvestmentEntity {
  final String id;
  final String name;
  final AssetClass assetClass;
  final double investedAmount;
  final double currentValue;
  final double? units;
  final double? buyPrice;
  final double? currentPrice;
  final String? institution; // e.g. Zerodha, Groww, SBI, ICICI
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const InvestmentEntity({
    required this.id,
    required this.name,
    required this.assetClass,
    required this.investedAmount,
    required this.currentValue,
    this.units,
    this.buyPrice,
    this.currentPrice,
    this.institution,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  InvestmentEntity copyWith({
    String? id,
    String? name,
    AssetClass? assetClass,
    double? investedAmount,
    double? currentValue,
    double? units,
    double? buyPrice,
    double? currentPrice,
    String? institution,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return InvestmentEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      assetClass: assetClass ?? this.assetClass,
      investedAmount: investedAmount ?? this.investedAmount,
      currentValue: currentValue ?? this.currentValue,
      units: units ?? this.units,
      buyPrice: buyPrice ?? this.buyPrice,
      currentPrice: currentPrice ?? this.currentPrice,
      institution: institution ?? this.institution,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'asset_class': assetClass.name,
      'invested_amount': investedAmount,
      'current_value': currentValue,
      'units': units,
      'buy_price': buyPrice,
      'current_price': currentPrice,
      'institution': institution,
      'notes': notes,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory InvestmentEntity.fromMap(Map<String, dynamic> map) {
    return InvestmentEntity(
      id: map['id'] as String,
      name: map['name'] as String,
      assetClass: AssetClass.fromString(map['asset_class'] as String),
      investedAmount: (map['invested_amount'] as num).toDouble(),
      currentValue: (map['current_value'] as num).toDouble(),
      units: (map['units'] as num?)?.toDouble(),
      buyPrice: (map['buy_price'] as num?)?.toDouble(),
      currentPrice: (map['current_price'] as num?)?.toDouble(),
      institution: map['institution'] as String?,
      notes: map['notes'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InvestmentEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          investedAmount == other.investedAmount &&
          currentValue == other.currentValue;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        investedAmount,
        currentValue,
      );
}

/// Calculated metrics for a single investment holding
class InvestmentMetrics {
  final InvestmentEntity investment;
  final double unrealizedProfitLoss;
  final double returnPercentage;
  final bool isProfit;

  const InvestmentMetrics({
    required this.investment,
    required this.unrealizedProfitLoss,
    required this.returnPercentage,
    required this.isProfit,
  });
}

/// Asset allocation item breakdown
class AssetAllocationItem {
  final AssetClass assetClass;
  final double investedAmount;
  final double currentValue;
  final double percentageOfPortfolio;
  final int itemsCount;

  const AssetAllocationItem({
    required this.assetClass,
    required this.investedAmount,
    required this.currentValue,
    required this.percentageOfPortfolio,
    required this.itemsCount,
  });
}

/// Overall portfolio summary
class OverallPortfolioSummary {
  final double totalInvested;
  final double totalCurrentValue;
  final double totalProfitLoss;
  final double overallReturnPercentage;
  final bool isProfit;
  final List<AssetAllocationItem> assetAllocations;
  final int totalHoldingsCount;

  const OverallPortfolioSummary({
    required this.totalInvested,
    required this.totalCurrentValue,
    required this.totalProfitLoss,
    required this.overallReturnPercentage,
    required this.isProfit,
    required this.assetAllocations,
    required this.totalHoldingsCount,
  });

  static const OverallPortfolioSummary empty = OverallPortfolioSummary(
    totalInvested: 0.0,
    totalCurrentValue: 0.0,
    totalProfitLoss: 0.0,
    overallReturnPercentage: 0.0,
    isProfit: true,
    assetAllocations: [],
    totalHoldingsCount: 0,
  );
}
