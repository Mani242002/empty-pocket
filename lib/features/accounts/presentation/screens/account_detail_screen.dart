import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/entities/bank_account_entity.dart';
import '../../../../core/domain/entities/credit_card_entity.dart';
import '../../../../core/utilities/currency_formatter.dart';
import '../../../transactions/presentation/screens/add_edit_transaction_sheet.dart';
import '../../../transactions/presentation/state/transactions_provider.dart';
import '../../../transactions/presentation/widgets/transaction_list_item.dart';
import 'account_transfer_sheet.dart';
import 'add_edit_bank_account_sheet.dart';
import 'add_edit_credit_card_sheet.dart';
import 'pay_credit_card_sheet.dart';
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

            // Section Title
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Account Activity (${filteredTransactions.length})',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
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
                      )
                    else
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                        label: const Text('Transfer'),
                        onPressed: () => AccountTransferSheet.show(context, fromAccount: liveAccount),
                      ),
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
                          onTap: () => AddEditTransactionSheet.show(
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

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E293B),
            const Color(0xFF0F172A),
            const Color(0xFF020617),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF6366F1).withAlpha(80), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                card.bankName.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CURRENT DUES / OUTSTANDING',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withAlpha(160),
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    CurrencyFormatter.format(card.usedAmount),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: card.utilizationHealth.color.withAlpha(50),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: card.utilizationHealth.color.withAlpha(100)),
                ),
                child: Text(
                  '${ratio.toStringAsFixed(0)}% Used • ${card.utilizationHealth.displayName}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: card.utilizationHealth.color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (ratio / 100).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(card.utilizationHealth.color),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Available: ${CurrencyFormatter.format(card.availableLimit)} / ${CurrencyFormatter.format(card.creditLimit)}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withAlpha(200),
                ),
              ),
              Text(
                'Due in ${card.daysUntilDue()} days',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
