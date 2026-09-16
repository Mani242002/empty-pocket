import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/utilities/math_expression_parser.dart';
import '../../../../core/utilities/currency_formatter.dart';

/// Form field component for entering transaction amounts.
/// Supports dynamic currency formatting, numeric input formatting,
/// inline math validation, and quick increment chips.
class AmountCalculatorField extends StatelessWidget {
  final TextEditingController controller;
  final Color activeAccentColor;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final List<int> quickAddAmounts;
  final bool autofocus;

  const AmountCalculatorField({
    super.key,
    required this.controller,
    required this.activeAccentColor,
    this.validator,
    this.onChanged,
    this.quickAddAmounts = const [100, 200, 500, 1000, 2000, 5000],
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final financialColors = context.financialColors;
    final isDark = theme.brightness == Brightness.dark;
    final currencySymbol = CurrencyFormatter.activeCurrency.symbol;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Amount Label
        Text(
          'AMOUNT',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: financialColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),

        // Text Form Field
        TextFormField(
          controller: controller,
          autofocus: autofocus,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9\.\+\-\*\/\(\)\s]')),
          ],
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: activeAccentColor,
          ),
          decoration: InputDecoration(
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 16, right: 8),
              child: Text(
                currencySymbol,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: activeAccentColor,
                ),
              ),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
            hintText: '0.00',
          ),
          validator: validator ??
              (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter amount';
                }
                if (double.tryParse(value) == null && MathExpressionParser.tryEvaluate(value) == null) {
                  return 'Invalid number';
                }
                return null;
              },
          onChanged: onChanged,
        ),
        const SizedBox(height: 10),

        // Quick Amount Adders
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: quickAddAmounts.map((quickAdd) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  label: Text('+$currencySymbol$quickAdd'),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                  onPressed: () {
                    final current = MathExpressionParser.tryEvaluate(controller.text) ??
                        (double.tryParse(controller.text) ?? 0.0);
                    final next = current + quickAdd;
                    controller.text = next == next.roundToDouble()
                        ? next.toInt().toString()
                        : next.toStringAsFixed(2);
                    controller.selection = TextSelection.collapsed(offset: controller.text.length);
                    onChanged?.call(controller.text);
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
