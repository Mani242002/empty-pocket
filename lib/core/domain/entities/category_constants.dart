import 'package:flutter/material.dart';
import 'transaction_entity.dart';

class CategoryItem {
  final String id;
  final String name;
  final TransactionType type;
  final IconData icon;
  final Color color;

  const CategoryItem({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
  });
}

abstract class CategoryConstants {
  // Preset Expense Categories
  static const List<CategoryItem> expenseCategories = [
    CategoryItem(
      id: 'food',
      name: 'Food & Dining',
      type: TransactionType.expense,
      icon: Icons.restaurant_rounded,
      color: Color(0xFFF97316),
    ),
    CategoryItem(
      id: 'groceries',
      name: 'Groceries',
      type: TransactionType.expense,
      icon: Icons.shopping_basket_rounded,
      color: Color(0xFF10B981),
    ),
    CategoryItem(
      id: 'shopping',
      name: 'Shopping',
      type: TransactionType.expense,
      icon: Icons.shopping_bag_rounded,
      color: Color(0xFFEC4899),
    ),
    CategoryItem(
      id: 'transport',
      name: 'Transportation',
      type: TransactionType.expense,
      icon: Icons.directions_car_rounded,
      color: Color(0xFF3B82F6),
    ),
    CategoryItem(
      id: 'housing',
      name: 'Housing & Rent',
      type: TransactionType.expense,
      icon: Icons.home_rounded,
      color: Color(0xFF8B5CF6),
    ),
    CategoryItem(
      id: 'bills',
      name: 'Bills & Utilities',
      type: TransactionType.expense,
      icon: Icons.bolt_rounded,
      color: Color(0xFFEAB308),
    ),
    CategoryItem(
      id: 'health',
      name: 'Health & Medical',
      type: TransactionType.expense,
      icon: Icons.medical_services_rounded,
      color: Color(0xFFEF4444),
    ),
    CategoryItem(
      id: 'entertainment',
      name: 'Entertainment',
      type: TransactionType.expense,
      icon: Icons.movie_rounded,
      color: Color(0xFF06B6D4),
    ),
    CategoryItem(
      id: 'education',
      name: 'Education',
      type: TransactionType.expense,
      icon: Icons.school_rounded,
      color: Color(0xFF6366F1),
    ),
    CategoryItem(
      id: 'debt',
      name: 'Debt & EMI',
      type: TransactionType.expense,
      icon: Icons.credit_card_off_rounded,
      color: Color(0xFFDC2626),
    ),
    CategoryItem(
      id: 'other_expense',
      name: 'Miscellaneous',
      type: TransactionType.expense,
      icon: Icons.category_rounded,
      color: Color(0xFF64748B),
    ),
  ];

  // Preset Income Categories
  static const List<CategoryItem> incomeCategories = [
    CategoryItem(
      id: 'salary',
      name: 'Salary',
      type: TransactionType.income,
      icon: Icons.account_balance_rounded,
      color: Color(0xFF10B981),
    ),
    CategoryItem(
      id: 'freelance',
      name: 'Freelance & Gig',
      type: TransactionType.income,
      icon: Icons.laptop_mac_rounded,
      color: Color(0xFF06B6D4),
    ),
    CategoryItem(
      id: 'business',
      name: 'Business Profit',
      type: TransactionType.income,
      icon: Icons.storefront_rounded,
      color: Color(0xFF8B5CF6),
    ),
    CategoryItem(
      id: 'investment_return',
      name: 'Investments / Dividend',
      type: TransactionType.income,
      icon: Icons.trending_up_rounded,
      color: Color(0xFF6366F1),
    ),
    CategoryItem(
      id: 'rental',
      name: 'Rental Income',
      type: TransactionType.income,
      icon: Icons.apartment_rounded,
      color: Color(0xFFEAB308),
    ),
    CategoryItem(
      id: 'gift',
      name: 'Gifts & Rewards',
      type: TransactionType.income,
      icon: Icons.card_giftcard_rounded,
      color: Color(0xFFEC4899),
    ),
    CategoryItem(
      id: 'other_income',
      name: 'Other Income',
      type: TransactionType.income,
      icon: Icons.monetization_on_rounded,
      color: Color(0xFF14B8A6),
    ),
  ];

  // Predefined Payment Sources
  static const List<String> paymentSources = [
    'UPI / Wallet',
    'Bank Account',
    'Cash',
    'Credit Card',
    'Debit Card',
    'Savings Account',
  ];

  static CategoryItem getCategoryByName(String name, TransactionType type) {
    final list = type == TransactionType.income ? incomeCategories : expenseCategories;
    return list.firstWhere(
      (c) => c.name.toLowerCase() == name.toLowerCase() || c.id.toLowerCase() == name.toLowerCase(),
      orElse: () => CategoryItem(
        id: 'custom',
        name: name,
        type: type,
        icon: type == TransactionType.income ? Icons.arrow_downward_rounded : Icons.category_rounded,
        color: type == TransactionType.income ? const Color(0xFF10B981) : const Color(0xFFF43F5E),
      ),
    );
  }

  static IconData getIconForCategory(String name, [TransactionType type = TransactionType.expense]) {
    return getCategoryByName(name, type).icon;
  }

  static Color getColorForCategory(String name, [TransactionType type = TransactionType.expense]) {
    return getCategoryByName(name, type).color;
  }
}
