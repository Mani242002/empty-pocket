import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/entities/category_constants.dart';
import '../../../../core/domain/entities/transaction_entity.dart';
import '../../../../core/utilities/app_haptics.dart';
import '../../../../core/utilities/currency_formatter.dart';
import '../../../../core/utilities/loan_share_helper.dart';
import '../../../../core/utilities/split_helper.dart';
import '../../../accounts/presentation/state/accounts_cards_provider.dart';
import '../../../transactions/presentation/screens/pending_shared_expenses_sheet.dart';
import '../../../transactions/presentation/screens/transaction_detail_sheet.dart';
import '../../../transactions/presentation/state/transactions_provider.dart';

class SharedSplitsTab extends ConsumerStatefulWidget {
  const SharedSplitsTab({super.key});

  @override
  ConsumerState<SharedSplitsTab> createState() => _SharedSplitsTabState();
}

class _SharedSplitsTabState extends ConsumerState<SharedSplitsTab> {
  bool _showPendingOnlySplits = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final financialColors = context.financialColors;
    final isDark = theme.brightness == Brightness.dark;

    final allSplits = ref.watch(allSharedExpensesProvider);
    final pendingSplits = ref.watch(pendingSharedExpensesProvider);
    final pendingTotal = ref.watch(pendingReimbursementsTotalProvider);
    final ccReserve = ref.watch(creditCardEarmarkedReserveProvider);
    final pendingByPerson = ref.watch(pendingByPersonSummaryProvider);

