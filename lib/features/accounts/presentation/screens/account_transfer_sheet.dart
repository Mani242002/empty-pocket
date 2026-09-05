import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/entities/bank_account_entity.dart';
import '../../../../core/utilities/currency_formatter.dart';
import '../state/accounts_cards_provider.dart';

class AccountTransferSheet extends ConsumerStatefulWidget {
  final BankAccountEntity? initialFromAccount;
  final BankAccountEntity? initialToAccount;

  const AccountTransferSheet({
    super.key,
    this.initialFromAccount,
    this.initialToAccount,
  });

  static Future<void> show(
    BuildContext context, {
    BankAccountEntity? fromAccount,
    BankAccountEntity? toAccount,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AccountTransferSheet(
        initialFromAccount: fromAccount,
        initialToAccount: toAccount,
      ),
    );
  }

  @override
  ConsumerState<AccountTransferSheet> createState() =>
      _AccountTransferSheetState();
}

class _AccountTransferSheetState extends ConsumerState<AccountTransferSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _amountController;
  late TextEditingController _notesController;
  late DateTime _selectedDate;

  String? _fromAccountId;
  String? _toAccountId;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _notesController = TextEditingController();
    _selectedDate = DateTime.now();

    _fromAccountId = widget.initialFromAccount?.id;
    _toAccountId = widget.initialToAccount?.id;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDate),
      );

      setState(() {
        _selectedDate = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime?.hour ?? _selectedDate.hour,
          pickedTime?.minute ?? _selectedDate.minute,
        );
      });
    }
  }

  Future<void> _submitTransfer() async {
    if (!_formKey.currentState!.validate()) return;

    final accounts = ref.read(activeBankAccountsProvider);
    if (_fromAccountId == null || _toAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both source and destination accounts.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_fromAccountId == _toAccountId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Source and destination accounts must be different.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final fromAccount = accounts.firstWhere((a) => a.id == _fromAccountId);
    final toAccount = accounts.firstWhere((a) => a.id == _toAccountId);
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid transfer amount.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Balance check warning
    if (fromAccount.currentBalance < amount) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Insufficient Balance Warning'),
          content: Text(
            'Transfer amount (${CurrencyFormatter.format(amount)}) exceeds available balance (${CurrencyFormatter.format(fromAccount.currentBalance)}) in "${fromAccount.accountName}". Proceed anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Proceed'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    await ref.read(accountOperationsProvider).performTransfer(
          fromAccount: fromAccount,
          toAccount: toAccount,
          amount: amount,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          date: _selectedDate,
        );

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Transferred ${CurrencyFormatter.format(amount)} from "${fromAccount.accountName}" to "${toAccount.accountName}".',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final financialColors = context.financialColors;
    final isDark = theme.brightness == Brightness.dark;

    final accounts = ref.watch(activeBankAccountsProvider);

    // Default source / dest if not set
    if (_fromAccountId == null && accounts.isNotEmpty) {
      _fromAccountId = accounts.first.id;
    }
    if (_toAccountId == null && accounts.length > 1) {
      _toAccountId = accounts[1].id;
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
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
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
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.swap_horiz_rounded,
                          color: AppColors.primaryEmerald,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Account Transfer',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (accounts.length < 2) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: financialColors.expense.withAlpha(20),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: financialColors.expense.withAlpha(60)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: financialColors.expense, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'You need at least 2 bank accounts to perform internal fund transfers.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: financialColors.expense,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Transfer Direction Cards (From -> To)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: financialColors.cardBorder),
                    ),
                    child: Column(
                      children: [
                        // FROM ACCOUNT
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: financialColors.expense.withAlpha(isDark ? 40 : 25),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.arrow_upward_rounded, color: financialColors.expense, size: 16),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'FROM (SOURCE)',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: financialColors.textMuted,
                                    ),
                                  ),
                                  DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _fromAccountId,
                                      isExpanded: true,
                                      isDense: true,
                                      items: accounts.map((acc) {
                                        return DropdownMenuItem(
                                          value: acc.id,
                                          child: Text(
                                            '${acc.accountName} (${CurrencyFormatter.format(acc.currentBalance)})',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (val) => setState(() => _fromAccountId = val),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        // TO ACCOUNT
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: financialColors.income.withAlpha(isDark ? 40 : 25),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.arrow_downward_rounded, color: financialColors.income, size: 16),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'TO (DESTINATION)',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: financialColors.textMuted,
                                    ),
                                  ),
                                  DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _toAccountId,
                                      isExpanded: true,
                                      isDense: true,
                                      items: accounts.map((acc) {
                                        return DropdownMenuItem(
                                          value: acc.id,
                                          child: Text(
                                            '${acc.accountName} [${acc.usedFor}] (${CurrencyFormatter.format(acc.currentBalance)})',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (val) => setState(() => _toAccountId = val),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Amount
                  Text(
                    'TRANSFER AMOUNT',
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
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryEmerald,
                    ),
                    decoration: InputDecoration(
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 16, right: 8),
                        child: Text(
                          '₹',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryEmerald,
                          ),
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                      hintText: '0.00',
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Enter transfer amount';
                      if ((double.tryParse(val) ?? 0) <= 0) return 'Invalid amount';
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),

                  // Quick amount adders
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [500, 1000, 2000, 5000, 10000].map((add) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            label: Text('+₹$add'),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                            onPressed: () {
                              final curr = double.tryParse(_amountController.text) ?? 0;
                              final next = curr + add;
                              _amountController.text = next.toStringAsFixed(0);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Date Picker
                  Text(
                    'TRANSFER DATE',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: financialColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
                              DateFormat('EEEE, dd MMM yyyy, h:mm a').format(_selectedDate),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Notes / Purpose Remarks
                  Text(
                    'NOTES / REASON (OPTIONAL)',
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
                      hintText: 'e.g. Monthly emergency savings allocation, bills allowance',
                      prefixIcon: Icon(Icons.edit_note_rounded, size: 20),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Transfer Button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryEmerald,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: const Icon(Icons.swap_horiz_rounded, size: 20),
                      label: const Text(
                        'Transfer Funds',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      onPressed: accounts.length >= 2 ? _submitTransfer : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
