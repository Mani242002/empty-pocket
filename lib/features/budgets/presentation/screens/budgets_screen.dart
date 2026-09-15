import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
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
    );
  }
}
