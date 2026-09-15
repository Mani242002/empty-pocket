import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/entities/transaction_entity.dart';
import '../../../budgets/presentation/screens/set_budget_sheet.dart';
import '../../../transactions/presentation/screens/add_edit_transaction_sheet.dart';

class DashboardQuickActions extends StatelessWidget {
  const DashboardQuickActions({super.key});

  Widget _buildActionButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
    bool horizontal = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final iconWidget = Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withAlpha(isDark ? 40 : 25),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 20),
    );

    final textWidget = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
      ),
    );

    return Material(
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: context.financialColors.cardBorder,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: horizontal
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    iconWidget,
                    const SizedBox(width: 10),
                    Flexible(child: textWidget),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    iconWidget,
                    const SizedBox(height: 8),
                    textWidget,
                  ],
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final financialColors = context.financialColors;

    return LayoutBuilder(
      builder: (context, constraints) {
        final expenseBtn = _buildActionButton(
          context,
          label: 'Add Expense',
          icon: Icons.remove_circle_outline_rounded,
          color: financialColors.expense,
          onTap: () => AddEditTransactionSheet.show(
            context,
            initialType: TransactionType.expense,
          ),
        );

        final incomeBtn = _buildActionButton(
          context,
          label: 'Add Income',
          icon: Icons.add_circle_outline_rounded,
          color: financialColors.income,
          onTap: () => AddEditTransactionSheet.show(
            context,
            initialType: TransactionType.income,
          ),
        );

        final isCompact = constraints.maxWidth < 360;

        final budgetBtn = _buildActionButton(
          context,
          label: 'Set Budget',
          icon: Icons.pie_chart_outline_rounded,
          color: financialColors.investment,
          horizontal: isCompact,
          onTap: () => SetBudgetSheet.show(context),
        );

        if (isCompact) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(child: expenseBtn),
                    const SizedBox(width: 8),
                    Expanded(child: incomeBtn),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: budgetBtn),
                  ],
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: expenseBtn),
                const SizedBox(width: 10),
                Expanded(child: incomeBtn),
                const SizedBox(width: 10),
                Expanded(child: budgetBtn),
              ],
            ),
          ),
        );
      },
    );
  }
}
