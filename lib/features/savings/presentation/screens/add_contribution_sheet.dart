import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/entities/category_constants.dart';
import '../../../../core/domain/entities/savings_goal_entity.dart';
import '../../../../core/utilities/currency_formatter.dart';
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
  late String _selectedPaymentSource;
  bool _logAsTransaction = true;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _notesController = TextEditingController();
    _selectedPaymentSource = CategoryConstants.paymentSources.first;
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

    await ref.read(savingsGoalsListNotifierProvider.notifier).addFunds(
          goal: widget.goal,
          amount: amount,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          logAsTransaction: _logAsTransaction,
          paymentSource: _selectedPaymentSource,
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
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final financialColors = context.financialColors;
    final isDark = theme.brightness == Brightness.dark;

    final goal = widget.goal;
    final remaining = (goal.targetAmount - goal.currentAmount).clamp(0.0, double.infinity);

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
                          Text(
                            goal.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
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
                          Text(
                            'Saved: ${CurrencyFormatter.format(goal.currentAmount)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: financialColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Target: ${CurrencyFormatter.format(goal.targetAmount)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: financialColors.textMuted,
                              fontWeight: FontWeight.w600,
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
                  decoration: const InputDecoration(
                    prefixText: '₹ ',
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
                            label: Text('+₹$amt'),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                            onPressed: () {
                              _amountController.text = amt.toString();
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
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Payment Source
                Text(
                  'SOURCE ACCOUNT',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: financialColors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedPaymentSource,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.account_balance_wallet_rounded),
                  ),
                  items: CategoryConstants.paymentSources.map((s) {
                    return DropdownMenuItem(value: s, child: Text(s));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedPaymentSource = val);
                  },
                ),
                const SizedBox(height: 16),

                // Log as ledger transaction checkbox
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Log as Expense in Daily Ledger', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Deducts from net balance and records savings contribution'),
                  value: _logAsTransaction,
                  activeColor: AppColors.primaryEmerald,
                  onChanged: (val) => setState(() => _logAsTransaction = val ?? true),
                ),
                const SizedBox(height: 10),

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
