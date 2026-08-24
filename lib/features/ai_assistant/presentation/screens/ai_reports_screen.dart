import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/entities/ai_assistant_entity.dart';
import '../state/ai_assistant_provider.dart';
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

  void _showClearAllConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: AppColors.expense),
            SizedBox(width: 8),
            Text('Clear All Generated Reports?'),
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
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryEmerald.withAlpha(isDark ? 45 : 30),
              ),
              child: const Icon(Icons.description_outlined, color: AppColors.primaryEmerald, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'AI Reports',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Financial Audits',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: financialColors.textMuted,
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
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'AI Model & Key Settings',
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
        ],
      ),
      body: Column(
        children: [
          // Model & Provider Selection Bar
          _buildModelBar(context, config, isDark, financialColors),

          // Quick Action Suggestion Chips
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.add_rounded, size: 16, color: AppColors.primaryEmerald),
                    label: const Text('+ New Report', style: TextStyle(fontWeight: FontWeight.w700)),
                    onPressed: () => _showNewReportModal(context),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.verified_rounded, size: 16, color: AppColors.primaryEmerald),
                    label: const Text('Full Health Audit'),
                    onPressed: () => ref.read(aiReportsProvider.notifier).generateReport(type: AiReportType.fullAudit),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.pie_chart_rounded, size: 16, color: AppColors.info),
                    label: const Text('Budget Optimization'),
                    onPressed: () => ref.read(aiReportsProvider.notifier).generateReport(type: AiReportType.budgetOptimization),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.credit_card_off_rounded, size: 16, color: AppColors.expense),
                    label: const Text('Debt Payoff Plan'),
                    onPressed: () => ref.read(aiReportsProvider.notifier).generateReport(type: AiReportType.debtPayoff),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.trending_up_rounded, size: 16, color: AppColors.investment),
                    label: const Text('Investment Review'),
                    onPressed: () => ref.read(aiReportsProvider.notifier).generateReport(type: AiReportType.investmentReview),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.shield_rounded, size: 16, color: AppColors.income),
                    label: const Text('Emergency Runway'),
                    onPressed: () => ref.read(aiReportsProvider.notifier).generateReport(type: AiReportType.emergencyRunway),
                  ),
                ],
              ),
            ),
          ),

          const Divider(height: 1),

          // Scrollable Reports List
          Expanded(
            child: reportsState.when(
              data: (reports) {
                if (reports.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.analytics_outlined, size: 56, color: financialColors.textMuted),
                          const SizedBox(height: 16),
                          const Text(
                            'No AI Reports Generated Yet',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Select a report category above or tap "+ New Report" to analyze your offline financial metrics.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: financialColors.textMuted, fontSize: 13, height: 1.4),
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: AppColors.primaryEmerald, foregroundColor: Colors.black),
                            icon: const Icon(Icons.auto_awesome_rounded),
                            label: const Text('Generate Full Audit Report', style: TextStyle(fontWeight: FontWeight.w700)),
                            onPressed: () => ref.read(aiReportsProvider.notifier).generateReport(type: AiReportType.fullAudit),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: reports.length,
                  itemBuilder: (context, index) {
                    final report = reports[index];
                    return _buildReportCard(context, report, isDark, financialColors);
                  },
                );
              },
              loading: () => const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(strokeWidth: 3),
                    SizedBox(height: 16),
                    Text('Analyzing offline metrics and generating report...', style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
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
                        Text('Error generating report:\n$err', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.expense, fontSize: 13)),
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
          ),
        ],
      ),
    );
  }

  Widget _buildModelBar(
    BuildContext context,
    AiProviderConfig config,
    bool isDark,
    dynamic financialColors,
  ) {
    final configured = config.configuredProviders;

    if (configured.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: AppColors.warning.withAlpha(25),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 18),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'No API key configured for report generation.',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AiSettingsScreen()),
                );
              },
              child: const Text('Setup Key', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(bottom: BorderSide(color: financialColors.cardBorder)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (configured.length > 1)
            Row(
              children: [
                ChoiceChip(
                  avatar: const Icon(Icons.auto_awesome_rounded, size: 14),
                  label: const Text('Gemini', style: TextStyle(fontSize: 11)),
                  selected: config.providerType == AiProviderType.gemini,
                  visualDensity: VisualDensity.compact,
                  onSelected: (sel) {
                    if (sel) ref.read(aiProviderConfigProvider.notifier).updateProvider(AiProviderType.gemini);
                  },
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  avatar: const Icon(Icons.bolt_rounded, size: 14),
                  label: const Text('Groq', style: TextStyle(fontSize: 11)),
                  selected: config.providerType == AiProviderType.groq,
                  visualDensity: VisualDensity.compact,
                  onSelected: (sel) {
                    if (sel) ref.read(aiProviderConfigProvider.notifier).updateProvider(AiProviderType.groq);
                  },
                ),
              ],
            )
          else
            Row(
              children: [
                Icon(config.providerType.icon, color: AppColors.primaryEmerald, size: 16),
                const SizedBox(width: 6),
                Text(
                  config.providerType.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.primaryEmerald),
                ),
              ],
            ),

          // Model Selector Dropdown
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: config.activeModel,
              isDense: true,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black,
              ),
              items: config.providerType.modelOptions.map((opt) {
                return DropdownMenuItem(
                  value: opt.id,
                  child: Text(opt.displayName),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  ref.read(aiProviderConfigProvider.notifier).updateModel(val);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(
    BuildContext context,
    AiReportItem report,
    bool isDark,
    dynamic financialColors,
  ) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.primaryEmerald.withAlpha(60), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(report.type.icon, color: AppColors.primaryEmerald, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              report.title,
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            Text(
                              '${report.providerUsed.displayName} • ${report.modelDisplayName}',
                              style: TextStyle(color: financialColors.textMuted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, size: 20),
                  onSelected: (action) {
                    if (action == 'copy') {
                      Clipboard.setData(ClipboardData(text: report.markdownContent));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Report copied to clipboard'), behavior: SnackBarBehavior.floating),
                      );
                    } else if (action == 'regenerate') {
                      ref.read(aiReportsProvider.notifier).regenerateReport(report.id);
                    } else if (action == 'delete') {
                      ref.read(aiReportsProvider.notifier).deleteReport(report.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Report deleted'), behavior: SnackBarBehavior.floating),
                      );
                    }
                  },
                  itemBuilder: (ctx) => [
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
            const SizedBox(height: 14),

            // Rendered Rich Markdown Content
            MarkdownBody(
              data: report.markdownContent,
              selectable: true,
              styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                p: TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
                h3: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black,
                  height: 1.5,
                ),
                listBullet: TextStyle(
                  color: AppColors.primaryEmerald,
                  fontWeight: FontWeight.bold,
                ),
                strong: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.primaryEmerald : const Color(0xFF047857),
                ),
                blockquote: TextStyle(
                  color: financialColors.textMuted,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Bottom Action Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.primaryEmerald,
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Regenerate', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  onPressed: () => ref.read(aiReportsProvider.notifier).regenerateReport(report.id),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      tooltip: 'Copy Markdown',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: report.markdownContent));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Report copied to clipboard'), behavior: SnackBarBehavior.floating),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.expense),
                      tooltip: 'Delete Report',
                      onPressed: () {
                        ref.read(aiReportsProvider.notifier).deleteReport(report.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Report deleted'), behavior: SnackBarBehavior.floating),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
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
                decoration: const InputDecoration(
                  hintText: 'e.g. Can I afford to buy a ₹40,000 laptop in 2 months?',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primaryEmerald, foregroundColor: Colors.black),
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
