import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/entities/category_constants.dart';
import '../../../../core/domain/entities/reports_entity.dart';
import '../../../../core/utilities/currency_formatter.dart';
import '../../../ai_assistant/presentation/screens/ai_assistant_screen.dart';
import '../../../ai_assistant/presentation/screens/ai_chat_screen.dart';
import '../../../ai_assistant/presentation/screens/ai_reports_screen.dart';
import '../../../ai_assistant/presentation/state/ai_assistant_provider.dart';
import '../../../transactions/presentation/state/transactions_provider.dart';
import '../state/reports_provider.dart';

class ReportsAnalyticsScreen extends ConsumerWidget {
  const ReportsAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final financialColors = context.financialColors;
    final isDark = theme.brightness == Brightness.dark;

    final trends = ref.watch(monthlyTrendsProvider);
    final forecast = ref.watch(cashFlowForecastProvider);
    final paymentSources = ref.watch(paymentSourceBreakdownProvider);
    final categoryBreakdown = ref.watch(monthlyCategoryBreakdownProvider);
    final aiConfig = ref.watch(aiProviderConfigProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        actions: [
          IconButton(
            icon: Icon(
              Icons.auto_awesome_rounded,
              color: aiConfig.isConfigured ? AppColors.primaryEmerald : AppColors.warning,
            ),
            tooltip: 'PocketAI Advisor',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AiAssistantScreen()),
              );
            },
          ),
        ],
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
        children: [
          // 1. AI Advisor Entry Card
          InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AiReportsScreen()),
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(16),
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
                  color: AppColors.primaryEmerald.withAlpha(isDark ? 70 : 40),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryEmerald.withAlpha(isDark ? 45 : 30),
                    ),
                    child: const Icon(Icons.description_outlined, color: AppColors.primaryEmerald, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Financial Reports & Audits',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          aiConfig.isConfigured
                              ? 'Generate & export comprehensive reports with ${aiConfig.providerType.displayName}'
                              : 'Private offline health audits with your Gemini or Groq key',
                          style: theme.textTheme.bodySmall?.copyWith(color: financialColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.primaryEmerald),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Quick Chat Launcher Card
          InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AiChatScreen()),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                border: Border.all(color: financialColors.cardBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primaryEmerald, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Chat with PocketAI Financial Advisor',
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.primaryEmerald),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 2. 6-Month Cash Flow Trend
          Text(
            '6-Month Cash Flow Trends',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(width: 10, height: 10, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.income)),
                          const SizedBox(width: 6),
                          const Text('Income', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 14),
                          Container(width: 10, height: 10, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.expense)),
                          const SizedBox(width: 6),
                          const Text('Expense', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      Text(
                        'MoM Overview',
                        style: TextStyle(fontSize: 11, color: financialColors.textMuted, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (trends.isEmpty || trends.every((t) => t.totalIncome == 0 && t.totalExpense == 0))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text('No historical transactions logged yet', style: TextStyle(color: financialColors.textMuted)),
                    )
                  else
                    ...trends.map((t) => _buildMonthTrendRow(context, t, isDark, financialColors)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 3. Category Spending Breakdown
          Text(
            'Top Expense Categories (This Month)',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (categoryBreakdown.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text('No expenses recorded this month', style: TextStyle(color: financialColors.textMuted)),
                ),
              ),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: categoryBreakdown.take(6).map((cat) {
                    final icon = CategoryConstants.getIconForCategory(cat.category);
                    final color = CategoryConstants.getColorForCategory(cat.category);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: color.withAlpha(isDark ? 40 : 25),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(icon, color: color, size: 16),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  cat.category,
                                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                              Text(
                                CurrencyFormatter.format(cat.amount),
                                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${cat.percentage.toStringAsFixed(0)}%',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: financialColors.textMuted),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: cat.percentage / 100,
                              minHeight: 6,
                              backgroundColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                              valueColor: AlwaysStoppedAnimation<Color>(color),
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

          // 4. Payment Methods Distribution
          if (paymentSources.isNotEmpty) ...[
            Text(
              'Payment Methods Used',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: paymentSources.map((p) {
                  return Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: financialColors.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.source,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: financialColors.textMuted),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          CurrencyFormatter.format(p.amount),
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          '${p.percentage.toStringAsFixed(1)}% of spending',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primaryEmerald),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // 5. 3-Month Forward Cash-Flow Forecast
          Text(
            '3-Month Forward Cash Flow Forecast',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Offline projection based on your recurring bills and active debt EMIs:',
                    style: theme.textTheme.bodySmall?.copyWith(color: financialColors.textMuted),
                  ),
                  const SizedBox(height: 14),
                  ...forecast.map((f) {
                    final monthName = DateFormat('MMMM yyyy').format(f.month);
                    final isPositive = f.projectedNetCash >= 0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: financialColors.cardBorder),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  monthName,
                                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  'Fixed Outflows: ${CurrencyFormatter.format(f.projectedFixedExpenses)}',
                                  style: theme.textTheme.bodySmall?.copyWith(color: financialColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${isPositive ? '+' : ''}${CurrencyFormatter.format(f.projectedNetCash)}/mo',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: isPositive ? financialColors.income : financialColors.expense,
                                ),
                              ),
                              Text(
                                'Est. Balance: ${CurrencyFormatter.format(f.projectedCumulativeBalance)}',
                                style: TextStyle(fontSize: 11, color: financialColors.textMuted, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthTrendRow(
    BuildContext context,
    MonthlyTrendData trend,
    bool isDark,
    dynamic financialColors,
  ) {
    final monthName = DateFormat('MMM yyyy').format(trend.month);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 75,
            child: Text(
              monthName,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '+${CurrencyFormatter.format(trend.totalIncome)}',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: financialColors.income),
                    ),
                    Text(
                      '-${CurrencyFormatter.format(trend.totalExpense)}',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: financialColors.expense),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Row(
                    children: [
                      Expanded(
                        flex: (trend.totalIncome).round().clamp(1, 1000000),
                        child: Container(height: 6, color: AppColors.income),
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        flex: (trend.totalExpense).round().clamp(1, 1000000),
                        child: Container(height: 6, color: AppColors.expense),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 65,
            child: Text(
              '${trend.savingsRate.toStringAsFixed(0)}% saved',
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: trend.isPositive ? financialColors.income : financialColors.expense,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
