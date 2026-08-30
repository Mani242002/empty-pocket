import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/entities/budget_entity.dart';
import '../../../../core/utilities/currency_formatter.dart';
import '../../../budgets/presentation/screens/set_budget_sheet.dart';

class DashboardBudgetCard extends StatelessWidget {
  final OverallBudgetSummary budgetSummary;
  final double totalExpense;

  const DashboardBudgetCard({
    super.key,
    required this.budgetSummary,
    required this.totalExpense,
  });

  Color _getBudgetHealthColor(BuildContext context, BudgetHealth health) {
    final fc = context.financialColors;
    switch (health) {
      case BudgetHealth.safe:
        return fc.income;
      case BudgetHealth.warning:
        return fc.warning;
      case BudgetHealth.exceeded:
        return fc.expense;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final financialColors = context.financialColors;
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Monthly Budget Status',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (budgetSummary.budgetedCategoriesCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getBudgetHealthColor(context, budgetSummary.health).withAlpha(isDark ? 40 : 25),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _getBudgetHealthColor(context, budgetSummary.health).withAlpha(isDark ? 60 : 40),
                        ),
                      ),
                      child: Text(
                        budgetSummary.health.displayName,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: _getBudgetHealthColor(context, budgetSummary.health),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Set Limit'),
                      onPressed: () => SetBudgetSheet.show(context),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (budgetSummary.budgetedCategoriesCount > 0) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: (budgetSummary.overallPercentage / 100).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: isDark
                        ? AppColors.darkSurfaceVariant
                        : AppColors.lightSurfaceVariant,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getBudgetHealthColor(context, budgetSummary.health),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'Spent: ${CurrencyFormatter.format(budgetSummary.totalSpent)} / ${CurrencyFormatter.format(budgetSummary.totalLimit)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: financialColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        budgetSummary.totalOverspent > 0
                            ? 'Over by ${CurrencyFormatter.format(budgetSummary.totalOverspent)}'
                            : '${CurrencyFormatter.format(budgetSummary.totalRemaining)} left',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: budgetSummary.totalOverspent > 0
                              ? financialColors.expense
                              : financialColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: 0.0,
                    minHeight: 8,
                    backgroundColor: isDark
                        ? AppColors.darkSurfaceVariant
                        : AppColors.lightSurfaceVariant,
                    valueColor: AlwaysStoppedAnimation<Color>(financialColors.income),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'Total Spent: ${CurrencyFormatter.format(totalExpense)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: financialColors.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'No category limits configured',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: financialColors.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
