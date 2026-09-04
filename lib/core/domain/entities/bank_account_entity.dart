import 'package:flutter/material.dart';

enum AccountType {
  savings,
  current,
  salary,
  cash,
  business,
  other;

  String get displayName {
    switch (this) {
      case AccountType.savings:
        return 'Savings';
      case AccountType.current:
        return 'Current';
      case AccountType.salary:
        return 'Salary';
      case AccountType.cash:
        return 'Cash / Wallet';
      case AccountType.business:
        return 'Business';
      case AccountType.other:
        return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case AccountType.savings:
        return Icons.savings_rounded;
      case AccountType.current:
        return Icons.account_balance_wallet_rounded;
      case AccountType.salary:
        return Icons.monetization_on_rounded;
      case AccountType.cash:
        return Icons.payments_rounded;
      case AccountType.business:
        return Icons.store_rounded;
      case AccountType.other:
        return Icons.account_balance_rounded;
    }
  }

  static AccountType fromString(String value) {
    return AccountType.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => AccountType.savings,
    );
  }
}

/// Standardized two-tier Payment Method Categories
enum PaymentMode {
  bankAccount('Bank Account', Icons.account_balance_rounded),
  upiWallet('UPI / Wallet', Icons.qr_code_scanner_rounded),
  cash('Cash', Icons.payments_rounded),
  creditCard('Credit Card', Icons.credit_card_rounded);

  final String displayName;
  final IconData icon;
  const PaymentMode(this.displayName, this.icon);

  static PaymentMode fromString(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('upi') || lower.contains('wallet')) {
      return PaymentMode.upiWallet;
    } else if (lower.contains('credit')) {
      return PaymentMode.creditCard;
    } else if (lower.contains('cash')) {
      return PaymentMode.cash;
    }
    return PaymentMode.bankAccount;
  }
}

/// Predefined recommended tags for what the user uses this account for
abstract class AccountPurposeTags {
  static const String dailySpending = 'Daily Spending';
  static const String emergencyFund = 'Emergency Fund';
  static const String shortTermSavings = 'Short-Term Savings';
  static const String billsAndEmis = 'Bills & EMIs';
  static const String investments = 'Investments';
  static const String investmentsAndInsurance = 'Investments & Insurance';
  static const String salaryHub = 'Salary & Income Hub';
  static const String familyShared = 'Family / Shared';
  static const String miscellaneous = 'Miscellaneous';

  static const List<String> defaultTags = [
    dailySpending,
    emergencyFund,
    shortTermSavings,
    billsAndEmis,
    investments,
    investmentsAndInsurance,
    salaryHub,
    familyShared,
    miscellaneous,
  ];

  /// Intelligently matches a transaction category to the most appropriate BankAccount
  static BankAccountEntity? matchAccountForCategory(
    String category,
    List<BankAccountEntity> accounts, {
    BankAccountEntity? defaultAccount,
  }) {
    if (accounts.isEmpty) return null;
    final catLower = category.toLowerCase();

    // 1. Insurance Premiums -> SBI (Investments & Insurance or Investments)
    if (catLower.contains('insurance')) {
      final match = accounts.where((a) =>
          a.usedFor == investmentsAndInsurance ||
          a.usedFor.toLowerCase().contains('insurance') ||
          a.bankName.toLowerCase().contains('sbi') ||
          a.accountName.toLowerCase().contains('sbi') ||
          a.usedFor == investments ||
          a.usedFor.toLowerCase().contains('investment')).firstOrNull;
      if (match != null) return match;
    }

    // 2. Investments & SIP -> SBI (Investments or Investments & Insurance)
    if (catLower.contains('investment') || catLower.contains('sip') || catLower.contains('mutual fund')) {
      final match = accounts.where((a) =>
          a.usedFor == investments ||
          a.usedFor == investmentsAndInsurance ||
          a.bankName.toLowerCase().contains('sbi') ||
          a.accountName.toLowerCase().contains('sbi') ||
          a.usedFor.toLowerCase().contains('investment')).firstOrNull;
      if (match != null) return match;
    }

    // 3. Bills & Utilities, Subscriptions, EMI -> ICICI (Bills & EMIs or Salary Hub)
    if (catLower.contains('bill') ||
        catLower.contains('utility') ||
        catLower.contains('subscription') ||
        catLower.contains('emi') ||
        catLower.contains('rent')) {
      final match = accounts.where((a) =>
          a.usedFor == billsAndEmis ||
          a.usedFor == salaryHub ||
          a.usedFor.toLowerCase().contains('bill') ||
          a.usedFor.toLowerCase().contains('salary')).firstOrNull;
      if (match != null) return match;
    }

    // 4. Salary -> ICICI (Salary & Income Hub)
    if (catLower.contains('salary')) {
      final match = accounts.where((a) =>
          a.usedFor == salaryHub ||
          a.usedFor.toLowerCase().contains('salary')).firstOrNull;
      if (match != null) return match;
    }

    // 5. Emergency Fund
    if (catLower.contains('emergency')) {
      final match = accounts.where((a) =>
          a.usedFor == emergencyFund ||
          a.usedFor.toLowerCase().contains('emergency')).firstOrNull;
      if (match != null) return match;
    }

    // 6. Daily Spending categories (Food, Groceries, Shopping, Transport, Personal Care, Entertainment, etc.) -> Kotak (Daily Spending)
    const dailyKeywords = [
      'food', 'dining', 'grocer', 'shopping', 'transport', 'entertainment',
      'personal', 'medical', 'health', 'cafe', 'fuel', 'lifestyle'
    ];
    if (dailyKeywords.any((kw) => catLower.contains(kw))) {
      final match = accounts.where((a) =>
          a.usedFor == dailySpending ||
          a.usedFor.toLowerCase().contains('daily') ||
          a.usedFor.toLowerCase().contains('spend')).firstOrNull;
      if (match != null) return match;
    }

    // Fallback: Default account or first account
    return defaultAccount ?? accounts.first;
  }
}

