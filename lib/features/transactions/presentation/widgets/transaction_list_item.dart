import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/entities/category_constants.dart';
import '../../../../core/domain/entities/transaction_entity.dart';
import '../../../../core/utilities/currency_formatter.dart';

class TransactionListItem extends StatelessWidget {
  final TransactionEntity transaction;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const TransactionListItem({
    super.key,
    required this.transaction,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final financialColors = context.financialColors;
    final isDark = theme.brightness == Brightness.dark;

    final categoryItem = CategoryConstants.getCategoryByName(
      transaction.category,
      transaction.type,
    );

    final isIncome = transaction.type == TransactionType.income;
    final amountColor = isIncome ? financialColors.income : financialColors.expense;
    final amountPrefix = isIncome ? '+' : '-';
    final timeStr = DateFormat('h:mm a').format(transaction.date);

    return Dismissible(
      key: Key(transaction.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Transaction?'),
            content: Text(
              'Are you sure you want to delete "${transaction.title}" (${CurrencyFormatter.format(transaction.amount)})?',
            ),
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
      onDismissed: (_) => onDelete?.call(),
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
              'Delete',
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
            color: financialColors.cardBorder,
            width: 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Category Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: categoryItem.color.withAlpha(isDark ? 45 : 30),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: categoryItem.color.withAlpha(isDark ? 60 : 40),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    categoryItem.icon,
                    color: categoryItem.color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                // Title and details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              categoryItem.name,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: financialColors.textMuted,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: financialColors.textMuted,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkSurfaceVariant
                                  : AppColors.lightSurfaceVariant,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              transaction.paymentSource,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            timeStr,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              color: financialColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Amount
                Text(
                  '$amountPrefix${CurrencyFormatter.format(transaction.amount)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: amountColor,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
