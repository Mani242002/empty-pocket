import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/entities/financial_health_entity.dart';
import '../../../../core/utilities/currency_formatter.dart';
import '../../../net_worth/presentation/screens/financial_health_screen.dart';
import '../../../transactions/presentation/state/transactions_provider.dart';

class DashboardBalanceCard extends StatelessWidget {
  final MonthlyFinancialSummary summary;
  final FinancialHealthSummary healthSummary;
  final bool isBalanceVisible;
  final VoidCallback onToggleBalanceVisibility;

  const DashboardBalanceCard({
    super.key,
    required this.summary,
    required this.healthSummary,
    required this.isBalanceVisible,
    required this.onToggleBalanceVisibility,
  });

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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withAlpha(isDark ? 50 : 35),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withAlpha(isDark ? 50 : 30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: context.financialColors.textMuted,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    amount,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final financialColors = context.financialColors;
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
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
                Flexible(
                  child: Text(
                    'THIS MONTH\'S BALANCE',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: financialColors.textMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    isBalanceVisible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                    color: financialColors.textMuted,
                  ),
                  onPressed: onToggleBalanceVisibility,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                isBalanceVisible ? CurrencyFormatter.format(summary.netBalance) : '••••••',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                  fontSize: 32,
                  color: summary.netBalance < 0 ? financialColors.expense : null,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Income & Expense split cards
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _buildFlowMetric(
                      context,
                      title: 'Income (${summary.incomeCount})',
                      amount: isBalanceVisible ? CurrencyFormatter.format(summary.totalIncome) : '••••',
                      icon: Icons.arrow_downward_rounded,
                      color: financialColors.income,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildFlowMetric(
                      context,
                      title: 'Expenses (${summary.expenseCount})',
                      amount: isBalanceVisible ? CurrencyFormatter.format(summary.totalExpense) : '••••',
                      icon: Icons.arrow_upward_rounded,
                      color: financialColors.expense,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Net Worth & Health Score banner
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const FinancialHealthScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurfaceVariant.withAlpha(180)
                        : AppColors.lightSurfaceVariant,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: financialColors.cardBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: healthSummary.grade.color.withAlpha(isDark ? 40 : 25),
                        ),
                        child: Icon(
                          healthSummary.grade.icon,
                          color: healthSummary.grade.color,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Net Worth: ${CurrencyFormatter.format(healthSummary.netWorth.netWorth)}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Health Score: ${healthSummary.overallScore}/100 • ${healthSummary.grade.displayName}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: healthSummary.grade.color,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: financialColors.textMuted, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
