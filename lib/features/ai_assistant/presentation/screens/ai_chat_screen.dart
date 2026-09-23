import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/entities/ai_assistant_entity.dart';
import '../../../../core/utilities/app_haptics.dart';
import '../../../../core/utilities/currency_formatter.dart';
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
  final FocusNode _focusNode = FocusNode();
  bool _hasInputText = false;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onInputChanged);
  }

  void _onInputChanged() {
    final hasText = _messageController.text.trim().isNotEmpty;
    if (hasText != _hasInputText) {
      setState(() => _hasInputText = hasText);
    }
  }

  @override
  void dispose() {
    _messageController.removeListener(_onInputChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
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

    AppHaptics.buttonPress();
    ref.read(aiChatProvider.notifier).sendMessage(msg);
    _messageController.clear();
    _scrollToBottom();
  }

  void _startNewChat() {
    AppHaptics.selectionClick();
    ref.read(aiChatProvider.notifier).startNewChat();
    _messageController.clear();
    _scrollToBottom();
  }

  void _copyText(String text, {String feedback = 'Message copied to clipboard'}) {
    AppHaptics.selectionClick();
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Text(feedback),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _shareText(String text) {
    AppHaptics.selectionClick();
    SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: 'PocketAI Financial Insight',
      ),
    );
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
    ).whenComplete(() => controller.dispose());
  }

  void _showDeleteSessionDialog(BuildContext context, AiChatSession session) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: AppColors.expense),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Delete Conversation?',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
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
            Expanded(
              child: Text(
                'Clear All Chat History?',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
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

  void _showModelPickerSheet(BuildContext context, AiProviderConfig config) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Consumer(
          builder: (modalCtx, ref, _) {
            final liveConfig = ref.watch(aiProviderConfigProvider);

            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.75,
                ),
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

                      // Provider switcher chips in responsive Wrap
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: AiProviderType.values.map((provider) {
                          final isSelected = liveConfig.providerType == provider;
                          final isConfigured = liveConfig.isProviderConfigured(provider);

                          return ChoiceChip(
                            avatar: Icon(provider.icon, size: 16),
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  provider.displayName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                  ),
                                ),
                                if (isConfigured) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: AppColors.income,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            selected: isSelected,
                            onSelected: (sel) {
                              if (sel) {
                                ref.read(aiProviderConfigProvider.notifier).updateProvider(provider);
                              }
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      Text(
                        'SELECT MODEL (${liveConfig.providerType.displayName.toUpperCase()})',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Scrollable Model Options
                      Flexible(
                        child: ListView(
                          shrinkWrap: true,
                          children: liveConfig.activeModelOptions.map((opt) {
                            final isSelected = liveConfig.activeModel == opt.id;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primaryEmerald.withAlpha(isDark ? 40 : 25)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primaryEmerald
                                      : (isDark ? Colors.white10 : Colors.black12),
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
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
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
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
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
          Navigator.pop(sheetContext);
          ref.read(aiChatProvider.notifier).selectSession(session.id);
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

    // Filter out welcome message placeholder from display list if we want to show hero state
    final isChatEmpty = chatMessages.isEmpty || (chatMessages.length == 1 && chatMessages.first.id == 'welcome');

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.history_rounded),
          tooltip: 'Chat History',
          onPressed: () => _showChatHistoryModal(context),
        ),
        title: Center(
          child: InkWell(
            onTap: () => _showModelPickerSheet(context, config),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                  Icon(config.providerType.icon, size: 14, color: AppColors.primaryEmerald),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.42),
                    child: Text(
                      config.activeModelDisplayName,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
                ],
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined, size: 20),
            tooltip: 'New Chat',
            onPressed: isGenerating ? null : _startNewChat,
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded, size: 20),
            tooltip: 'AI Settings',
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
          // Warning banner if API key is not configured
          if (!config.isConfigured)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.warning.withAlpha(25),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No ${config.providerType.displayName} API Key configured.',
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

          // Main Chat Area
          Expanded(
            child: isChatEmpty
                ? _buildHeroEmptyState(context, isDark, financialColors)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    itemCount: chatMessages.length,
                    itemBuilder: (context, index) {
                      final message = chatMessages[index];
                      // Check if it's the last AI message
                      final isLastAiMessage = !message.isUser && index == chatMessages.length - 1;
                      return _buildMessageItem(
                        context,
                        message,
                        isDark,
                        financialColors,
                        isLastAiMessage: isLastAiMessage,
                      );
                    },
                  ),
          ),

          // Generating indicator card if busy
          if (isGenerating)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryEmerald),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'PocketAI is analyzing your finances...',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: financialColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),

          // Ergonomic Bottom Input Bar
          _buildInputBar(context, isDark, financialColors, isGenerating),
        ],
      ),
    );
  }

  /// Modern Hero Empty State with 2x2 prompt starter cards
  Widget _buildHeroEmptyState(
    BuildContext context,
    bool isDark,
    AppFinancialColors financialColors,
  ) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        children: [
          // Hero Glowing Avatar
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primaryEmerald,
                  AppColors.primaryTeal,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryEmerald.withAlpha(isDark ? 80 : 50),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'How can I help with your finances?',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Ask me anything about your cash flows, budgets, debts, and savings goals.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: financialColors.textMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),

          // 2x2 Responsive Prompt Starter Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 360;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildPromptCard(
                    title: 'Audit Top Spending',
                    subtitle: 'Find spending leaks & tips to save',
                    icon: Icons.pie_chart_outline_rounded,
                    iconColor: AppColors.expense,
                    prompt: 'Audit my highest expense category this month and give me practical tips to reduce it.',
                    width: isNarrow ? constraints.maxWidth : (constraints.maxWidth - 10) / 2,
                    isDark: isDark,
                    financialColors: financialColors,
                  ),
                  _buildPromptCard(
                    title: 'Emergency Runway',
                    subtitle: 'Check safety fund buffer status',
                    icon: Icons.shield_outlined,
                    iconColor: AppColors.income,
                    prompt: 'Analyze my emergency fund buffer and safety duration based on my monthly expenses.',
                    width: isNarrow ? constraints.maxWidth : (constraints.maxWidth - 10) / 2,
                    isDark: isDark,
                    financialColors: financialColors,
                  ),
                  _buildPromptCard(
                    title: 'Prepay vs Invest',
                    subtitle: 'Loan prepay vs mutual fund SIPs',
                    icon: Icons.account_balance_outlined,
                    iconColor: AppColors.investment,
                    prompt: 'Should I prioritize prepaying my active loans or investing more in mutual funds/equity?',
                    width: isNarrow ? constraints.maxWidth : (constraints.maxWidth - 10) / 2,
                    isDark: isDark,
                    financialColors: financialColors,
                  ),
                  _buildPromptCard(
                    title: 'Trip Affordability',
                    subtitle: 'Vacation readiness evaluation',
                    icon: Icons.flight_takeoff_rounded,
                    iconColor: AppColors.info,
                    prompt: 'Based on my current cash balance, expenses, and safety runway, can I comfortably afford a ${CurrencyFormatter.currentSymbol}15,000 trip next month?',
                    width: isNarrow ? constraints.maxWidth : (constraints.maxWidth - 10) / 2,
                    isDark: isDark,
                    financialColors: financialColors,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPromptCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required String prompt,
    required double width,
    required bool isDark,
    required AppFinancialColors financialColors,
  }) {
    return InkWell(
      onTap: () => _sendMessage(prompt),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: financialColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withAlpha(isDark ? 40 : 25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: financialColors.textMuted,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// Full-width edge-to-edge message stream (ChatGPT / Claude / Gemini style)
  Widget _buildMessageItem(
    BuildContext context,
    AiChatMessage message,
    bool isDark,
    AppFinancialColors financialColors, {
    bool isLastAiMessage = false,
  }) {
    final theme = Theme.of(context);
    final isUser = message.isUser;

    if (isUser) {
      // User message: Compact right-aligned bubble
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF047857) : AppColors.primaryEmerald,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableText(
                message.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14.5,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('h:mm a').format(message.timestamp),
                style: TextStyle(
                  color: Colors.white.withAlpha(160),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // AI Assistant message: Full-width layout spanning edge-to-edge
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Assistant Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryEmerald.withAlpha(isDark ? 45 : 30),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primaryEmerald, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                'PocketAI',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.black12,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  DateFormat('h:mm a').format(message.timestamp),
                  style: TextStyle(
                    fontSize: 10,
                    color: financialColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Rich Markdown Body with Horizontally Scrollable Tables
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: MarkdownBody(
              data: message.text,
              selectable: true,
              styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                tableColumnWidth: const IntrinsicColumnWidth(),
                tableCellsPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                tableBorder: TableBorder.all(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(8),
                ),
                tableHead: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 12.5,
                ),
                tableBody: TextStyle(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  fontSize: 12,
                ),
                p: TextStyle(
                  fontSize: 14,
                  height: 1.55,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
                h1: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black,
                  height: 1.4,
                ),
                h2: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black,
                  height: 1.4,
                ),
                h3: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.primaryEmerald : const Color(0xFF047857),
                  height: 1.4,
                ),
                listBullet: const TextStyle(
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
                  fontSize: 13,
                ),
                blockquoteDecoration: BoxDecoration(
                  border: const Border(
                    left: BorderSide(color: AppColors.primaryEmerald, width: 3),
                  ),
                  color: AppColors.primaryEmerald.withAlpha(isDark ? 25 : 15),
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(6)),
                ),
                code: TextStyle(
                  backgroundColor: isDark ? Colors.white10 : Colors.black12,
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Message Action Bar (Copy, Share, Regenerate)
          Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: const Icon(Icons.copy_rounded, size: 16),
                tooltip: 'Copy Message',
                onPressed: () => _copyText(message.text),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: const Icon(Icons.share_outlined, size: 16),
                tooltip: 'Share Insight',
                onPressed: () => _shareText(message.text),
              ),
              if (isLastAiMessage)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  tooltip: 'Regenerate Response',
                  onPressed: () {
                    // Find preceding user message
                    final userMsgs = ref.read(aiChatProvider).messages.where((m) => m.isUser).toList();
                    if (userMsgs.isNotEmpty) {
                      _sendMessage(userMsgs.last.text);
                    }
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Ergonomic bottom text input pill (auto-expanding 1 to 5 lines)
  Widget _buildInputBar(
    BuildContext context,
    bool isDark,
    AppFinancialColors financialColors,
    bool isGenerating,
  ) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          border: Border(top: BorderSide(color: financialColors.cardBorder)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Input TextField Pill
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _focusNode.hasFocus
                        ? AppColors.primaryEmerald
                        : financialColors.cardBorder,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        focusNode: _focusNode,
                        minLines: 1,
                        maxLines: 5,
                        textInputAction: TextInputAction.newline,
                        enabled: !isGenerating,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: isGenerating
                              ? 'PocketAI is thinking...'
                              : 'Ask PocketAI about your finances...',
                          hintStyle: TextStyle(
                            fontSize: 13.5,
                            color: financialColors.textMuted,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                    if (_hasInputText && !isGenerating)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () => _messageController.clear(),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Send Button
            Container(
              height: 46,
              width: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isGenerating
                    ? AppColors.primaryEmerald.withAlpha(40)
                    : (_hasInputText ? AppColors.primaryEmerald : (isDark ? Colors.white12 : Colors.black12)),
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: isGenerating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryEmerald),
                      )
                    : Icon(
                        Icons.arrow_upward_rounded,
                        color: _hasInputText ? Colors.white : (isDark ? Colors.white38 : Colors.black38),
                        size: 22,
                      ),
                onPressed: (isGenerating || !_hasInputText) ? null : () => _sendMessage(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
