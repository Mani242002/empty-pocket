import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/entities/bank_account_entity.dart';
import '../../../../core/domain/entities/credit_card_entity.dart';
import '../../../../core/utilities/currency_formatter.dart';
import '../../../transactions/presentation/screens/transaction_detail_sheet.dart';
import '../../../transactions/presentation/state/transactions_provider.dart';
import '../../../transactions/presentation/widgets/transaction_list_item.dart';
import 'account_transfer_sheet.dart';
import 'add_edit_bank_account_sheet.dart';
import 'add_edit_credit_card_sheet.dart';
import 'pay_credit_card_sheet.dart';
import 'smart_inflow_distribution_sheet.dart';
import '../../../../core/domain/entities/savings_goal_entity.dart';
import '../../../savings/presentation/state/savings_goals_provider.dart';
import '../../../savings/presentation/screens/add_edit_savings_goal_sheet.dart';
import '../state/accounts_cards_provider.dart';

class AccountDetailScreen extends ConsumerWidget {
  final BankAccountEntity? bankAccount;
  final CreditCardEntity? creditCard;

  const AccountDetailScreen.forAccount({
    super.key,
    required BankAccountEntity account,
  })  : bankAccount = account,
        creditCard = null;

  const AccountDetailScreen.forCard({
    super.key,
    required CreditCardEntity card,
  })  : creditCard = card,
        bankAccount = null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final financialColors = context.financialColors;
    final isDark = theme.brightness == Brightness.dark;

    final allTransactionsAsync = ref.watch(transactionListNotifierProvider);
    final allTransactions = allTransactionsAsync.valueOrNull ?? [];

    final liveAccounts = ref.watch(activeBankAccountsProvider);
    final liveCards = ref.watch(activeCreditCardsProvider);

    final liveAccount = bankAccount != null
        ? liveAccounts.firstWhere((a) => a.id == bankAccount!.id, orElse: () => bankAccount!)
        : null;
    final liveCard = creditCard != null
        ? liveCards.firstWhere((c) => c.id == creditCard!.id, orElse: () => creditCard!)
        : null;

    final allGoals = ref.watch(savingsGoalsListNotifierProvider).valueOrNull ?? [];
    final linkedGoals = liveAccount != null
        ? allGoals.where((g) => g.linkedAccountId == liveAccount.id).toList()
        : <SavingsGoalEntity>[];

    // Filter transactions linked to this account or card
    final filteredTransactions = allTransactions.where((tx) {
      if (liveAccount != null) {
        return tx.accountId == liveAccount.id ||
            tx.toAccountId == liveAccount.id ||
            tx.paymentSource.toLowerCase() == liveAccount.accountName.toLowerCase();
      } else if (liveCard != null) {
        return tx.creditCardId == liveCard.id ||
            tx.paymentSource.toLowerCase() == liveCard.cardName.toLowerCase();
      }
      return false;
    }).toList();

    final isCard = liveCard != null;
    final title = isCard ? liveCard.cardName : (liveAccount?.accountName ?? 'Account');

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: () {
              if (isCard) {
                AddEditCreditCardSheet.show(context, card: liveCard);
              } else if (liveAccount != null) {
                AddEditBankAccountSheet.show(context, account: liveAccount);
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Account / Card Hero Summary
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: isCard
                    ? _buildCardHero(context, liveCard, isDark, financialColors)
                    : _buildAccountHero(context, liveAccount!, isDark, financialColors),
              ),
            ),

