import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/entities/savings_goal_entity.dart';
import '../../../../core/utilities/currency_formatter.dart';
import '../../../savings/presentation/screens/add_contribution_sheet.dart';
import '../../../savings/presentation/screens/add_edit_savings_goal_sheet.dart';
import '../../../savings/presentation/state/savings_goals_provider.dart';

class SavingsGoalsTab extends ConsumerWidget {
  const SavingsGoalsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final financialColors = context.financialColors;
    final isDark = theme.brightness == Brightness.dark;

    final goalsAsync = ref.watch(savingsGoalsListNotifierProvider);
    final summary = ref.watch(overallSavingsSummaryProvider);
    final metricsList = ref.watch(goalProgressMetricsListProvider);

    return goalsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading goals: $e')),
      data: (goals) {
        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
          children: [
            // Overall Savings Summary Card
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [AppColors.primaryEmerald.withAlpha(50), AppColors.darkSurface]
                      : [AppColors.primaryEmerald.withAlpha(20), Colors.white],
                ),
                border: Border.all(
                  color: isDark ? AppColors.income.withAlpha(60) : AppColors.income.withAlpha(40),
                  width: 1.5,
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'TOTAL SAVED ACROSS GOALS',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: financialColors.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: financialColors.income.withAlpha(isDark ? 40 : 25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${summary.overallPercentage.toStringAsFixed(0)}% Reached',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: financialColors.income,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      CurrencyFormatter.format(summary.totalSaved),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Target: ${CurrencyFormatter.format(summary.totalTarget)} • ${summary.activeGoalsCount} Active Goals',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: financialColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: (summary.overallPercentage / 100).clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: isDark
                          ? AppColors.darkSurfaceVariant
                          : AppColors.lightSurfaceVariant,
                      valueColor: AlwaysStoppedAnimation<Color>(financialColors.income),
                    ),
                  ),
                ],
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Your Goals (${goals.length})',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (goals.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => AddEditSavingsGoalSheet.show(context),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Goal'),
                    ),
                ],
              ),
            ),

            // Goals List or Empty State
            if (goals.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: financialColors.savings.withAlpha(isDark ? 40 : 25),
                        ),
                        child: Icon(
                          Icons.savings_rounded,
                          color: financialColors.savings,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Savings Goals Yet',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Create goals for an Emergency Fund, Bali Vacation, New Tech, or Vehicle to track monthly progress milestones.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: financialColors.textMuted,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: financialColors.savings),
                        onPressed: () => AddEditSavingsGoalSheet.show(context),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Create First Goal'),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...metricsList.map((metric) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildSavingsGoalCard(context, ref, metric),
                );
              }),
          ],
        );
      },
    );
  }

  Widget _buildSavingsGoalCard(BuildContext context, WidgetRef ref, GoalProgressMetrics metric) {
    final theme = Theme.of(context);
    final financialColors = context.financialColors;
    final isDark = theme.brightness == Brightness.dark;
    final goal = metric.goal;

    return Dismissible(
      key: Key(goal.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Savings Goal?'),
            content: Text('Remove goal "${goal.title}" and its history?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) {
        ref.read(savingsGoalsListNotifierProvider.notifier).deleteGoal(goal.id);
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.expense.withAlpha(200),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
            SizedBox(width: 8),
            Text(
              'Remove',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
      child: Material(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: goal.isEmergencyFund
                ? AppColors.primaryEmerald.withAlpha(isDark ? 80 : 60)
                : financialColors.cardBorder,
            width: goal.isEmergencyFund ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          onTap: () => AddEditSavingsGoalSheet.show(context, goal: goal),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: goal.isEmergencyFund
                            ? AppColors.primaryEmerald.withAlpha(isDark ? 45 : 30)
                            : financialColors.savings.withAlpha(isDark ? 45 : 30),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        goal.isEmergencyFund ? Icons.shield_rounded : Icons.savings_rounded,
                        color: goal.isEmergencyFund ? AppColors.primaryEmerald : financialColors.savings,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  goal.title,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (goal.isEmergencyFund) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryEmerald.withAlpha(isDark ? 50 : 30),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Emergency Fund',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryEmerald,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            metric.isCompleted
                                ? '🎉 Goal Completed!'
                                : '${CurrencyFormatter.format(metric.remainingAmount)} remaining',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: metric.isCompleted ? financialColors.income : financialColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              CurrencyFormatter.format(goal.currentAmount),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: metric.isCompleted ? financialColors.income : null,
                              ),
                            ),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              'of ${CurrencyFormatter.format(goal.targetAmount)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: financialColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (metric.percentage / 100).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: isDark
                        ? AppColors.darkSurfaceVariant
                        : AppColors.lightSurfaceVariant,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      metric.isCompleted
                          ? financialColors.income
                          : (goal.isEmergencyFund ? AppColors.primaryEmerald : financialColors.savings),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Bottom row: Target date, Monthly recommendation, and "+ Add Funds" button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Target: ${DateFormat('MMM yyyy').format(goal.targetDate)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: financialColors.textMuted,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (!metric.isCompleted && metric.recommendedMonthlySavings > 0)
                            Text(
                              'Save ${CurrencyFormatter.format(metric.recommendedMonthlySavings)}/mo',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: financialColors.info,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: goal.autoSyncAccount
                          ? 'This goal automatically tracks a percentage of your linked bank account balance.'
                          : 'Contribute funds to this goal',
                      child: FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                        icon: Icon(goal.autoSyncAccount ? Icons.sync_rounded : Icons.add_rounded, size: 16),
                        label: Text(goal.autoSyncAccount ? 'Auto-Synced' : 'Add Funds'),
                        onPressed: goal.autoSyncAccount
                            ? null
                            : () => AddContributionSheet.show(context, goal),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
