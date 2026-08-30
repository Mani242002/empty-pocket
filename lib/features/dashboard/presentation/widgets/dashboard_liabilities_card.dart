import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/entities/debt_entity.dart';
import '../../../../core/utilities/currency_formatter.dart';
import '../../../debts/presentation/screens/add_edit_debt_sheet.dart';
import '../../../debts/presentation/screens/debts_screen.dart';

class DashboardLiabilitiesCard extends StatelessWidget {
  final OverallLiabilitiesSummary liabilitiesSummary;

  const DashboardLiabilitiesCard({
    super.key,
    required this.liabilitiesSummary,
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
                      Icon(Icons.account_balance_rounded, color: financialColors.expense, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Loans & Liabilities',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  if (liabilitiesSummary.activeDebtsCount > 0)
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('Manage'),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const DebtsScreen()),
                        );
                      },
                    )
                  else
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Loan'),
                      onPressed: () => AddEditDebtSheet.show(context),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (liabilitiesSummary.activeDebtsCount > 0) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: liabilitiesSummary.totalOriginalPrincipal > 0
                        ? (liabilitiesSummary.totalPaidOff / liabilitiesSummary.totalOriginalPrincipal).clamp(0.0, 1.0)
                        : 0.0,
                    minHeight: 8,
                    backgroundColor: isDark
                        ? AppColors.darkSurfaceVariant
                        : AppColors.lightSurfaceVariant,
                    valueColor: AlwaysStoppedAnimation<Color>(financialColors.income),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Outstanding: ${CurrencyFormatter.format(liabilitiesSummary.totalOutstanding)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: financialColors.expense,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Monthly EMI: ${CurrencyFormatter.format(liabilitiesSummary.totalMonthlyEmi)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: financialColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
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
                    value: 1.0,
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
                        '🎉 Zero Debt',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: financialColors.income,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'No active liabilities',
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
