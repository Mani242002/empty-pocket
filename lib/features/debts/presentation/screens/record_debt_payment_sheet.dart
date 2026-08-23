import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/entities/category_constants.dart';
import '../../../../core/domain/entities/debt_entity.dart';
import '../../../../core/utilities/currency_formatter.dart';
import '../state/debts_provider.dart';

class RecordDebtPaymentSheet extends ConsumerStatefulWidget {
  final DebtEntity debt;

  const RecordDebtPaymentSheet({super.key, required this.debt});

  static Future<void> show(BuildContext context, DebtEntity debt) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RecordDebtPaymentSheet(debt: debt),
    );
  }

  @override
  ConsumerState<RecordDebtPaymentSheet> createState() =>
      _RecordDebtPaymentSheetState();
}

class _RecordDebtPaymentSheetState
    extends ConsumerState<RecordDebtPaymentSheet> {
  late TextEditingController _amountController;
  late TextEditingController _notesController;
  late String _selectedPaymentSource;
  bool _logAsTransaction = true;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final defaultAmount = widget.debt.monthlyEmi > 0
        ? (widget.debt.monthlyEmi == widget.debt.monthlyEmi.roundToDouble()
            ? widget.debt.monthlyEmi.toInt().toString()
            : widget.debt.monthlyEmi.toString())
        : '';
    _amountController = TextEditingController(text: defaultAmount);
    _notesController = TextEditingController();
    _selectedPaymentSource = CategoryConstants.paymentSources.first;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid payment amount.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await ref.read(debtListNotifierProvider.notifier).recordPayment(
          debt: widget.debt,
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
            'Recorded ${CurrencyFormatter.format(amount)} payment for "${widget.debt.title}".',
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

    final debt = widget.debt;
    final remaining = debt.remainingAmount;

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
                  Text(
                    'Record Loan / EMI Payment',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Debt summary card
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
                          children: [
                            Icon(debt.type.icon, color: financialColors.expense, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                debt.title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (debt.lenderName != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                debt.lenderName!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: financialColors.textMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Remaining Balance:',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: financialColors.textMuted,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                CurrencyFormatter.format(remaining),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: financialColors.expense,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Monthly EMI:',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: financialColors.textMuted,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                CurrencyFormatter.format(debt.monthlyEmi),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Amount to pay
                  Text(
                    'PAYMENT AMOUNT',
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
                      color: financialColors.warning,
                    ),
                    decoration: const InputDecoration(
                      prefixText: '₹ ',
                      hintText: '10,000',
                    ),
                    validator: (val) =>
                        val == null || val.trim().isEmpty ? 'Please enter payment amount' : null,
                  ),
                  const SizedBox(height: 10),

                  // Quick Amount Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        if (debt.monthlyEmi > 0)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ActionChip(
                              label: Text('Monthly EMI (${CurrencyFormatter.format(debt.monthlyEmi)})'),
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: financialColors.warning,
                              ),
                              onPressed: () {
                                _amountController.text = (debt.monthlyEmi == debt.monthlyEmi.roundToDouble()
                                    ? debt.monthlyEmi.toInt().toString()
                                    : debt.monthlyEmi.toString());
                              },
                            ),
                          ),
                        ...[1000, 5000, 10000, 25000].map((amt) {
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
                              avatar: const Icon(Icons.check_circle_outline_rounded, size: 16),
                              label: Text('Full Payoff (${CurrencyFormatter.format(remaining)})'),
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
                    'PAYMENT ACCOUNT',
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

                  // Log as transaction checkbox
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Log as Expense in Daily Ledger', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Deducts from net balance and records debt repayment expense'),
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
                      hintText: 'e.g. Monthly EMI auto-debit, Prepayment, Final settlement',
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Save Action Button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: financialColors.expense,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _submitPayment,
                      child: const Text(
                        'Record Debt Payment',
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
