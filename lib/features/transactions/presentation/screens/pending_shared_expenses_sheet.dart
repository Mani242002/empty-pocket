import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/entities/credit_card_entity.dart';
import '../../../../core/domain/entities/transaction_entity.dart';
import '../../../../core/utilities/app_haptics.dart';
import '../../../../core/utilities/currency_formatter.dart';
import '../../../accounts/presentation/state/accounts_cards_provider.dart';
import '../state/transactions_provider.dart';

/// Modal bottom sheet to settle pending shared expenses from roommates/friends
class PendingSharedExpensesSheet extends ConsumerStatefulWidget {
  final TransactionEntity? preselectedTransaction;

  const PendingSharedExpensesSheet({super.key, this.preselectedTransaction});

  static Future<void> show(
    BuildContext context, {
    TransactionEntity? preselectedTransaction,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PendingSharedExpensesSheet(
        preselectedTransaction: preselectedTransaction,
      ),
    );
  }

  @override
  ConsumerState<PendingSharedExpensesSheet> createState() =>
      _PendingSharedExpensesSheetState();
}

class _PendingSharedExpensesSheetState
    extends ConsumerState<PendingSharedExpensesSheet> {
  late TextEditingController _amountController;
  late TextEditingController _notesController;
  TransactionEntity? _selectedTransaction;
  String? _selectedAccountId;
  bool _isSaving = false;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _selectedTransaction = widget.preselectedTransaction;
    final initialAmt = _selectedTransaction?.pendingReimbursement ?? 0.0;
    _amountController = TextEditingController(
      text: initialAmt > 0
          ? (initialAmt == initialAmt.roundToDouble()
              ? initialAmt.toInt().toString()
              : initialAmt.toStringAsFixed(2))
          : '',
    );
    _notesController = TextEditingController(
      text: _selectedTransaction != null
          ? 'Share payback for "${_selectedTransaction!.title}"'
          : '',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitSettlement() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTransaction == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a shared expense to settle.')),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid received amount.')),
      );
      return;
    }

    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select the receiving bank account.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(transactionListNotifierProvider.notifier).settleSharedExpense(
            transactionId: _selectedTransaction!.id,
            amountReceived: amount,
            destinationAccountId: _selectedAccountId!,
            notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          );

      AppHaptics.success();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Recorded ${CurrencyFormatter.format(amount)} reimbursement for "${_selectedTransaction!.title}".',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to record settlement: $e'), backgroundColor: AppColors.expense),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final financialColors = context.financialColors;
    final isDark = theme.brightness == Brightness.dark;

    final pendingList = ref.watch(pendingSharedExpensesProvider);
    final bankAccounts = ref.watch(activeBankAccountsProvider);
    final creditCards = ref.watch(activeCreditCardsProvider);

    // Default select first bank account if none selected
    if (_selectedAccountId == null && bankAccounts.isNotEmpty) {
      final defaultAcc = bankAccounts.where((a) => a.isDefault);
      _selectedAccountId = defaultAcc.isNotEmpty ? defaultAcc.first.id : bankAccounts.first.id;
    }

    // Default select first pending shared transaction if none preselected
    if (_selectedTransaction == null && pendingList.isNotEmpty) {
      _selectedTransaction = pendingList.first;
      final pendingAmt = _selectedTransaction!.pendingReimbursement;
      _amountController.text = pendingAmt == pendingAmt.roundToDouble()
          ? pendingAmt.toInt().toString()
          : pendingAmt.toStringAsFixed(2);
      _notesController.text = 'Share payback for "${_selectedTransaction!.title}"';
    }

    CreditCardEntity? linkedCard;
    if (_selectedTransaction?.creditCardId != null) {
      final matches = creditCards.where((c) => c.id == _selectedTransaction!.creditCardId);
      if (matches.isNotEmpty) linkedCard = matches.first;
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
            physics: const BouncingScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Form(
              key: _formKey,
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
                  const SizedBox(height: 16),

                  // Header
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
                              'Record Reimbursement',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Money collected back from roommates / friends',
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

                  // If no pending shared expenses
                  if (pendingList.isEmpty && _selectedTransaction == null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: financialColors.cardBorder),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.check_circle_outline_rounded, size: 48, color: AppColors.primaryEmerald),
                          const SizedBox(height: 12),
                          Text(
                            'All Caught Up!',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'You have no pending shared expenses awaiting reimbursement.',
                            style: TextStyle(fontSize: 12, color: financialColors.textMuted),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Select Shared Expense Dropdown
                    Text(
                      'WHICH EXPENSE IS BEING SETTLED?',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: financialColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedTransaction?.id,
                      isExpanded: true,
                      isDense: true,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.receipt_long_rounded),
                      ),
                      items: pendingList.map((tx) {
                        return DropdownMenuItem(
                          value: tx.id,
                          child: Text(
                            '${tx.title} (${CurrencyFormatter.format(tx.pendingReimbursement)} pending)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val == null) return;
                        final matched = pendingList.firstWhere((t) => t.id == val);
                        setState(() {
                          _selectedTransaction = matched;
                          final amt = matched.pendingReimbursement;
                          _amountController.text = amt == amt.roundToDouble()
                              ? amt.toInt().toString()
                              : amt.toStringAsFixed(2);
                          _notesController.text = 'Share payback for "${matched.title}"';
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Selected Expense Breakdown Summary Card
                    if (_selectedTransaction != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: financialColors.cardBorder),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                _buildSummaryItem(context, 'Total Bill', CurrencyFormatter.format(_selectedTransaction!.amount)),
                                const SizedBox(width: 12),
                                _buildSummaryItem(context, 'Your Share', CurrencyFormatter.format(_selectedTransaction!.myShareAmount ?? _selectedTransaction!.amount)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _buildSummaryItem(context, 'Friends\' Share', CurrencyFormatter.format(_selectedTransaction!.friendsShare)),
                                const SizedBox(width: 12),
                                _buildSummaryItem(context, 'Pending', CurrencyFormatter.format(_selectedTransaction!.pendingReimbursement), isHighlight: true),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Credit Card Earmark Banner (if original expense was credit card)
                      if (linkedCard != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.info.withAlpha(isDark ? 30 : 20),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.info.withAlpha(100)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.credit_card_rounded, color: AppColors.info, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Originally paid on ${linkedCard.cardName}. Depositing this reimbursement to your bank account will earmark it to help clear your credit card balance!',
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],

                    // Amount Received Field
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
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: financialColors.income,
                      ),
                      decoration: const InputDecoration(
                        prefixText: '₹ ',
                        hintText: '1,500',
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Enter amount received';
                        final numVal = double.tryParse(val.trim());
                        if (numVal == null || numVal <= 0) return 'Enter a valid positive number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Destination Account Dropdown
                    Text(
                      'DEPOSIT INTO ACCOUNT',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: financialColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (bankAccounts.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: financialColors.cardBorder.withAlpha(60),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('No bank accounts configured. Will default to Cash/Wallet.', style: TextStyle(fontSize: 12)),
                      )
                    else
                      DropdownButtonFormField<String>(
                        initialValue: _selectedAccountId,
                        isExpanded: true,
                        isDense: true,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.account_balance_rounded),
                        ),
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
                        validator: (val) => val == null ? 'Select an account' : null,
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
                        hintText: 'e.g. Rahul sent his share via Google Pay',
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
                        onPressed: _isSaving ? null : _submitSettlement,
                        child: _isSaving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                            : const Text(
                                'Confirm Reimbursement',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                              ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(BuildContext context, String label, String value, {bool isHighlight = false}) {
    final financialColors = context.financialColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
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
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: isHighlight
                    ? AppColors.primaryEmerald
                    : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
