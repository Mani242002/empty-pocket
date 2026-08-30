import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/entities/transaction_entity.dart';
import '../../../transactions/presentation/screens/add_edit_transaction_sheet.dart';
import '../../../transactions/presentation/widgets/transaction_list_item.dart';

class DashboardRecentActivityHeader extends StatelessWidget {
  final bool hasTransactions;
  final VoidCallback? onViewAllTransactions;

  const DashboardRecentActivityHeader({
    super.key,
    required this.hasTransactions,
    this.onViewAllTransactions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
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
          if (hasTransactions && onViewAllTransactions != null)
            TextButton(
              onPressed: onViewAllTransactions,
              child: const Text('View All'),
            ),
        ],
      ),
    );
  }
}

class DashboardEmptyTransactionsPrompt extends StatelessWidget {
  const DashboardEmptyTransactionsPrompt({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final financialColors = context.financialColors;
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
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
    );
  }
}

class DashboardRecentActivityList extends StatelessWidget {
  final List<TransactionEntity> recentTransactions;
  final void Function(TransactionEntity transaction) onTapTransaction;
  final void Function(String id) onDeleteTransaction;

  const DashboardRecentActivityList({
    super.key,
    required this.recentTransactions,
    required this.onTapTransaction,
    required this.onDeleteTransaction,
  });

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final tx = recentTransactions[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TransactionListItem(
                transaction: tx,
                onTap: () => onTapTransaction(tx),
                onDelete: () => onDeleteTransaction(tx.id),
              ),
            );
          },
          childCount: recentTransactions.length,
        ),
      ),
    );
  }
}
