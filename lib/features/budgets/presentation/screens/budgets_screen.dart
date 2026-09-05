import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/entities/budget_entity.dart';
import '../../../../core/domain/entities/category_constants.dart';
import '../../../../core/domain/entities/recurring_expense_entity.dart';
import '../../../../core/domain/entities/savings_goal_entity.dart';
import '../../../../core/domain/entities/transaction_entity.dart';
import '../../../../core/utilities/currency_formatter.dart';
import '../../../savings/presentation/screens/add_contribution_sheet.dart';
import '../../../savings/presentation/screens/add_edit_savings_goal_sheet.dart';
import '../../../savings/presentation/state/savings_goals_provider.dart';
import '../../../transactions/presentation/screens/add_edit_transaction_sheet.dart';
import '../../../transactions/presentation/screens/pending_shared_expenses_sheet.dart';
import '../../../transactions/presentation/screens/transaction_detail_sheet.dart';
import '../../../transactions/presentation/state/transactions_provider.dart';
import '../screens/add_recurring_sheet.dart';
import '../screens/set_budget_sheet.dart';
import '../state/budgets_provider.dart';
import '../state/recurring_provider.dart';

class BudgetsScreen extends ConsumerStatefulWidget {
  const BudgetsScreen({super.key});

  @override
  ConsumerState<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends ConsumerState<BudgetsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _showPendingOnlySplits = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final financialColors = context.financialColors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets & Goals'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppColors.primaryEmerald,
          labelColor: isDark ? AppColors.primaryMint : AppColors.primaryTeal,
          unselectedLabelColor: financialColors.textMuted,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
          tabs: const [
            Tab(icon: Icon(Icons.pie_chart_outline_rounded, size: 20), text: 'Monthly Budgets'),
            Tab(icon: Icon(Icons.savings_outlined, size: 20), text: 'Savings & Goals'),
            Tab(icon: Icon(Icons.event_repeat_rounded, size: 20), text: 'Recurring & Bills'),
            Tab(icon: Icon(Icons.group_outlined, size: 20), text: 'Shared & Splits'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMonthlyBudgetsTab(context),
          _buildSavingsGoalsTab(context),
          _buildRecurringTab(context),
          _buildSharedSplitsTab(context),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'budgets_fab',
        onPressed: () {
          if (_tabController.index == 0) {
            SetBudgetSheet.show(context, targetMonth: ref.read(selectedMonthProvider));
          } else if (_tabController.index == 1) {
            AddEditSavingsGoalSheet.show(context);
          } else if (_tabController.index == 2) {
            AddRecurringSheet.show(context);
          } else {
            AddEditTransactionSheet.show(context, initialType: TransactionType.expense);
          }
        },
        tooltip: 'Add Budget, Goal, Recurring or Shared Expense',
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }

  // --- TAB 1: MONTHLY BUDGETS ---

  Widget _buildMonthlyBudgetsTab(BuildContext context) {
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
              InkWell(
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        monthTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
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
              Text(
                'Category Budgets (${categoryStatuses.length})',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
              child: _buildCategoryBudgetCard(context, status),
            );
          }),
      ],
    );
  }

  Widget _buildCategoryBudgetCard(BuildContext context, CategoryBudgetStatus status) {
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

  // --- TAB 2: SAVINGS & GOALS ---

  Widget _buildSavingsGoalsTab(BuildContext context) {
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
                  child: _buildSavingsGoalCard(context, metric),
                );
              }),
          ],
        );
      },
    );
  }

  Widget _buildSavingsGoalCard(BuildContext context, GoalProgressMetrics metric) {
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
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Add Funds'),
                      onPressed: () => AddContributionSheet.show(context, goal),
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

  // --- TAB 3: RECURRING & BILLS ---

  Widget _buildRecurringTab(BuildContext context) {
    final theme = Theme.of(context);
    final financialColors = context.financialColors;
    final isDark = theme.brightness == Brightness.dark;

    final recurringListAsync = ref.watch(recurringListNotifierProvider);
    final monthlyCommitment = ref.watch(monthlyRecurringTotalProvider);

    return recurringListAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading recurring: $e')),
      data: (items) {
        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
          children: [
            // Monthly Commitment Overview Card
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [const Color(0xFF2E1065), const Color(0xFF131B26)]
                      : [const Color(0xFFF3E8FF), const Color(0xFFFFFFFF)],
                ),
                border: Border.all(
                  color: isDark ? AppColors.savings.withAlpha(60) : AppColors.savings.withAlpha(40),
                  width: 1.5,
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.savings.withAlpha(isDark ? 50 : 30),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.repeat_rounded, color: AppColors.savings, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MONTHLY RECURRING TOTAL',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: financialColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          CurrencyFormatter.format(monthlyCommitment),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${items.where((i) => i.isActive).length} active subscriptions & obligations',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: financialColors.textMuted,
                          ),
                        ),
                      ],
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
                  Expanded(
                    child: Text(
                      'Subscriptions & Fixed Bills (${items.length})',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (items.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => AddRecurringSheet.show(context),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add'),
                    ),
                  ],
                ],
              ),
            ),

            // Items List or Empty State
            if (items.isEmpty)
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
                          Icons.repeat_rounded,
                          color: financialColors.savings,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Subscriptions or Bills',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Keep track of fixed recurring expenses like Netflix, Spotify, Rent, Gym, and EMIs with due date reminders.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: financialColors.textMuted,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: financialColors.savings),
                        onPressed: () => AddRecurringSheet.show(context),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add First Subscription'),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...items.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildRecurringItemCard(context, item),
                );
              }),
          ],
        );
      },
    );
  }

  Widget _buildRecurringItemCard(BuildContext context, RecurringExpenseEntity item) {
    final theme = Theme.of(context);
    final financialColors = context.financialColors;
    final isDark = theme.brightness == Brightness.dark;

    final categoryItem = CategoryConstants.getCategoryByName(
      item.category,
      TransactionType.expense,
    );

    final days = item.daysUntilDue;
    String dueText;
    Color dueColor;
    if (days < 0) {
      dueText = 'Overdue by ${days.abs()}d';
      dueColor = financialColors.expense;
    } else if (days == 0) {
      dueText = 'Due Today';
      dueColor = financialColors.warning;
    } else if (days == 1) {
      dueText = 'Due Tomorrow';
      dueColor = financialColors.warning;
    } else {
      dueText = 'Due in ${days}d';
      dueColor = financialColors.info;
    }

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Recurring Expense?'),
            content: Text('Remove "${item.title}" from recurring plans?'),
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
        ref.read(recurringListNotifierProvider.notifier).deleteRecurring(item.id);
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
          onTap: () => AddRecurringSheet.show(context, recurring: item),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: categoryItem.color.withAlpha(isDark ? 45 : 30),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(categoryItem.icon, color: categoryItem.color, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item.frequency.displayName,
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: dueColor.withAlpha(isDark ? 40 : 25),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  dueText,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: dueColor,
                                  ),
                                ),
                              ),
                            ],
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
                              CurrencyFormatter.format(item.amount),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('dd MMM').format(item.nextDueDate),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: financialColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch.adaptive(
                            value: item.isActive,
                            activeTrackColor: AppColors.primaryEmerald,
                            onChanged: (_) {
                              ref.read(recurringListNotifierProvider.notifier).toggleActive(item.id);
                            },
                          ),
                          Flexible(
                            child: Text(
                              item.isActive ? 'Active' : 'Paused',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: item.isActive ? null : financialColors.textMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Log Payment'),
                        ),
                      onPressed: () async {
                        await ref
                            .read(recurringListNotifierProvider.notifier)
                            .logPaymentAsTransaction(item);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Logged ${item.title} (${CurrencyFormatter.format(item.amount)}) as transaction and moved next due date.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
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

  // --- TAB 4: SHARED & SPLITS ---

  Widget _buildSharedSplitsTab(BuildContext context) {
    final theme = Theme.of(context);
    final financialColors = context.financialColors;
    final isDark = theme.brightness == Brightness.dark;

    final allSplits = ref.watch(allSharedExpensesProvider);
    final pendingSplits = ref.watch(pendingSharedExpensesProvider);
    final pendingTotal = ref.watch(pendingReimbursementsTotalProvider);
    final ccReserve = ref.watch(creditCardEarmarkedReserveProvider);

    final displayedSplits = _showPendingOnlySplits ? pendingSplits : allSplits;

    return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
          children: [
            // Hero Card: Total Pending & CC Reserve Earmark
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                      : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFBFDBFE),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(isDark ? 50 : 15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryEmerald.withAlpha(30),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.group_work_rounded,
                          size: 20,
                          color: AppColors.primaryEmerald,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Roommate & Shared Ledger',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      if (pendingSplits.isNotEmpty)
                        FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () => PendingSharedExpensesSheet.show(context),
                          icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                          label: const Text('Settle', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'TOTAL PENDING REIMBURSEMENT',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: financialColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    CurrencyFormatter.format(pendingTotal),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: pendingTotal > 0 ? financialColors.warning : financialColors.income,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Credit Card Reserve Note
                  if (ccReserve > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: financialColors.warning.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: financialColors.warning.withAlpha(50)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.credit_card_rounded, size: 16, color: financialColors.warning),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${CurrencyFormatter.format(ccReserve)} is charged on Credit Cards. Keep incoming paybacks reserved for your CC bill.',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Filter Tabs (Pending vs All)
            Row(
              children: [
                FilterChip(
                  label: Text('Pending (${pendingSplits.length})'),
                  selected: _showPendingOnlySplits,
                  onSelected: (val) => setState(() => _showPendingOnlySplits = true),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text('All Splits (${allSplits.length})'),
                  selected: !_showPendingOnlySplits,
                  onSelected: (val) => setState(() => _showPendingOnlySplits = false),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (displayedSplits.isEmpty)
              _buildEmptySplitsCard(context, isDark, financialColors)
            else
              ...displayedSplits.map((tx) => _buildSplitItemCard(context, tx, isDark, financialColors)),
          ],
        );
  }

  Widget _buildSplitItemCard(
    BuildContext context,
    TransactionEntity tx,
    bool isDark,
    AppFinancialColors financialColors,
  ) {
    final theme = Theme.of(context);
    final myShare = tx.myShareAmount ?? (tx.amount / 2);
    final friendsShare = tx.friendsShare;
    final isSettled = tx.isSettled;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSettled
              ? financialColors.cardBorder
              : financialColors.warning.withAlpha(80),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => TransactionDetailSheet.show(context, transaction: tx),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Title, Category, Status Badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (isSettled ? financialColors.income : financialColors.warning).withAlpha(30),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isSettled ? Icons.check_circle_outline_rounded : Icons.pending_actions_rounded,
                        size: 20,
                        color: isSettled ? financialColors.income : financialColors.warning,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tx.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${DateFormat('dd MMM yyyy').format(tx.date)} • ${tx.paymentSource}',
                            style: TextStyle(fontSize: 11, color: financialColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (isSettled ? financialColors.income : financialColors.warning).withAlpha(25),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: (isSettled ? financialColors.income : financialColors.warning).withAlpha(60),
                        ),
                      ),
                      child: Text(
                        isSettled
                            ? 'Settled'
                            : '${CurrencyFormatter.format(tx.pendingReimbursement)} Pending',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isSettled ? financialColors.income : financialColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
                if (tx.sharedWith != null && tx.sharedWith!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.person_outline_rounded, size: 14, color: financialColors.textMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Shared with: ${tx.sharedWith}',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: financialColors.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                const Divider(height: 20),
                // Breakdown numbers
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Bill',
                            style: TextStyle(fontSize: 10.5, color: financialColors.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              CurrencyFormatter.format(tx.amount),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Share',
                            style: TextStyle(fontSize: 10.5, color: financialColors.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              CurrencyFormatter.format(myShare),
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: financialColors.expense),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Friends Share',
                            style: TextStyle(fontSize: 10.5, color: financialColors.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              CurrencyFormatter.format(friendsShare),
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: financialColors.income),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (!isSettled) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.handshake_rounded, size: 16),
                      onPressed: () => PendingSharedExpensesSheet.show(context, preselectedTransaction: tx),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Record Payback (${CurrencyFormatter.format(tx.pendingReimbursement)})',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptySplitsCard(
    BuildContext context,
    bool isDark,
    AppFinancialColors financialColors,
  ) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: financialColors.cardBorder),
      ),
      child: Column(
        children: [
          Icon(Icons.group_outlined, size: 48, color: financialColors.textMuted),
          const SizedBox(height: 12),
          Text(
            'No Shared Expenses Found',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'When you pay for roommates or group outings, toggle "Split / Shared with Others" when adding an expense to track paybacks here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: financialColors.textMuted),
          ),
        ],
      ),
    );
  }
}
