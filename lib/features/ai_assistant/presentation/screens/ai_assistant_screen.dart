import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSettingsOpen = false;
  bool _obscureKey = true;
  bool _isTestingKey = false;
  String? _testResultStatus;

  @override
  void initState() {
    super.initState();
    final config = ref.read(aiProviderConfigProvider);
    _apiKeyController.text = config.apiKey;
    if (!config.isConfigured) {
      _isSettingsOpen = true;
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _apiKeyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _testConnection() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      setState(() => _testResultStatus = 'Please enter an API key.');
      return;
    }

    setState(() {
      _isTestingKey = true;
      _testResultStatus = null;
    });

    await ref.read(aiProviderConfigProvider.notifier).updateApiKey(key);
    final config = ref.read(aiProviderConfigProvider);
    final aiService = ref.read(aiServiceProvider);

    final success = await aiService.testConnection(config);

    if (mounted) {
      setState(() {
        _isTestingKey = false;
        _testResultStatus = success
            ? '✅ Connection successful with ${config.providerType.displayName}!'
            : '❌ Connection failed. Please verify your API key and model.';
      });
    }
  }

  void _sendMessage([String? text]) {
    final msg = text ?? _messageController.text;
    if (msg.trim().isEmpty) return;

    ref.read(aiChatProvider.notifier).sendMessage(msg);
    _messageController.clear();
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final financialColors = context.financialColors;
    final isDark = theme.brightness == Brightness.dark;

    final config = ref.watch(aiProviderConfigProvider);
    final chatMessages = ref.watch(aiChatProvider);
    final auditState = ref.watch(aiAuditProvider);

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
              _isSettingsOpen ? Icons.settings_rounded : Icons.settings_outlined,
              color: config.isConfigured ? AppColors.primaryEmerald : AppColors.warning,
            ),
            tooltip: 'AI Provider Settings',
            onPressed: () {
              setState(() => _isSettingsOpen = !_isSettingsOpen);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear Chat',
            onPressed: () => ref.read(aiChatProvider.notifier).clearChat(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Collapsible Provider Settings Card
          if (_isSettingsOpen)
            _buildSettingsPanel(context, config, isDark, financialColors),

          // Audit Report Card (if generated)
          auditState.when(
            data: (report) => report != null ? _buildAuditReportCard(context, report, isDark, financialColors) : const SizedBox.shrink(),
            loading: () => Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: financialColors.cardBorder),
              ),
              child: const Row(
                children: [
                  SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5)),
                  SizedBox(width: 12),
                  Text('Generating personalized financial audit...'),
                ],
              ),
            ),
            error: (err, _) => Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.expense.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.expense.withAlpha(80)),
              ),
              child: Text(
                'Audit error: $err',
                style: const TextStyle(color: AppColors.expense, fontSize: 12),
              ),
            ),
          ),

          // Quick Action Suggestion Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                ActionChip(
                  avatar: const Icon(Icons.analytics_outlined, size: 16, color: AppColors.primaryEmerald),
                  label: const Text('Generate Full Audit'),
                  onPressed: () => ref.read(aiAuditProvider.notifier).generateAudit(),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.shopping_bag_outlined, size: 16),
                  label: const Text('Can I afford ₹15k trip?'),
                  onPressed: () => _sendMessage('Based on my current cash balance, expenses, and safety runway, can I afford a ₹15,000 trip next month?'),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.shield_outlined, size: 16),
                  label: const Text('Emergency buffer analysis'),
                  onPressed: () => _sendMessage('Analyze my emergency fund buffer and safety duration based on my monthly expenses.'),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.account_balance_outlined, size: 16),
                  label: const Text('Prepay loans vs SIPs'),
                  onPressed: () => _sendMessage('Should I prioritize prepaying my active loans or investing more in mutual funds/equity?'),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Chat Messages List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: chatMessages.length,
              itemBuilder: (context, index) {
                final message = chatMessages[index];
                return _buildChatBubble(context, message, isDark, financialColors);
              },
            ),
          ),

          // Chat Input Box
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
      ),
    );
  }

  Widget _buildSettingsPanel(
    BuildContext context,
    AiProviderConfig config,
    bool isDark,
    dynamic financialColors,
  ) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
              Text(
                'AI PROVIDER & BYOK SETTINGS',
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
          const SizedBox(height: 10),

          // Provider Selector Segmented Buttons
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  avatar: const Icon(Icons.auto_awesome_rounded, size: 16),
                  label: const Text('Google Gemini'),
                  selected: config.providerType == AiProviderType.gemini,
                  onSelected: (sel) {
                    if (sel) {
                      ref.read(aiProviderConfigProvider.notifier).updateProvider(AiProviderType.gemini);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  avatar: const Icon(Icons.bolt_rounded, size: 16),
                  label: const Text('Groq (Qwen 3.6)'),
                  selected: config.providerType == AiProviderType.groq,
                  onSelected: (sel) {
                    if (sel) {
                      ref.read(aiProviderConfigProvider.notifier).updateProvider(AiProviderType.groq);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Model Selection Dropdown
          DropdownButtonFormField<String>(
            initialValue: config.selectedModel,
            decoration: const InputDecoration(
              labelText: 'Model',
              prefixIcon: Icon(Icons.memory_rounded),
            ),
            items: config.providerType.availableModels.map((m) {
              return DropdownMenuItem(value: m, child: Text(m));
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                ref.read(aiProviderConfigProvider.notifier).updateModel(val);
              }
            },
          ),
          const SizedBox(height: 12),

          // API Key Input
          TextFormField(
            controller: _apiKeyController,
            obscureText: _obscureKey,
            decoration: InputDecoration(
              labelText: '${config.providerType.displayName} API Key',
              prefixIcon: const Icon(Icons.key_rounded),
              suffixIcon: IconButton(
                icon: Icon(_obscureKey ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscureKey = !_obscureKey),
              ),
            ),
            onChanged: (val) {
              ref.read(aiProviderConfigProvider.notifier).updateApiKey(val);
            },
          ),
          const SizedBox(height: 10),

          // Test connection & key link
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Get key: ${config.providerType.keyUrl}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.primaryEmerald,
                  fontSize: 11,
                ),
              ),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                ),
                icon: _isTestingKey
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check_circle_outline_rounded, size: 16),
                label: const Text('Test Key'),
                onPressed: _isTestingKey ? null : _testConnection,
              ),
            ],
          ),
          if (_testResultStatus != null) ...[
            const SizedBox(height: 8),
            Text(
              _testResultStatus!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _testResultStatus!.startsWith('✅') ? AppColors.income : AppColors.expense,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAuditReportCard(
    BuildContext context,
    AiAuditReport report,
    bool isDark,
    dynamic financialColors,
  ) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryEmerald.withAlpha(100), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryEmerald.withAlpha(20),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified_rounded, color: AppColors.primaryEmerald, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'AI Financial Health Audit',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 18),
                tooltip: 'Copy Audit',
                onPressed: () {
                  Clipboard.setData(ClipboardData(
                    text: 'EXECUTIVE OVERVIEW:\n${report.overview}\n\nSTRENGTHS:\n${report.strengths.join('\n')}\n\nRISKS:\n${report.risks.join('\n')}\n\nRECOMMENDATIONS:\n${report.recommendations.join('\n')}',
                  ));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Audit copied to clipboard'), behavior: SnackBarBehavior.floating),
                  );
                },
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(report.overview, style: theme.textTheme.bodyMedium?.copyWith(height: 1.4)),
          const SizedBox(height: 14),

          // Strengths
          Text('Key Strengths', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700, color: AppColors.income)),
          const SizedBox(height: 4),
          ...report.strengths.map((s) => Text('• $s', style: const TextStyle(fontSize: 12, height: 1.3))),
          const SizedBox(height: 10),

          // Risks
          Text('Risk Areas', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700, color: AppColors.warning)),
          const SizedBox(height: 4),
          ...report.risks.map((r) => Text('• $r', style: const TextStyle(fontSize: 12, height: 1.3))),
          const SizedBox(height: 10),

          // Recommendations
          Text('Action Recommendations', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700, color: AppColors.info)),
          const SizedBox(height: 4),
          ...report.recommendations.map((a) => Text('• $a', style: const TextStyle(fontSize: 12, height: 1.3))),
        ],
      ),
    );
  }

  Widget _buildChatBubble(
    BuildContext context,
    AiChatMessage message,
    bool isDark,
    dynamic financialColors,
  ) {
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              message.text,
              style: TextStyle(
                color: isUser
                    ? Colors.white
                    : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
