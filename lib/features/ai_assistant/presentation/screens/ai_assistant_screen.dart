import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/entities/ai_assistant_entity.dart';
import '../state/ai_assistant_provider.dart';

class AiAssistantScreen extends ConsumerStatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  ConsumerState<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _geminiKeyController = TextEditingController();
  final TextEditingController _groqKeyController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final ScrollController _reportsScrollController = ScrollController();

  bool _isSettingsOpen = false;
  bool _obscureGeminiKey = true;
  bool _obscureGroqKey = true;
  bool _isTestingGemini = false;
  bool _isTestingGroq = false;
  String? _geminiTestStatus;
  String? _groqTestStatus;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    final config = ref.read(aiProviderConfigProvider);
    _geminiKeyController.text = config.geminiApiKey;
    _groqKeyController.text = config.groqApiKey;

    if (!config.isConfigured) {
      _isSettingsOpen = true;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    _geminiKeyController.dispose();
    _groqKeyController.dispose();
    _chatScrollController.dispose();
    _reportsScrollController.dispose();
    super.dispose();
  }

  void _scrollToChatBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _testKey(AiProviderType provider) async {
    final isGemini = provider == AiProviderType.gemini;
    final key = isGemini ? _geminiKeyController.text.trim() : _groqKeyController.text.trim();

    if (key.isEmpty) {
      setState(() {
        if (isGemini) {
          _geminiTestStatus = 'Please enter a Gemini API key.';
        } else {
          _groqTestStatus = 'Please enter a Groq API key.';
        }
      });
      return;
    }

    setState(() {
      if (isGemini) {
        _isTestingGemini = true;
        _geminiTestStatus = null;
      } else {
        _isTestingGroq = true;
        _groqTestStatus = null;
      }
    });

    if (isGemini) {
      await ref.read(aiProviderConfigProvider.notifier).updateGeminiApiKey(key);
    } else {
      await ref.read(aiProviderConfigProvider.notifier).updateGroqApiKey(key);
    }

    final config = ref.read(aiProviderConfigProvider).copyWith(providerType: provider);
    final aiService = ref.read(aiServiceProvider);
    final success = await aiService.testConnection(config);

    if (mounted) {
      setState(() {
        if (isGemini) {
          _isTestingGemini = false;
          _geminiTestStatus = success
              ? '✅ Gemini connection successful!'
              : '❌ Gemini test failed. Check key & model.';
        } else {
          _isTestingGroq = false;
          _groqTestStatus = success
              ? '✅ Groq connection successful!'
              : '❌ Groq test failed. Check key & model.';
        }
      });
    }
  }

  void _sendMessage([String? text]) {
    final msg = text ?? _messageController.text;
    if (msg.trim().isEmpty) return;

    ref.read(aiChatProvider.notifier).sendMessage(msg);
    _messageController.clear();
    _scrollToChatBottom();
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
          _tabController.animateTo(0);
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
            Text('Clear AI History & Reports?'),
          ],
        ),
        content: const Text(
          'This will remove all generated AI reports and clear your chat conversation history.',
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
              ref.read(aiChatProvider.notifier).clearChat();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All AI reports and chats cleared.'),
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
    final chatMessages = ref.watch(aiChatProvider);

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
              child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primaryEmerald, size: 18),
            ),
            const SizedBox(width: 8),
            const Text('PocketAI Financial Advisor'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isSettingsOpen ? Icons.tune_rounded : Icons.tune_outlined,
              color: config.isConfigured ? AppColors.primaryEmerald : AppColors.warning,
            ),
            tooltip: 'AI Model & Dual Keys',
            onPressed: () {
              setState(() => _isSettingsOpen = !_isSettingsOpen);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear History',
            onPressed: () => _showClearAllConfirmDialog(context),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.primaryEmerald,
            indicatorWeight: 3,
            labelColor: AppColors.primaryEmerald,
            unselectedLabelColor: financialColors.textMuted,
            tabs: const [
              Tab(
                icon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.description_outlined, size: 18),
                    SizedBox(width: 6),
                    Text('AI Reports & Audits'),
                  ],
                ),
              ),
              Tab(
                icon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chat_bubble_outline_rounded, size: 18),
                    SizedBox(width: 6),
                    Text('Live Chat'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // Active Provider Bar
          _buildActiveProviderBar(context, config, isDark, financialColors),

          // Collapsible Dual-Key Settings Panel
          if (_isSettingsOpen)
            _buildDualKeySettingsPanel(context, config, isDark, financialColors),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: AI Reports & Audits
                _buildReportsTab(context, reportsState, isDark, financialColors),

                // Tab 2: Live Chat Assistant
                _buildChatTab(context, chatMessages, isDark, financialColors),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveProviderBar(
    BuildContext context,
    AiProviderConfig config,
    bool isDark,
    dynamic financialColors,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(bottom: BorderSide(color: financialColors.cardBorder)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(config.providerType.icon, color: AppColors.primaryEmerald, size: 16),
              const SizedBox(width: 6),
              Text(
                'Active: ${config.providerType.displayName} (${config.activeModel})',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: config.isConfigured ? AppColors.primaryEmerald : AppColors.warning,
                ),
              ),
            ],
          ),
          // Quick Provider Switch Pill
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () {
                  ref.read(aiProviderConfigProvider.notifier).updateProvider(
                        config.providerType == AiProviderType.gemini
                            ? AiProviderType.groq
                            : AiProviderType.gemini,
                      );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryEmerald.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primaryEmerald.withAlpha(80)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.swap_horiz_rounded, size: 14, color: AppColors.primaryEmerald),
                      const SizedBox(width: 4),
                      Text(
                        config.providerType == AiProviderType.gemini ? 'Switch to Groq' : 'Switch to Gemini',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryEmerald,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDualKeySettingsPanel(
    BuildContext context,
    AiProviderConfig config,
    bool isDark,
    dynamic financialColors,
  ) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      constraints: const BoxConstraints(maxHeight: 400),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: financialColors.cardBorder),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'AI PROVIDERS & DUAL KEY VAULT',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: financialColors.textMuted,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () => setState(() => _isSettingsOpen = false),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Save keys for BOTH Gemini and Groq on your device. Easily switch providers if one reaches its rate limit.',
              style: theme.textTheme.bodySmall?.copyWith(color: financialColors.textMuted, fontSize: 11),
            ),
            const SizedBox(height: 12),

            // Provider Active Segmented Selector
            SegmentedButton<AiProviderType>(
              segments: const [
                ButtonSegment(
                  value: AiProviderType.gemini,
                  label: Text('Google Gemini'),
                  icon: Icon(Icons.auto_awesome_rounded, size: 16),
                ),
                ButtonSegment(
                  value: AiProviderType.groq,
                  label: Text('Groq Models'),
                  icon: Icon(Icons.bolt_rounded, size: 16),
                ),
              ],
              selected: {config.providerType},
              onSelectionChanged: (set) {
                ref.read(aiProviderConfigProvider.notifier).updateProvider(set.first);
              },
            ),
            const SizedBox(height: 16),

            // Google Gemini Section
            _buildProviderConfigBlock(
              context: context,
              title: 'Google Gemini',
              icon: Icons.auto_awesome_rounded,
              isActive: config.providerType == AiProviderType.gemini,
              controller: _geminiKeyController,
              obscureKey: _obscureGeminiKey,
              onToggleObscure: () => setState(() => _obscureGeminiKey = !_obscureGeminiKey),
              onKeyChanged: (val) => ref.read(aiProviderConfigProvider.notifier).updateGeminiApiKey(val),
              selectedModel: config.geminiModel,
              availableModels: AiProviderType.gemini.availableModels,
              onModelChanged: (m) {
                if (m != null) ref.read(aiProviderConfigProvider.notifier).updateGeminiModel(m);
              },
              keyUrl: AiProviderType.gemini.keyUrl,
              isTesting: _isTestingGemini,
              testStatus: _geminiTestStatus,
              onTestKey: () => _testKey(AiProviderType.gemini),
              isDark: isDark,
              financialColors: financialColors,
            ),
            const SizedBox(height: 16),

            // Groq Section
            _buildProviderConfigBlock(
              context: context,
              title: 'Groq (Open Models)',
              icon: Icons.bolt_rounded,
              isActive: config.providerType == AiProviderType.groq,
              controller: _groqKeyController,
              obscureKey: _obscureGroqKey,
              onToggleObscure: () => setState(() => _obscureGroqKey = !_obscureGroqKey),
              onKeyChanged: (val) => ref.read(aiProviderConfigProvider.notifier).updateGroqApiKey(val),
              selectedModel: config.groqModel,
              availableModels: AiProviderType.groq.availableModels,
              onModelChanged: (m) {
                if (m != null) ref.read(aiProviderConfigProvider.notifier).updateGroqModel(m);
              },
              keyUrl: AiProviderType.groq.keyUrl,
              isTesting: _isTestingGroq,
              testStatus: _groqTestStatus,
              onTestKey: () => _testKey(AiProviderType.groq),
              isDark: isDark,
              financialColors: financialColors,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderConfigBlock({
    required BuildContext context,
    required String title,
    required IconData icon,
    required bool isActive,
    required TextEditingController controller,
    required bool obscureKey,
    required VoidCallback onToggleObscure,
    required ValueChanged<String> onKeyChanged,
    required String selectedModel,
    required List<String> availableModels,
    required ValueChanged<String?> onModelChanged,
    required String keyUrl,
    required bool isTesting,
    required String? testStatus,
    required VoidCallback onTestKey,
    required bool isDark,
    required dynamic financialColors,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.primaryEmerald.withAlpha(isDark ? 20 : 15)
            : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? AppColors.primaryEmerald.withAlpha(100) : financialColors.cardBorder,
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: isActive ? AppColors.primaryEmerald : financialColors.textMuted),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: isActive ? AppColors.primaryEmerald : null,
                    ),
                  ),
                ],
              ),
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryEmerald,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('ACTIVE', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w800)),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Model dropdown
          DropdownButtonFormField<String>(
            initialValue: selectedModel,
            isDense: true,
            decoration: const InputDecoration(
              labelText: 'Model',
              prefixIcon: Icon(Icons.memory_rounded, size: 18),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: availableModels.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 13)))).toList(),
            onChanged: onModelChanged,
          ),
          const SizedBox(height: 8),

          // API Key input
          TextFormField(
            controller: controller,
            obscureText: obscureKey,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              labelText: '$title API Key',
              isDense: true,
              prefixIcon: const Icon(Icons.key_rounded, size: 18),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              suffixIcon: IconButton(
                icon: Icon(obscureKey ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18),
                onPressed: onToggleObscure,
              ),
            ),
            onChanged: onKeyChanged,
          ),
          const SizedBox(height: 8),

          // Key link & test button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Get key: $keyUrl',
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.primaryEmerald, fontSize: 10),
              ),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                ),
                icon: isTesting
                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check_circle_outline_rounded, size: 14),
                label: const Text('Test Key', style: TextStyle(fontSize: 11)),
                onPressed: isTesting ? null : onTestKey,
              ),
            ],
          ),
          if (testStatus != null) ...[
            const SizedBox(height: 6),
            Text(
              testStatus,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: testStatus.startsWith('✅') ? AppColors.income : AppColors.expense,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ================= TAB 1: REPORTS =================
  Widget _buildReportsTab(
    BuildContext context,
    AsyncValue<List<AiReportItem>> reportsState,
    bool isDark,
    dynamic financialColors,
  ) {
    return Column(
      children: [
        // Quick Action ActionChips to generate new reports
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
                  avatar: const Icon(Icons.shield_rounded, size: 16, color: AppColors.income),
                  label: const Text('Emergency Buffer'),
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
                          'Tap "+ New Report" or select an audit chip above to generate an offline-analyzed financial report.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: financialColors.textMuted, fontSize: 13, height: 1.4),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: AppColors.primaryEmerald, foregroundColor: Colors.black),
                          icon: const Icon(Icons.auto_awesome_rounded),
                          label: const Text('Generate First Audit Report', style: TextStyle(fontWeight: FontWeight.w700)),
                          onPressed: () => ref.read(aiReportsProvider.notifier).generateReport(type: AiReportType.fullAudit),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                controller: _reportsScrollController,
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
            // Header: Type icon, Title, Actions
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
                              '${report.providerUsed.displayName} • ${report.modelUsed}',
                              style: TextStyle(color: financialColors.textMuted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Report Action Menu
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

            // Bottom action bar
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
      ),
    );
  }

  // ================= TAB 2: CHAT =================
  Widget _buildChatTab(
    BuildContext context,
    List<AiChatMessage> chatMessages,
    bool isDark,
    dynamic financialColors,
  ) {
    return Column(
      children: [
        // Quick Question Suggestion Chips
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                ActionChip(
                  avatar: const Icon(Icons.shopping_bag_outlined, size: 16),
                  label: const Text('Can I afford ₹15k trip?'),
                  onPressed: () => _sendMessage('Based on my current cash balance, expenses, and safety runway, can I afford a ₹15,000 trip next month?'),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.account_balance_outlined, size: 16),
                  label: const Text('Prepay loans vs SIPs?'),
                  onPressed: () => _sendMessage('Should I prioritize prepaying my active loans or investing more in mutual funds/equity?'),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.shield_outlined, size: 16),
                  label: const Text('Emergency buffer health?'),
                  onPressed: () => _sendMessage('Analyze my emergency fund buffer and safety duration based on my monthly expenses.'),
                ),
              ],
            ),
          ),
        ),

        const Divider(height: 1),

        // Scrollable Chat Messages
        Expanded(
          child: ListView.builder(
            controller: _chatScrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: chatMessages.length,
            itemBuilder: (context, index) {
              final message = chatMessages[index];
              return _buildChatBubble(context, message, isDark, financialColors);
            },
          ),
        ),

        // Bottom Chat Input Box
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            border: Border(top: BorderSide(color: financialColors.cardBorder)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _messageController,
                  textInputAction: TextInputAction.send,
                  onFieldSubmitted: (val) => _sendMessage(),
                  decoration: InputDecoration(
                    hintText: 'Ask PocketAI about your finances...',
                    prefixIcon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: AppColors.primaryEmerald),
                icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                onPressed: () => _sendMessage(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChatBubble(
    BuildContext context,
    AiChatMessage message,
    bool isDark,
    dynamic financialColors,
  ) {
    final isUser = message.isUser;
    final theme = Theme.of(context);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.86),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser
              ? AppColors.primaryEmerald
              : (isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          border: isUser ? null : Border.all(color: financialColors.cardBorder),
        ),
        child: isUser
            ? Text(
                message.text,
                style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
              )
            : MarkdownBody(
                data: message.text,
                selectable: true,
                styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                  p: TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                  h3: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  strong: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.primaryEmerald : const Color(0xFF047857),
                  ),
                  listBullet: const TextStyle(color: AppColors.primaryEmerald),
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
