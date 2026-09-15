import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/entities/budget_entity.dart';
import '../../../../core/domain/entities/category_constants.dart';
import '../../../../core/domain/entities/transaction_entity.dart';
import '../../../../core/utilities/currency_formatter.dart';
import '../../../transactions/presentation/state/transactions_provider.dart';
import '../screens/set_budget_sheet.dart';
import '../state/budgets_provider.dart';

class MonthlyBudgetsTab extends ConsumerWidget {
  const MonthlyBudgetsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final financialColors = context.financialColors;
    final isDark = theme.brightness == Brightness.dark;

    final selectedMonth = ref.watch(selectedMonthProvider);
    final monthTitle = DateFormat('MMMM yyyy').format(selectedMonth);

    final overallSummary = ref.watch(overallMonthlyBudgetSummaryProvider);
    final categoryStatuses = ref.watch(monthlyCategoryBudgetStatusesProvider);

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
      children: [
        // Month Selector
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: financialColors.cardBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () {
                  ref.read(selectedMonthProvider.notifier).previousMonth();
                },
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedMonth,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2040),
                    );
                    if (picked != null) {
                      ref.read(selectedMonthProvider.notifier).setMonth(picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_month_rounded, size: 18),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            monthTitle,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: () {
                  ref.read(selectedMonthProvider.notifier).nextMonth();
                },
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),

        // Overall Monthly Budget Hero Card
        if (overallSummary.budgetedCategoriesCount > 0)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [const Color(0xFF1E1B4B), const Color(0xFF131B26)]
                    : [const Color(0xFFEEF2FF), const Color(0xFFFFFFFF)],
              ),
              border: Border.all(
                color: isDark ? AppColors.investment.withAlpha(60) : AppColors.investment.withAlpha(40),
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
                        'TOTAL BUDGETED ALLOWANCE',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: financialColors.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildHealthBadge(context, overallSummary.health),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              CurrencyFormatter.format(overallSummary.totalRemaining),
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: overallSummary.health == BudgetHealth.exceeded
                                    ? financialColors.expense
                                    : null,
                              ),
                            ),
                          ),
                          Text(
                            overallSummary.totalOverspent > 0
                                ? 'Overspent by ${CurrencyFormatter.format(overallSummary.totalOverspent)}'
                                : 'Remaining to spend',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: overallSummary.totalOverspent > 0
                                  ? financialColors.expense
                                  : financialColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${overallSummary.overallPercentage.toStringAsFixed(0)}%',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: _getHealthColor(context, overallSummary.health),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: (overallSummary.overallPercentage / 100).clamp(0.0, 1.0),
                    minHeight: 10,
                    backgroundColor: isDark
                        ? AppColors.darkSurfaceVariant
                        : AppColors.lightSurfaceVariant,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getHealthColor(context, overallSummary.health),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'Spent: ${CurrencyFormatter.format(overallSummary.totalSpent)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: financialColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Limit: ${CurrencyFormatter.format(overallSummary.totalLimit)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: financialColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

        // Section Title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Category Budgets (${categoryStatuses.length})',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              if (categoryStatuses.isNotEmpty)
                TextButton.icon(
                  onPressed: () => SetBudgetSheet.show(
                    context,
                    targetMonth: selectedMonth,
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add'),
                ),
            ],
          ),
        ),

        // Category Budget Cards List or Empty State
        if (categoryStatuses.isEmpty)
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
                      color: financialColors.investment.withAlpha(isDark ? 40 : 25),
                    ),
                    child: Icon(
                      Icons.pie_chart_rounded,
                      color: financialColors.investment,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Budgets in $monthTitle',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Set monthly spending limits for categories like Food, Shopping, and Rent to track your remaining allowance.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: financialColors.textMuted,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: financialColors.investment),
                    onPressed: () => SetBudgetSheet.show(
                      context,
                      targetMonth: selectedMonth,
                    ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Create Category Budget'),
                  ),
                ],
              ),
            ),
          )
        else
          ...categoryStatuses.map((status) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildCategoryBudgetCard(context, ref, status),
            );
          }),
      ],
    );
  }

  Widget _buildCategoryBudgetCard(BuildContext context, WidgetRef ref, CategoryBudgetStatus status) {
    final theme = Theme.of(context);
    final financialColors = context.financialColors;
    final isDark = theme.brightness == Brightness.dark;

    final categoryItem = CategoryConstants.getCategoryByName(
      status.category,
      TransactionType.expense,
    );

    final healthColor = _getHealthColor(context, status.health);

    return Dismissible(
      key: Key(status.budget.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Budget?'),
            content: Text('Remove monthly budget limit for "${status.category}"?'),
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
        ref.read(budgetListNotifierProvider.notifier).deleteBudget(status.budget.id);
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
          side: BorderSide(color: financialColors.cardBorder),
        ),
        child: InkWell(
          onTap: () => SetBudgetSheet.show(
            context,
            budget: status.budget,
            targetMonth: status.budget.month,
          ),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: categoryItem.color.withAlpha(isDark ? 45 : 30),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(categoryItem.icon, color: categoryItem.color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            status.category,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            status.overspentAmount > 0
                                ? 'Over by ${CurrencyFormatter.format(status.overspentAmount)}'
                                : '${CurrencyFormatter.format(status.remainingAmount)} left',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: status.overspentAmount > 0
                                  ? financialColors.expense
                                  : financialColors.textMuted,
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
                              '${CurrencyFormatter.format(status.spentAmount)} / ${CurrencyFormatter.format(status.limitAmount)}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${status.spentPercentage.toStringAsFixed(0)}% spent',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: healthColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (status.spentPercentage / 100).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: isDark
                        ? AppColors.darkSurfaceVariant
                        : AppColors.lightSurfaceVariant,
                    valueColor: AlwaysStoppedAnimation<Color>(healthColor),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHealthBadge(BuildContext context, BudgetHealth health) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = _getHealthColor(context, health);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(isDark ? 40 : 25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(isDark ? 60 : 40)),
      ),
      child: Text(
        health.displayName,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Color _getHealthColor(BuildContext context, BudgetHealth health) {
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
}
