import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/entities/investment_entity.dart';
import '../../../../core/utilities/currency_formatter.dart';
import '../state/investments_provider.dart';

class UpdateValuationSheet extends ConsumerStatefulWidget {
  final InvestmentEntity investment;

  const UpdateValuationSheet({super.key, required this.investment});

  static Future<void> show(BuildContext context, InvestmentEntity investment) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => UpdateValuationSheet(investment: investment),
    );
  }

  @override
  ConsumerState<UpdateValuationSheet> createState() => _UpdateValuationSheetState();
}

class _UpdateValuationSheetState extends ConsumerState<UpdateValuationSheet> {
  late TextEditingController _currentValueController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final cur = widget.investment.currentValue;
    _currentValueController = TextEditingController(
      text: cur == cur.roundToDouble() ? cur.toInt().toString() : cur.toString(),
    );
  }

  @override
  void dispose() {
    _currentValueController.dispose();
    super.dispose();
  }

  void _applyPercentageMultiplier(double multiplier) {
    final cur = double.tryParse(_currentValueController.text.trim()) ?? widget.investment.currentValue;
    final newVal = cur * (1.0 + multiplier);
    setState(() {
      _currentValueController.text = newVal.round().toString();
    });
  }

  Future<void> _submitUpdate() async {
    if (!_formKey.currentState!.validate()) return;

    final newVal = double.tryParse(_currentValueController.text.trim());
    if (newVal == null || newVal < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid valuation amount.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await ref.read(investmentListNotifierProvider.notifier).updateValuation(
          investment: widget.investment,
          newCurrentValue: newVal,
        );

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Updated "${widget.investment.name}" valuation to ${CurrencyFormatter.format(newVal)}.',
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

    final inv = widget.investment;
    final currentInput = double.tryParse(_currentValueController.text.trim()) ?? inv.currentValue;
    final pnl = currentInput - inv.investedAmount;
    final returnPct = inv.investedAmount > 0 ? (pnl / inv.investedAmount) * 100 : 0.0;
    final isProfit = pnl >= 0;

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

                  // Header
                  Text(
                    'Update Current Valuation',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Summary Box
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
                            Icon(inv.assetClass.icon, color: inv.assetClass.color, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                inv.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (inv.institution != null)
                              Text(
                                inv.institution!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: financialColors.textMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Original Invested:',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: financialColors.textMuted,
                                ),
                              ),
                            ),
                            Text(
                              CurrencyFormatter.format(inv.investedAmount),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // New Valuation Input
                  Text(
                    'NEW CURRENT VALUE',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: financialColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _currentValueController,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isProfit ? financialColors.income : financialColors.expense,
                    ),
                    decoration: const InputDecoration(
                      prefixText: '₹ ',
                      hintText: '75,000',
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (val) =>
                        val == null || val.trim().isEmpty ? 'Enter current value' : null,
                  ),
                  const SizedBox(height: 10),

                  // Quick Percentage Adder Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ...[0.05, 0.10, 0.20].map((pct) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ActionChip(
                              label: Text('+${(pct * 100).toInt()}%'),
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: financialColors.income,
                              ),
                              onPressed: () => _applyPercentageMultiplier(pct),
                            ),
                          );
                        }),
                        ...[-0.05, -0.10].map((pct) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ActionChip(
                              label: Text('${(pct * 100).toInt()}%'),
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: financialColors.expense,
                              ),
                              onPressed: () => _applyPercentageMultiplier(pct),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // P&L Live Preview Card
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: (isProfit ? financialColors.income : financialColors.expense)
                          .withAlpha(isDark ? 30 : 15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (isProfit ? financialColors.income : financialColors.expense)
                            .withAlpha(isDark ? 70 : 40),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Estimated Returns:',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '${isProfit ? '+' : ''}${CurrencyFormatter.format(pnl)} (${returnPct.toStringAsFixed(1)}%)',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: isProfit ? financialColors.income : financialColors.expense,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Submit Action Button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: financialColors.income,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _submitUpdate,
                      child: const Text(
                        'Update Valuation',
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
