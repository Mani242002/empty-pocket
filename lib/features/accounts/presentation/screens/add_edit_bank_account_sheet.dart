import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/entities/bank_account_entity.dart';
import '../../../../core/utilities/currency_formatter.dart';
import '../state/accounts_cards_provider.dart';

class AddEditBankAccountSheet extends ConsumerStatefulWidget {
  final BankAccountEntity? initialAccount;

  const AddEditBankAccountSheet({super.key, this.initialAccount});

  static Future<void> show(BuildContext context, {BankAccountEntity? account}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddEditBankAccountSheet(initialAccount: account),
    );
  }

  @override
  ConsumerState<AddEditBankAccountSheet> createState() =>
      _AddEditBankAccountSheetState();
}

class _AddEditBankAccountSheetState
    extends ConsumerState<AddEditBankAccountSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _bankController;
  late TextEditingController _balanceController;
  late TextEditingController _customTagController;

  late AccountType _selectedType;
  late String _selectedUsedForTag;
  bool _isDefault = false;
  bool _isCustomTag = false;

  bool get _isEditMode => widget.initialAccount != null;

  final List<String> _presetTags = AccountPurposeTags.defaultTags;

  @override
  void initState() {
    super.initState();
    final acc = widget.initialAccount;

    _nameController = TextEditingController(text: acc?.accountName ?? '');
    _bankController = TextEditingController(text: acc?.bankName ?? '');
    _balanceController = TextEditingController(
      text: acc != null
          ? (acc.currentBalance == acc.currentBalance.roundToDouble()
              ? acc.currentBalance.toInt().toString()
              : acc.currentBalance.toString())
          : '',
    );
    _selectedType = acc?.accountType ?? AccountType.savings;

    final initialTag = acc?.usedFor ?? _presetTags.first;
    if (_presetTags.contains(initialTag)) {
      _selectedUsedForTag = initialTag;
      _isCustomTag = false;
      _customTagController = TextEditingController();
    } else {
      _selectedUsedForTag = initialTag;
      _isCustomTag = true;
      _customTagController = TextEditingController(text: initialTag);
    }

    _isDefault = acc?.isDefault ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bankController.dispose();
    _balanceController.dispose();
    _customTagController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final balance = double.tryParse(_balanceController.text.trim()) ?? 0.0;
    final accountName = _nameController.text.trim();
    final bankName = _bankController.text.trim().isEmpty
        ? (_selectedType == AccountType.cash ? 'Cash' : 'Bank Account')
        : _bankController.text.trim();

    final usedFor = _isCustomTag && _customTagController.text.trim().isNotEmpty
        ? _customTagController.text.trim()
        : _selectedUsedForTag;

    final now = DateTime.now();

    if (_isEditMode) {
      final updated = widget.initialAccount!.copyWith(
        accountName: accountName,
        bankName: bankName,
        accountType: _selectedType,
        usedFor: usedFor,
        currentBalance: balance,
        isDefault: _isDefault,
        updatedAt: now,
      );

      await ref.read(bankAccountListProvider.notifier).saveAccount(updated);

      if (_isDefault) {
        await ref.read(bankAccountListProvider.notifier).setDefaultAccount(updated.id);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Updated "${updated.accountName}"'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      final newAcc = BankAccountEntity(
        id: const Uuid().v4(),
        accountName: accountName,
        bankName: bankName,
        accountType: _selectedType,
        usedFor: usedFor,
        initialBalance: balance,
        currentBalance: balance,
        isDefault: _isDefault,
        createdAt: now,
        updatedAt: now,
      );

      await ref.read(bankAccountListProvider.notifier).saveAccount(newAcc);

      if (_isDefault) {
        await ref.read(bankAccountListProvider.notifier).setDefaultAccount(newAcc.id);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added "${newAcc.accountName}" (${CurrencyFormatter.format(newAcc.currentBalance)})'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _delete() async {
    if (!_isEditMode) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account?'),
        content: Text(
          'Are you sure you want to delete "${widget.initialAccount!.accountName}"? Associated transactions will remain in ledger.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(bankAccountListProvider.notifier).deleteAccount(widget.initialAccount!.id);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account deleted.'),
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primaryEmerald.withAlpha(isDark ? 40 : 25),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.account_balance_rounded,
                                color: AppColors.primaryEmerald,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _isEditMode ? 'Edit Account' : 'Add Bank / Cash Account',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_isEditMode)
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.expense),
                          onPressed: _delete,
                          tooltip: 'Delete Account',
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Account Name
                  Text(
                    'ACCOUNT NAME',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: financialColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. HDFC Salary, Emergency Stash, Cash Wallet',
                      prefixIcon: Icon(Icons.badge_rounded, size: 20),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter account name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),

                  // Bank / Institution Name
                  Text(
                    'BANK / INSTITUTION NAME',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: financialColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _bankController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. HDFC Bank, SBI, ICICI, Cash, Paytm',
                      prefixIcon: Icon(Icons.corporate_fare_rounded, size: 20),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Account Type Selector
                  Text(
                    'ACCOUNT TYPE',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: financialColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: AccountType.values.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final type = AccountType.values[index];
                        final isSelected = _selectedType == type;
                        return ChoiceChip(
                          avatar: Icon(
                            type.icon,
                            size: 16,
                            color: isSelected ? Colors.white : financialColors.textMuted,
                          ),
                          label: Text(type.displayName),
                          selected: isSelected,
                          onSelected: (val) {
                            if (val) setState(() => _selectedType = type);
                          },
                          selectedColor: AppColors.primaryEmerald,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? Colors.white : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 18),

                  // "Used For" Purpose Tag
                  Text(
                    'USED FOR (PURPOSE TAG)',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: financialColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tag what you use this account for (e.g. Daily Spending, Emergency Fund)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: financialColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ..._presetTags.map((tag) {
                        final isSelected = !_isCustomTag && _selectedUsedForTag == tag;
                        return FilterChip(
                          label: Text(tag),
                          selected: isSelected,
                          onSelected: (val) {
                            setState(() {
                              _selectedUsedForTag = tag;
                              _isCustomTag = false;
                            });
                          },
                          selectedColor: AppColors.primaryEmerald.withAlpha(isDark ? 60 : 40),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? (isDark ? AppColors.primaryMint : AppColors.primaryTeal)
                                : financialColors.textMuted,
                          ),
                        );
                      }),
                      FilterChip(
                        label: const Text('+ Custom Tag'),
                        selected: _isCustomTag,
                        onSelected: (val) {
                          setState(() {
                            _isCustomTag = true;
                          });
                        },
                        selectedColor: AppColors.primaryEmerald.withAlpha(isDark ? 60 : 40),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: _isCustomTag ? FontWeight.w700 : FontWeight.w500,
                          color: _isCustomTag
                              ? (isDark ? AppColors.primaryMint : AppColors.primaryTeal)
                              : financialColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  if (_isCustomTag) ...[
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _customTagController,
                      decoration: const InputDecoration(
                        hintText: 'Enter custom purpose (e.g. Vacation Fund, Car EMI)',
                        prefixIcon: Icon(Icons.tag_rounded, size: 20),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),

                  // Current Balance
                  Text(
                    'CURRENT BALANCE',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: financialColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _balanceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: financialColors.income,
                    ),
                    decoration: InputDecoration(
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 16, right: 8),
                        child: Text(
                          '₹',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: financialColors.income,
                          ),
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                      hintText: '0.00',
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter balance';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Default Account Switch
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Set as Primary / Default Account',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      'Pre-selected for new income & expense records',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: financialColors.textMuted,
                      ),
                    ),
                    value: _isDefault,
                    onChanged: (val) => setState(() => _isDefault = val),
                  ),
                  const SizedBox(height: 24),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryEmerald,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _save,
                      child: Text(
                        _isEditMode ? 'Save Changes' : 'Create Account',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
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
