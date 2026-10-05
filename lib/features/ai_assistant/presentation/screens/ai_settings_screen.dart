import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/entities/ai_assistant_entity.dart';
import '../../../../core/utilities/app_haptics.dart';
import '../state/ai_assistant_provider.dart';

enum _ProviderCategory {
  all('All Engines'),
  frontier('Frontier Cloud'),
  speed('Speed & Open'),
  local('Local / Sovereign');

  final String label;
  const _ProviderCategory(this.label);
}

class AiSettingsScreen extends ConsumerStatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  ConsumerState<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends ConsumerState<AiSettingsScreen> {
  final TextEditingController _geminiKeyController = TextEditingController();
  final TextEditingController _openAiKeyController = TextEditingController();
  final TextEditingController _anthropicKeyController = TextEditingController();
  final TextEditingController _groqKeyController = TextEditingController();
  final TextEditingController _openRouterKeyController =
      TextEditingController();
  final TextEditingController _deepSeekKeyController = TextEditingController();
  final TextEditingController _customKeyController = TextEditingController();
  final TextEditingController _customBaseUrlController =
      TextEditingController();
  final TextEditingController _customNewModelController =
      TextEditingController();

  late AiProviderType _focusedProvider;
  _ProviderCategory _selectedCategory = _ProviderCategory.all;

  final Map<AiProviderType, bool> _obscureKeys = {
    for (final p in AiProviderType.values) p: true,
  };

  final Map<AiProviderType, bool> _isTesting = {
    for (final p in AiProviderType.values) p: false,
  };

  final Map<AiProviderType, String?> _testStatuses = {
    for (final p in AiProviderType.values) p: null,
  };

  final Map<AiProviderType, int?> _testLatencies = {
    for (final p in AiProviderType.values) p: null,
  };

  @override
  void initState() {
    super.initState();
    final config = ref.read(aiProviderConfigProvider);
    _geminiKeyController.text = config.geminiApiKey;
    _openAiKeyController.text = config.openAiApiKey;
    _anthropicKeyController.text = config.anthropicApiKey;
    _groqKeyController.text = config.groqApiKey;
    _openRouterKeyController.text = config.openRouterApiKey;
    _deepSeekKeyController.text = config.deepSeekApiKey;
    _customKeyController.text = config.customApiKey;
    _customBaseUrlController.text = config.customBaseUrl;

    _focusedProvider = config.providerType;
  }

  @override
  void dispose() {
    _geminiKeyController.dispose();
    _openAiKeyController.dispose();
    _anthropicKeyController.dispose();
    _groqKeyController.dispose();
    _openRouterKeyController.dispose();
    _deepSeekKeyController.dispose();
    _customKeyController.dispose();
    _customBaseUrlController.dispose();
    _customNewModelController.dispose();
    super.dispose();
  }

  TextEditingController _controllerFor(AiProviderType provider) {
    switch (provider) {
      case AiProviderType.gemini:
        return _geminiKeyController;
      case AiProviderType.openAi:
        return _openAiKeyController;
      case AiProviderType.anthropic:
        return _anthropicKeyController;
      case AiProviderType.groq:
        return _groqKeyController;
      case AiProviderType.openRouter:
        return _openRouterKeyController;
      case AiProviderType.deepSeek:
        return _deepSeekKeyController;
      case AiProviderType.custom:
        return _customKeyController;
    }
  }

  Color _colorFor(AiProviderType provider) {
    switch (provider) {
      case AiProviderType.gemini:
        return AppColors.primaryEmerald;
      case AiProviderType.openAi:
        return const Color(0xFF10A37F);
      case AiProviderType.anthropic:
        return const Color(0xFFD97706);
      case AiProviderType.groq:
        return const Color(0xFF0EA5E9);
      case AiProviderType.openRouter:
        return const Color(0xFF6366F1);
      case AiProviderType.deepSeek:
        return const Color(0xFF0284C7);
      case AiProviderType.custom:
        return const Color(0xFF8B5CF6);
    }
  }

