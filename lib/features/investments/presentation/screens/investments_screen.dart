import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/entities/investment_entity.dart';
import '../../../../core/utilities/currency_formatter.dart';
import '../screens/add_edit_investment_sheet.dart';
import '../screens/update_valuation_sheet.dart';
import '../state/investments_provider.dart';

class InvestmentsScreen extends ConsumerWidget {
  const InvestmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final financialColors = context.financialColors;
    final isDark = theme.brightness == Brightness.dark;

    final investmentsAsync = ref.watch(investmentListNotifierProvider);
    final summary = ref.watch(overallPortfolioSummaryProvider);
    final allocations = ref.watch(assetAllocationListProvider);
    final groupedHoldings = ref.watch(investmentsByAssetClassProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Investments & Assets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add Investment',
            onPressed: () => AddEditInvestmentSheet.show(context),
          ),
        ],
      ),
      body: investmentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading investments: $e')),
        data: (investments) {
          if (investments.isEmpty) {
            return ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: financialColors.income.withAlpha(isDark ? 40 : 25),
                          ),
                          child: Icon(
                            Icons.trending_up_rounded,
                            color: financialColors.income,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Investments Tracked Yet',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Track your mutual funds, Indian stocks, fixed deposits, EPF/PPF, gold, real estate, and crypto in one private offline place.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: financialColors.textMuted,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: financialColors.income),
                          onPressed: () => AddEditInvestmentSheet.show(context),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Add First Holding'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
            children: [
              // Portfolio Hero Card
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [const Color(0xFF064E3B), const Color(0xFF131B26)]
                        : [const Color(0xFFECFDF5), const Color(0xFFFFFFFF)],
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
                        Text(
                          'TOTAL PORTFOLIO VALUE',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: financialColors.textMuted,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (summary.isProfit ? financialColors.income : financialColors.expense)
                                .withAlpha(isDark ? 40 : 25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${summary.isProfit ? '+' : ''}${CurrencyFormatter.format(summary.totalProfitLoss)} (${summary.overallReturnPercentage.toStringAsFixed(1)}%)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: summary.isProfit ? financialColors.income : financialColors.expense,
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
                        CurrencyFormatter.format(summary.totalCurrentValue),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: financialColors.income,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Total Invested: ${CurrencyFormatter.format(summary.totalInvested)}',
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
                            '${summary.totalHoldingsCount} Holdings',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: financialColors.textMuted,
                            ),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Asset Allocation Section
              if (allocations.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Text(
                    'Asset Allocation',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 8),

                // Multi-colored segmented allocation bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: 12,
                    child: Row(
                      children: allocations.map((item) {
                        return Expanded(
                          flex: (item.percentageOfPortfolio * 10).round().clamp(1, 1000),
                          child: Container(
                            color: item.assetClass.color,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Asset Class Allocation Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: allocations.map((item) {
                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: financialColors.cardBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: item.assetClass.color,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${item.assetClass.name.toUpperCase()}: ${item.percentageOfPortfolio.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Grouped Holdings List
              ...groupedHoldings.entries.map((entry) {
                final assetClass = entry.key;
                final holdings = entry.value;
                final classTotal = holdings.fold(0.0, (sum, h) => sum + h.currentValue);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      child: Row(
                        children: [
                          Icon(assetClass.icon, color: assetClass.color, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${assetClass.displayName} (${holdings.length})',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            CurrencyFormatter.format(classTotal),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: assetClass.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...holdings.map((inv) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildHoldingCard(context, ref, inv),
                      );
                    }),
                    const SizedBox(height: 8),
                  ],
                );
              }),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'investments_fab',
        onPressed: () => AddEditInvestmentSheet.show(context),
        tooltip: 'Add Investment',
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }

  Widget _buildHoldingCard(BuildContext context, WidgetRef ref, InvestmentEntity inv) {
    final theme = Theme.of(context);
    final financialColors = context.financialColors;
    final isDark = theme.brightness == Brightness.dark;

    final pnl = inv.currentValue - inv.investedAmount;
    final returnPct = inv.investedAmount > 0 ? (pnl / inv.investedAmount) * 100 : 0.0;
    final isProfit = pnl >= 0;

    return Dismissible(
      key: Key(inv.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Remove Investment Holding?'),
            content: Text('Remove "${inv.name}" from your portfolio?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Remove'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) {
        ref.read(investmentListNotifierProvider.notifier).deleteInvestment(inv.id);
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
            Text('Remove', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
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
          onTap: () => AddEditInvestmentSheet.show(context, investment: inv),
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
                        color: inv.assetClass.color.withAlpha(isDark ? 45 : 30),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        inv.assetClass.icon,
                        color: inv.assetClass.color,
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
                                  inv.name,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (inv.institution != null) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    inv.institution!,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: financialColors.textMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Invested: ${CurrencyFormatter.format(inv.investedAmount)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: financialColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            CurrencyFormatter.format(inv.currentValue),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: isProfit ? financialColors.income : financialColors.expense,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (isProfit ? financialColors.income : financialColors.expense)
                                .withAlpha(isDark ? 35 : 20),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${isProfit ? '+' : ''}${returnPct.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isProfit ? financialColors.income : financialColors.expense,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (inv.units != null && inv.currentPrice != null)
                      Expanded(
                        child: Text(
                          '${inv.units} units @ ₹${inv.currentPrice}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: financialColors.textMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    else
                      Expanded(
                        child: Text(
                          'P&L: ${isProfit ? '+' : ''}${CurrencyFormatter.format(pnl)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isProfit ? financialColors.income : financialColors.expense,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      ),
                      icon: const Icon(Icons.edit_note_rounded, size: 16),
                      label: const Text('Update Value'),
                      onPressed: () => UpdateValuationSheet.show(context, inv),
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
