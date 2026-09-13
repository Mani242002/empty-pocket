import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/entities/transaction_entity.dart';
import '../../../savings/presentation/screens/add_edit_savings_goal_sheet.dart';
import '../../../transactions/presentation/screens/add_edit_transaction_sheet.dart';
import '../../../transactions/presentation/state/transactions_provider.dart';
import '../screens/add_recurring_sheet.dart';
import '../screens/set_budget_sheet.dart';
import '../widgets/monthly_budgets_tab.dart';
import '../widgets/recurring_bills_tab.dart';
import '../widgets/savings_goals_tab.dart';
import '../widgets/shared_splits_tab.dart';

class BudgetsScreen extends ConsumerStatefulWidget {
  const BudgetsScreen({super.key});

  @override
  ConsumerState<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends ConsumerState<BudgetsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final financialColors = context.financialColors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets & Goals'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppColors.primaryEmerald,
          labelColor: isDark ? AppColors.primaryMint : AppColors.primaryTeal,
          unselectedLabelColor: financialColors.textMuted,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
          tabs: const [
            Tab(icon: Icon(Icons.pie_chart_outline_rounded, size: 20), text: 'Monthly Budgets'),
            Tab(icon: Icon(Icons.savings_outlined, size: 20), text: 'Savings & Goals'),
            Tab(icon: Icon(Icons.event_repeat_rounded, size: 20), text: 'Recurring & Bills'),
            Tab(icon: Icon(Icons.group_outlined, size: 20), text: 'Shared & Splits'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          MonthlyBudgetsTab(),
          SavingsGoalsTab(),
          RecurringBillsTab(),
          SharedSplitsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'budgets_fab',
        onPressed: () {
          if (_tabController.index == 0) {
            SetBudgetSheet.show(context, targetMonth: ref.read(selectedMonthProvider));
          } else if (_tabController.index == 1) {
            AddEditSavingsGoalSheet.show(context);
          } else if (_tabController.index == 2) {
            AddRecurringSheet.show(context);
          } else {
            AddEditTransactionSheet.show(context, initialType: TransactionType.expense);
          }
        },
        tooltip: 'Add Budget, Goal, Recurring or Shared Expense',
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }
}
