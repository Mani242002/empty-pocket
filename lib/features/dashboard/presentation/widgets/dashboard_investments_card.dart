import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/entities/investment_entity.dart';
import '../../../../core/utilities/currency_formatter.dart';
import '../../../investments/presentation/screens/add_edit_investment_sheet.dart';
import '../../../investments/presentation/screens/investments_screen.dart';

class DashboardInvestmentsCard extends StatelessWidget {
  final OverallPortfolioSummary portfolioSummary;

  const DashboardInvestmentsCard({
    super.key,
    required this.portfolioSummary,
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
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.trending_up_rounded, color: financialColors.income, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Investments & Assets',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (portfolioSummary.totalHoldingsCount > 0)
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('Manage'),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const InvestmentsScreen()),
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
                      label: const Text('Add Asset'),
                      onPressed: () => AddEditInvestmentSheet.show(context),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (portfolioSummary.totalHoldingsCount > 0) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        CurrencyFormatter.format(portfolioSummary.totalCurrentValue),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: financialColors.income,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (portfolioSummary.isProfit ? financialColors.income : financialColors.expense)
                              .withAlpha(isDark ? 35 : 20),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${portfolioSummary.isProfit ? '+' : ''}${CurrencyFormatter.format(portfolioSummary.totalProfitLoss)} (${portfolioSummary.overallReturnPercentage.toStringAsFixed(1)}%)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: portfolioSummary.isProfit ? financialColors.income : financialColors.expense,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Invested: ${CurrencyFormatter.format(portfolioSummary.totalInvested)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: financialColors.textMuted,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '${portfolioSummary.totalHoldingsCount} Assets Tracked',
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Start tracking mutual funds, stocks, gold & FDs',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: financialColors.textMuted,
                        ),
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
