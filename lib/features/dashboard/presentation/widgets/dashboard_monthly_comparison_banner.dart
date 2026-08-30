import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/calculation/financial_calculator.dart';
import '../../../../core/utilities/currency_formatter.dart';

class DashboardMonthlyComparisonBanner extends StatelessWidget {
  final MonthlySpendingComparison comparison;

  const DashboardMonthlyComparisonBanner({
    super.key,
    required this.comparison,
  });

  @override
  Widget build(BuildContext context) {
    if (!comparison.hasPreviousMonthData || comparison.previousMonthExpense <= 0) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final financialColors = context.financialColors;
    final isDark = theme.brightness == Brightness.dark;

    final isSaving = comparison.isLower;
    final accentColor = isSaving ? financialColors.income : (comparison.percentageChange > 20 ? financialColors.expense : financialColors.warning);
    final icon = isSaving ? Icons.trending_down_rounded : Icons.trending_up_rounded;

    final title = isSaving
        ? 'Spending is down by ${comparison.percentageChange.toStringAsFixed(0)}%'
        : 'Spending is up by ${comparison.percentageChange.toStringAsFixed(0)}%';

    final subtitle = isSaving
        ? 'You spent ${CurrencyFormatter.format(comparison.differenceAmount.abs())} less than last month. Keep it up!'
        : 'You spent ${CurrencyFormatter.format(comparison.differenceAmount.abs())} more than last month.';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: accentColor.withAlpha(isDark ? 30 : 18),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accentColor.withAlpha(isDark ? 70 : 50),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withAlpha(isDark ? 50 : 30),
              ),
              child: Icon(icon, color: accentColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: financialColors.textMuted,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
