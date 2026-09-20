import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/entities/ai_assistant_entity.dart';
import '../../../../core/utilities/app_haptics.dart';
import '../../../../core/utilities/currency_formatter.dart';
import '../state/ai_assistant_provider.dart';
import 'ai_report_detail_screen.dart';
import 'ai_settings_screen.dart';

class AiReportsScreen extends ConsumerStatefulWidget {
  const AiReportsScreen({super.key});

  @override
  ConsumerState<AiReportsScreen> createState() => _AiReportsScreenState();
}

class _AiReportsScreenState extends ConsumerState<AiReportsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _showNewReportModal(BuildContext context) {
    AppHaptics.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _NewReportBottomSheet(
        onSelectType: (type, customPrompt) {
          Navigator.pop(ctx);
          ref.read(aiReportsProvider.notifier).generateReport(
                type: type,
                customPrompt: customPrompt,
              );
        },
      ),
    );
  }

  void _showModelPickerSheet(BuildContext context, AiProviderConfig config) {
    final theme = Theme.of(context);
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
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.tune_rounded, color: AppColors.primaryEmerald, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'AI Provider & Model',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        avatar: const Icon(Icons.auto_awesome_rounded, size: 16),
                        label: const Center(child: Text('Google Gemini')),
                        selected: config.providerType == AiProviderType.gemini,
                        onSelected: (sel) {
                          if (sel) {
                            ref.read(aiProviderConfigProvider.notifier).updateProvider(AiProviderType.gemini);
                            Navigator.pop(ctx);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ChoiceChip(
                        avatar: const Icon(Icons.bolt_rounded, size: 16),
                        label: const Center(child: Text('Groq Cloud')),
                        selected: config.providerType == AiProviderType.groq,
                        onSelected: (sel) {
                          if (sel) {
                            ref.read(aiProviderConfigProvider.notifier).updateProvider(AiProviderType.groq);
                            Navigator.pop(ctx);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'SELECT MODEL',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
                const SizedBox(height: 8),
                ...config.providerType.modelOptions.map((opt) {
                  final isSelected = config.activeModel == opt.id;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryEmerald.withAlpha(isDark ? 40 : 25)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppColors.primaryEmerald : (isDark ? Colors.white10 : Colors.black12),
                      ),
                    ),
                    child: ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                      title: Text(
                        opt.displayName,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? AppColors.primaryEmerald : null,
                        ),
                      ),
                      subtitle: Text(
                        opt.id,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle_rounded, color: AppColors.primaryEmerald, size: 20)
                          : null,
                      onTap: () {
                        ref.read(aiProviderConfigProvider.notifier).updateModel(opt.id);
                        Navigator.pop(ctx);
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showClearAllConfirmDialog(BuildContext context) {
    AppHaptics.warning();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: AppColors.expense),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Clear All Generated Reports?',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: const Text(
          'This will permanently remove all saved financial reports and audits from your device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () {
              ref.read(aiReportsProvider.notifier).clearAllReports();
              ref.read(aiAuditProvider.notifier).clearAudit();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All generated reports cleared.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  void _shareReport(AiReportItem report) {
    AppHaptics.selectionClick();
    final shareText = '''
${report.title}
Generated by EmptyPocket PocketAI (${report.providerUsed.displayName} • ${report.modelDisplayName})
Date: ${DateFormat('dd MMM yyyy, h:mm a').format(report.createdAt)}

----------------------------------------

${report.markdownContent}
''';
    SharePlus.instance.share(
      ShareParams(
        text: shareText,
        subject: report.title,
      ),
    );
  }

  void _copyMarkdown(AiReportItem report) {
    AppHaptics.selectionClick();
    Clipboard.setData(ClipboardData(text: report.markdownContent));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Text('Report copied to clipboard'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final financialColors = context.financialColors;
    final isDark = theme.brightness == Brightness.dark;

    final config = ref.watch(aiProviderConfigProvider);
    final reportsState = ref.watch(aiReportsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text(
              'AI Reports',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () => _showModelPickerSheet(context, config),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primaryEmerald.withAlpha(isDark ? 80 : 50),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(config.providerType.icon, size: 13, color: AppColors.primaryEmerald),
                    const SizedBox(width: 4),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.3),
                      child: Text(
                        config.activeModelDisplayName,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.keyboard_arrow_down_rounded, size: 15),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'AI Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AiSettingsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear All Reports',
            onPressed: () => _showClearAllConfirmDialog(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Warning banner if API key is not configured
          if (!config.isConfigured)
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: AppColors.warning.withAlpha(25),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No API key configured for report generation.',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AiSettingsScreen()),
                        );
                      },
                      child: const Text('Configure', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ),

          // Report Hub Section: Quick Templates Carousel
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryEmerald.withAlpha(isDark ? 45 : 30),
                        ),
                        child: const Icon(Icons.description_outlined, color: AppColors.primaryEmerald, size: 16),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'GENERATE FINANCIAL AUDIT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                          color: financialColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildTemplatePill(
                          title: '+ New Report',
                          icon: Icons.add_rounded,
                          color: AppColors.primaryEmerald,
                          onTap: () => _showNewReportModal(context),
                          isDark: isDark,
                          financialColors: financialColors,
                        ),
                        const SizedBox(width: 8),
                        _buildTemplatePill(
                          title: 'Full Health Audit',
                          icon: Icons.verified_rounded,
                          color: AppColors.primaryEmerald,
                          onTap: () {
                            AppHaptics.buttonPress();
                            ref.read(aiReportsProvider.notifier).generateReport(type: AiReportType.fullAudit);
                          },
                          isDark: isDark,
                          financialColors: financialColors,
                        ),
                        const SizedBox(width: 8),
                        _buildTemplatePill(
                          title: 'Budget Optimization',
                          icon: Icons.pie_chart_rounded,
                          color: AppColors.info,
                          onTap: () {
                            AppHaptics.buttonPress();
                            ref.read(aiReportsProvider.notifier).generateReport(type: AiReportType.budgetOptimization);
                          },
                          isDark: isDark,
                          financialColors: financialColors,
                        ),
                        const SizedBox(width: 8),
                        _buildTemplatePill(
                          title: 'Debt Payoff Plan',
                          icon: Icons.credit_card_off_rounded,
                          color: AppColors.expense,
                          onTap: () {
                            AppHaptics.buttonPress();
                            ref.read(aiReportsProvider.notifier).generateReport(type: AiReportType.debtPayoff);
                          },
                          isDark: isDark,
                          financialColors: financialColors,
                        ),
                        const SizedBox(width: 8),
                        _buildTemplatePill(
                          title: 'Investment Review',
                          icon: Icons.trending_up_rounded,
                          color: AppColors.investment,
                          onTap: () {
                            AppHaptics.buttonPress();
                            ref.read(aiReportsProvider.notifier).generateReport(type: AiReportType.investmentReview);
                          },
                          isDark: isDark,
                          financialColors: financialColors,
                        ),
                        const SizedBox(width: 8),
                        _buildTemplatePill(
                          title: 'Emergency Runway',
                          icon: Icons.shield_rounded,
                          color: AppColors.income,
                          onTap: () {
                            AppHaptics.buttonPress();
                            ref.read(aiReportsProvider.notifier).generateReport(type: AiReportType.emergencyRunway);
                          },
                          isDark: isDark,
                          financialColors: financialColors,
                        ),
                        const SizedBox(width: 8),
                        _buildTemplatePill(
                          title: 'Custom Prompt',
                          icon: Icons.edit_note_rounded,
                          color: AppColors.primaryTeal,
                          onTap: () => _showNewReportModal(context),
                          isDark: isDark,
                          financialColors: financialColors,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: Divider(),
            ),
          ),

          // Reports List Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
              child: Text(
                'SAVED REPORTS & AUDITS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: financialColors.textMuted,
                ),
              ),
            ),
          ),

          // Reports Content Area
          reportsState.when(
            skipLoadingOnReload: true,
            skipError: true,
            data: (reports) {
              if (reports.isEmpty) {
                return SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primaryEmerald.withAlpha(isDark ? 40 : 20),
                            ),
                            child: const Icon(Icons.analytics_outlined, size: 44, color: AppColors.primaryEmerald),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No AI Reports Generated Yet',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Choose an audit template above or tap "+ New Report" to analyze your offline financial health.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: financialColors.textMuted, fontSize: 13, height: 1.4),
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primaryEmerald,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            ),
                            icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                            label: const Text('Generate Full Audit Report', style: TextStyle(fontWeight: FontWeight.w700)),
                            onPressed: () {
                              AppHaptics.buttonPress();
                              ref.read(aiReportsProvider.notifier).generateReport(type: AiReportType.fullAudit);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final report = reports[index];
                      return _buildReportSummaryCard(context, report, isDark, financialColors);
                    },
                    childCount: reports.length,
                  ),
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(strokeWidth: 3, color: AppColors.primaryEmerald),
                    SizedBox(height: 16),
                    Text(
                      'Analyzing offline metrics & generating audit...',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            error: (err, _) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.expense.withAlpha(25),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.expense.withAlpha(80)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.expense, size: 32),
                      const SizedBox(height: 8),
                      Text(
                        'Error generating report:\n$err',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.expense, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
                        onPressed: () => ref.read(aiReportsProvider.notifier).generateReport(type: AiReportType.fullAudit),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplatePill({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
    required AppFinancialColors financialColors,
  }) {
    return ActionChip(
      avatar: Icon(icon, size: 15, color: color),
      label: Text(title),
      backgroundColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
      side: BorderSide(color: financialColors.cardBorder),
      visualDensity: VisualDensity.compact,
      labelStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      onPressed: onTap,
    );
  }

  /// Modern Sleek Executive Summary Card for Feed
  Widget _buildReportSummaryCard(
    BuildContext context,
    AiReportItem report,
    bool isDark,
    AppFinancialColors financialColors,
  ) {
    final theme = Theme.of(context);

    // Extract a 2-3 line plain text excerpt from markdown content
    final cleanExcerpt = report.markdownContent
        .replaceAll(RegExp(r'[#*`_>|]'), '')
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .take(3)
        .join(' ');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.primaryEmerald.withAlpha(isDark ? 60 : 40),
          width: 1.2,
        ),
      ),
      child: InkWell(
        onTap: () {
          AppHaptics.selectionClick();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AiReportDetailScreen(report: report),
            ),
          );
        },
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppColors.primaryEmerald.withAlpha(isDark ? 45 : 30),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(report.type.icon, color: AppColors.primaryEmerald, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${DateFormat('dd MMM yyyy, h:mm a').format(report.createdAt)} • ${report.modelDisplayName}',
                          style: TextStyle(
                            color: financialColors.textMuted,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, size: 18),
                    padding: EdgeInsets.zero,
                    onSelected: (action) {
                      if (action == 'share') {
                        _shareReport(report);
                      } else if (action == 'copy') {
                        _copyMarkdown(report);
                      } else if (action == 'regenerate') {
                        AppHaptics.buttonPress();
                        ref.read(aiReportsProvider.notifier).regenerateReport(report.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Regenerating report in background...'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      } else if (action == 'delete') {
                        AppHaptics.warning();
                        ref.read(aiReportsProvider.notifier).deleteReport(report.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Report deleted'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'share',
                        child: Row(
                          children: [
                            Icon(Icons.share_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Share Report'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'copy',
                        child: Row(
                          children: [
                            Icon(Icons.copy_rounded, size: 18),
                            SizedBox(width: 8),
                            Text('Copy Markdown'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'regenerate',
                        child: Row(
                          children: [
                            Icon(Icons.refresh_rounded, size: 18, color: AppColors.primaryEmerald),
                            SizedBox(width: 8),
                            Text('Regenerate Report'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.expense),
                            SizedBox(width: 8),
                            Text('Delete Report', style: TextStyle(color: AppColors.expense)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Executive Excerpt Preview
              Text(
                cleanExcerpt,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),

              // Card Bottom Action Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryEmerald.withAlpha(isDark ? 30 : 20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      report.type.displayName,
                      style: const TextStyle(
                        color: AppColors.primaryEmerald,
                        fontWeight: FontWeight.w700,
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        'Read Full Report',
                        style: TextStyle(
                          color: AppColors.primaryEmerald,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.primaryEmerald),
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
}

class _NewReportBottomSheet extends StatefulWidget {
  final void Function(AiReportType type, String? customPrompt) onSelectType;

  const _NewReportBottomSheet({required this.onSelectType});

  @override
  State<_NewReportBottomSheet> createState() => _NewReportBottomSheetState();
}

class _NewReportBottomSheetState extends State<_NewReportBottomSheet> {
  final TextEditingController _customPromptController = TextEditingController();
  bool _isCustomSelected = false;

  @override
  void dispose() {
    _customPromptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withAlpha(100),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Generate New Financial Report',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Select a report category to analyze your private offline numbers:',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 16),

            _buildReportOption(
              title: 'Full Financial Health Audit',
              subtitle: 'Executive overview, strengths, risks & 30-day recommendations',
              icon: Icons.verified_rounded,
              color: AppColors.primaryEmerald,
              onTap: () => widget.onSelectType(AiReportType.fullAudit, null),
            ),
            _buildReportOption(
              title: 'Budget & Expense Optimization',
              subtitle: 'Category spending analysis & 50/30/20 rebalancing plan',
              icon: Icons.pie_chart_rounded,
              color: AppColors.info,
              onTap: () => widget.onSelectType(AiReportType.budgetOptimization, null),
            ),
            _buildReportOption(
              title: 'Debt Freedom & Loan Payoff Plan',
              subtitle: 'Avalanche vs Snowball payoff timeline & interest savings',
              icon: Icons.credit_card_off_rounded,
              color: AppColors.expense,
              onTap: () => widget.onSelectType(AiReportType.debtPayoff, null),
            ),
            _buildReportOption(
              title: 'Investment & Asset Review',
              subtitle: 'Asset allocation balance & strategic diversification',
              icon: Icons.trending_up_rounded,
              color: AppColors.investment,
              onTap: () => widget.onSelectType(AiReportType.investmentReview, null),
            ),
            _buildReportOption(
              title: 'Emergency Runway & Safety Buffer',
              subtitle: 'Survival months calculation & emergency fund roadmap',
              icon: Icons.shield_rounded,
              color: AppColors.income,
              onTap: () => widget.onSelectType(AiReportType.emergencyRunway, null),
            ),

            const Divider(height: 24),

            // Custom Prompt Option
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: Colors.white10,
                child: Icon(Icons.edit_note_rounded, color: AppColors.primaryEmerald),
              ),
              title: const Text('Custom Financial Question / Audit', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              subtitle: const Text('Ask a custom question tailored to your data', style: TextStyle(fontSize: 12)),
              onTap: () => setState(() => _isCustomSelected = !_isCustomSelected),
            ),
            if (_isCustomSelected) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _customPromptController,
                decoration: InputDecoration(
                  hintText: 'e.g. Can I afford to buy a ${CurrencyFormatter.currentSymbol}40,000 laptop in 2 months?',
                  border: const OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryEmerald,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    final text = _customPromptController.text.trim();
                    if (text.isNotEmpty) {
                      widget.onSelectType(AiReportType.custom, text);
                    }
                  },
                  child: const Text('Generate Custom Report', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReportOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withAlpha(30),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
      onTap: onTap,
    );
  }
}
