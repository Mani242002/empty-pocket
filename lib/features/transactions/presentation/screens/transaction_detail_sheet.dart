import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/entities/category_constants.dart';
import '../../../../core/domain/entities/transaction_entity.dart';
import '../../../../core/services/log_service.dart';
import '../../../../core/utilities/app_haptics.dart';
import '../../../../core/utilities/currency_formatter.dart';
import '../../../../core/utilities/split_helper.dart';
import '../../../../core/utilities/loan_share_helper.dart';
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
      reimbursedAmount: transaction.isShared ? 0.0 : transaction.reimbursedAmount,
      isSettled: transaction.isShared ? false : transaction.isSettled,
      sharedWith: transaction.isShared
          ? SplitHelper.resetSharesForDuplication(transaction.sharedWith)
          : transaction.sharedWith,
    );

    try {
      // Synchronize account/card balances atomically for the duplicated transaction
      await ref
          .read(transactionListNotifierProvider.notifier)
          .saveTransactionWithLedgerImpact(transaction: cloned);
      AppHaptics.success();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Duplicated "${cloned.title}" (${CurrencyFormatter.format(cloned.amount)}).'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e, st) {
      LogService.error('TransactionDetailSheet', 'Failed to duplicate transaction', e, st);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to duplicate transaction: ${e.toString()}'),
            backgroundColor: AppColors.expense,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
              try {
                await ref
                    .read(transactionListNotifierProvider.notifier)
                    .deleteTransaction(transaction.id);
                AppHaptics.deleteAction();
              } catch (e, st) {
                LogService.error('TransactionDetailSheet', 'Failed to delete transaction', e, st);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete transaction: ${e.toString()}'),
                      backgroundColor: AppColors.expense,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
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
    final parsedShares = SplitHelper.parseShares(transaction.sharedWith);

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
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: amountColor.withAlpha(isDark ? 40 : 25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        transaction.type.displayName.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: amountColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 19),
                        tooltip: 'Duplicate',
                        constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _duplicateTransaction(context, ref),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_rounded, size: 19),
                        tooltip: 'Edit Transaction',
                        constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                        padding: EdgeInsets.zero,
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
                        icon: const Icon(Icons.delete_outline_rounded, size: 19, color: AppColors.expense),
                        tooltip: 'Delete',
                        constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _confirmDelete(context, ref),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 19),
                        tooltip: 'Close',
                        constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                        padding: EdgeInsets.zero,
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
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          '$sign${CurrencyFormatter.format(transaction.amount)}',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: amountColor,
                          ),
                        ),
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

              // Shared / Loan Expense Details Card
              if (LoanShareHelper.parseLoan(transaction.sharedWith) != null) ...[
                _buildLoanDetailCard(
                  context,
                  ref,
                  theme,
                  financialColors,
                  isDark,
                  LoanShareHelper.parseLoan(transaction.sharedWith)!,
                ),
              ] else if (transaction.isShared) ...[
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
                      if (parsedShares.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'ROOMMATE SHARES',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: financialColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: parsedShares.map((share) {
                            final settled = share.isSettled;
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: (settled ? financialColors.income : financialColors.warning).withAlpha(isDark ? 35 : 20),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: (settled ? financialColors.income : financialColors.warning).withAlpha(50),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    share.personName,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    CurrencyFormatter.format(share.amount),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: settled ? financialColors.income : financialColors.warning,
                                    ),
                                  ),
                                  if (settled) ...[
                                    const SizedBox(width: 3),
                                    Icon(Icons.check, size: 12, color: financialColors.income),
                                  ],
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ] else if (transaction.sharedWith != null &&
                          transaction.sharedWith!.isNotEmpty &&
                          !transaction.sharedWith!.trim().startsWith('{') &&
                          !transaction.sharedWith!.trim().startsWith('[')) ...[
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
                              foregroundColor: Colors.white,
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
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: financialColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.right,
            maxLines: 1,
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

  Widget _buildLoanDetailCard(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    AppFinancialColors financialColors,
    bool isDark,
    LoanShareData loan,
  ) {
    final isRepaid = loan.isRepaid || transaction.isSettled;
    final isOverdue = loan.isOverdue;

    final Color statusColor;
    final String statusText;
    if (isRepaid) {
      statusColor = financialColors.income;
      statusText = 'FULLY REPAID';
    } else if (isOverdue) {
      statusColor = AppColors.expense;
      statusText = 'OVERDUE';
    } else {
      statusColor = financialColors.warning;
      statusText = 'PENDING REPAYMENT';
    }

    return Container(
      margin: const EdgeInsets.only(top: 16),
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
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.handshake_rounded, color: AppColors.primaryEmerald, size: 20),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Money Lent to ${loan.borrowerName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(isDark ? 40 : 25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMiniStat(context, 'Principal Lent', CurrencyFormatter.format(loan.principalAmount)),
              const SizedBox(width: 12),
              _buildMiniStat(
                context,
                'Expected Interest',
                loan.expectedInterest > 0
                    ? '+ ${CurrencyFormatter.format(loan.expectedInterest)}${loan.interestRate != null ? ' (${loan.interestRate}%)' : ''}'
                    : '${CurrencyFormatter.format(0)} (None)',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildMiniStat(context, 'Total Expected', CurrencyFormatter.format(loan.totalExpected)),
              const SizedBox(width: 12),
              _buildMiniStat(context, 'Repaid So Far', CurrencyFormatter.format(loan.repaidAmount)),
            ],
          ),
          if (loan.expectedReturnDate != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                _buildMiniStat(
                  context,
                  'Expected Return Date',
                  DateFormat('dd MMMM yyyy').format(loan.expectedReturnDate!),
                ),
                const SizedBox(width: 12),
                _buildMiniStat(
                  context,
                  'Pending Return',
                  CurrencyFormatter.format(loan.pendingAmount),
                ),
              ],
            ),
          ],
          if (!isRepaid && loan.pendingAmount > 0) ...[
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
                icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Record Repayment (${CurrencyFormatter.format(loan.pendingAmount)} pending)',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
                onPressed: () {
                  _showRecordRepaymentModal(context, ref, transaction, loan);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showRecordRepaymentModal(
    BuildContext context,
    WidgetRef ref,
    TransactionEntity tx,
    LoanShareData loan,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RecordLoanRepaymentSheet(
        parentDetailContext: context,
        transaction: tx,
        loan: loan,
      ),
    );
  }
}

class _RecordLoanRepaymentSheet extends ConsumerStatefulWidget {
  final BuildContext parentDetailContext;
  final TransactionEntity transaction;
  final LoanShareData loan;

  const _RecordLoanRepaymentSheet({
    required this.parentDetailContext,
    required this.transaction,
    required this.loan,
  });

  @override
  ConsumerState<_RecordLoanRepaymentSheet> createState() => _RecordLoanRepaymentSheetState();
}

class _RecordLoanRepaymentSheetState extends ConsumerState<_RecordLoanRepaymentSheet> {
  late TextEditingController _amountController;
  late TextEditingController _notesController;
  String? _selectedAccountId;
  late DateTime _selectedDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final pending = widget.loan.pendingAmount;
    _amountController = TextEditingController(
      text: pending == pending.roundToDouble()
          ? pending.toInt().toString()
          : pending.toStringAsFixed(2),
    );
    _notesController = TextEditingController(
      text: 'Loan repayment received from ${widget.loan.borrowerName}',
    );
    _selectedDate = DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitRepayment() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      AppHaptics.warning();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid repayment amount.')),
      );
      return;
    }

    if (_selectedAccountId == null) {
      AppHaptics.warning();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select receiving bank account.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(transactionListNotifierProvider.notifier).recordLoanRepayment(
            originalTransactionId: widget.transaction.id,
            amountRepaid: amount,
            destinationAccountId: _selectedAccountId!,
            repaymentDate: _selectedDate,
            notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
          );

      AppHaptics.success();
      if (mounted) {
        Navigator.pop(context); // Close repayment sheet
        if (widget.parentDetailContext.mounted) {
          Navigator.pop(widget.parentDetailContext); // Close transaction detail
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recorded repayment of ${CurrencyFormatter.format(amount)} from ${widget.loan.borrowerName}!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to record repayment: $e'), backgroundColor: AppColors.expense),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final financialColors = context.financialColors;
    final isDark = theme.brightness == Brightness.dark;
    final bankAccounts = ref.watch(activeBankAccountsProvider);

    if (_selectedAccountId == null && bankAccounts.isNotEmpty) {
      final def = bankAccounts.where((a) => a.isDefault).firstOrNull;
      _selectedAccountId = def?.id ?? bankAccounts.first.id;
    }

    return Material(
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
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
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryEmerald.withAlpha(isDark ? 40 : 25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.handshake_rounded, color: AppColors.primaryEmerald, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Record Loan Repayment',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Received from ${widget.loan.borrowerName}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: financialColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Amount Repaid
                Text(
                  'AMOUNT RECEIVED',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: financialColors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryEmerald,
                  ),
                  decoration: InputDecoration(
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 16, right: 8),
                      child: Text(
                        CurrencyFormatter.activeCurrency.symbol,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryEmerald,
                        ),
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                  ),
                ),
                const SizedBox(height: 16),

                // Receiving Account
                Text(
                  'DEPOSIT TO (BANK ACCOUNT / CASH)',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: financialColors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedAccountId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.account_balance_rounded, size: 20),
                  ),
                  items: bankAccounts.map((acc) {
                    return DropdownMenuItem<String>(
                      value: acc.id,
                      child: Text(
                        '${acc.accountName} (${CurrencyFormatter.format(acc.currentBalance)})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedAccountId = val);
                  },
                ),
                const SizedBox(height: 16),

                // Date Picker
                Text(
                  'DATE RECEIVED',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: financialColors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2040),
                    );
                    if (picked != null) {
                      setState(() => _selectedDate = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: financialColors.cardBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            DateFormat('dd MMMM yyyy').format(_selectedDate),
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Notes
                Text(
                  'NOTES (OPTIONAL)',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: financialColors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Received full amount via GPay',
                  ),
                ),
                const SizedBox(height: 24),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryEmerald,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _isSaving ? null : _submitRepayment,
                    child: _isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : const Text('Confirm Repayment', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
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