  String _providerBadge(AiProviderType provider) {
    switch (provider) {
      case AiProviderType.gemini:
        return 'Google AI Studio';
      case AiProviderType.openAi:
        return 'OpenAI Platform';
      case AiProviderType.anthropic:
        return 'Anthropic Console';
      case AiProviderType.groq:
        return 'GroqCloud LPUs';
      case AiProviderType.openRouter:
        return 'Meta & Multi-Routing';
      case AiProviderType.deepSeek:
        return 'DeepSeek Platform';
      case AiProviderType.custom:
        return 'Local / Self-Hosted';
    }
  }

  _ProviderCategory _categoryFor(AiProviderType provider) {
    switch (provider) {
      case AiProviderType.gemini:
      case AiProviderType.openAi:
      case AiProviderType.anthropic:
        return _ProviderCategory.frontier;
      case AiProviderType.groq:
      case AiProviderType.openRouter:
      case AiProviderType.deepSeek:
        return _ProviderCategory.speed;
      case AiProviderType.custom:
        return _ProviderCategory.local;
    }
  }

  List<AiProviderType> get _filteredProviders {
    if (_selectedCategory == _ProviderCategory.all) {
      return AiProviderType.values;
    }
    return AiProviderType.values
        .where((p) => _categoryFor(p) == _selectedCategory)
        .toList();
  }

  Future<void> _testKey(AiProviderType provider) async {
    final rawKey = _controllerFor(provider).text;
    final key = rawKey.trim().replaceAll(RegExp(r'["\x27\r\n]'), '');

    if (provider != AiProviderType.custom && key.isEmpty) {
      AppHaptics.warning();
      setState(() {
        _testStatuses[provider] =
            'Please enter an API key for ${provider.displayName}.';
        _testLatencies[provider] = null;
      });
      return;
    }

    if (provider == AiProviderType.custom &&
        _customBaseUrlController.text.trim().isEmpty) {
      AppHaptics.warning();
      setState(() {
        _testStatuses[provider] =
            'Please specify a Base URL for the custom endpoint.';
        _testLatencies[provider] = null;
      });
      return;
    }

    setState(() {
      _isTesting[provider] = true;
      _testStatuses[provider] = null;
      _testLatencies[provider] = null;
    });

    AppHaptics.buttonPress();
    final notifier = ref.read(aiProviderConfigProvider.notifier);
    await notifier.updateApiKeyFor(provider, key);
    if (provider == AiProviderType.custom) {
      await notifier.updateCustomBaseUrl(_customBaseUrlController.text.trim());
    }

    final config = ref
        .read(aiProviderConfigProvider)
        .copyWith(providerType: provider);
    final aiService = ref.read(aiServiceProvider);

    final stopwatch = Stopwatch()..start();
    bool success = false;
    try {
      success = await aiService.testConnection(config);
    } catch (_) {
      success = false;
    } finally {
      stopwatch.stop();
    }

    if (mounted) {
      final elapsed = stopwatch.elapsedMilliseconds;
      if (success) {
        AppHaptics.success();
      } else {
        AppHaptics.warning();
      }

      setState(() {
        _isTesting[provider] = false;
        _testLatencies[provider] = elapsed;
        _testStatuses[provider] = success
            ? 'Connection verified successfully (${elapsed}ms). Engine is ready for PocketAI!'
            : 'Connection test failed (${elapsed}ms). Verify API key, endpoint URL, or network.';
      });
    }
  }

