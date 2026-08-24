import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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

  void _startNewChat() {
    ref.read(aiChatProvider.notifier).startNewChat();
    _messageController.clear();
    _scrollToBottom();
  }

  void _showRenameDialog(BuildContext context, AiChatSession session) {
    final controller = TextEditingController(text: session.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Conversation'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter conversation title',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primaryEmerald),
            onPressed: () {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty) {
                ref.read(aiChatProvider.notifier).renameSession(session.id, newTitle);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteSessionDialog(BuildContext context, AiChatSession session) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: AppColors.expense),
            SizedBox(width: 8),
            Text('Delete Conversation?'),
          ],
        ),
        content: Text('Delete "${session.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () {
              ref.read(aiChatProvider.notifier).deleteSession(session.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showClearAllChatsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: AppColors.expense),
            SizedBox(width: 8),
            Text('Clear All Chat History?'),
          ],
        ),
        content: const Text(
          'This will permanently delete all your previous AI chat sessions and messages.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () {
              ref.read(aiChatProvider.notifier).clearAllChats();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All chat history cleared.'),
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

  void _showChatHistoryModal(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) {
        return Consumer(
          builder: (ctx, ref, _) {
            final chatState = ref.watch(aiChatProvider);
            final sessions = chatState.sessions;
            final currentId = chatState.currentSession?.id;

            // Group sessions by date
            final now = DateTime.now();
            final todayStart = DateTime(now.year, now.month, now.day);
            final yesterdayStart = todayStart.subtract(const Duration(days: 1));
            final sevenDaysAgo = todayStart.subtract(const Duration(days: 7));

            final todaySessions = <AiChatSession>[];
            final yesterdaySessions = <AiChatSession>[];
            final previousWeekSessions = <AiChatSession>[];
            final olderSessions = <AiChatSession>[];

            for (final s in sessions) {
              if (s.updatedAt.isAfter(todayStart)) {
                todaySessions.add(s);
              } else if (s.updatedAt.isAfter(yesterdayStart)) {
                yesterdaySessions.add(s);
              } else if (s.updatedAt.isAfter(sevenDaysAgo)) {
                previousWeekSessions.add(s);
              } else {
                olderSessions.add(s);
              }
            }

            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.4,
              maxChildSize: 0.92,
              expand: false,
              builder: (ctx, scrollController) {
                return Column(
                  children: [
                    // Handle Bar
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Header with "+ New Chat" button
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 16, 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primaryEmerald.withAlpha(isDark ? 40 : 25),
                            ),
                            child: const Icon(
                              Icons.history_rounded,
                              color: AppColors.primaryEmerald,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Chat History',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  '${sessions.length} conversation${sessions.length == 1 ? '' : 's'}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primaryEmerald,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            ),
                            icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                            label: const Text(
                              'New Chat',
                              style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 13),
                            ),
                            onPressed: () {
                              Navigator.pop(bottomSheetContext);
                              _startNewChat();
                            },
                          ),
                        ],
                      ),
                    ),

                    const Divider(height: 1),

                    // Sessions List
                    Expanded(
                      child: sessions.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.forum_outlined,
                                      size: 48,
                                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No past conversations yet',
                                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Start chatting with PocketAI and your conversations will be securely stored here.',
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView(
                              controller: scrollController,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              children: [
                                if (todaySessions.isNotEmpty) ...[
                                  _buildSessionSectionHeader('Today', isDark),
                                  ...todaySessions.map((s) => _buildSessionTile(bottomSheetContext, s, currentId, isDark)),
                                ],
                                if (yesterdaySessions.isNotEmpty) ...[
                                  _buildSessionSectionHeader('Yesterday', isDark),
                                  ...yesterdaySessions.map((s) => _buildSessionTile(bottomSheetContext, s, currentId, isDark)),
                                ],
                                if (previousWeekSessions.isNotEmpty) ...[
                                  _buildSessionSectionHeader('Previous 7 Days', isDark),
                                  ...previousWeekSessions.map((s) => _buildSessionTile(bottomSheetContext, s, currentId, isDark)),
                                ],
                                if (olderSessions.isNotEmpty) ...[
                                  _buildSessionSectionHeader('Older', isDark),
                                  ...olderSessions.map((s) => _buildSessionTile(bottomSheetContext, s, currentId, isDark)),
                                ],
                              ],
                            ),
                    ),

                    if (sessions.isNotEmpty) ...[
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.expense,
                          ),
                          icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                          label: const Text('Clear All Conversations', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          onPressed: () {
                            Navigator.pop(bottomSheetContext);
                            _showClearAllChatsDialog(context);
                          },
                        ),
                      ),
                    ],
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSessionSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
        ),
      ),
    );
  }

  Widget _buildSessionTile(BuildContext sheetContext, AiChatSession session, String? currentId, bool isDark) {
    final isSelected = session.id == currentId;
    final timeFormat = DateFormat('h:mm a');

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primaryEmerald.withAlpha(isDark ? 35 : 25)
            : (isDark ? AppColors.darkSurfaceVariant.withAlpha(120) : AppColors.lightSurfaceVariant.withAlpha(120)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected
              ? AppColors.primaryEmerald.withAlpha(180)
              : (isDark ? Colors.white10 : Colors.black12),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelected
                ? AppColors.primaryEmerald.withAlpha(50)
                : (isDark ? Colors.white10 : Colors.black12),
          ),
          child: Icon(
            isSelected ? Icons.chat_bubble_rounded : Icons.chat_bubble_outline_rounded,
            size: 16,
            color: isSelected ? AppColors.primaryEmerald : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
        title: Text(
          session.title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 13.5,
            color: isSelected
                ? AppColors.primaryEmerald
                : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${session.modelUsed.isNotEmpty ? session.modelUsed : session.provider.toUpperCase()} • ${timeFormat.format(session.updatedAt)}',
          style: TextStyle(
            fontSize: 11,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, size: 18),
          padding: EdgeInsets.zero,
          onSelected: (action) {
            if (action == 'rename') {
              _showRenameDialog(context, session);
            } else if (action == 'delete') {
              _showDeleteSessionDialog(context, session);
            }
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(
              value: 'rename',
              child: Row(
                children: [
                  Icon(Icons.edit_outlined, size: 18),
                  SizedBox(width: 8),
                  Text('Rename'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.expense),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: AppColors.expense)),
                ],
              ),
            ),
          ],
        ),
        onTap: () {
          ref.read(aiChatProvider.notifier).selectSession(session.id);
          Navigator.pop(sheetContext);
          _scrollToBottom();
        },
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
    final currentSession = chatState.currentSession;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    currentSession?.title ?? 'PocketAI',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    currentSession != null ? 'Financial Advisor • Active Chat' : 'Financial Advisor',
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
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: const Icon(Icons.add_comment_outlined, size: 20),
            tooltip: 'New Chat',
            onPressed: isGenerating ? null : _startNewChat,
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: const Icon(Icons.history_rounded, size: 20),
            tooltip: 'Chat History',
            onPressed: () => _showChatHistoryModal(context),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: const Icon(Icons.tune_rounded, size: 20),
            tooltip: 'AI Model & Key Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AiSettingsScreen()),
              );
            },
          ),
          const SizedBox(width: 4),
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
          Flexible(
            child: configured.length > 1
                ? SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
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
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(config.providerType.icon, color: AppColors.primaryEmerald, size: 16),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          config.providerType.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.primaryEmerald),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(width: 8),

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
