import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/entities/bank_account_entity.dart';
import '../../../../core/utilities/currency_formatter.dart';
import '../../../savings/presentation/state/savings_goals_provider.dart';

/// Sheet for distributing inflows into multi-purpose accounts
/// (e.g. Distribute SBI deposit into Mutual Funds, Insurance Premiums, and idle buffer)
class SmartInflowDistributionSheet extends ConsumerStatefulWidget {
  final BankAccountEntity account;

  const SmartInflowDistributionSheet({
    super.key,
    required this.account,
  });

  static Future<void> show(BuildContext context, {required BankAccountEntity account}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SmartInflowDistributionSheet(account: account),
    );
  }

  @override
  ConsumerState<SmartInflowDistributionSheet> createState() => _SmartInflowDistributionSheetState();
}

class _SmartInflowDistributionSheetState extends ConsumerState<SmartInflowDistributionSheet> {
  late TextEditingController _amountController;
  double _primaryPercent = 60.0;
  double _secondaryPercent = 30.0;

  @override
  void initState() {
    super.initState();
    final bal = widget.account.currentBalance;
    _amountController = TextEditingController(
      text: bal > 0 ? (bal == bal.roundToDouble() ? bal.toInt().toString() : bal.toStringAsFixed(2)) : '50000',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  double get _idlePercent {
    final remaining = 100.0 - (_primaryPercent + _secondaryPercent);
    return remaining.clamp(0.0, 100.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final financialColors = context.financialColors;
    final isDark = theme.brightness == Brightness.dark;

    final totalAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final primaryAmount = totalAmount * (_primaryPercent / 100.0);
    final secondaryAmount = totalAmount * (_secondaryPercent / 100.0);
    final idleAmount = totalAmount * (_idlePercent / 100.0);

    final isMultiPurpose = widget.account.usedFor.toLowerCase().contains('insurance') ||
        widget.account.usedFor.toLowerCase().contains('investment');

    final primaryLabel = isMultiPurpose ? 'Investments & SIPs' : 'Primary Purpose (${widget.account.usedFor})';
    final secondaryLabel = isMultiPurpose ? 'Insurance Premiums' : 'Secondary Goal / Buffer';

    return Material(
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
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
                const SizedBox(height: 16),

                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.investment.withAlpha(isDark ? 60 : 35),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.pie_chart_rounded, color: AppColors.investment, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Smart Inflow Distribution',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${widget.account.accountName} • ${widget.account.usedFor}',
                            style: TextStyle(
                              fontSize: 12,
                              color: financialColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Total Inflow Amount Field
                Text(
                  'AMOUNT TO DISTRIBUTE',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: financialColors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: 'Enter deposit / inflow amount',
                    prefixIcon: const Icon(Icons.currency_rupee_rounded),
                    suffixIcon: TextButton(
                      onPressed: () {
                        setState(() {
                          final bal = widget.account.currentBalance;
                          _amountController.text = bal == bal.roundToDouble()
                              ? bal.toInt().toString()
                              : bal.toStringAsFixed(2);
                        });
                      },
                      child: const Text('Use Balance', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 20),

                // Quick Presets
                Row(
                  children: [
                    _buildPresetChip('60 / 30 / 10', 60, 30),
                    const SizedBox(width: 8),
                    _buildPresetChip('70 / 20 / 10', 70, 20),
                    const SizedBox(width: 8),
                    _buildPresetChip('50 / 40 / 10', 50, 40),
                    const SizedBox(width: 8),
                    _buildPresetChip('50 / 50', 50, 50),
                  ],
                ),
                const SizedBox(height: 20),

                // Primary Purpose Card
                _buildBucketCard(
                  title: primaryLabel,
                  percentage: _primaryPercent,
                  amount: primaryAmount,
                  color: AppColors.investment,
                  icon: Icons.trending_up_rounded,
                  onChanged: (val) {
                    setState(() {
                      _primaryPercent = val;
                      if (_primaryPercent + _secondaryPercent > 100) {
                        _secondaryPercent = 100 - _primaryPercent;
                      }
                    });
                  },
                ),
                const SizedBox(height: 14),

                // Secondary Purpose Card
                _buildBucketCard(
                  title: secondaryLabel,
                  percentage: _secondaryPercent,
                  amount: secondaryAmount,
                  color: AppColors.savings,
                  icon: Icons.shield_outlined,
                  onChanged: (val) {
                    setState(() {
                      _secondaryPercent = val;
                      if (_primaryPercent + _secondaryPercent > 100) {
                        _primaryPercent = 100 - _secondaryPercent;
                      }
                    });
                  },
                ),
                const SizedBox(height: 14),

                // Idle Cash / Buffer Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: financialColors.cardBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.info.withAlpha(isDark ? 50 : 30),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.nightlight_round, size: 20, color: AppColors.info),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Idle Cash Buffer (Sits Quiet in Account)',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              '${_idlePercent.toInt()}% unassigned reserve in ${widget.account.bankName}',
                              style: TextStyle(fontSize: 11, color: financialColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        CurrencyFormatter.format(idleAmount),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.info),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Action Button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryEmerald,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () async {
                      // Trigger goal sync for any linked goals
                      await ref.read(savingsGoalsListNotifierProvider.notifier).syncGoalsForAccount(widget.account.id);
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Smart distribution applied: ${CurrencyFormatter.format(primaryAmount)} to $primaryLabel, ${CurrencyFormatter.format(secondaryAmount)} to $secondaryLabel, ${CurrencyFormatter.format(idleAmount)} idle buffer.',
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    child: const Text(
                      'Apply Distribution Plan',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, double primary, double secondary) {
    final isSelected = _primaryPercent == primary && _secondaryPercent == secondary;
    return GestureDetector(
      onTap: () {
        setState(() {
          _primaryPercent = primary;
          _secondaryPercent = secondary;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryEmerald : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primaryEmerald : Colors.grey.withAlpha(80),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : null,
          ),
        ),
      ),
    );
  }

  Widget _buildBucketCard({
    required String title,
    required double percentage,
    required double amount,
    required Color color,
    required IconData icon,
    required ValueChanged<double> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final financialColors = context.financialColors;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: financialColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withAlpha(isDark ? 50 : 30),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${percentage.toInt()}% allocation',
                      style: TextStyle(fontSize: 11, color: financialColors.textMuted),
                    ),
                  ],
                ),
              ),
              Text(
                CurrencyFormatter.format(amount),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Slider(
            value: percentage,
            min: 0,
            max: 100,
            divisions: 20,
            activeColor: color,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
