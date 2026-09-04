import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/utilities/currency_formatter.dart';
import '../../../transactions/presentation/screens/pending_shared_expenses_sheet.dart';
import '../../../transactions/presentation/state/transactions_provider.dart';

/// Dashboard card displaying pending shared expense reimbursements from roommates
class DashboardPendingSharedCard extends ConsumerWidget {
  const DashboardPendingSharedCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final financialColors = context.financialColors;
    final isDark = theme.brightness == Brightness.dark;

    final pendingList = ref.watch(pendingSharedExpensesProvider);
    final totalPending = ref.watch(pendingReimbursementsTotalProvider);
    final ccEarmark = ref.watch(creditCardEarmarkedReserveProvider);

    if (pendingList.isEmpty && ccEarmark <= 0) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF13221B),
                    const Color(0xFF131B26),
                  ]
                : [
                    const Color(0xFFECFDF5),
                    const Color(0xFFF0FDF4),
                  ],
          ),
          border: Border.all(
            color: AppColors.primaryEmerald.withAlpha(isDark ? 80 : 50),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryEmerald.withAlpha(isDark ? 40 : 25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.handshake_rounded,
                    color: AppColors.primaryEmerald,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pending Reimbursements',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${pendingList.length} shared bills awaiting payback',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: financialColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      CurrencyFormatter.format(totalPending),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryEmerald,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (ccEarmark > 0) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.info.withAlpha(isDark ? 30 : 20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.credit_card_rounded, size: 14, color: AppColors.info),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${CurrencyFormatter.format(ccEarmark)} in bank is earmarked for Credit Card bill',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryEmerald,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text(
                  'Settle Reimbursement',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
                onPressed: () => PendingSharedExpensesSheet.show(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
