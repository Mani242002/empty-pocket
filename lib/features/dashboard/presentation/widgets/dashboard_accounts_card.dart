import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/calculation/financial_calculator.dart';
import '../../../../core/domain/entities/bank_account_entity.dart';
import '../../../../core/domain/entities/credit_card_entity.dart';
import '../../../../core/utilities/currency_formatter.dart';
import '../../../accounts/presentation/screens/accounts_cards_screen.dart';
import '../../../accounts/presentation/screens/account_transfer_sheet.dart';
import '../../../accounts/presentation/screens/pay_credit_card_sheet.dart';

class DashboardAccountsCard extends StatelessWidget {
  final List<BankAccountEntity> bankAccounts;
  final List<CreditCardEntity> creditCards;
  final double combinedCash;
  final CombinedCreditSummary creditSummary;

  const DashboardAccountsCard({
    super.key,
    required this.bankAccounts,
    required this.creditCards,
    required this.combinedCash,
    required this.creditSummary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final financialColors = context.financialColors;
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.account_balance_wallet_rounded, color: AppColors.primaryEmerald, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Accounts & Cards',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Manage'),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AccountsCardsScreen()),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Bank Accounts Metric Box
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AccountsCardsScreen(initialTabIndex: 0),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: financialColors.cardBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'BANK ACCOUNTS',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: financialColors.textMuted,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const Icon(Icons.account_balance_rounded, size: 14, color: AppColors.primaryEmerald),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                CurrencyFormatter.format(combinedCash),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: combinedCash >= 0 ? financialColors.income : financialColors.expense,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${bankAccounts.length} Accounts active',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: financialColors.textMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Credit Cards Metric Box
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AccountsCardsScreen(initialTabIndex: 1),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: financialColors.cardBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'CREDIT CARDS',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: financialColors.textMuted,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const Icon(Icons.credit_card_rounded, size: 14, color: Color(0xFF6366F1)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                CurrencyFormatter.format(creditSummary.totalUsed),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: creditSummary.totalUsed > 0 ? const Color(0xFF6366F1) : null,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                creditCards.isNotEmpty
                                    ? '${creditSummary.overallUtilizationRatio.toStringAsFixed(0)}% limit used'
                                    : 'No cards added',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: creditCards.isNotEmpty ? creditSummary.overallHealth.color : financialColors.textMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (bankAccounts.isNotEmpty || creditCards.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                        label: const Text('Transfer', style: TextStyle(fontSize: 12)),
                        onPressed: () => AccountTransferSheet.show(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.credit_score_rounded, size: 16),
                        label: const Text('Pay Card', style: TextStyle(fontSize: 12)),
                        onPressed: () => PayCreditCardSheet.show(context),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
