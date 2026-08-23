import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Theme extension for EmptyPocket custom financial semantic colors
class AppFinancialColors extends ThemeExtension<AppFinancialColors> {
  final Color income;
  final Color expense;
  final Color warning;
  final Color investment;
  final Color info;
  final Color savings;
  final Color cardBorder;
  final Color textMuted;

  const AppFinancialColors({
    required this.income,
    required this.expense,
    required this.warning,
    required this.investment,
    required this.info,
    required this.savings,
    required this.cardBorder,
    required this.textMuted,
  });

  @override
  AppFinancialColors copyWith({
    Color? income,
    Color? expense,
    Color? warning,
    Color? investment,
    Color? info,
    Color? savings,
    Color? cardBorder,
    Color? textMuted,
  }) {
    return AppFinancialColors(
      income: income ?? this.income,
      expense: expense ?? this.expense,
      warning: warning ?? this.warning,
      investment: investment ?? this.investment,
      info: info ?? this.info,
      savings: savings ?? this.savings,
      cardBorder: cardBorder ?? this.cardBorder,
      textMuted: textMuted ?? this.textMuted,
    );
  }

  @override
  AppFinancialColors lerp(ThemeExtension<AppFinancialColors>? other, double t) {
    if (other is! AppFinancialColors) return this;
    return AppFinancialColors(
      income: Color.lerp(income, other.income, t) ?? income,
      expense: Color.lerp(expense, other.expense, t) ?? expense,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      investment: Color.lerp(investment, other.investment, t) ?? investment,
      info: Color.lerp(info, other.info, t) ?? info,
      savings: Color.lerp(savings, other.savings, t) ?? savings,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t) ?? cardBorder,
      textMuted: Color.lerp(textMuted, other.textMuted, t) ?? textMuted,
    );
  }

  static const AppFinancialColors dark = AppFinancialColors(
    income: AppColors.income,
    expense: AppColors.expense,
    warning: AppColors.warning,
    investment: AppColors.investment,
    info: AppColors.info,
    savings: AppColors.savings,
    cardBorder: AppColors.darkBorder,
    textMuted: AppColors.darkTextMuted,
  );

  static const AppFinancialColors light = AppFinancialColors(
    income: AppColors.income,
    expense: AppColors.expense,
    warning: AppColors.warning,
    investment: AppColors.investment,
    info: AppColors.info,
    savings: AppColors.savings,
    cardBorder: AppColors.lightBorder,
    textMuted: AppColors.lightTextMuted,
  );
}

extension FinancialColorsExtension on BuildContext {
  AppFinancialColors get financialColors =>
      Theme.of(this).extension<AppFinancialColors>() ?? AppFinancialColors.light;
}

/// Main App Themes
abstract class AppTheme {
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryEmerald,
      brightness: Brightness.light,
      primary: AppColors.primaryEmerald,
      surface: AppColors.lightSurface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.lightBackground,
      extensions: const [AppFinancialColors.light],
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightBackground,
        foregroundColor: AppColors.lightTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.lightTextPrimary,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.lightBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.lightSurface,
        elevation: 0,
        indicatorColor: AppColors.primaryEmerald.withAlpha(38),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppColors.primaryTeal : AppColors.lightTextSecondary,
            letterSpacing: -0.3,
            height: 1.2,
            overflow: TextOverflow.ellipsis,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: isSelected ? AppColors.primaryTeal : AppColors.lightTextSecondary,
            size: 22,
          );
        }),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryEmerald,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryEmerald,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryEmerald, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.lightBorder,
        thickness: 1,
        space: 1,
      ),
    );
  }

  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryEmerald,
      brightness: Brightness.dark,
      primary: AppColors.primaryEmerald,
      surface: AppColors.darkSurface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.darkBackground,
      extensions: const [AppFinancialColors.dark],
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkBackground,
        foregroundColor: AppColors.darkTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.darkTextPrimary,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.darkBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        elevation: 0,
        indicatorColor: AppColors.primaryEmerald.withAlpha(51),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppColors.primaryMint : AppColors.darkTextSecondary,
            letterSpacing: -0.3,
            height: 1.2,
            overflow: TextOverflow.ellipsis,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: isSelected ? AppColors.primaryMint : AppColors.darkTextSecondary,
            size: 22,
          );
        }),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryEmerald,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryEmerald,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryEmerald, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkBorder,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