            // Linked Goals & Allocations Card (if any exist)
            if (linkedGoals.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: _buildLinkedGoalsCard(context, ref, liveAccount!, linkedGoals, isDark, financialColors),
                ),
              ),

            // Section Title
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Account Activity (${filteredTransactions.length})',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isCard)
                          FilledButton.tonalIcon(
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            icon: const Icon(Icons.credit_score_rounded, size: 16),
                            label: const Text('Pay Bill'),
                            onPressed: () => PayCreditCardSheet.show(context, card: liveCard),
                          ),
                      ],
                    ),
                    if (!isCard) ...[
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            FilledButton.tonalIcon(
                              style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              icon: const Icon(Icons.pie_chart_rounded, size: 16),
                              label: const Text('Smart Split'),
                              onPressed: () => SmartInflowDistributionSheet.show(context, account: liveAccount!),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.tonalIcon(
                              style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                              label: const Text('Transfer'),
                              onPressed: () => AccountTransferSheet.show(context, fromAccount: liveAccount),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Transactions List
            if (filteredTransactions.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 48,
                          color: financialColors.textMuted,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No Transactions Yet',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Transactions charged to or deposited into this ${isCard ? "card" : "account"} will appear here.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: financialColors.textMuted,
                          ),
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
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final tx = filteredTransactions[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: TransactionListItem(
                          transaction: tx,
                          onTap: () => TransactionDetailSheet.show(
                            context,
                            transaction: tx,
                          ),
                          onDelete: () => ref
                              .read(transactionListNotifierProvider.notifier)
                              .deleteTransaction(tx.id),
                        ),
                      );
                    },
                    childCount: filteredTransactions.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountHero(
    BuildContext context,
    BankAccountEntity acc,
    bool isDark,
    AppFinancialColors financialColors,
  ) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: financialColors.cardBorder, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryEmerald.withAlpha(isDark ? 40 : 25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(acc.accountType.icon, color: AppColors.primaryEmerald, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        acc.bankName,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: financialColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        acc.accountType.displayName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryEmerald.withAlpha(isDark ? 40 : 25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  acc.usedFor,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryEmerald,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'CURRENT BALANCE',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: financialColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            CurrencyFormatter.format(acc.currentBalance),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: acc.currentBalance >= 0 ? financialColors.income : financialColors.expense,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardHero(
    BuildContext context,
    CreditCardEntity card,
    bool isDark,
    AppFinancialColors financialColors,
  ) {
    final theme = Theme.of(context);
    final ratio = card.utilizationRatio;
    final hasExcess = card.excessCredit > 0;

    List<Color> gradientColors;
    Color accentGlow;
    switch (card.cardTheme) {
      case 'emerald':
        gradientColors = [const Color(0xFF064E3B), const Color(0xFF047857), const Color(0xFF0F172A)];
        accentGlow = const Color(0xFF10B981);
        break;
      case 'midnightBlue':
        gradientColors = [const Color(0xFF1E3A8A), const Color(0xFF1E40AF), const Color(0xFF0F172A)];
        accentGlow = const Color(0xFF38BDF8);
        break;
      case 'royalPurple':
        gradientColors = [const Color(0xFF581C87), const Color(0xFF6B21A8), const Color(0xFF1E1B4B)];
        accentGlow = const Color(0xFFA855F7);
        break;
      case 'roseGold':
        gradientColors = [const Color(0xFF831843), const Color(0xFF9D174D), const Color(0xFF500724)];
        accentGlow = const Color(0xFFFB7185);
        break;
      case 'obsidian':
      default:
        gradientColors = [const Color(0xFF1E293B), const Color(0xFF0F172A), const Color(0xFF020617)];
        accentGlow = const Color(0xFF6366F1);
    }

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withAlpha(isDark ? 40 : 60),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: accentGlow.withAlpha(isDark ? 45 : 30),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 80 : 40),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Bank Name, Contactless icon, and Network Name
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 32,
                    height: 22,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFD4AF37), Color(0xFFFFDF73), Color(0xFFAA771C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.developer_board_rounded, size: 14, color: Colors.black54),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    card.bankName.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.contactless_rounded, color: Colors.white70, size: 18),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(30),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      card.cardNetwork.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Row 2: Outstanding Dues & Utilization/Excess Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CURRENT DUES / OUTSTANDING',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withAlpha(170),
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        CurrencyFormatter.format(card.currentDues),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (hasExcess)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withAlpha(45),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF10B981).withAlpha(140)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF10B981)),
                      const SizedBox(width: 5),
                      Text(
                        'Excess: +${CurrencyFormatter.format(card.excessCredit)}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: card.utilizationHealth.color.withAlpha(45),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: card.utilizationHealth.color.withAlpha(120)),
                    ),
                    child: Text(
                      '${ratio.toStringAsFixed(0)}% • ${card.utilizationHealth.shortDisplayName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: card.utilizationHealth.color,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (ratio / 100).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(
                hasExcess ? const Color(0xFF10B981) : card.utilizationHealth.color,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Row 3: Available Limit & Due Date metrics (Spacious 2-column layout)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AVAILABLE LIMIT',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withAlpha(160),
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        CurrencyFormatter.format(card.availableLimit),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Total Limit: ${CurrencyFormatter.format(card.creditLimit)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withAlpha(140),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'PAYMENT DUE',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withAlpha(160),
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        card.currentDues <= 0
                            ? 'No Dues'
                            : (card.daysUntilDue() == 0 ? 'Due Today' : 'In ${card.daysUntilDue()} days'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: card.currentDues <= 0
                              ? const Color(0xFF10B981)
                              : (card.daysUntilDue() <= 3 ? const Color(0xFFEF4444) : const Color(0xFFF59E0B)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Bill Day: ${card.statementDateDay}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withAlpha(140),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLinkedGoalsCard(
    BuildContext context,
    WidgetRef ref,
    BankAccountEntity account,
    List<SavingsGoalEntity> goals,
    bool isDark,
    AppFinancialColors financialColors,
  ) {
    final theme = Theme.of(context);
    final totalAllocatedPercent = goals.fold<double>(0.0, (sum, g) => sum + g.allocationPercentage);
    final idlePercent = (100.0 - totalAllocatedPercent).clamp(0.0, 100.0);
    final idleAmount = account.currentBalance * (idlePercent / 100.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: financialColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.track_changes_rounded, size: 18, color: AppColors.savings),
                  const SizedBox(width: 8),
                  Text(
                    'LINKED GOALS & ALLOCATIONS',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: financialColors.textMuted,
                    ),
                  ),
                ],
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.sync_rounded, size: 18, color: AppColors.primaryEmerald),
                tooltip: 'Sync Goals with Balance',
                onPressed: () async {
                  await ref.read(savingsGoalsListNotifierProvider.notifier).syncGoalsForAccount(account.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Synced goal progress with current account balance.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...goals.map((goal) {
            final allocatedAmt = account.currentBalance * (goal.allocationPercentage / 100.0);
            return InkWell(
              onTap: () => AddEditSavingsGoalSheet.show(context, goal: goal),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.savings.withAlpha(isDark ? 50 : 30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${goal.allocationPercentage.toInt()}%',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.savings,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            goal.title,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Target: ${CurrencyFormatter.format(goal.targetAmount)} • Synced: ${CurrencyFormatter.format(goal.currentAmount)}',
                            style: TextStyle(fontSize: 11, color: financialColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      CurrencyFormatter.format(allocatedAmt),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            );
          }),
          if (idlePercent > 0) ...[
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.nightlight_round, size: 14, color: AppColors.info),
                    const SizedBox(width: 6),
                    Text(
                      'Idle Buffer (${idlePercent.toInt()}% unallocated)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: financialColors.textMuted),
                    ),
                  ],
                ),
                Text(
                  CurrencyFormatter.format(idleAmount),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.info),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
