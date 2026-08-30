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
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withAlpha(isDark ? 40 : 25),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final financialColors = context.financialColors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _buildActionButton(
                context,
                label: 'Add Expense',
                icon: Icons.remove_circle_outline_rounded,
                color: financialColors.expense,
                onTap: () => AddEditTransactionSheet.show(
                  context,
                  initialType: TransactionType.expense,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildActionButton(
                context,
                label: 'Add Income',
                icon: Icons.add_circle_outline_rounded,
                color: financialColors.income,
                onTap: () => AddEditTransactionSheet.show(
                  context,
                  initialType: TransactionType.income,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildActionButton(
                context,
                label: 'Set Budget',
                icon: Icons.pie_chart_outline_rounded,
                color: financialColors.investment,
                onTap: () => SetBudgetSheet.show(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
