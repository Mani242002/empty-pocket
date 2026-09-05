import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/entities/category_constants.dart';
import '../../../../core/domain/entities/transaction_entity.dart';
import '../../../../core/utilities/app_haptics.dart';
import '../../../../core/utilities/currency_formatter.dart';
import '../../../accounts/presentation/state/accounts_cards_provider.dart';
import '../state/transactions_provider.dart';
import 'add_edit_transaction_sheet.dart';
import 'pending_shared_expenses_sheet.dart';

/// Read-only receipt and detail view for a transaction with top-right actions
class TransactionDetailSheet extends ConsumerWidget {
  final TransactionEntity transaction;

  const TransactionDetailSheet({super.key, required this.transaction});

  static Future<void> show(BuildContext context, {required TransactionEntity transaction}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TransactionDetailSheet(transaction: transaction),
    );
  }

  void _duplicateTransaction(BuildContext context, WidgetRef ref) async {
    Navigator.pop(context);
    final now = DateTime.now();
    final cloned = transaction.copyWith(
      id: const Uuid().v4(),
      date: now,
      createdAt: now,
      updatedAt: now,
    );

    // Synchronize account/card balances for the duplicated transaction
    if (cloned.type == TransactionType.income) {
      if (cloned.accountId != null) {
        await ref
            .read(bankAccountListProvider.notifier)
            .adjustAccountBalance(cloned.accountId!, cloned.amount);
      } else if (cloned.creditCardId != null) {
        await ref
            .read(creditCardListProvider.notifier)
            .adjustUsedAmount(cloned.creditCardId!, -cloned.amount);
      }
    } else if (cloned.type == TransactionType.expense) {
      if (cloned.creditCardId != null) {
        await ref
            .read(creditCardListProvider.notifier)
            .adjustUsedAmount(cloned.creditCardId!, cloned.amount);
      } else if (cloned.accountId != null) {
        await ref
            .read(bankAccountListProvider.notifier)
            .adjustAccountBalance(cloned.accountId!, -cloned.amount);
      }
    } else if (cloned.type == TransactionType.transfer) {
      if (cloned.accountId != null) {
        await ref
            .read(bankAccountListProvider.notifier)
            .adjustAccountBalance(cloned.accountId!, -cloned.amount);
      }
      if (cloned.toAccountId != null) {
        await ref
            .read(bankAccountListProvider.notifier)
            .adjustAccountBalance(cloned.toAccountId!, cloned.amount);
      } else if (cloned.creditCardId != null) {
        await ref
            .read(creditCardListProvider.notifier)
            .adjustUsedAmount(cloned.creditCardId!, -cloned.amount);
      }
    }

    await ref.read(transactionListNotifierProvider.notifier).addTransaction(cloned);
    AppHaptics.success();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Duplicated "${cloned.title}" (${CurrencyFormatter.format(cloned.amount)}).'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction?'),
        content: Text(
          'Are you sure you want to delete "${transaction.title}" of ${CurrencyFormatter.format(transaction.amount)}?\n\n'
          'Any linked account or credit card balance impact will be reverted automatically.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () async {
              Navigator.pop(ctx); // Close dialog
              Navigator.pop(context); // Close sheet
              await ref
                  .read(transactionListNotifierProvider.notifier)
                  .deleteTransaction(transaction.id);
              AppHaptics.deleteAction();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final financialColors = context.financialColors;
    final isDark = theme.brightness == Brightness.dark;

    final categoryItem = CategoryConstants.getCategoryByName(
      transaction.category,
      transaction.type,
    );

    final isExpense = transaction.type == TransactionType.expense;
    final isIncome = transaction.type == TransactionType.income;

    final amountColor = isExpense
        ? financialColors.expense
        : (isIncome ? financialColors.income : AppColors.info);

    final sign = isExpense ? '-' : (isIncome ? '+' : '↔ ');

    final formattedDate = DateFormat('EEEE, d MMMM yyyy').format(transaction.date);
    final formattedTime = DateFormat('h:mm a').format(transaction.date);

    final bankAccounts = ref.watch(activeBankAccountsProvider);
    final creditCards = ref.watch(activeCreditCardsProvider);

    String accountDisplay = transaction.paymentSource;
    if (transaction.accountId != null) {
      final matching = bankAccounts.where((a) => a.id == transaction.accountId);
      if (matching.isNotEmpty) {
        accountDisplay = '${matching.first.accountName} (${matching.first.bankName})';
      }
    } else if (transaction.creditCardId != null) {
      final matching = creditCards.where((c) => c.id == transaction.creditCardId);
      if (matching.isNotEmpty) {
        accountDisplay = '${matching.first.cardName} (${matching.first.bankName})';
      }
    }

    return Material(
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: financialColors.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Header Bar with Action Icons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: amountColor.withAlpha(isDark ? 40 : 25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      transaction.type.displayName.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: amountColor,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 20),
                        tooltip: 'Duplicate',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _duplicateTransaction(context, ref),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_rounded, size: 20),
                        tooltip: 'Edit Transaction',
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          Navigator.pop(context);
                          AddEditTransactionSheet.show(
                            context,
                            transaction: transaction,
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.expense),
                        tooltip: 'Delete',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _confirmDelete(context, ref),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        tooltip: 'Close',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Hero Category & Amount Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: financialColors.cardBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: categoryItem.color.withAlpha(isDark ? 50 : 35),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(categoryItem.icon, color: categoryItem.color, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            transaction.title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            transaction.category,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: financialColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$sign${CurrencyFormatter.format(transaction.amount)}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: amountColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Date, Time & Payment Source Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceVariant.withAlpha(120) : AppColors.lightSurfaceVariant.withAlpha(120),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: financialColors.cardBorder),
                ),
                child: Column(
                  children: [
                    _buildDetailRow(
                      context,
                      icon: Icons.calendar_today_rounded,
                      label: 'Date & Time',
                      value: '$formattedDate at $formattedTime',
                    ),
                    const Divider(height: 20),
                    _buildDetailRow(
                      context,
                      icon: transaction.creditCardId != null
                          ? Icons.credit_card_rounded
                          : (transaction.accountId != null
                              ? Icons.account_balance_rounded
                              : Icons.payment_rounded),
                      label: transaction.type == TransactionType.income ? 'Deposited To' : 'Paid From',
                      value: accountDisplay,
                    ),
                  ],
                ),
              ),

              // Shared Expense Details Card (if shared)
              if (transaction.isShared) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryEmerald.withAlpha(isDark ? 25 : 15),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.primaryEmerald.withAlpha(isDark ? 80 : 50),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Row(
                              children: [
                                Icon(Icons.people_alt_rounded, color: AppColors.primaryEmerald, size: 20),
                                SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Shared / Split Expense',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: transaction.isSettled
                                  ? financialColors.income.withAlpha(isDark ? 40 : 25)
                                  : financialColors.warning.withAlpha(isDark ? 40 : 25),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              transaction.isSettled ? 'FULLY SETTLED' : 'PENDING',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: transaction.isSettled ? financialColors.income : financialColors.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildMiniStat(context, 'Total Bill', CurrencyFormatter.format(transaction.amount)),
                          const SizedBox(width: 12),
                          _buildMiniStat(context, 'My Share', CurrencyFormatter.format(transaction.myShareAmount ?? transaction.amount)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildMiniStat(context, 'Friends\' Share', CurrencyFormatter.format(transaction.friendsShare)),
                          const SizedBox(width: 12),
                          _buildMiniStat(context, 'Collected', CurrencyFormatter.format(transaction.reimbursedAmount)),
                        ],
                      ),
                      if (transaction.sharedWith != null && transaction.sharedWith!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Shared with: ${transaction.sharedWith}',
                          style: TextStyle(fontSize: 12, color: financialColors.textMuted, fontWeight: FontWeight.w600),
                        ),
                      ],
                      if (!transaction.isSettled && transaction.pendingReimbursement > 0) ...[
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primaryEmerald,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.handshake_rounded, size: 18),
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Record Reimbursement (${CurrencyFormatter.format(transaction.pendingReimbursement)} pending)',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                              ),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              PendingSharedExpensesSheet.show(
                                context,
                                preselectedTransaction: transaction,
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              // Notes Card (if present)
              if (transaction.notes != null && transaction.notes!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceVariant.withAlpha(120) : AppColors.lightSurfaceVariant.withAlpha(120),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: financialColors.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NOTES',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: financialColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        transaction.notes!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    final financialColors = context.financialColors;

    return Row(
      children: [
        Icon(icon, size: 18, color: financialColors.textMuted),
        const SizedBox(width: 12),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: financialColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStat(BuildContext context, String label, String value) {
    final financialColors = context.financialColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: financialColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
