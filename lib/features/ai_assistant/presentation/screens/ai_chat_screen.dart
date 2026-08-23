import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/entities/ai_assistant_entity.dart';
import '../state/ai_assistant_provider.dart';
import 'ai_settings_screen.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
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

  void _sendMessage([String? text]) {
    final msg = text ?? _messageController.text;
    if (msg.trim().isEmpty) return;

    ref.read(aiChatProvider.notifier).sendMessage(msg);
    _messageController.clear();
    _scrollToBottom();
  }

  void _showClearChatDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: AppColors.expense),
            SizedBox(width: 8),
            Text('Clear Chat History?'),
          ],
        ),
        content: const Text('This will clear the current conversation with PocketAI.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () {
              ref.read(aiChatProvider.notifier).clearChat();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Chat history cleared.'), behavior: SnackBarBehavior.floating),
              );
            },
            child: const Text('Clear'),
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
    final chatState = ref.watch(aiChatProvider);
    final chatMessages = chatState.messages;
    final isGenerating = chatState.isGenerating;

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
            tooltip: 'Clear Chat',
            onPressed: () => _showClearChatDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Model & Provider Selector Bar
          _buildModelBar(context, config, isDark, financialColors),

          // Quick Question Suggestion Chips
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.shopping_bag_outlined, size: 15),
                    label: const Text('Can I afford ₹15k trip?'),
                    onPressed: isGenerating
                        ? null
                        : () => _sendMessage('Based on my current cash balance, expenses, and safety runway, can I afford a ₹15,000 trip next month?'),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.account_balance_outlined, size: 15),
                    label: const Text('Prepay loans vs SIPs?'),
                    onPressed: isGenerating
                        ? null
                        : () => _sendMessage('Should I prioritize prepaying my active loans or investing more in mutual funds/equity?'),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.shield_outlined, size: 15),
                    label: const Text('Emergency buffer status?'),
                    onPressed: isGenerating
                        ? null
                        : () => _sendMessage('Analyze my emergency fund buffer and safety duration based on my monthly expenses.'),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.pie_chart_outline_rounded, size: 15),
                    label: const Text('Audit top spending category'),
                    onPressed: isGenerating
                        ? null
                        : () => _sendMessage('Audit my highest expense category this month and give me practical tips to reduce it.'),
                  ),
                ],
              ),
            ),
          ),

          const Divider(height: 1),

          // Scrollable Chat Message Stream
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
                    enabled: !isGenerating,
                    onFieldSubmitted: (val) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: isGenerating
                          ? 'PocketAI is analyzing...'
                          : 'Ask PocketAI about your finances...',
                      prefixIcon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: AppColors.primaryEmerald),
                  icon: isGenerating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                  onPressed: isGenerating ? null : () => _sendMessage(),
                ),
              ],
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

    // Case 1: No key configured yet
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
                'No API key configured for AI assistant.',
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
          // Provider Switcher / Badge
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