  Future<void> _pasteKeyFromClipboard(AiProviderType provider) async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text =
          data?.text?.trim().replaceAll(RegExp(r'["\x27\r\n]'), '') ?? '';
      if (text.isEmpty) {
        if (mounted) {
          AppHaptics.warning();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Clipboard is empty or contains no text'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      _controllerFor(provider).text = text;
      await ref
          .read(aiProviderConfigProvider.notifier)
          .updateApiKeyFor(provider, text);
      AppHaptics.success();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Pasted ${provider.displayName} API key from clipboard',
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AppHaptics.warning();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Clipboard error: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.expense,
          ),
        );
      }
    }
  }

  void _confirmClearKey(AiProviderType provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: AppColors.expense),
            SizedBox(width: 8),
            Expanded(child: Text('Clear Stored Key?')),
          ],
        ),
        content: Text(
          'Remove stored credentials for ${provider.displayName}? You will need to enter the key again to use this engine.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () {
              Navigator.pop(ctx);
              _controllerFor(provider).clear();
              ref
                  .read(aiProviderConfigProvider.notifier)
                  .updateApiKeyFor(provider, '');
              setState(() {
                _testStatuses[provider] = null;
                _testLatencies[provider] = null;
              });
              AppHaptics.deleteAction();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Cleared ${provider.displayName} API Key'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Clear Key'),
          ),
        ],
      ),
    );
  }

  Future<void> _copyKeyUrl(AiProviderType provider) async {
    try {
      await Clipboard.setData(ClipboardData(text: provider.keyUrl));
      AppHaptics.selectionClick();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Copied portal link: ${provider.keyUrl}'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {}
  }

  void _handleAddCustomModel() {
    final modelName = _customNewModelController.text.trim();
    if (modelName.isEmpty) return;

    ref.read(aiProviderConfigProvider.notifier).addCustomSavedModel(modelName);
    _customNewModelController.clear();
    FocusScope.of(context).unfocus();
    AppHaptics.success();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added custom model "$modelName"'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleRemoveCustomModel(String modelName) {
    AppHaptics.deleteAction();
    ref
        .read(aiProviderConfigProvider.notifier)
        .removeCustomSavedModel(modelName);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed "$modelName"'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showSecurityInfoDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.shield_rounded, color: AppColors.primaryEmerald),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'BYOK Security & Privacy',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoBullet(
                icon: Icons.lock_outline_rounded,
                title: 'Hardware-Backed Encryption',
                description: 'All API keys are encrypted with AES-256 on-device in Android Keystore / Apple Keychain via FlutterSecureStorage.',
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _buildInfoBullet(
                icon: Icons.sync_alt_rounded,
                title: 'Direct Peer-to-Provider Streaming',
                description: 'EmptyPocket communicates directly from your device to your selected provider or local IP without intermediary proxies or telemetry.',
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _buildInfoBullet(
                icon: Icons.dns_rounded,
                title: 'Offline & Sovereign LLMs',
                description: 'Use custom local endpoints (Ollama, LM Studio, vLLM) for 100% air-gapped, sovereign financial analysis without internet access.',
                isDark: isDark,
              ),
            ],
          ),
        ),
        actions: [
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBullet({
    required IconData icon,
    required String title,
    required String description,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.primaryEmerald.withAlpha(isDark ? 35 : 20),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.primaryEmerald, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final financialColors = context.financialColors;
    final isDark = theme.brightness == Brightness.dark;
    final config = ref.watch(aiProviderConfigProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AI Providers & BYOK Vault',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            Text(
              'Hardware Encrypted • Direct Stream',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: financialColors.textMuted,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'Security & Privacy Architecture',
            onPressed: () => _showSecurityInfoDialog(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Hero Active Engine Showcase
                  _buildActiveEngineHero(
                    context: context,
                    config: config,
                    isDark: isDark,
                    financialColors: financialColors,
                  ),
                  const SizedBox(height: 22),

                  // 2. Intelligence Engine Hub & Category Switcher
                  _buildEngineHubSection(
                    context: context,
                    config: config,
                    isDark: isDark,
                    financialColors: financialColors,
                  ),
                  const SizedBox(height: 20),

                  // 3. Focused Engine Studio Card
                  _buildEngineStudioCard(
                    context: context,
                    provider: _focusedProvider,
                    config: config,
                    isDark: isDark,
                    financialColors: financialColors,
                  ),
                  const SizedBox(height: 22),

                  // 4. Privacy & Transparency Assurance Card
                  _buildSecurityVaultCard(
                    context: context,
                    isDark: isDark,
                    financialColors: financialColors,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. ACTIVE ENGINE HERO CARD
  // ---------------------------------------------------------------------------
  Widget _buildActiveEngineHero({
    required BuildContext context,
    required AiProviderConfig config,
    required bool isDark,
    required AppFinancialColors financialColors,
  }) {
    final theme = Theme.of(context);
    final activeProvider = config.providerType;
    final activeColor = _colorFor(activeProvider);
    final isConfigured = config.isConfigured;
    final isTesting = _isTesting[activeProvider] ?? false;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  activeColor.withAlpha(45),
                  AppColors.darkSurface,
                  AppColors.darkSurfaceVariant.withAlpha(120),
                ]
              : [
                  activeColor.withAlpha(20),
                  AppColors.lightSurface,
                  AppColors.lightSurfaceVariant,
                ],
        ),
        border: Border.all(
          color: activeColor.withAlpha(isDark ? 90 : 50),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: activeColor.withAlpha(isDark ? 25 : 12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Active Engine Badge & Configuration Status
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: activeColor.withAlpha(isDark ? 40 : 25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: activeColor.withAlpha(80)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: activeColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'ACTIVE ENGINE',
                        style: TextStyle(
                          color: activeColor,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: (isConfigured ? AppColors.income : AppColors.warning)
                        .withAlpha(isDark ? 35 : 20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isConfigured
                            ? Icons.check_circle_rounded
                            : Icons.error_outline_rounded,
                        size: 13,
                        color: isConfigured
                            ? AppColors.income
                            : AppColors.warning,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isConfigured ? 'Ready & Verified' : 'Setup Required',
                        style: TextStyle(
                          color: isConfigured
                              ? AppColors.income
                              : AppColors.warning,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Provider Identity & Active Model
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: activeColor.withAlpha(isDark ? 50 : 30),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: activeColor.withAlpha(120),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    activeProvider.icon,
                    color: activeColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activeProvider.displayName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.memory_rounded,
                            size: 14,
                            color: activeColor,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              config.activeModelDisplayName,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Security Tags & Quick Ping Action
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_rounded,
                          size: 13,
                          color: financialColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Direct SSL Stream',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: financialColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: 13,
                          color: financialColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Zero Telemetry',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: financialColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    backgroundColor: activeColor.withAlpha(isDark ? 40 : 25),
                    foregroundColor: isDark ? Colors.white : activeColor,
                  ),
                  icon: isTesting
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: activeColor,
                          ),
                        )
                      : Icon(Icons.bolt_rounded, size: 16, color: activeColor),
                  label: Text(
                    isTesting ? 'Pinging...' : 'Quick Test Ping',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  onPressed: isTesting ? null : () => _testKey(activeProvider),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. INTELLIGENCE ENGINE HUB SECTION
  // ---------------------------------------------------------------------------
  Widget _buildEngineHubSection({
    required BuildContext context,
    required AiProviderConfig config,
    required bool isDark,
    required AppFinancialColors financialColors,
  }) {
    final theme = Theme.of(context);
    final filtered = _filteredProviders;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(
              'Intelligence Engine Hub',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              '${config.configuredProviders.length} of ${AiProviderType.values.length} configured',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: financialColors.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Select an engine below to inspect credentials, change models, or activate for PocketAI.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
        ),
        const SizedBox(height: 12),

        // Category Filter Pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: _ProviderCategory.values.map((cat) {
              final isCatSelected = _selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  visualDensity: VisualDensity.compact,
                  label: Text(
                    cat.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isCatSelected
                          ? FontWeight.w800
                          : FontWeight.w600,
                    ),
                  ),
                  selected: isCatSelected,
                  selectedColor: AppColors.primaryEmerald.withAlpha(
                    isDark ? 45 : 30,
                  ),
                  labelStyle: TextStyle(
                    color: isCatSelected
                        ? (isDark
                              ? AppColors.primaryMint
                              : AppColors.primaryTeal)
                        : (isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary),
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      AppHaptics.selectionClick();
                      setState(() {
                        _selectedCategory = cat;
                        // If focused provider is no longer in filter, focus first available
                        if (!_filteredProviders.contains(_focusedProvider)) {
                          _focusedProvider = _filteredProviders.first;
                        }
                      });
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),

        // Responsive Engine Selection Grid/Wrap
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final int crossAxisCount = width > 540 ? 4 : (width > 360 ? 3 : 2);
            final double itemWidth =
                (width - ((crossAxisCount - 1) * 10)) / crossAxisCount;

            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: filtered.map((provider) {
                final isFocused = _focusedProvider == provider;
                final isActive = config.providerType == provider;
                final isConfigured = config.isProviderConfigured(provider);
                final providerColor = _colorFor(provider);

                return SizedBox(
                  width: itemWidth,
                  height: 122,
                  child: InkWell(
                    onTap: () {
                      AppHaptics.selectionClick();
                      setState(() => _focusedProvider = provider);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSurface
                            : AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isFocused
                              ? providerColor
                              : (isActive
                                    ? providerColor.withAlpha(120)
                                    : financialColors.cardBorder),
                          width: isFocused ? 2 : 1,
                        ),
                        boxShadow: isFocused
                            ? [
                                BoxShadow(
                                  color: providerColor.withAlpha(
                                    isDark ? 40 : 20,
                                  ),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Top Row: Icon + Configured Dot
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: providerColor.withAlpha(
                                    isDark ? 40 : 25,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  provider.icon,
                                  color: providerColor,
                                  size: 18,
                                ),
                              ),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: isConfigured
                                      ? AppColors.income
                                      : (isDark
                                            ? Colors.white24
                                            : Colors.black12),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),

                          // Provider Name
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                provider.displayName,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isFocused
                                      ? FontWeight.w900
                                      : FontWeight.w700,
                                  color: isFocused ? providerColor : null,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isConfigured ? 'Ready' : 'Setup needed',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: isConfigured
                                      ? AppColors.income
                                      : (isDark
                                            ? AppColors.darkTextMuted
                                            : AppColors.lightTextMuted),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),

                          // Active Engine Badge or Action
                          if (isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: providerColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'ACTIVE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            )
                          else if (isFocused)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: providerColor.withAlpha(
                                  isDark ? 30 : 20,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'EDITING',
                                style: TextStyle(
                                  color: providerColor,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            )
                          else
                            const SizedBox(height: 14),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 3. FOCUSED ENGINE STUDIO CARD
  // ---------------------------------------------------------------------------
  Widget _buildEngineStudioCard({
    required BuildContext context,
    required AiProviderType provider,
    required AiProviderConfig config,
    required bool isDark,
    required AppFinancialColors financialColors,
  }) {
    final theme = Theme.of(context);
    final isActive = config.providerType == provider;
    final isConfigured = config.isProviderConfigured(provider);
    final providerColor = _colorFor(provider);
    final controller = _controllerFor(provider);
    final obscureKey = _obscureKeys[provider] ?? true;
    final isTesting = _isTesting[provider] ?? false;
    final testStatus = _testStatuses[provider];
    final testLatency = _testLatencies[provider];

    final isCustom = provider == AiProviderType.custom;
    final modelOptions = config.getModelOptionsFor(provider);
    final currentModel = config.getModelFor(provider);
    final isModelInOptions = modelOptions.any((o) => o.id == currentModel);
    final effectiveModel = isModelInOptions
        ? currentModel
        : (modelOptions.isNotEmpty ? modelOptions.first.id : currentModel);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: isActive
              ? providerColor.withAlpha(160)
              : financialColors.cardBorder,
          width: isActive ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Studio Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: providerColor.withAlpha(isDark ? 40 : 25),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          provider.icon,
                          color: providerColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    provider.displayName,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isActive) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: providerColor,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'ACTIVE',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              _providerBadge(provider),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.darkTextMuted
                                    : AppColors.lightTextMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isActive)
                  FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      backgroundColor: providerColor.withAlpha(
                        isDark ? 40 : 25,
                      ),
                      foregroundColor: isDark ? Colors.white : providerColor,
                    ),
                    onPressed: () {
                      AppHaptics.selectionClick();
                      ref
                          .read(aiProviderConfigProvider.notifier)
                          .updateProvider(provider);
                    },
                    child: const Text(
                      'Set Active',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 18),

            // Model Selection Dropdown
            Text(
              'Intelligence Model',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              key: ValueKey('${provider.name}_$effectiveModel'),
              initialValue: effectiveModel,
              isExpanded: true,
              isDense: true,
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.memory_rounded, color: providerColor),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              items: modelOptions.map((opt) {
                return DropdownMenuItem(
                  value: opt.id,
                  child: Text(
                    opt.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (newModel) {
                if (newModel != null) {
                  AppHaptics.selectionClick();
                  ref
                      .read(aiProviderConfigProvider.notifier)
                      .updateModelFor(provider, newModel);
                }
              },
            ),
            const SizedBox(height: 16),

            // If Custom Endpoint: Base URL & Presets
            if (isCustom) ...[
              Text(
                'Base URL (OpenAI-compatible Endpoint)',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _customBaseUrlController,
                decoration: InputDecoration(
                  hintText: 'http://10.0.2.2:11434/v1',
                  prefixIcon: Icon(Icons.link_rounded, color: providerColor),
                  suffixIcon: _customBaseUrlController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _customBaseUrlController.clear();
                            ref
                                .read(aiProviderConfigProvider.notifier)
                                .updateCustomBaseUrl('');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onChanged: (url) {
                  ref
                      .read(aiProviderConfigProvider.notifier)
                      .updateCustomBaseUrl(url);
                },
              ),
              const SizedBox(height: 8),

              // Quick Presets
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildPresetChip(
                    'Ollama (Emulator)',
                    'http://10.0.2.2:11434/v1',
                    providerColor,
                  ),
                  _buildPresetChip(
                    'Ollama (Localhost)',
                    'http://localhost:11434/v1',
                    providerColor,
                  ),
                  _buildPresetChip(
                    'LM Studio',
                    'http://10.0.2.2:1234/v1',
                    providerColor,
                  ),
                  _buildPresetChip(
                    'vLLM',
                    'http://10.0.2.2:8000/v1',
                    providerColor,
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // API Key Input Field
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  isCustom
                      ? 'Custom API Key (Optional)'
                      : '${provider.displayName} API Key',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
                if (controller.text.isNotEmpty)
                  InkWell(
                    onTap: () => _confirmClearKey(provider),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      child: Text(
                        'Clear Key',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.expense.withAlpha(220),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: controller,
              obscureText: obscureKey,
              decoration: InputDecoration(
                hintText: isCustom
                    ? 'Leave empty if unauthenticated'
                    : 'Enter or paste API key',
                prefixIcon: Icon(Icons.key_rounded, color: providerColor),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        obscureKey
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                      ),
                      tooltip: obscureKey ? 'Show Key' : 'Hide Key',
                      onPressed: () =>
                          setState(() => _obscureKeys[provider] = !obscureKey),
                    ),
                    IconButton(
                      icon: const Icon(Icons.content_paste_rounded, size: 20),
                      tooltip: 'Paste from Clipboard',
                      onPressed: () => _pasteKeyFromClipboard(provider),
                    ),
                  ],
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onChanged: (val) {
                ref
                    .read(aiProviderConfigProvider.notifier)
                    .updateApiKeyFor(provider, val);
              },
            ),
            const SizedBox(height: 6),
            Text(
              isCustom
                  ? 'Optional for unauthenticated local instances like Ollama.'
                  : 'Encrypted securely in hardware-backed Keystore on this device.',
              style: TextStyle(
                fontSize: 11,
                color: isDark
                    ? AppColors.darkTextMuted
                    : AppColors.lightTextMuted,
              ),
            ),
            const SizedBox(height: 14),

            // If Custom: Add Model & Saved Models Manager
            if (isCustom) ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _customNewModelController,
                      decoration: InputDecoration(
                        labelText: 'Add Custom Model Name',
                        hintText: 'e.g. mistral-nemo, deepseek-r1:8b',
                        prefixIcon: Icon(
                          Icons.add_box_outlined,
                          color: providerColor,
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onSubmitted: (_) => _handleAddCustomModel(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                    onPressed: _handleAddCustomModel,
                    child: const Text('Add'),
                  ),
                ],
              ),
              if (config.customSavedModels.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Saved Custom Models:',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.darkTextMuted
                        : AppColors.lightTextMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: config.customSavedModels.map((savedModel) {
                    final isCurrent = config.customModel == savedModel;
                    return InputChip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        savedModel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isCurrent
                              ? FontWeight.w800
                              : FontWeight.w500,
                          color: isCurrent ? providerColor : null,
                        ),
                      ),
                      selected: isCurrent,
                      selectedColor: providerColor.withAlpha(isDark ? 40 : 25),
                      onSelected: (_) {
                        AppHaptics.selectionClick();
                        ref
                            .read(aiProviderConfigProvider.notifier)
                            .updateModelFor(provider, savedModel);
                      },
                      onDeleted: () => _handleRemoveCustomModel(savedModel),
                      deleteIconColor: isDark ? Colors.white60 : Colors.black54,
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 14),
            ],

            // Key Portal Link & Diagnostics Action
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!isCustom)
                  InkWell(
                    onTap: () => _copyKeyUrl(provider),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.copy_rounded,
                            size: 14,
                            color: providerColor,
                          ),
                          const SizedBox(width: 5),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 200),
                            child: Text(
                              'Copy Portal Link: ${provider.keyUrl.replaceFirst("https://", "")}',
                              style: TextStyle(
                                color: providerColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Text(
                    isConfigured ? 'Ready to connect' : 'Base URL required',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isConfigured
                          ? AppColors.income
                          : financialColors.textMuted,
                    ),
                  ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    backgroundColor: providerColor,
                    foregroundColor: Colors.white,
                  ),
                  icon: isTesting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 16,
                        ),
                  label: Text(
                    isTesting ? 'Verifying...' : 'Test Connection',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  onPressed: isTesting ? null : () => _testKey(provider),
                ),
              ],
            ),

            // Test Feedback Banner
            if (testStatus != null) ...[
              const SizedBox(height: 14),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: testStatus.startsWith('Connection verified')
                      ? AppColors.income.withAlpha(isDark ? 30 : 18)
                      : AppColors.expense.withAlpha(isDark ? 30 : 18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: testStatus.startsWith('Connection verified')
                        ? AppColors.income.withAlpha(90)
                        : AppColors.expense.withAlpha(90),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      testStatus.startsWith('Connection verified')
                          ? Icons.check_circle_rounded
                          : Icons.error_outline_rounded,
                      color: testStatus.startsWith('Connection verified')
                          ? AppColors.income
                          : AppColors.expense,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            testStatus,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color:
                                  testStatus.startsWith('Connection verified')
                                  ? AppColors.income
                                  : AppColors.expense,
                            ),
                          ),
                          if (testLatency != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Round-trip ping response: ${testLatency}ms',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.darkTextMuted
                                    : AppColors.lightTextMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, String url, Color providerColor) {
    return ActionChip(
      visualDensity: VisualDensity.compact,
      label: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
      onPressed: () {
        AppHaptics.selectionClick();
        _customBaseUrlController.text = url;
        ref.read(aiProviderConfigProvider.notifier).updateCustomBaseUrl(url);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 4. SECURITY & PRIVACY TRANSPARENCY CARD
  // ---------------------------------------------------------------------------
  Widget _buildSecurityVaultCard({
    required BuildContext context,
    required bool isDark,
    required AppFinancialColors financialColors,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceVariant.withAlpha(70)
            : AppColors.lightSurfaceVariant,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: financialColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.shield_outlined,
                color: AppColors.primaryEmerald,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '100% Private BYOK Architecture',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'EmptyPocket is designed with zero server-side telemetry. Your API keys never leave this device and connect directly to official model APIs over encrypted TLS streams.',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.4,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _buildSecurityTag(Icons.lock_rounded, 'AES-256 Keystore', isDark),
              _buildSecurityTag(
                Icons.wifi_off_rounded,
                'Zero Proxy Middleware',
                isDark,
              ),
              _buildSecurityTag(
                Icons.visibility_off_rounded,
                'No Data Logging',
                isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityTag(IconData icon, String text, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.primaryEmerald),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
        ),
      ],
    );
  }
}
