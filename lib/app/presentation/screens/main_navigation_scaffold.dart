import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../../core/domain/entities/transaction_entity.dart';
import '../../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../../features/transactions/presentation/screens/add_edit_transaction_sheet.dart';
import '../../../features/transactions/presentation/screens/transactions_screen.dart';
import '../../../features/budgets/presentation/screens/budgets_screen.dart';
import '../../../features/reports/presentation/screens/reports_analytics_screen.dart';
import '../../../features/settings/presentation/screens/settings_screen.dart';

class MainNavigationScaffold extends StatefulWidget {
  const MainNavigationScaffold({super.key});

  @override
  State<MainNavigationScaffold> createState() => _MainNavigationScaffoldState();
}

class _MainNavigationScaffoldState extends State<MainNavigationScaffold> {
  static const MethodChannel _overlayChannel = MethodChannel('dev.emptypocket.app/overlay');
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _setupOverlayListener();
  }

  void _setupOverlayListener() {
    _overlayChannel.setMethodCallHandler((call) async {
      if (call.method == 'triggerQuickAdd') {
        if (mounted) {
          AddEditTransactionSheet.show(
            context,
            initialType: TransactionType.expense,
          );
        }
      }
    });
  }

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _showQuickAddBottomSheet() {
    final theme = Theme.of(context);
    final financialColors = context.financialColors;
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                const SizedBox(height: 20),
                Text(
                  'Quick Action',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Record a transaction or create a plan',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: financialColors.textMuted,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildModalActionButton(
                        context,
                        title: 'Add Expense',
                        subtitle: 'Money going out',
                        icon: Icons.arrow_upward_rounded,
                        color: financialColors.expense,
                        onTap: () {
                          Navigator.pop(ctx);
                          AddEditTransactionSheet.show(
                            context,
                            initialType: TransactionType.expense,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildModalActionButton(
                        context,
                        title: 'Add Income',
                        subtitle: 'Money coming in',
                        icon: Icons.arrow_downward_rounded,
                        color: financialColors.income,
                        onTap: () {
                          Navigator.pop(ctx);
                          AddEditTransactionSheet.show(
                            context,
                            initialType: TransactionType.income,
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildModalSecondaryAction(
                  context,
                  title: 'Set Monthly Category Budget',
                  subtitle: 'Define spending limits',
                  icon: Icons.pie_chart_outline_rounded,
                  onTap: () {
                    Navigator.pop(ctx);
                    _onTabSelected(2);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModalActionButton(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: color.withAlpha(isDark ? 35 : 20),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: context.financialColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModalSecondaryAction(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primaryEmerald, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: context.financialColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: context.financialColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(
        onViewAllTransactions: () => _onTabSelected(1),
        onSetBudget: () => _onTabSelected(2),
      ),
      const TransactionsScreen(),
      const BudgetsScreen(),
      const ReportsAnalyticsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showQuickAddBottomSheet,
        tooltip: 'Quick Add',
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Transactions',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline_rounded),
            selectedIcon: Icon(Icons.pie_chart_rounded),
            label: 'Budgets',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded),
            label: 'Reports & AI',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
