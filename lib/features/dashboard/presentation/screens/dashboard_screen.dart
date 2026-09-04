import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../accounts/presentation/state/accounts_cards_provider.dart';
import '../../../budgets/presentation/state/budgets_provider.dart';
import '../../../budgets/presentation/state/recurring_provider.dart';
import '../../../debts/presentation/state/debts_provider.dart';
import '../../../investments/presentation/state/investments_provider.dart';
import '../../../net_worth/presentation/state/net_worth_provider.dart';
import '../../../savings/presentation/state/savings_goals_provider.dart';
import '../../../transactions/presentation/screens/transaction_detail_sheet.dart';
import '../../../transactions/presentation/state/transactions_provider.dart';
import '../widgets/dashboard_accounts_card.dart';
import '../widgets/dashboard_balance_card.dart';
import '../widgets/dashboard_budget_card.dart';
import '../widgets/dashboard_header_bar.dart';
import '../widgets/dashboard_investments_card.dart';
import '../widgets/dashboard_liabilities_card.dart';
import '../widgets/dashboard_monthly_comparison_banner.dart';
import '../widgets/dashboard_quick_actions.dart';
import '../widgets/dashboard_recent_activity.dart';
import '../widgets/dashboard_savings_card.dart';
import '../widgets/pending_shared_card.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  final VoidCallback? onViewAllTransactions;
  final VoidCallback? onSetBudget;

  const DashboardScreen({
    super.key,
    this.onViewAllTransactions,
    this.onSetBudget,
  });

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _isBalanceVisible = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final today = DateFormat('EEEE, d MMMM').format(DateTime.now());

    final summary = ref.watch(monthlyFinancialSummaryProvider);
    final comparison = ref.watch(monthlySpendingComparisonProvider);
    final budgetSummary = ref.watch(overallMonthlyBudgetSummaryProvider);
    final savingsSummary = ref.watch(overallSavingsSummaryProvider);
    final liabilitiesSummary = ref.watch(overallLiabilitiesSummaryProvider);
    final portfolioSummary = ref.watch(overallPortfolioSummaryProvider);
    final healthSummary = ref.watch(financialHealthSummaryProvider);
    final recentTransactions = ref.watch(recentTransactionsProvider);
    final bankAccounts = ref.watch(activeBankAccountsProvider);
    final creditCards = ref.watch(activeCreditCardsProvider);
    final combinedCash = ref.watch(combinedLiquidCashProvider);
    final creditSummary = ref.watch(combinedCreditSummaryProvider);
    final dailySafeToSpend = ref.watch(dailySafeToSpendProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primaryEmerald,
          backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          onRefresh: () async {
            HapticFeedback.lightImpact();
            ref.invalidate(transactionListNotifierProvider);
            ref.invalidate(bankAccountListProvider);
            ref.invalidate(creditCardListProvider);
            ref.invalidate(budgetListNotifierProvider);
            ref.invalidate(recurringListNotifierProvider);
            ref.invalidate(savingsGoalsListNotifierProvider);
            ref.invalidate(debtListNotifierProvider);
            ref.invalidate(investmentListNotifierProvider);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              // Top App Bar Header
              SliverToBoxAdapter(
                child: DashboardHeaderBar(todayFormatted: today),
              ),

              // Monthly Spending Comparison Banner
              SliverToBoxAdapter(
                child: DashboardMonthlyComparisonBanner(comparison: comparison),
              ),

              // Main Balance Hero Card
              SliverToBoxAdapter(
                child: DashboardBalanceCard(
                  summary: summary,
                  healthSummary: healthSummary,
                  dailySafeToSpend: dailySafeToSpend,
                  isBalanceVisible: _isBalanceVisible,
                  onToggleBalanceVisibility: () {
                    setState(() {
                      _isBalanceVisible = !_isBalanceVisible;
                    });
                  },
                ),
              ),

              // Quick Actions
              const SliverToBoxAdapter(
                child: DashboardQuickActions(),
              ),

              // Pending Shared Reimbursements Card
              const SliverToBoxAdapter(
                child: DashboardPendingSharedCard(),
              ),

              // Accounts & Cards Overview Card
              SliverToBoxAdapter(
                child: DashboardAccountsCard(
                  bankAccounts: bankAccounts,
                  creditCards: creditCards,
                  combinedCash: combinedCash,
                  creditSummary: creditSummary,
                ),
              ),

              // Monthly Budget Status Card
              SliverToBoxAdapter(
                child: DashboardBudgetCard(
                  budgetSummary: budgetSummary,
                  totalExpense: summary.totalExpense,
                ),
              ),

              // Savings & Goals Card
              SliverToBoxAdapter(
                child: DashboardSavingsCard(
                  savingsSummary: savingsSummary,
                ),
              ),

              // Investments & Portfolio Card
              SliverToBoxAdapter(
                child: DashboardInvestmentsCard(
                  portfolioSummary: portfolioSummary,
                ),
              ),

              // Loans & Liabilities Card
              SliverToBoxAdapter(
                child: DashboardLiabilitiesCard(
                  liabilitiesSummary: liabilitiesSummary,
                ),
              ),

              // Recent Transactions Section Header
              SliverToBoxAdapter(
                child: DashboardRecentActivityHeader(
                  hasTransactions: recentTransactions.isNotEmpty,
                  onViewAllTransactions: widget.onViewAllTransactions,
                ),
              ),

              // Recent Transactions List or Empty State
              if (recentTransactions.isEmpty)
                const SliverToBoxAdapter(
                  child: DashboardEmptyTransactionsPrompt(),
                )
              else
                DashboardRecentActivityList(
                  recentTransactions: recentTransactions,
                  onTapTransaction: (tx) => TransactionDetailSheet.show(
                    context,
                    transaction: tx,
                  ),
                  onDeleteTransaction: (id) => ref
                      .read(transactionListNotifierProvider.notifier)
                      .deleteTransaction(id),
                ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 32),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
