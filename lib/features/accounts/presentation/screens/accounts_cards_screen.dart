import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/calculation/financial_calculator.dart';
import '../../../../core/domain/entities/bank_account_entity.dart';
import '../../../../core/domain/entities/credit_card_entity.dart';
import '../../../../core/utilities/currency_formatter.dart';
import '../state/accounts_cards_provider.dart';
import 'account_detail_screen.dart';
import 'account_transfer_sheet.dart';
import 'add_edit_bank_account_sheet.dart';
import 'add_edit_cash_account_sheet.dart';
import 'add_edit_credit_card_sheet.dart';
import 'pay_credit_card_sheet.dart';
import '../../../settings/presentation/state/backup_provider.dart';
import '../../../transactions/presentation/screens/add_edit_transaction_sheet.dart';
import '../../../../core/domain/entities/transaction_entity.dart';

class AccountsCardsScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;

  const AccountsCardsScreen({super.key, this.initialTabIndex = 0});

  @override
  ConsumerState<AccountsCardsScreen> createState() =>
      _AccountsCardsScreenState();
}

class _AccountsCardsScreenState extends ConsumerState<AccountsCardsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(currencyProvider);
    final theme = Theme.of(context);
    final financialColors = context.financialColors;
    final isDark = theme.brightness == Brightness.dark;

    final bankAccounts = ref.watch(pureBankAccountsProvider);
    final cashAccounts = ref.watch(activeCashAccountsProvider);
    final primaryCash = ref.watch(primaryCashAccountProvider);
    final defaultBank = ref.watch(defaultBankAccountProvider);
    final totalBankBalance = ref.watch(totalBankBalanceProvider);
    final totalCash = ref.watch(totalPhysicalCashBalanceProvider);
    final cards = ref.watch(activeCreditCardsProvider);
    final creditSummary = ref.watch(combinedCreditSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts & Cards'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppColors.primaryEmerald,
          indicatorWeight: 3,
          labelColor: isDark ? AppColors.primaryMint : AppColors.primaryTeal,
          unselectedLabelColor: financialColors.textMuted,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          tabs: [
            Tab(
              icon: const Icon(Icons.account_balance_rounded, size: 20),
              text: 'Bank Accounts (${bankAccounts.length})',
            ),
            Tab(
              icon: const Icon(Icons.credit_card_rounded, size: 20),
              text: 'Credit Cards (${cards.length})',
            ),
            Tab(
              icon: const Icon(Icons.payments_rounded, size: 20),
              text: 'Cash in Hand (${cashAccounts.length})',
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Bank Accounts
                _buildBankAccountsTab(
                  context,
                  bankAccounts,
                  totalBankBalance,
                  isDark,
                  financialColors,
                ),
                // Tab 2: Credit Cards
                _buildCreditCardsTab(
                  context,
                  cards,
                  creditSummary,
                  isDark,
                  financialColors,
                ),
                // Tab 3: Cash in Hand
                _buildCashTab(
                  context,
                  cashAccounts,
                  totalCash,
                  defaultBank,
                  primaryCash,
                  isDark,
                  financialColors,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBankAccountsTab(
    BuildContext context,
    List<BankAccountEntity> accounts,
    double combinedCash,
    bool isDark,
    AppFinancialColors financialColors,
  ) {
    final theme = Theme.of(context);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Combined Cash Hero Card
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [const Color(0xFF13221B), const Color(0xFF131B26)]
                      : [const Color(0xFFECFDF5), const Color(0xFFF0FDF4)],
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: AppColors.primaryEmerald.withAlpha(isDark ? 60 : 40),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'COMBINED BANK BALANCE',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: financialColors.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryEmerald.withAlpha(
                            isDark ? 40 : 25,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${accounts.length} Bank Account${accounts.length == 1 ? '' : 's'}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryEmerald,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    CurrencyFormatter.format(combinedCash),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: combinedCash >= 0
                          ? financialColors.income
                          : financialColors.expense,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Transfer Funds'),
                          ),
                          onPressed: () => AccountTransferSheet.show(context),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primaryEmerald,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Add Account'),
                          ),
                          onPressed: () =>
                              AddEditBankAccountSheet.show(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // Accounts List Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: Text(
              'Your Accounts (${accounts.length})',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),

        // Accounts Cards or Empty State
        if (accounts.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.account_balance_outlined,
                      size: 48,
                      color: financialColors.textMuted,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'No Bank Accounts Added Yet',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Add your savings, salary, checking, and cash accounts to track balances and transfer money.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: financialColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () => AddEditBankAccountSheet.show(context),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add Your First Account'),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final acc = accounts[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildAccountCard(
                    context,
                    acc,
                    isDark,
                    financialColors,
                  ),
                );
              }, childCount: accounts.length),
            ),
          ),
      ],
    );
  }

  Widget _buildAccountCard(
    BuildContext context,
    BankAccountEntity acc,
    bool isDark,
    AppFinancialColors financialColors,
  ) {
    final theme = Theme.of(context);

    return Material(
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: financialColors.cardBorder, width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AccountDetailScreen.forAccount(account: acc),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primaryEmerald.withAlpha(
                        isDark ? 40 : 25,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      acc.accountType.icon,
                      color: AppColors.primaryEmerald,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                acc.accountName,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (acc.isDefault) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryEmerald.withAlpha(
                                    isDark ? 40 : 25,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Primary',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryEmerald,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${acc.bankName} • ${acc.accountType.displayName}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: financialColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        CurrencyFormatter.format(acc.currentBalance),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: acc.currentBalance >= 0
                              ? financialColors.income
                              : financialColors.expense,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurfaceVariant
                          : AppColors.lightSurfaceVariant,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: financialColors.cardBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.label_outline_rounded,
                          size: 12,
                          color: financialColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          acc.usedFor,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                        icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                        label: const Text('Transfer'),
                        onPressed: () => AccountTransferSheet.show(
                          context,
                          fromAccount: acc,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        onPressed: () =>
                            AddEditBankAccountSheet.show(context, account: acc),
                        tooltip: 'Edit Account',
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreditCardsTab(
    BuildContext context,
    List<CreditCardEntity> cards,
    CombinedCreditSummary creditSummary,
    bool isDark,
    AppFinancialColors financialColors,
  ) {
    final theme = Theme.of(context);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Combined Credit Hero Card
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1E1B4B),
                    Color(0xFF0F172A),
                    Color(0xFF020617),
                  ],
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: const Color(0xFF6366F1).withAlpha(80),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Flexible(
                        child: Text(
                          'TOTAL CREDIT UTILIZATION',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: Colors.white70,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: creditSummary.overallHealth.color.withAlpha(
                            40,
                          ),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: creditSummary.overallHealth.color.withAlpha(
                              100,
                            ),
                          ),
                        ),
                        child: Text(
                          '${creditSummary.overallUtilizationRatio.toStringAsFixed(0)}% • ${creditSummary.overallHealth.displayName}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: creditSummary.overallHealth.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        CurrencyFormatter.format(creditSummary.totalUsed),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '/ ${CurrencyFormatter.format(creditSummary.totalLimit)} Limit',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (creditSummary.overallUtilizationRatio / 100)
                          .clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        creditSummary.overallHealth.color,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(
                            Icons.credit_score_rounded,
                            size: 18,
                          ),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Pay Card Bill'),
                          ),
                          onPressed: () => PayCreditCardSheet.show(context),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.investment,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Add Card'),
                          ),
                          onPressed: () => AddEditCreditCardSheet.show(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // Cards List Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: Text(
              'Your Credit Cards (${cards.length})',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),

        // Credit Cards List or Empty State
        if (cards.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.credit_card_outlined,
                      size: 48,
                      color: financialColors.textMuted,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'No Credit Cards Added',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Add your credit cards to track statement billing dates, grace periods, and stay under the 30% credit limit rule.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: financialColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () => AddEditCreditCardSheet.show(context),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add Your First Credit Card'),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final card = cards[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildCreditCardItem(
                    context,
                    card,
                    isDark,
                    financialColors,
                  ),
                );
              }, childCount: cards.length),
            ),
          ),
      ],
    );
  }

  Widget _buildCreditCardItem(
    BuildContext context,
    CreditCardEntity card,
    bool isDark,
    AppFinancialColors financialColors,
  ) {
    final theme = Theme.of(context);
    final ratio = card.utilizationRatio;

    List<Color> gradientColors;
    switch (card.cardTheme) {
      case 'emerald':
        gradientColors = [
          const Color(0xFF065F46),
          const Color(0xFF047857),
          const Color(0xFF064E3B),
        ];
        break;
      case 'midnightBlue':
        gradientColors = [
          const Color(0xFF1E3A8A),
          const Color(0xFF1E40AF),
          const Color(0xFF0F172A),
        ];
        break;
      case 'royalPurple':
        gradientColors = [
          const Color(0xFF581C87),
          const Color(0xFF6B21A8),
          const Color(0xFF3B0764),
        ];
        break;
      case 'roseGold':
        gradientColors = [
          const Color(0xFF9D174D),
          const Color(0xFFBE185D),
          const Color(0xFF831843),
        ];
        break;
      case 'obsidian':
      default:
        gradientColors = [
          const Color(0xFF1E293B),
          const Color(0xFF0F172A),
          const Color(0xFF020617),
        ];
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(60),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AccountDetailScreen.forCard(card: card),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            card.bankName.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            card.cardName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      card.cardNetwork.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CURRENT DUES',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                            ),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              CurrencyFormatter.format(card.currentDues),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (card.excessCredit > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Advance: +${CurrencyFormatter.format(card.excessCredit)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF10B981),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'AVAILABLE LIMIT',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                            ),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              CurrencyFormatter.format(card.availableLimit),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (ratio / 100).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      card.utilizationHealth.color,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.event_repeat_rounded,
                          size: 14,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Bill day: ${card.statementDateDay}th • Due in ${card.daysUntilDue()}d',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            backgroundColor: Colors.white24,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () =>
                              PayCreditCardSheet.show(context, card: card),
                          child: const Text(
                            'Pay Bill',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: Colors.white70,
                            size: 16,
                          ),
                          onPressed: () =>
                              AddEditCreditCardSheet.show(context, card: card),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCashTab(
    BuildContext context,
    List<BankAccountEntity> cashAccounts,
    double totalCash,
    BankAccountEntity? defaultBank,
    BankAccountEntity? primaryCash,
    bool isDark,
    AppFinancialColors financialColors,
  ) {
    final theme = Theme.of(context);
    final isDeficit = totalCash < 0;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Cash in Hand Hero Card
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [const Color(0xFF0D251C), const Color(0xFF14241B)]
                      : [const Color(0xFFE8FDF3), const Color(0xFFF0FDF5)],
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: (isDeficit
                          ? financialColors.expense
                          : AppColors.primaryEmerald)
                      .withAlpha(isDark ? 80 : 50),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.payments_rounded,
                              size: 16,
                              color: isDeficit
                                  ? financialColors.expense
                                  : AppColors.primaryEmerald,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'TOTAL CASH IN HAND',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                  color: financialColors.textMuted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: (isDeficit
                                  ? financialColors.expense
                                  : AppColors.primaryEmerald)
                              .withAlpha(isDark ? 40 : 25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isDeficit
                              ? 'Deficit'
                              : '${cashAccounts.length} Wallet${cashAccounts.length == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDeficit
                                ? financialColors.expense
                                : AppColors.primaryEmerald,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      CurrencyFormatter.format(totalCash),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isDeficit
                            ? financialColors.expense
                            : financialColors.income,
                      ),
                    ),
                  ),
                  if (isDeficit) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Cash spending exceeds recorded cash balance. Log an ATM withdrawal or adjust balance.',
                      style: TextStyle(
                        fontSize: 12,
                        color: financialColors.expense,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Row 1: ATM Withdrawal (Bank -> Cash) & Deposit (Cash -> Bank)
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: 11,
                              horizontal: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.local_atm_rounded, size: 18),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('ATM Withdraw'),
                          ),
                          onPressed: () {
                            if (defaultBank == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please add a bank account first to withdraw cash from.',
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }
                            AccountTransferSheet.show(
                              context,
                              fromAccount: defaultBank,
                              toAccount: primaryCash,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: 11,
                              horizontal: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.upload_rounded, size: 18),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Deposit to Bank'),
                          ),
                          onPressed: () {
                            if (defaultBank == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please add a bank account first to deposit cash into.',
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }
                            AccountTransferSheet.show(
                              context,
                              fromAccount: primaryCash,
                              toAccount: defaultBank,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Row 2: + Cash In, - Cash Out, Adjust Balance
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primaryEmerald,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 11,
                              horizontal: 6,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Cash In',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          onPressed: () => AddEditTransactionSheet.show(
                            context,
                            initialType: TransactionType.income,
                            initialPaymentMode: PaymentMode.cash,
                            initialAccountId: primaryCash?.id,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            backgroundColor: financialColors.expense.withAlpha(
                              isDark ? 40 : 25,
                            ),
                            foregroundColor: financialColors.expense,
                            padding: const EdgeInsets.symmetric(
                              vertical: 11,
                              horizontal: 6,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.remove_rounded, size: 18),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Cash Out',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          onPressed: () => AddEditTransactionSheet.show(
                            context,
                            initialType: TransactionType.expense,
                            initialPaymentMode: PaymentMode.cash,
                            initialAccountId: primaryCash?.id,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder,
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 11,
                              horizontal: 6,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.tune_rounded, size: 16),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Adjust'),
                          ),
                          onPressed: () => AddEditCashAccountSheet.show(
                            context,
                            account: primaryCash,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // Cash Wallets List Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Physical Cash Wallets (${cashAccounts.length})',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Wallet'),
                  onPressed: () => AddEditCashAccountSheet.show(context),
                ),
              ],
            ),
          ),
        ),

        // Wallets Cards
        if (cashAccounts.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurfaceVariant
                      : AppColors.lightSurfaceVariant,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: financialColors.cardBorder),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.payments_rounded,
                      size: 44,
                      color: AppColors.primaryEmerald.withAlpha(180),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No Cash Wallet Set Up',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Keep track of physical money in your wallet, pocket, or home cash drawer.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: financialColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryEmerald,
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add Cash in Hand'),
                      onPressed: () => AddEditCashAccountSheet.show(context),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final wallet = cashAccounts[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildCashWalletCard(
                      context,
                      wallet,
                      isDark,
                      financialColors,
                    ),
                  );
                },
                childCount: cashAccounts.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCashWalletCard(
    BuildContext context,
    BankAccountEntity wallet,
    bool isDark,
    AppFinancialColors financialColors,
  ) {
    final theme = Theme.of(context);
    final isDeficit = wallet.currentBalance < 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (ctx) => AccountDetailScreen.forAccount(
                account: wallet,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkSurfaceVariant
                : AppColors.lightSurfaceVariant,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: financialColors.cardBorder,
              width: 1.2,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primaryEmerald.withAlpha(
                        isDark ? 40 : 25,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.payments_rounded,
                      color: AppColors.primaryEmerald,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          wallet.accountName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryEmerald.withAlpha(
                              isDark ? 30 : 20,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            wallet.usedFor,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryEmerald,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            CurrencyFormatter.format(wallet.currentBalance),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: isDeficit
                                  ? financialColors.expense
                                  : financialColors.income,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    icon: const Icon(Icons.tune_rounded, size: 15),
                    label: const Text(
                      'Adjust Balance',
                      style: TextStyle(fontSize: 12),
                    ),
                    onPressed: () => AddEditCashAccountSheet.show(
                      context,
                      account: wallet,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    icon: const Icon(Icons.swap_horiz_rounded, size: 15),
                    label: const Text(
                      'Transfer',
                      style: TextStyle(fontSize: 12),
                    ),
                    onPressed: () => AccountTransferSheet.show(
                      context,
                      fromAccount: wallet,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
