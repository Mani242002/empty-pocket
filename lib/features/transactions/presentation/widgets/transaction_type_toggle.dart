import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/entities/transaction_entity.dart';

/// Segmented type selector for transactions (Expense, Income, Transfer)
/// with animated selection styling, responsive overflow protection, and haptic feedback.
class TransactionTypeToggle extends StatelessWidget {
  final TransactionType selectedType;
  final ValueChanged<TransactionType> onTypeChanged;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;

  const TransactionTypeToggle({
    super.key,
    required this.selectedType,
    required this.onTypeChanged,
    this.padding = const EdgeInsets.all(4),
    this.borderRadius,
  });

  Widget _buildTypeSegment({
    required BuildContext context,
    required String title,
    required IconData icon,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withAlpha(isDark ? 80 : 50),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? Colors.white
                  : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final financialColors = context.financialColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
        borderRadius: borderRadius ?? BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTypeSegment(
              context: context,
              title: 'Expense',
              icon: Icons.arrow_upward_rounded,
              isSelected: selectedType == TransactionType.expense,
              color: financialColors.expense,
              onTap: () => onTypeChanged(TransactionType.expense),
            ),
          ),
          Expanded(
            child: _buildTypeSegment(
              context: context,
              title: 'Income',
              icon: Icons.arrow_downward_rounded,
              isSelected: selectedType == TransactionType.income,
              color: financialColors.income,
              onTap: () => onTypeChanged(TransactionType.income),
            ),
          ),
          Expanded(
            child: _buildTypeSegment(
              context: context,
              title: 'Transfer',
              icon: Icons.swap_horiz_rounded,
              isSelected: selectedType == TransactionType.transfer,
              color: AppColors.primaryEmerald,
              onTap: () => onTypeChanged(TransactionType.transfer),
            ),
          ),
        ],
      ),
    );
  }
}
