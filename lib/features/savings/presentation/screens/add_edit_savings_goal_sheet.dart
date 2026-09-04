import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/entities/savings_goal_entity.dart';
import '../../../../core/utilities/currency_formatter.dart';
import '../../../accounts/presentation/state/accounts_cards_provider.dart';
import '../state/savings_goals_provider.dart';

class AddEditSavingsGoalSheet extends ConsumerStatefulWidget {
  final SavingsGoalEntity? initialGoal;
  final bool isEmergencyFundDefault;

  const AddEditSavingsGoalSheet({
    super.key,
    this.initialGoal,
    this.isEmergencyFundDefault = false,
  });

  static Future<void> show(
    BuildContext context, {
    SavingsGoalEntity? goal,
    bool isEmergencyFundDefault = false,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddEditSavingsGoalSheet(
        initialGoal: goal,
        isEmergencyFundDefault: isEmergencyFundDefault,
      ),
    );
  }

  @override
  ConsumerState<AddEditSavingsGoalSheet> createState() =>
      _AddEditSavingsGoalSheetState();
}

class _AddEditSavingsGoalSheetState
    extends ConsumerState<AddEditSavingsGoalSheet> {
  late TextEditingController _titleController;
  late TextEditingController _targetAmountController;
  late TextEditingController _currentAmountController;
  late String _selectedCategory;
  late DateTime _targetDate;
  late bool _isEmergencyFund;
  String? _selectedAccountId;
  bool _deductInitialFromAccount = true;

  final _formKey = GlobalKey<FormState>();

  bool get _isEditMode => widget.initialGoal != null;

  static const List<String> _goalCategories = [
    'Emergency Fund',
    'Vacation & Travel',
    'Gadget & Tech',
    'Vehicle / Car',
    'Home & Renovation',
    'Education',
    'Wedding & Events',
    'Retirement',
    'Custom Goal',
  ];

  @override
  void initState() {
    super.initState();
    final goal = widget.initialGoal;

    _isEmergencyFund = goal?.isEmergencyFund ?? widget.isEmergencyFundDefault;
    _selectedAccountId = goal?.linkedAccountId;
    _titleController = TextEditingController(
      text: goal?.title ?? (_isEmergencyFund ? 'Emergency Fund (6 Months)' : ''),
    );
    _targetAmountController = TextEditingController(
      text: goal != null
          ? (goal.targetAmount == goal.targetAmount.roundToDouble()
              ? goal.targetAmount.toInt().toString()
              : goal.targetAmount.toString())
          : (_isEmergencyFund ? '150000' : ''),
    );
    _currentAmountController = TextEditingController(
      text: goal != null
          ? (goal.currentAmount == goal.currentAmount.roundToDouble()
              ? goal.currentAmount.toInt().toString()
              : goal.currentAmount.toString())
          : '0',
    );

    _selectedCategory = goal?.category ?? (_isEmergencyFund ? 'Emergency Fund' : _goalCategories.first);
    _targetDate = goal?.targetDate ?? DateTime.now().add(const Duration(days: 365));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _targetAmountController.dispose();
    _currentAmountController.dispose();
    super.dispose();
  }

  Future<void> _pickTargetDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2050),
    );

    if (picked != null && mounted) {
      setState(() => _targetDate = picked);
    }
  }

  Future<void> _saveGoal() async {
    if (!_formKey.currentState!.validate()) return;

    final target = double.tryParse(_targetAmountController.text.trim());
    if (target == null || target <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid target amount.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final current = double.tryParse(_currentAmountController.text.trim()) ?? 0.0;
    final title = _titleController.text.trim();
    final now = DateTime.now();

    final goal = SavingsGoalEntity(
      id: widget.initialGoal?.id ?? const Uuid().v4(),
      title: title,
      targetAmount: target,
      currentAmount: current,
      category: _selectedCategory,
      targetDate: _targetDate,
      isEmergencyFund: _isEmergencyFund,
      status: current >= target ? GoalStatus.completed : GoalStatus.active,
      linkedAccountId: _selectedAccountId,
      createdAt: widget.initialGoal?.createdAt ?? now,
      updatedAt: now,
    );

    if (!_isEditMode && current > 0) {
      final bankAccounts = ref.read(activeBankAccountsProvider);
      final selectedAcc = bankAccounts.where((a) => a.id == _selectedAccountId).firstOrNull;
      final paymentSource = selectedAcc?.accountName ?? 'Bank Account';

      await ref.read(savingsGoalsListNotifierProvider.notifier).createGoalWithInitialDeposit(
            goal: goal,
            initialAmount: current,
            deductFromAccount: _deductInitialFromAccount,
            accountId: _deductInitialFromAccount ? _selectedAccountId : null,
            paymentSource: paymentSource,
          );
    } else {
      await ref.read(savingsGoalsListNotifierProvider.notifier).saveGoal(goal);
    }

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved goal "${goal.title}" (${CurrencyFormatter.format(goal.targetAmount)} target).'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteGoal() async {
    if (!_isEditMode) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Savings Goal?'),
        content: Text('Permanently remove "${widget.initialGoal!.title}" and all its history?'),
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

    if (confirmed == true && mounted) {
      await ref
          .read(savingsGoalsListNotifierProvider.notifier)
          .deleteGoal(widget.initialGoal!.id);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Savings goal deleted.'),
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

    final bankAccounts = ref.watch(activeBankAccountsProvider);
    final defaultAcc = ref.watch(defaultBankAccountProvider);

    if (_selectedAccountId == null && bankAccounts.isNotEmpty) {
      _selectedAccountId = defaultAcc?.id ?? bankAccounts.first.id;
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
                // Drag handle
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
                    Flexible(
                      child: Text(
                        _isEditMode ? 'Edit Savings Goal' : 'New Savings Goal',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_isEditMode)
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.expense),
                        onPressed: _deleteGoal,
                        tooltip: 'Delete',
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // Goal Title
                Text(
                  'GOAL TITLE',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: financialColors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Bali Trip, Emergency Fund, New Laptop',
                    prefixIcon: Icon(Icons.savings_rounded),
                  ),
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? 'Please enter goal title' : null,
                ),
                const SizedBox(height: 18),

                // Target Amount & Initial Saved Amount Row
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TARGET AMOUNT',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                                color: financialColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _targetAmountController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                              ],
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: financialColors.savings,
                              ),
                              decoration: const InputDecoration(
                                prefixText: '₹ ',
                                hintText: '1,00,000',
                              ),
                              validator: (val) =>
                                  val == null || val.trim().isEmpty ? 'Enter target' : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ALREADY SAVED',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                                color: financialColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _currentAmountController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                              ],
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                              decoration: const InputDecoration(
                                prefixText: '₹ ',
                                hintText: '0',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Category Selector
                Text(
                  'CATEGORY',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: financialColors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.category_rounded),
                  ),
                  items: _goalCategories.map((c) {
                    return DropdownMenuItem(value: c, child: Text(c));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedCategory = val;
                        if (val == 'Emergency Fund') {
                          _isEmergencyFund = true;
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 18),

                // Target Date Picker
                Text(
                  'TARGET COMPLETION DATE',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: financialColors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _pickTargetDate,
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
                        const Icon(Icons.calendar_today_rounded, size: 20),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            DateFormat('dd MMMM yyyy').format(_targetDate),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${((_targetDate.difference(DateTime.now()).inDays) / 30).ceil()} months)',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: financialColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Deep Account Linking: Primary Bank Account & Deduct Toggle
                if (bankAccounts.isNotEmpty) ...[
                  Text(
                    'PRIMARY LINKED ACCOUNT',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: financialColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedAccountId,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.account_balance_rounded),
                    ),
                    items: bankAccounts.map((acc) {
                      return DropdownMenuItem(
                        value: acc.id,
                        child: Text(
                          '${acc.accountName} (${CurrencyFormatter.format(acc.currentBalance)})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedAccountId = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  if (!_isEditMode) ...[
                    Material(
                      color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: financialColors.cardBorder),
                        ),
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Deduct Initial Amount from Account', style: TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(
                            _deductInitialFromAccount
                                ? 'Deducts saved portion from bank balance and records expense in daily ledger'
                                : 'Set initial savings progress without deducting bank balance',
                            style: TextStyle(fontSize: 12, color: financialColors.textMuted),
                          ),
                          value: _deductInitialFromAccount,
                          activeThumbColor: AppColors.primaryEmerald,
                          onChanged: (val) => setState(() => _deductInitialFromAccount = val),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],

                // Emergency Fund Switch Tile
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mark as Emergency Fund', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Highlighted with safety metrics on your dashboard'),
                  value: _isEmergencyFund,
                  activeTrackColor: AppColors.primaryEmerald,
                  onChanged: (val) => setState(() => _isEmergencyFund = val),
                ),
                const SizedBox(height: 24),

                // Save Action
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: financialColors.savings,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: _saveGoal,
                    child: Text(
                      _isEditMode ? 'Update Goal' : 'Create Savings Goal',
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
