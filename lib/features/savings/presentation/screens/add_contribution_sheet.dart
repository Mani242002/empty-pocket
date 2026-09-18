import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/entities/savings_goal_entity.dart';
import '../../../../core/utilities/currency_formatter.dart';
import '../../../accounts/presentation/state/accounts_cards_provider.dart';
import '../state/savings_goals_provider.dart';

class AddContributionSheet extends ConsumerStatefulWidget {
  final SavingsGoalEntity goal;

  const AddContributionSheet({super.key, required this.goal});

  static Future<void> show(BuildContext context, SavingsGoalEntity goal) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddContributionSheet(goal: goal),
    );
  }

  @override
  ConsumerState<AddContributionSheet> createState() =>
      _AddContributionSheetState();
}

class _AddContributionSheetState extends ConsumerState<AddContributionSheet> {
  late TextEditingController _amountController;
  late TextEditingController _notesController;
  String? _selectedAccountId;
  bool _deductAndLog = true;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitContribution() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid positive contribution amount.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final bankAccounts = ref.read(activeBankAccountsProvider);
    final selectedAcc = bankAccounts.where((a) => a.id == _selectedAccountId).firstOrNull;
    final paymentSource = selectedAcc?.accountName ?? 'Bank Account';

    final goal = widget.goal;
    if (_deductAndLog && goal.autoSyncAccount && goal.linkedAccountId != null && _selectedAccountId == goal.linkedAccountId) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: AppColors.warning),
              SizedBox(width: 8),
              Expanded(child: Text('Linked Account Conflict', overflow: TextOverflow.ellipsis)),
            ],
          ),
          content: Text(
            'This goal auto-tracks ${goal.allocationPercentage.toStringAsFixed(0)}% of "${selectedAcc?.accountName ?? 'this account'}". Deducting funds from it will decrease the bank balance, which in turn lowers the goal\'s auto-tracked savings. Do you still want to proceed?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Proceed Anyway'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    try {
      await ref.read(savingsGoalsListNotifierProvider.notifier).addFunds(
            goal: widget.goal,
            amount: amount,
            notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
            logAsTransaction: _deductAndLog,
            paymentSource: paymentSource,
            accountId: _deductAndLog ? _selectedAccountId : null,
          );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Added ${CurrencyFormatter.format(amount)} to "${widget.goal.title}". Keep up the great savings!',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add contribution: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.expense,
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

    final goal = widget.goal;
    final remaining = (goal.targetAmount - goal.currentAmount).clamp(0.0, double.infinity);

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

                // Goal summary card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: financialColors.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              goal.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: financialColors.savings.withAlpha(isDark ? 40 : 25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${((goal.currentAmount / goal.targetAmount) * 100).clamp(0.0, 100.0).toStringAsFixed(0)}% Saved',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: financialColors.savings,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              'Saved: ${CurrencyFormatter.format(goal.currentAmount)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: financialColors.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Target: ${CurrencyFormatter.format(goal.targetAmount)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: financialColors.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Amount to add
                Text(
                  'CONTRIBUTION AMOUNT',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: financialColors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _amountController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: financialColors.income,
                  ),
                  decoration: InputDecoration(
                    prefixText: '${CurrencyFormatter.activeCurrency.symbol} ',
                    hintText: '5,000',
                  ),
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? 'Please enter contribution amount' : null,
                ),
                const SizedBox(height: 10),

                // Quick Amount Adders
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ...[500, 1000, 2000, 5000, 10000].map((amt) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            label: Text('+${CurrencyFormatter.activeCurrency.symbol}$amt'),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                            onPressed: () {
                              _amountController.text = amt.toString();
                              _amountController.selection =
                                  TextSelection.collapsed(offset: _amountController.text.length);
                            },
                          ),
                        );
                      }),
                      if (remaining > 0)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            avatar: const Icon(Icons.stars_rounded, size: 16),
                            label: Text('Fill Remaining (${CurrencyFormatter.format(remaining)})'),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: financialColors.income,
                            ),
                            onPressed: () {
                              _amountController.text = remaining.toStringAsFixed(0);
                              _amountController.selection =
                                  TextSelection.collapsed(offset: _amountController.text.length);
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                if (goal.autoSyncAccount && goal.linkedAccountId != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withAlpha(isDark ? 30 : 18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.warning.withAlpha(70)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This goal automatically tracks ${goal.allocationPercentage.toStringAsFixed(0)}% of "${bankAccounts.where((a) => a.id == goal.linkedAccountId).firstOrNull?.accountName ?? 'Linked Account'}". If you deduct contributions from this same account, its tracked balance will automatically readjust.',
                            style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Deep Account Linking: ON/OFF Toggle
                Material(
                  color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: financialColors.cardBorder),
                    ),
                    child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Deduct from Account', style: TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(
                          _deductAndLog
                              ? 'Deducts funds from bank balance and records expense in daily ledger'
                              : 'Only update goal progress (No bank account balance change)',
                          style: TextStyle(fontSize: 12, color: financialColors.textMuted),
                        ),
                        value: _deductAndLog,
                        activeThumbColor: AppColors.primaryEmerald,
                        onChanged: (val) => setState(() => _deductAndLog = val),
                      ),
                      if (_deductAndLog && bankAccounts.isNotEmpty) ...[
                        const Divider(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedAccountId,
                          isExpanded: true,
                          isDense: true,
                          decoration: const InputDecoration(
                            labelText: 'Payment Account',
                            prefixIcon: Icon(Icons.account_balance_rounded),
                          ),
                          items: bankAccounts.map((acc) {
                            final isAutoLinked = goal.autoSyncAccount && acc.id == goal.linkedAccountId;
                            return DropdownMenuItem(
                              value: acc.id,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${acc.accountName} (${CurrencyFormatter.format(acc.currentBalance)})',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isAutoLinked)
                                    Container(
                                      margin: const EdgeInsets.only(left: 6),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.warning.withAlpha(25),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: AppColors.warning.withAlpha(80)),
                                      ),
                                      child: const Text(
                                        'Auto-tracked',
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.warning),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedAccountId = val);
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                ),
                const SizedBox(height: 16),

                // Optional Notes
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
                    hintText: 'e.g. Monthly salary savings portion, Bonus deposit',
                  ),
                ),
                const SizedBox(height: 24),

                // Save Action Button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: financialColors.income,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: _submitContribution,
                    child: const Text(
                      'Add Funds to Goal',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
