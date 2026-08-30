import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/entities/savings_goal_entity.dart';
import '../../../../core/utilities/currency_formatter.dart';
import '../../../savings/presentation/screens/add_edit_savings_goal_sheet.dart';

class DashboardSavingsCard extends StatelessWidget {
  final OverallSavingsSummary savingsSummary;

  const DashboardSavingsCard({
    super.key,
    required this.savingsSummary,
  });

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
                  Row(
                    children: [
                      Icon(Icons.savings_rounded, color: financialColors.savings, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Savings Goals',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  if (savingsSummary.totalTarget > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: financialColors.savings.withAlpha(isDark ? 40 : 25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${savingsSummary.overallPercentage.toStringAsFixed(0)}% Saved',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: financialColors.savings,
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
                      label: const Text('Add Goal'),
                      onPressed: () => AddEditSavingsGoalSheet.show(context),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (savingsSummary.totalTarget > 0) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: (savingsSummary.overallPercentage / 100).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: isDark
                        ? AppColors.darkSurfaceVariant
                        : AppColors.lightSurfaceVariant,
                    valueColor: AlwaysStoppedAnimation<Color>(financialColors.savings),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'Saved: ${CurrencyFormatter.format(savingsSummary.totalSaved)} / ${CurrencyFormatter.format(savingsSummary.totalTarget)}',
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
                        '${savingsSummary.activeGoalsCount} active • ${savingsSummary.completedGoalsCount} reached',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: financialColors.textMuted,
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
                    valueColor: AlwaysStoppedAnimation<Color>(financialColors.savings),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'No savings goals set',
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
                        'Emergency fund, travel, etc.',
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
