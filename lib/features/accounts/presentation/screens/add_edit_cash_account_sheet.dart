import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/entities/bank_account_entity.dart';
import '../../../../core/utilities/currency_formatter.dart';
import '../state/accounts_cards_provider.dart';

class AddEditCashAccountSheet extends ConsumerStatefulWidget {
  final BankAccountEntity? initialAccount;

  const AddEditCashAccountSheet({super.key, this.initialAccount});

  static Future<bool?> show(
    BuildContext context, {
    BankAccountEntity? account,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddEditCashAccountSheet(initialAccount: account),
    );
  }

  @override
  ConsumerState<AddEditCashAccountSheet> createState() =>
      _AddEditCashAccountSheetState();
}

class _AddEditCashAccountSheetState
    extends ConsumerState<AddEditCashAccountSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _balanceController;
  late String _selectedTag;
  bool _isSaving = false;

  bool get _isEditMode => widget.initialAccount != null;

  static const List<String> _cashTags = [
    AccountPurposeTags.dailySpending,
    'Petty Cash',
    AccountPurposeTags.emergencyFund,
    'Travel Cash',
    AccountPurposeTags.miscellaneous,
  ];

  @override
  void initState() {
    super.initState();
    final acc = widget.initialAccount;
    _nameController = TextEditingController(
      text: acc?.accountName ?? 'Cash in Hand',
    );
    _balanceController = TextEditingController(
      text: acc != null ? acc.currentBalance.toStringAsFixed(2) : '0.00',
    );
    _selectedTag = acc?.usedFor ?? AccountPurposeTags.dailySpending;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  void _addAmount(double addition) {
    HapticFeedback.selectionClick();
    final current = double.tryParse(_balanceController.text.trim()) ?? 0.0;
    final next = (current + addition).clamp(-99999999.0, 99999999.0);
    setState(() {
      _balanceController.text = next.toStringAsFixed(2);
    });
  }

  void _clearAmount() {
    HapticFeedback.selectionClick();
    setState(() {
      _balanceController.text = '0.00';
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final balance = double.tryParse(_balanceController.text.trim()) ?? 0.0;
    final name = _nameController.text.trim().isEmpty
        ? 'Cash in Hand'
        : _nameController.text.trim();
    final now = DateTime.now();

    setState(() => _isSaving = true);

    try {
      if (_isEditMode) {
        final updated = widget.initialAccount!.copyWith(
          accountName: name,
          bankName: 'Physical Cash',
          accountType: AccountType.cash,
          usedFor: _selectedTag,
          currentBalance: balance,
          updatedAt: now,
        );

        await ref.read(bankAccountListProvider.notifier).saveAccount(updated);
      } else {
        final newAccount = BankAccountEntity(
          id: const Uuid().v4(),
          accountName: name,
          bankName: 'Physical Cash',
          accountType: AccountType.cash,
          usedFor: _selectedTag,
          initialBalance: balance,
          currentBalance: balance,
          isDefault: false,
          isArchived: false,
          createdAt: now,
          updatedAt: now,
        );

        await ref.read(bankAccountListProvider.notifier).saveAccount(newAccount);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditMode
                  ? 'Updated "$name" balance to ${CurrencyFormatter.format(balance)}'
                  : 'Added "$name" with ${CurrencyFormatter.format(balance)}',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save cash wallet: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _deleteAccount() async {
    final acc = widget.initialAccount;
    if (acc == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Cash Wallet?'),
        content: Text(
          'Are you sure you want to delete "${acc.accountName}"? Historical transactions will remain preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await ref.read(bankAccountListProvider.notifier).deleteAccount(acc.id);
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted "${acc.accountName}"'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete cash wallet: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final financialColors = context.financialColors;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: financialColors.textMuted.withAlpha(60),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  // Header Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primaryEmerald.withAlpha(
                                  isDark ? 45 : 25,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.payments_rounded,
                                color: AppColors.primaryEmerald,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isEditMode
                                        ? 'Adjust Cash Balance'
                                        : 'Add Cash Wallet',
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Physical notes & coins in hand',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: financialColors.textMuted,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
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
                  const SizedBox(height: 22),

                  // Cash Balance Amount Field
                  Text(
                    'PHYSICAL CASH IN HAND',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: financialColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _balanceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^-?\d*\.?\d{0,2}'),
                      ),
                    ],
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryEmerald,
                    ),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(
                        Icons.currency_rupee_rounded,
                        size: 22,
                        color: AppColors.primaryEmerald,
                      ),
                      hintText: '0.00',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        tooltip: 'Clear',
                        onPressed: _clearAmount,
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter a valid amount';
                      }
                      if (double.tryParse(val.trim()) == null) {
                        return 'Enter a valid number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Quick Increment Cash Chips
                  Text(
                    'COUNT NOTES & COINS QUICKLY',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: financialColors.textMuted,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildQuickChip('+₹100', () => _addAmount(100)),
                      _buildQuickChip('+₹200', () => _addAmount(200)),
                      _buildQuickChip('+₹500', () => _addAmount(500)),
                      _buildQuickChip('+₹1,000', () => _addAmount(1000)),
                      _buildQuickChip('+₹2,000', () => _addAmount(2000)),
                      ActionChip(
                        avatar: const Icon(Icons.refresh_rounded, size: 14),
                        label: const Text('Reset ₹0'),
                        onPressed: _clearAmount,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Wallet Name
                  Text(
                    'WALLET / STASH NAME',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: financialColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Cash in Hand, Pocket Wallet, Home Cash',
                      prefixIcon: Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 20,
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please give this wallet a name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Purpose Tag
                  Text(
                    'PURPOSE TAG',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: financialColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _cashTags.map((tag) {
                      final isSelected = _selectedTag == tag;
                      return ChoiceChip(
                        label: Text(tag),
                        selected: isSelected,
                        selectedColor: AppColors.primaryEmerald,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : (isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary),
                        ),
                        onSelected: (val) {
                          if (val) {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedTag = tag);
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 28),

                  // Action Buttons
                  Row(
                    children: [
                      if (_isEditMode) ...[
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _isSaving ? null : _deleteAccount,
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primaryEmerald,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.check_rounded, size: 20),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _isSaving
                                  ? 'Saving...'
                                  : (_isEditMode
                                      ? 'Update Cash Balance'
                                      : 'Save Cash Wallet'),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          onPressed: _isSaving ? null : _save,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickChip(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label),
      avatar: const Icon(
        Icons.add_rounded,
        size: 14,
        color: AppColors.primaryEmerald,
      ),
      onPressed: onTap,
    );
  }
}