    final displayedSplits = _showPendingOnlySplits ? pendingSplits : allSplits;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
      children: [
        // Hero Card: Total Pending & CC Reserve Earmark
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                  : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFBFDBFE),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 50 : 15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryEmerald.withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.group_work_rounded,
                      size: 20,
                      color: AppColors.primaryEmerald,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Roommate & Shared Ledger',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (pendingSplits.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: financialColors.warning.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: financialColors.warning.withAlpha(60)),
                      ),
                      child: Text(
                        '${pendingSplits.length} Pending',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: financialColors.warning,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'TOTAL PENDING REIMBURSEMENT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: financialColors.textMuted,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  CurrencyFormatter.format(pendingTotal),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: pendingTotal > 0 ? financialColors.warning : financialColors.income,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Credit Card Reserve Note
              if (ccReserve > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: financialColors.warning.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: financialColors.warning.withAlpha(50)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.credit_card_rounded, size: 16, color: financialColors.warning),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${CurrencyFormatter.format(ccReserve)} is charged on Credit Cards. Keep incoming paybacks reserved for your CC bill.',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Action Buttons: Settle All & Settle by Bill
              if (pendingSplits.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryEmerald,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _showSettleAllDialog(context),
                        icon: const Icon(Icons.done_all_rounded, size: 17),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Settle All',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: BorderSide(
                            color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                          ),
                        ),
                        onPressed: () => PendingSharedExpensesSheet.show(context),
                        icon: const Icon(Icons.receipt_long_rounded, size: 17),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Settle by Bill',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        // Pending by Roommate / Friend Section
        if (pendingByPerson.isNotEmpty) ...[
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PENDING BY ROOMMATE / FRIEND',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: financialColors.textMuted,
                ),
              ),
              Text(
                '${pendingByPerson.length} ${pendingByPerson.length == 1 ? 'person' : 'people'}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: financialColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: pendingByPerson.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final summary = pendingByPerson[index];
                return _buildPersonSummaryCard(context, summary, isDark, financialColors);
              },
            ),
          ),
        ],

        const SizedBox(height: 16),

        // Filter Tabs (Pending vs All)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              FilterChip(
                label: Text('Pending (${pendingSplits.length})'),
                selected: _showPendingOnlySplits,
                onSelected: (val) => setState(() => _showPendingOnlySplits = true),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: Text('All Splits (${allSplits.length})'),
                selected: !_showPendingOnlySplits,
                onSelected: (val) => setState(() => _showPendingOnlySplits = false),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        if (displayedSplits.isEmpty)
          _buildEmptySplitsCard(context, isDark, financialColors)
        else
          ...displayedSplits.map((tx) => _buildSplitItemCard(context, tx, isDark, financialColors)),
      ],
    );
  }

  Widget _buildSplitItemCard(
    BuildContext context,
    TransactionEntity tx,
    bool isDark,
    AppFinancialColors financialColors,
  ) {
    final theme = Theme.of(context);
    final myShare = tx.myShareAmount ?? (tx.amount / 2);
    final friendsShare = tx.friendsShare;
    final isSettled = tx.isSettled;
    final parsedShares = SplitHelper.parseShares(tx.sharedWith);
    final loan = LoanShareHelper.parseLoan(tx.sharedWith);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSettled
              ? financialColors.cardBorder
              : financialColors.warning.withAlpha(80),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => TransactionDetailSheet.show(context, transaction: tx),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Title, Category, Status Badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (isSettled ? financialColors.income : financialColors.warning).withAlpha(30),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isSettled ? Icons.check_circle_outline_rounded : Icons.pending_actions_rounded,
                        size: 20,
                        color: isSettled ? financialColors.income : financialColors.warning,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tx.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${DateFormat('dd MMM yyyy').format(tx.date)} • ${tx.paymentSource}',
                            style: TextStyle(fontSize: 11, color: financialColors.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isSettled ? financialColors.income : financialColors.warning).withAlpha(25),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: (isSettled ? financialColors.income : financialColors.warning).withAlpha(60),
                          ),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            isSettled
                                ? 'Settled'
                                : '${CurrencyFormatter.format(tx.pendingReimbursement)} Pending',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isSettled ? financialColors.income : financialColors.warning,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (loan != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryEmerald.withAlpha(isDark ? 30 : 20),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.primaryEmerald.withAlpha(isDark ? 80 : 50),
                      ),
                    ),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              const WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Padding(
                                  padding: EdgeInsets.only(right: 5),
                                  child: Icon(Icons.handshake_rounded, size: 15, color: AppColors.primaryEmerald),
                                ),
                              ),
                              TextSpan(
                                text: 'Lent to ${loan.borrowerName}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryEmerald,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (loan.expectedInterest > 0)
                          Text(
                            '(+${CurrencyFormatter.format(loan.expectedInterest)} interest)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                        if (loan.expectedReturnDate != null)
                          Text(
                            '• Due ${DateFormat('dd MMM').format(loan.expectedReturnDate!)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: financialColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ] else if (parsedShares.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: parsedShares.map((share) {
                      final personSettled = share.isSettled;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (personSettled ? financialColors.income : financialColors.warning).withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (personSettled ? financialColors.income : financialColors.warning).withAlpha(50),
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
                                color: personSettled ? financialColors.income : financialColors.warning,
                              ),
                            ),
                            if (personSettled) ...[
                              const SizedBox(width: 3),
                              Icon(Icons.check, size: 12, color: financialColors.income),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ] else if (tx.sharedWith != null &&
                    tx.sharedWith!.isNotEmpty &&
                    !tx.sharedWith!.trim().startsWith('{') &&
                    !tx.sharedWith!.trim().startsWith('[')) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.person_outline_rounded, size: 14, color: financialColors.textMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Shared with: ${tx.sharedWith}',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: financialColors.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                const Divider(height: 20),
                // Breakdown numbers
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Bill',
                            style: TextStyle(fontSize: 10.5, color: financialColors.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              CurrencyFormatter.format(tx.amount),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Share',
                            style: TextStyle(fontSize: 10.5, color: financialColors.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              CurrencyFormatter.format(myShare),
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: financialColors.expense),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Friends Share',
                            style: TextStyle(fontSize: 10.5, color: financialColors.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              CurrencyFormatter.format(friendsShare),
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: financialColors.income),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (!isSettled) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.handshake_rounded, size: 16),
                      onPressed: () => PendingSharedExpensesSheet.show(context, preselectedTransaction: tx),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Record Payback (${CurrencyFormatter.format(tx.pendingReimbursement)})',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptySplitsCard(
    BuildContext context,
    bool isDark,
    AppFinancialColors financialColors,
  ) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: financialColors.cardBorder),
      ),
      child: Column(
        children: [
          Icon(Icons.group_outlined, size: 48, color: financialColors.textMuted),
          const SizedBox(height: 12),
          const Text(
            'No Shared Expenses Found',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'When you pay for roommates or group outings, toggle "Split / Shared with Others" when adding an expense to track paybacks here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: financialColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonSummaryCard(
    BuildContext context,
    PersonPendingSummary summary,
    bool isDark,
    AppFinancialColors financialColors,
  ) {
    return Container(
      width: 165,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: financialColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 30 : 10),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.primaryEmerald.withAlpha(35),
                child: Text(
                  summary.personName.isNotEmpty ? summary.personName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryEmerald,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  summary.personName,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  CurrencyFormatter.format(summary.totalPending),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: financialColors.warning,
                  ),
                ),
              ),
              Text(
                '${summary.expenseCount} ${summary.expenseCount == 1 ? 'bill' : 'bills'} pending',
                style: TextStyle(fontSize: 10.5, color: financialColors.textMuted),
              ),
            ],
          ),
          SizedBox(
            width: double.infinity,
            height: 28,
            child: FilledButton.tonal(
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => _showSettlePersonDialog(context, summary.personName, summary.totalPending),
              child: const Text(
                'Settle',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSettleAllDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => const _SettleAllBottomSheet(),
    );
  }

  void _showSettlePersonDialog(BuildContext context, String personName, double totalPending) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _SettlePersonBottomSheet(
        personName: personName,
        totalPending: totalPending,
      ),
    );
  }
}

