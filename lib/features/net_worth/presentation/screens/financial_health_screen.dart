import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/entities/financial_health_entity.dart';
import '../../../../core/utilities/currency_formatter.dart';
import '../state/net_worth_provider.dart';

class FinancialHealthScreen extends ConsumerWidget {
  const FinancialHealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final financialColors = context.financialColors;
    final isDark = theme.brightness == Brightness.dark;

    final healthSummary = ref.watch(financialHealthSummaryProvider);
    final netWorth = healthSummary.netWorth;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Health & Net Worth'),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
        children: [
          // 1. Health Score Gauge Hero Card
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                    : [const Color(0xFFF8FAFC), const Color(0xFFFFFFFF)],
              ),
              border: Border.all(
                color: healthSummary.grade.color.withAlpha(isDark ? 80 : 50),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: healthSummary.grade.color.withAlpha(isDark ? 20 : 10),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'FINANCIAL HEALTH SCORE',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: financialColors.textMuted,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: healthSummary.grade.color.withAlpha(isDark ? 40 : 25),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: healthSummary.grade.color.withAlpha(isDark ? 90 : 50),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(healthSummary.grade.icon, color: healthSummary.grade.color, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            healthSummary.grade.displayName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: healthSummary.grade.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Radial Score Meter
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 130,
                      height: 130,
                      child: CircularProgressIndicator(
                        value: healthSummary.overallScore / 100,
                        strokeWidth: 10,
                        backgroundColor: isDark
                            ? AppColors.darkSurfaceVariant
                            : AppColors.lightSurfaceVariant,
                        valueColor: AlwaysStoppedAnimation<Color>(healthSummary.grade.color),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${healthSummary.overallScore}',
                          style: theme.textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.0,
                            color: healthSummary.grade.color,
                          ),
                        ),
                        Text(
                          'OUT OF 100',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: financialColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  _getGradeDescription(healthSummary.grade),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Consolidated Net Worth Hero Card
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [const Color(0xFF064E3B), const Color(0xFF131B26)]
                    : [const Color(0xFFECFDF5), const Color(0xFFFFFFFF)],
              ),
              border: Border.all(
                color: isDark ? AppColors.income.withAlpha(70) : AppColors.income.withAlpha(50),
                width: 1.5,
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'CONSOLIDATED NET WORTH',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: financialColors.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (netWorth.isPositive ? financialColors.income : financialColors.expense)
                            .withAlpha(isDark ? 40 : 25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        netWorth.isPositive ? 'SOLVENT' : 'LIABILITIES EXCEED ASSETS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: netWorth.isPositive ? financialColors.income : financialColors.expense,
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
                    CurrencyFormatter.format(netWorth.netWorth),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: netWorth.isPositive ? financialColors.income : financialColors.expense,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Assets vs Liabilities Row
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface.withAlpha(150) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: financialColors.cardBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'TOTAL ASSETS',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: financialColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 4),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  CurrencyFormatter.format(netWorth.totalAssets),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: financialColors.income,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface.withAlpha(150) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: financialColors.cardBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'TOTAL LIABILITIES',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: financialColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 4),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  CurrencyFormatter.format(netWorth.totalLiabilities),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: netWorth.totalLiabilities > 0
                                        ? financialColors.expense
                                        : financialColors.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Asset Composition Progress Bar
                if (netWorth.totalAssets > 0) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      height: 10,
                      child: Row(
                        children: [
                          if (netWorth.cashPercentage > 0)
                            Expanded(
                              flex: (netWorth.cashPercentage * 10).round().clamp(1, 1000),
                              child: Container(color: AppColors.income),
                            ),
                          if (netWorth.savingsPercentage > 0)
                            Expanded(
                              flex: (netWorth.savingsPercentage * 10).round().clamp(1, 1000),
                              child: Container(color: AppColors.savings),
                            ),
                          if (netWorth.investmentsPercentage > 0)
                            Expanded(
                              flex: (netWorth.investmentsPercentage * 10).round().clamp(1, 1000),
                              child: Container(color: AppColors.investment),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      _buildCompositionLegend('Liquid Cash', netWorth.cashPercentage, AppColors.income),
                      _buildCompositionLegend('Savings Goals', netWorth.savingsPercentage, AppColors.savings),
                      _buildCompositionLegend('Investments', netWorth.investmentsPercentage, AppColors.investment),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3. Four Financial Health Pillars
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Text(
              '4 Pillars of Financial Fitness',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
          _buildPillarCard(context, healthSummary.emergencyBufferPillar),
          const SizedBox(height: 10),
          _buildPillarCard(context, healthSummary.savingsRatePillar),
          const SizedBox(height: 10),
          _buildPillarCard(context, healthSummary.debtBurdenPillar),
          const SizedBox(height: 10),
          _buildPillarCard(context, healthSummary.diversificationPillar),
          const SizedBox(height: 20),

          // 4. Actionable Financial Health Insights
          if (healthSummary.actionableTips.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text(
                'Personalized Recommendations',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: healthSummary.actionableTips.map((tip) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primaryEmerald.withAlpha(isDark ? 40 : 25),
                            ),
                            child: const Icon(
                              Icons.lightbulb_outline_rounded,
                              color: AppColors.primaryEmerald,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              tip,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                height: 1.4,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // 5. Assets vs Liabilities Audit Breakdown Table
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Text(
              'Complete Balance Sheet',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  _buildBalanceSheetRow(
                    context,
                    'Liquid Cash & Accounts',
                    netWorth.cashBalance,
                    isAsset: true,
                    icon: Icons.account_balance_wallet_rounded,
                    color: AppColors.income,
                  ),
                  const Divider(height: 20),
                  _buildBalanceSheetRow(
                    context,
                    'Savings & Emergency Reserves',
                    netWorth.savingsGoalsAmount,
                    isAsset: true,
                    icon: Icons.savings_rounded,
                    color: AppColors.savings,
                  ),
                  const Divider(height: 20),
                  _buildBalanceSheetRow(
                    context,
                    'Investments & Market Assets',
                    netWorth.investmentsAmount,
                    isAsset: true,
                    icon: Icons.trending_up_rounded,
                    color: AppColors.investment,
                  ),
                  const Divider(height: 20),
                  _buildBalanceSheetRow(
                    context,
                    'Total Liabilities (Loans & Debts)',
                    netWorth.totalLiabilities,
                    isAsset: false,
                    icon: Icons.account_balance_rounded,
                    color: AppColors.expense,
                  ),
                  const Divider(height: 24, thickness: 1.5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Net Worth:',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            CurrencyFormatter.format(netWorth.netWorth),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: netWorth.isPositive ? financialColors.income : financialColors.expense,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompositionLegend(String label, double percentage, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 4),
        Text(
          '$label: ${percentage.toStringAsFixed(0)}%',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildPillarCard(BuildContext context, HealthPillarScore pillar) {
    final theme = Theme.of(context);
    final financialColors = context.financialColors;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: financialColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: pillar.color.withAlpha(isDark ? 40 : 25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(pillar.icon, color: pillar.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pillar.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      pillar.statusText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: financialColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${pillar.score}/${pillar.maxScore}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: pillar.color,
                    ),
                  ),
                  Text(
                    'pts',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: financialColors.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pillar.percentage / 100,
              minHeight: 6,
              backgroundColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(pillar.color),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            pillar.tip,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceSheetRow(
    BuildContext context,
    String title,
    double amount, {
    required bool isAsset,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final financialColors = context.financialColors;

    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text(
            '${isAsset ? '+' : '-'}${CurrencyFormatter.format(amount)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: isAsset ? financialColors.income : (amount > 0 ? financialColors.expense : financialColors.textMuted),
            ),
          ),
        ),
      ],
    );
  }

  String _getGradeDescription(HealthGrade grade) {
    switch (grade) {
      case HealthGrade.excellent:
        return 'Your financial fitness is in the top tier! You have robust emergency reserves, healthy savings habits, low debt, and diversified assets.';
      case HealthGrade.strong:
        return 'You have a solid financial foundation with strong cash flow retention and manageable liabilities. Keep optimizing your asset spread.';
      case HealthGrade.moderate:
        return 'Your financial health is on track, but there is room for improvement in emergency buffers, debt management, or asset diversification.';
      case HealthGrade.needsAttention:
        return 'Your financial profile shows high liability exposure or insufficient emergency reserves. Review our personalized action tips below.';
    }
  }
}
