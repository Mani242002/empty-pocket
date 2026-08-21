import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/entities/debt_entity.dart';
import '../../../../core/utilities/currency_formatter.dart';
import '../screens/add_edit_debt_sheet.dart';
import '../screens/record_debt_payment_sheet.dart';
import '../state/debts_provider.dart';

class DebtsScreen extends ConsumerWidget {
  const DebtsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final financialColors = context.financialColors;
    final isDark = theme.brightness == Brightness.dark;

    final debtsAsync = ref.watch(debtListNotifierProvider);
    final summary = ref.watch(overallLiabilitiesSummaryProvider);
    final metricsList = ref.watch(debtRepaymentMetricsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Loans & Liabilities'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add Loan',
            onPressed: () => AddEditDebtSheet.show(context),
          ),
        ],
      ),
      body: debtsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading debts: $e')),
        data: (debts) {
          final activeMetrics = metricsList.where((m) => !m.isPaidOff).toList();
          final paidOffMetrics = metricsList.where((m) => m.isPaidOff).toList();

          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
            children: [
              // Overall Liabilities Summary Hero Card
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [const Color(0xFF4C0519), const Color(0xFF131B26)]
                        : [const Color(0xFFFFF1F2), const Color(0xFFFFFFFF)],
                  ),
                  border: Border.all(
                    color: isDark ? AppColors.expense.withAlpha(60) : AppColors.expense.withAlpha(40),
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
                          'TOTAL OUTSTANDING DEBT',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: financialColors.textMuted,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: financialColors.expense.withAlpha(isDark ? 40 : 25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${summary.activeDebtsCount} Active Loans',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: financialColors.expense,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      CurrencyFormatter.format(summary.totalOutstanding),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: financialColors.expense,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Monthly EMI: ${CurrencyFormatter.format(summary.totalMonthlyEmi)}',
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
                            'Original: ${CurrencyFormatter.format(summary.totalOriginalPrincipal)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: financialColors.textMuted,
                            ),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: summary.totalOriginalPrincipal > 0
                            ? (summary.totalPaidOff / summary.totalOriginalPrincipal).clamp(0.0, 1.0)
                            : 0.0,
                        minHeight: 8,
                        backgroundColor: isDark
                            ? AppColors.darkSurfaceVariant
                            : AppColors.lightSurfaceVariant,
                        valueColor: AlwaysStoppedAnimation<Color>(financialColors.income),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        summary.totalOriginalPrincipal > 0
                            ? '${((summary.totalPaidOff / summary.totalOriginalPrincipal) * 100).toStringAsFixed(0)}% Repaid'
                            : '0% Repaid',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: financialColors.income,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Active Loans Section Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Active Liabilities (${activeMetrics.length})',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (activeMetrics.isNotEmpty)
                      TextButton.icon(
                        onPressed: () => AddEditDebtSheet.show(context),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add'),
                      ),
                  ],
                ),
              ),

              // Active Loans List or Empty State
              if (activeMetrics.isEmpty)
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
                            color: financialColors.expense.withAlpha(isDark ? 40 : 25),
                          ),
                          child: Icon(
                            Icons.credit_card_off_rounded,
                            color: financialColors.expense,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Active Loans or Debts',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Keep track of home loans, car EMIs, education loans, credit card balances, or personal borrowings.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: financialColors.textMuted,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: financialColors.expense),
                          onPressed: () => AddEditDebtSheet.show(context),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Add First Loan / Debt'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...activeMetrics.map((metric) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildDebtCard(context, ref, metric),
                  );
                }),

              // Paid Off Loans Section (if any)
              if (paidOffMetrics.isNotEmpty) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Text(
                    'Paid Off (${paidOffMetrics.length})',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: financialColors.income,
                    ),
                  ),
                ),
                ...paidOffMetrics.map((metric) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildDebtCard(context, ref, metric),
                  );
                }),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'debts_fab',
        onPressed: () => AddEditDebtSheet.show(context),
        tooltip: 'Add Loan',
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }

  Widget _buildDebtCard(BuildContext context, WidgetRef ref, DebtRepaymentMetrics metric) {
    final theme = Theme.of(context);
    final financialColors = context.financialColors;
    final isDark = theme.brightness == Brightness.dark;
    final debt = metric.debt;

    return Dismissible(
      key: Key(debt.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Debt Record?'),
            content: Text('Remove "${debt.title}" and its repayment history?'),
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
        ref.read(debtListNotifierProvider.notifier).deleteDebt(debt.id);
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
          onTap: () => AddEditDebtSheet.show(context, debt: debt),
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
                        color: (metric.isPaidOff ? financialColors.income : financialColors.expense)
                            .withAlpha(isDark ? 45 : 30),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        metric.isPaidOff ? Icons.verified_rounded : debt.type.icon,
                        color: metric.isPaidOff ? financialColors.income : financialColors.expense,
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
                                  debt.title,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (debt.lenderName != null) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    debt.lenderName!,
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
                            metric.isPaidOff
                                ? '🎉 Fully Paid Off'
                                : 'Due on ${debt.dueDateDay}th • ${metric.estimatedMonthsRemaining} months left',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: metric.isPaidOff ? financialColors.income : financialColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          CurrencyFormatter.format(debt.remainingAmount),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: metric.isPaidOff ? financialColors.income : financialColors.expense,
                          ),
                        ),
                        Text(
                          'of ${CurrencyFormatter.format(debt.principalAmount)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: financialColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (metric.paidPercentage / 100).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: isDark
                        ? AppColors.darkSurfaceVariant
                        : AppColors.lightSurfaceVariant,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      metric.isPaidOff ? financialColors.income : financialColors.warning,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Bottom row: Monthly EMI, Interest rate, and Pay EMI button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EMI: ${CurrencyFormatter.format(debt.monthlyEmi)}/mo',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: financialColors.warning,
                          ),
                        ),
                        if (debt.interestRate > 0)
                          Text(
                            '${debt.interestRate}% interest p.a.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: financialColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                    if (!metric.isPaidOff)
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                        icon: const Icon(Icons.payment_rounded, size: 16),
                        label: const Text('Pay EMI'),
                        onPressed: () => RecordDebtPaymentSheet.show(context, debt),
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