class _SettleAllBottomSheet extends ConsumerStatefulWidget {
  const _SettleAllBottomSheet();

  @override
  ConsumerState<_SettleAllBottomSheet> createState() => _SettleAllBottomSheetState();
}

class _SettleAllBottomSheetState extends ConsumerState<_SettleAllBottomSheet> {
  String? _selectedAccountId;
  final _notesController = TextEditingController(text: 'Bulk settlement of all pending reimbursements');
  bool _isSaving = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a destination account.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(transactionListNotifierProvider.notifier).settleAllPendingSharedExpenses(
            destinationAccountId: _selectedAccountId!,
            notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          );

      AppHaptics.success();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All pending reimbursements have been successfully settled!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to settle: $e'), backgroundColor: AppColors.expense),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final financialColors = context.financialColors;
    final bankAccounts = ref.watch(activeBankAccountsProvider);
    final pendingSplits = ref.watch(pendingSharedExpensesProvider);
    final pendingTotal = ref.watch(pendingReimbursementsTotalProvider);

    if (_selectedAccountId == null && bankAccounts.isNotEmpty) {
      final defaultAcc = bankAccounts.where((a) => a.isDefault);
      _selectedAccountId = defaultAcc.isNotEmpty ? defaultAcc.first.id : bankAccounts.first.id;
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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
                child: const Icon(Icons.done_all_rounded, color: AppColors.primaryEmerald, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Settle All Reimbursements',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Clear all pending roommate shares at once',
                      style: theme.textTheme.bodySmall?.copyWith(color: financialColors.textMuted),
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
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: financialColors.cardBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TOTAL COLLECTED', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: financialColors.textMuted)),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          CurrencyFormatter.format(pendingTotal),
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: financialColors.income),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: financialColors.income.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${pendingSplits.length} Bills',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: financialColors.income),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'DEPOSIT INTO ACCOUNT',
            style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.1, color: financialColors.textMuted),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _selectedAccountId,
            isExpanded: true,
            isDense: true,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.account_balance_rounded)),
            items: bankAccounts.map((acc) {
              return DropdownMenuItem(
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
          Text(
            'NOTES (OPTIONAL)',
            style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.1, color: financialColors.textMuted),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _notesController,
            decoration: const InputDecoration(hintText: 'e.g. Cleared all shared expenses for this month'),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryEmerald,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _isSaving ? null : _submit,
              icon: _isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_rounded, size: 20),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _isSaving ? 'Settling All...' : 'Confirm Settlement (${CurrencyFormatter.format(pendingTotal)})',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettlePersonBottomSheet extends ConsumerStatefulWidget {
  final String personName;
  final double totalPending;

  const _SettlePersonBottomSheet({
    required this.personName,
    required this.totalPending,
  });

  @override
  ConsumerState<_SettlePersonBottomSheet> createState() => _SettlePersonBottomSheetState();
}

class _SettlePersonBottomSheetState extends ConsumerState<_SettlePersonBottomSheet> {
  late TextEditingController _amountController;
  late TextEditingController _notesController;
  late TextEditingController _offsetController;
  bool _enableOffset = false;
  String _offsetCategory = 'Food & Dining';
  String? _selectedAccountId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final amt = widget.totalPending;
    _amountController = TextEditingController(
      text: amt == amt.roundToDouble() ? amt.toInt().toString() : amt.toStringAsFixed(2),
    );
    _offsetController = TextEditingController();
    _notesController = TextEditingController(text: 'Reimbursement from ${widget.personName}');
  }

  @override
  void dispose() {
    _amountController.dispose();
    _offsetController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid received amount.')),
      );
      return;
    }

    final offsetAmt = _enableOffset ? double.tryParse(_offsetController.text.trim()) : null;

    if (_selectedAccountId == null && amount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a destination account.')),
      );
      return;
    }

    final bankAccounts = ref.read(activeBankAccountsProvider);
    final chosenAccount = _selectedAccountId ?? (bankAccounts.isNotEmpty ? bankAccounts.first.id : '');

    setState(() => _isSaving = true);
    try {
      await ref.read(transactionListNotifierProvider.notifier).settlePersonReimbursements(
            personName: widget.personName,
            destinationAccountId: chosenAccount,
            customAmount: amount,
            offsetExpenseAmount: offsetAmt,
            offsetExpenseCategory: _enableOffset ? _offsetCategory : null,
            notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          );

      AppHaptics.success();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Settled ${CurrencyFormatter.format(amount)} from ${widget.personName}!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to settle: $e'), backgroundColor: AppColors.expense),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final financialColors = context.financialColors;
    final bankAccounts = ref.watch(activeBankAccountsProvider);

    if (_selectedAccountId == null && bankAccounts.isNotEmpty) {
      final defaultAcc = bankAccounts.where((a) => a.isDefault);
      _selectedAccountId = defaultAcc.isNotEmpty ? defaultAcc.first.id : bankAccounts.first.id;
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primaryEmerald.withAlpha(35),
                  child: Text(
                    widget.personName.isNotEmpty ? widget.personName[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primaryEmerald),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Settle with ${widget.personName}',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Total owed across all bills: ${CurrencyFormatter.format(widget.totalPending)}',
                        style: theme.textTheme.bodySmall?.copyWith(color: financialColors.textMuted),
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
            const SizedBox(height: 16),

            // Offset Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _enableOffset ? AppColors.primaryEmerald.withAlpha(90) : financialColors.cardBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Deduct Share I Owed (Offset)',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: _enableOffset ? AppColors.primaryEmerald : null,
                              ),
                            ),
                            Text(
                              'Offset against an earlier expense paid by ${widget.personName}',
                              style: TextStyle(fontSize: 11, color: financialColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: _enableOffset,
                        onChanged: (val) {
                          setState(() {
                            _enableOffset = val;
                            if (!val) {
                              _offsetController.clear();
                              final amt = widget.totalPending;
                              _amountController.text = amt == amt.roundToDouble()
                                  ? amt.toInt().toString()
                                  : amt.toStringAsFixed(2);
                            }
                          });
                        },
                      ),
                    ],
                  ),
                  if (_enableOffset) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'I OWED (${CurrencyFormatter.activeCurrency.symbol})',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: financialColors.textMuted),
                              ),
                              const SizedBox(height: 4),
                              TextFormField(
                                controller: _offsetController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  hintText: 'e.g. 250',
                                  isDense: true,
                                  prefixText: '${CurrencyFormatter.activeCurrency.symbol} ',
                                ),
                                onChanged: (val) {
                                  final offset = double.tryParse(val.trim()) ?? 0.0;
                                  final net = (widget.totalPending - offset).clamp(0.0, double.infinity);
                                  _amountController.text = net == net.roundToDouble()
                                      ? net.toInt().toString()
                                      : net.toStringAsFixed(2);
                                  setState(() {});
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'EXPENSE CATEGORY',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: financialColors.textMuted),
                              ),
                              const SizedBox(height: 4),
                              DropdownButtonFormField<String>(
                                initialValue: _offsetCategory,
                                isExpanded: true,
                                isDense: true,
                                decoration: const InputDecoration(isDense: true),
                                items: CategoryConstants.expenseCategories.map((c) {
                                  return DropdownMenuItem(
                                    value: c.name,
                                    child: Text(
                                      c.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _offsetCategory = val);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Net Received: ${CurrencyFormatter.format(widget.totalPending)} - ${CurrencyFormatter.format(double.tryParse(_offsetController.text.trim()) ?? 0.0)} = ${CurrencyFormatter.activeCurrency.symbol}${_amountController.text}',
                      style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: financialColors.textMuted),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'NET AMOUNT RECEIVED',
              style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.1, color: financialColors.textMuted),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: financialColors.income),
              decoration: InputDecoration(prefixText: '${CurrencyFormatter.activeCurrency.symbol} '),
            ),
            const SizedBox(height: 16),
            Text(
              'DEPOSIT INTO ACCOUNT',
              style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.1, color: financialColors.textMuted),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedAccountId,
              isExpanded: true,
              isDense: true,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.account_balance_rounded)),
              items: bankAccounts.map((acc) {
                return DropdownMenuItem(
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
            Text(
              'NOTES (OPTIONAL)',
              style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.1, color: financialColors.textMuted),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(hintText: 'e.g. Paid back via UPI'),
            ),
            const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryEmerald,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _isSaving ? null : _submit,
              icon: _isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_rounded, size: 20),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _isSaving ? 'Settling...' : 'Confirm Settle with ${widget.personName}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
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