/// Core domain entity representing a Bank Account or Cash Wallet
class BankAccountEntity {
  final String id;
  final String accountName;
  final String bankName;
  final AccountType accountType;
  final String usedFor; // Purpose tag: e.g. "Daily Spending", "Emergency Fund"
  final double initialBalance;
  final double currentBalance;
  final String? colorHex;
  final bool isDefault;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BankAccountEntity({
    required this.id,
    required this.accountName,
    required this.bankName,
    required this.accountType,
    required this.usedFor,
    required this.initialBalance,
    required this.currentBalance,
    this.colorHex,
    this.isDefault = false,
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
  });

  static const Object _sentinel = Object();

  BankAccountEntity copyWith({
    String? id,
    String? accountName,
    String? bankName,
    AccountType? accountType,
    String? usedFor,
    double? initialBalance,
    double? currentBalance,
    Object? colorHex = _sentinel,
    bool? isDefault,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BankAccountEntity(
      id: id ?? this.id,
      accountName: accountName ?? this.accountName,
      bankName: bankName ?? this.bankName,
      accountType: accountType ?? this.accountType,
      usedFor: usedFor ?? this.usedFor,
      initialBalance: initialBalance ?? this.initialBalance,
      currentBalance: currentBalance ?? this.currentBalance,
      colorHex: identical(colorHex, _sentinel) ? this.colorHex : (colorHex as String?),
      isDefault: isDefault ?? this.isDefault,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'account_name': accountName,
      'bank_name': bankName,
      'account_type': accountType.name,
      'used_for': usedFor,
      'initial_balance': initialBalance,
      'current_balance': currentBalance,
      'color_hex': colorHex,
      'is_default': isDefault ? 1 : 0,
      'is_archived': isArchived ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory BankAccountEntity.fromMap(Map<String, dynamic> map) {
    return BankAccountEntity(
      id: map['id'] as String,
      accountName: map['account_name'] as String,
      bankName: map['bank_name'] as String? ?? 'Bank Account',
      accountType: AccountType.fromString(map['account_type'] as String? ?? 'savings'),
      usedFor: map['used_for'] as String? ?? 'Daily Spending',
      initialBalance: (map['initial_balance'] as num?)?.toDouble() ?? 0.0,
      currentBalance: (map['current_balance'] as num?)?.toDouble() ?? 0.0,
      colorHex: map['color_hex'] as String?,
      isDefault: (map['is_default'] as int?) == 1,
      isArchived: (map['is_archived'] as int?) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BankAccountEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          accountName == other.accountName &&
          bankName == other.bankName &&
          accountType == other.accountType &&
          usedFor == other.usedFor &&
          currentBalance == other.currentBalance &&
          isDefault == other.isDefault &&
          isArchived == other.isArchived;

  @override
  int get hashCode => Object.hash(
        id,
        accountName,
        bankName,
        accountType,
        usedFor,
        currentBalance,
        isDefault,
        isArchived,
      );
}
