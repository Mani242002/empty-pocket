import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/entities/budget_entity.dart';
import '../../../../core/domain/entities/transaction_entity.dart';
import '../../../../core/utilities/currency_formatter.dart';
import '../../../budgets/presentation/screens/set_budget_sheet.dart';
import '../../../budgets/presentation/state/budgets_provider.dart';
import '../../../transactions/presentation/screens/add_edit_transaction_sheet.dart';
import '../../../transactions/presentation/state/transactions_provider.dart';
import '../../../transactions/presentation/widgets/transaction_list_item.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  final VoidCallback? onViewAllTransactions;
  final VoidCallback? onSetBudget;

  const DashboardScreen({
    super.key,
    this.onViewAllTransactions,
    this.onSetBudget,
  });

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _isBalanceVisible = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final financialColors = context.financialColors;
    final isDark = theme.brightness == Brightness.dark;
    final today = DateFormat('EEEE, d MMMM').format(DateTime.now());

    final summary = ref.watch(monthlyFinancialSummaryProvider);
    final budgetSummary = ref.watch(overallMonthlyBudgetSummaryProvider);
    final recentTransactions = ref.watch(recentTransactionsProvider);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Top App Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.primaryEmerald.withAlpha(isDark ? 50 : 30),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.account_balance_wallet_rounded,
                                color: AppColors.primaryEmerald,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'EmptyPocket',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          today,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: financialColors.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    // Privacy badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: financialColors.cardBorder,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            size: 14,
                            color: financialColors.income,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Offline & Private',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Main Balance Hero Card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [
                              const Color(0xFF13221B),
                              const Color(0xFF131B26),
                              const Color(0xFF0F172A),
                            ]
                          : [
                              const Color(0xFFECFDF5),
                              const Color(0xFFF0FDF4),
                              const Color(0xFFFFFFFF),
                            ],
                    ),
                    border: Border.all(
                      color: isDark
                          ? AppColors.primaryEmerald.withAlpha(50)
                          : AppColors.primaryEmerald.withAlpha(60),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withAlpha(80)
                            : AppColors.primaryEmerald.withAlpha(20),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'THIS MONTH\'S BALANCE',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: financialColors.textMuted,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              _isBalanceVisible
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 20,
                              color: financialColors.textMuted,
                            ),
                            onPressed: () {
                              setState(() {
                                _isBalanceVisible = !_isBalanceVisible;
                              });
                            },
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isBalanceVisible ? CurrencyFormatter.format(summary.netBalance) : '••••••',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                          fontSize: 32,
                          color: summary.netBalance < 0 ? financialColors.expense : null,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Income & Expense split cards
                      Row(
                        children: [
                          Expanded(
                            child: _buildFlowMetric(
                              context,
                              title: 'Income (${summary.incomeCount})',
                              amount: _isBalanceVisible ? CurrencyFormatter.format(summary.totalIncome) : '••••',
                              icon: Icons.arrow_downward_rounded,
                              color: financialColors.income,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildFlowMetric(
                              context,
                              title: 'Expenses (${summary.expenseCount})',
                              amount: _isBalanceVisible ? CurrencyFormatter.format(summary.totalExpense) : '••••',
                              icon: Icons.arrow_upward_rounded,
                              color: financialColors.expense,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Quick Actions
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        context,
                        label: 'Add Expense',
                        icon: Icons.remove_circle_outline_rounded,
                        color: financialColors.expense,
                        onTap: () => AddEditTransactionSheet.show(
                          context,
                          initialType: TransactionType.expense,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildActionButton(
                        context,
                        label: 'Add Income',
                        icon: Icons.add_circle_outline_rounded,
                        color: financialColors.income,
                        onTap: () => AddEditTransactionSheet.show(
                          context,
                          initialType: TransactionType.income,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildActionButton(
                        context,
                        label: 'Set Budget',
                        icon: Icons.pie_chart_outline_rounded,
                        color: financialColors.investment,
                        onTap: () => SetBudgetSheet.show(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Monthly Budget Status Card
            SliverToBoxAdapter(
              child: Padding(
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
                              Text(
                                'Spent: ${CurrencyFormatter.format(budgetSummary.totalSpent)} / ${CurrencyFormatter.format(budgetSummary.totalLimit)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: financialColors.textMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                budgetSummary.totalOverspent > 0
                                    ? 'Over by ${CurrencyFormatter.format(budgetSummary.totalOverspent)}'
                                    : '${CurrencyFormatter.format(budgetSummary.totalRemaining)} left',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: budgetSummary.totalOverspent > 0
                                      ? financialColors.expense
                                      : financialColors.textMuted,
                                  fontWeight: FontWeight.w600,
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
                              Text(
                                'Total Spent: ${CurrencyFormatter.format(summary.totalExpense)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: financialColors.textMuted,
                                ),
                              ),
                              Text(
                                'No category limits configured',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: financialColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Recent Transactions Section Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Activity',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (recentTransactions.isNotEmpty && widget.onViewAllTransactions != null)
                      TextButton(
                        onPressed: widget.onViewAllTransactions,
                        child: const Text('View All'),
                      ),
                  ],
                ),
              ),
            ),

            // Recent Transactions List or Empty State
            if (recentTransactions.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                      child: Column(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primaryEmerald.withAlpha(isDark ? 40 : 25),
                            ),
                            child: const Icon(
                              Icons.receipt_long_rounded,
                              color: AppColors.primaryEmerald,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No Transactions Yet',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Every financial journey begins with your first entry.\nTap the button below to add your first expense or income.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: financialColors.textMuted,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed: () => AddEditTransactionSheet.show(
                              context,
                              initialType: TransactionType.expense,
                            ),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add First Transaction'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final tx = recentTransactions[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TransactionListItem(
                          transaction: tx,
                          onTap: () => AddEditTransactionSheet.show(
                            context,
                            transaction: tx,
                          ),
                          onDelete: () => ref
                              .read(transactionListNotifierProvider.notifier)
                              .deleteTransaction(tx.id),
                        ),
                      );
                    },
                    childCount: recentTransactions.length,
                  ),
                ),
              ),

            const SliverToBoxAdapter(
              child: SizedBox(height: 32),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlowMetric(
    BuildContext context, {
    required String title,
    required String amount,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withAlpha(isDark ? 50 : 35),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withAlpha(isDark ? 50 : 30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: context.financialColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  amount,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: context.financialColors.cardBorder,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withAlpha(isDark ? 40 : 25),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

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
}
