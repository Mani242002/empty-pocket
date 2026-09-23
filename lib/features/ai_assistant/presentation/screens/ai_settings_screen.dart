import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/entities/ai_assistant_entity.dart';
import '../state/ai_assistant_provider.dart';

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
  final TextEditingController _openRouterKeyController = TextEditingController();
  final TextEditingController _deepSeekKeyController = TextEditingController();
  final TextEditingController _customKeyController = TextEditingController();
  final TextEditingController _customBaseUrlController = TextEditingController();
  final TextEditingController _customNewModelController = TextEditingController();

  final Map<AiProviderType, bool> _obscureKeys = {
    for (final p in AiProviderType.values) p: true,
  };

  final Map<AiProviderType, bool> _isTesting = {
    for (final p in AiProviderType.values) p: false,
  };

  final Map<AiProviderType, String?> _testStatuses = {
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
        return AppColors.info;
      case AiProviderType.openRouter:
        return const Color(0xFF6366F1);
      case AiProviderType.deepSeek:
        return const Color(0xFF0284C7);
      case AiProviderType.custom:
        return const Color(0xFF8B5CF6);
    }
  }

  Future<void> _testKey(AiProviderType provider) async {
    final rawKey = _controllerFor(provider).text;
    final key = rawKey.trim().replaceAll(RegExp(r'["\x27\r\n]'), '');

    if (provider != AiProviderType.custom && key.isEmpty) {
      setState(() {
        _testStatuses[provider] = 'Please enter an API key for ${provider.displayName}.';
      });
      return;
    }

    if (provider == AiProviderType.custom && _customBaseUrlController.text.trim().isEmpty) {
      setState(() {
        _testStatuses[provider] = 'Please enter a Base URL for Custom Endpoint.';
      });
      return;
    }

    setState(() {
      _isTesting[provider] = true;
      _testStatuses[provider] = null;
    });

    final notifier = ref.read(aiProviderConfigProvider.notifier);
    await notifier.updateApiKeyFor(provider, key);
    if (provider == AiProviderType.custom) {
      await notifier.updateCustomBaseUrl(_customBaseUrlController.text.trim());
    }

    final config = ref.read(aiProviderConfigProvider).copyWith(providerType: provider);
    final aiService = ref.read(aiServiceProvider);
    final success = await aiService.testConnection(config);

    if (mounted) {
      setState(() {
        _isTesting[provider] = false;
        _testStatuses[provider] = success
            ? '✅ ${provider.displayName} connection successful!'
            : '❌ ${provider.displayName} test failed. Check key, URL, or model.';
      });
    }
  }

  void _handleAddCustomModel() {
    final modelName = _customNewModelController.text.trim();
    if (modelName.isEmpty) return;

    ref.read(aiProviderConfigProvider.notifier).addCustomSavedModel(modelName);
    _customNewModelController.clear();
    FocusScope.of(context).unfocus();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added custom model "$modelName"'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
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
        title: const Text('AI Providers & BYOK Vault'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        children: [
          // Privacy Banner & Data Disclosure
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryEmerald.withAlpha(isDark ? 25 : 15),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.primaryEmerald.withAlpha(80)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.shield_outlined, color: AppColors.primaryEmerald, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '100% Private BYOK (Bring Your Own Key)',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your API keys are encrypted securely on-device with hardware-backed Keystore. All AI calls stream directly to your selected provider or local instance without proxy servers, telemetry, or data logging.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Active Provider Selector
          Text(
            'Active AI Provider',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'PocketAI and Financial Audits will query the active provider below.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ),
          const SizedBox(height: 12),

          // Responsive Wrap of Provider Choices
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AiProviderType.values.map((provider) {
              final isSelected = config.providerType == provider;
              final isConfigured = config.isProviderConfigured(provider);
              final providerColor = _colorFor(provider);

              return ChoiceChip(
                avatar: Icon(
                  provider.icon,
                  size: 16,
                  color: isSelected ? Colors.white : providerColor,
                ),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      provider.displayName,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    if (isConfigured) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : AppColors.income,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                selected: isSelected,
                selectedColor: providerColor,
                onSelected: (sel) {
                  if (sel) {
                    ref.read(aiProviderConfigProvider.notifier).updateProvider(provider);
                  }
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          Text(
            'Provider Configurations',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Configure your credentials for each provider. All keys are saved independently and never overwrite each other.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ),
          const SizedBox(height: 16),

          // 1. Google Gemini Card
          _buildStandardProviderCard(
            context: context,
            provider: AiProviderType.gemini,
            config: config,
            isDark: isDark,
            financialColors: financialColors,
          ),
          const SizedBox(height: 16),

          // 2. OpenAI Card
          _buildStandardProviderCard(
            context: context,
            provider: AiProviderType.openAi,
            config: config,
            isDark: isDark,
            financialColors: financialColors,
          ),
          const SizedBox(height: 16),

          // 3. Anthropic Claude Card
          _buildStandardProviderCard(
            context: context,
            provider: AiProviderType.anthropic,
            config: config,
            isDark: isDark,
            financialColors: financialColors,
          ),
          const SizedBox(height: 16),

          // 4. Groq Card
          _buildStandardProviderCard(
            context: context,
            provider: AiProviderType.groq,
            config: config,
            isDark: isDark,
            financialColors: financialColors,
          ),
          const SizedBox(height: 16),

          // 5. OpenRouter Card
          _buildStandardProviderCard(
            context: context,
            provider: AiProviderType.openRouter,
            config: config,
            isDark: isDark,
            financialColors: financialColors,
          ),
          const SizedBox(height: 16),

          // 6. DeepSeek Card
          _buildStandardProviderCard(
            context: context,
            provider: AiProviderType.deepSeek,
            config: config,
            isDark: isDark,
            financialColors: financialColors,
          ),
          const SizedBox(height: 16),

          // 7. Custom Endpoint Card (Ollama / Localhost / LM Studio / Proxy)
          _buildCustomEndpointCard(
            context: context,
            config: config,
            isDark: isDark,
            financialColors: financialColors,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildStandardProviderCard({
    required BuildContext context,
    required AiProviderType provider,
    required AiProviderConfig config,
    required bool isDark,
    required AppFinancialColors financialColors,
  }) {
    final theme = Theme.of(context);
    final isActive = config.providerType == provider;
    final isConfigured = config.isProviderConfigured(provider);
    final iconColor = _colorFor(provider);
    final controller = _controllerFor(provider);
    final obscureKey = _obscureKeys[provider] ?? true;
    final isTesting = _isTesting[provider] ?? false;
    final testStatus = _testStatuses[provider];
    final selectedModel = config.getModelFor(provider);

    return Card(
      elevation: isActive ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isActive ? iconColor.withAlpha(160) : financialColors.cardBorder,
          width: isActive ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Title Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: iconColor.withAlpha(30),
                        ),
                        child: Icon(provider.icon, color: iconColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              provider.displayName,
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: isConfigured ? AppColors.income : (isDark ? Colors.white30 : Colors.black26),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  isConfigured ? 'Key Stored' : 'Not Configured',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isConfigured
                                        ? AppColors.income
                                        : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: iconColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'ACTIVE',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                    ),
                  )
                else
                  TextButton(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    ),
                    onPressed: () {
                      ref.read(aiProviderConfigProvider.notifier).updateProvider(provider);
                    },
                    child: const Text('Set Active', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Model Selection Dropdown
            DropdownButtonFormField<String>(
              key: ValueKey('${provider.name}_$selectedModel'),
              initialValue: selectedModel,
              isExpanded: true,
              isDense: true,
              decoration: const InputDecoration(
                labelText: 'Select AI Model',
                prefixIcon: Icon(Icons.memory_rounded),
              ),
              items: provider.modelOptions.map((opt) {
                return DropdownMenuItem(
                  value: opt.id,
                  child: Text(
                    opt.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                );
              }).toList(),
              onChanged: (newModel) {
                if (newModel != null) {
                  ref.read(aiProviderConfigProvider.notifier).updateModelFor(provider, newModel);
                }
              },
            ),
            const SizedBox(height: 14),

            // API Key Input
            TextFormField(
              controller: controller,
              obscureText: obscureKey,
              decoration: InputDecoration(
                labelText: '${provider.displayName} API Key',
                prefixIcon: const Icon(Icons.key_rounded),
                suffixIcon: IconButton(
                  icon: Icon(obscureKey ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscureKeys[provider] = !obscureKey),
                ),
              ),
              onChanged: (val) {
                ref.read(aiProviderConfigProvider.notifier).updateApiKeyFor(provider, val);
              },
            ),
            const SizedBox(height: 12),

            // Link & Test Button
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Text(
                    'Get key: ${provider.keyUrl}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: iconColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  ),
                  icon: isTesting
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check_circle_outline_rounded, size: 16),
                  label: const Text('Test Key'),
                  onPressed: isTesting ? null : () => _testKey(provider),
                ),
              ],
            ),

            if (testStatus != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: testStatus.startsWith('✅') ? AppColors.income.withAlpha(20) : AppColors.expense.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  testStatus,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: testStatus.startsWith('✅') ? AppColors.income : AppColors.expense,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCustomEndpointCard({
    required BuildContext context,
    required AiProviderConfig config,
    required bool isDark,
    required AppFinancialColors financialColors,
  }) {
    final theme = Theme.of(context);
    const provider = AiProviderType.custom;
    final isActive = config.providerType == provider;
    final isConfigured = config.isProviderConfigured(provider);
    final iconColor = _colorFor(provider);
    final obscureKey = _obscureKeys[provider] ?? true;
    final isTesting = _isTesting[provider] ?? false;
    final testStatus = _testStatuses[provider];

    return Card(
      elevation: isActive ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isActive ? iconColor.withAlpha(160) : financialColors.cardBorder,
          width: isActive ? 2 : 1,
        ),
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
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: iconColor.withAlpha(30),
                        ),
                        child: Icon(Icons.dns_rounded, color: iconColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Custom Endpoint',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Ollama, LM Studio, vLLM, Local',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
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
                if (isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: iconColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'ACTIVE',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                    ),
                  )
                else
                  TextButton(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    ),
                    onPressed: () {
                      ref.read(aiProviderConfigProvider.notifier).updateProvider(provider);
                    },
                    child: const Text('Set Active', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // Base URL Field
            TextFormField(
              controller: _customBaseUrlController,
              decoration: const InputDecoration(
                labelText: 'Base URL (OpenAI-compatible)',
                hintText: 'http://10.0.2.2:11434/v1',
                prefixIcon: Icon(Icons.link_rounded),
              ),
              onChanged: (url) {
                ref.read(aiProviderConfigProvider.notifier).updateCustomBaseUrl(url);
              },
            ),
            const SizedBox(height: 8),

            // Quick Preset Chips for Common Local Runtimes
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildPresetChip('Ollama (Emulator)', 'http://10.0.2.2:11434/v1'),
                _buildPresetChip('Ollama (Localhost)', 'http://localhost:11434/v1'),
                _buildPresetChip('LM Studio', 'http://10.0.2.2:1234/v1'),
                _buildPresetChip('vLLM', 'http://10.0.2.2:8000/v1'),
              ],
            ),
            const SizedBox(height: 14),

            // Optional API Key
            TextFormField(
              controller: _customKeyController,
              obscureText: obscureKey,
              decoration: InputDecoration(
                labelText: 'Custom API Key (Optional)',
                helperText: 'Leave empty for unauthenticated local instances (e.g. default Ollama)',
                prefixIcon: const Icon(Icons.key_rounded),
                suffixIcon: IconButton(
                  icon: Icon(obscureKey ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscureKeys[provider] = !obscureKey),
                ),
              ),
              onChanged: (val) {
                ref.read(aiProviderConfigProvider.notifier).updateApiKeyFor(provider, val);
              },
            ),
            const SizedBox(height: 14),

            // Active Model Dropdown
            () {
              final customOptions = config.getModelOptionsFor(AiProviderType.custom);
              final isModelInOptions = customOptions.any((o) => o.id == config.customModel);
              final effectiveModel = isModelInOptions ? config.customModel : customOptions.first.id;

              return DropdownButtonFormField<String>(
                key: ValueKey('custom_$effectiveModel'),
                initialValue: effectiveModel,
                isExpanded: true,
                isDense: true,
                decoration: const InputDecoration(
                  labelText: 'Select Active Model',
                  prefixIcon: Icon(Icons.memory_rounded),
                ),
                items: customOptions.map((opt) {
                  return DropdownMenuItem(
                    value: opt.id,
                    child: Text(
                      opt.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  );
                }).toList(),
                onChanged: (newModel) {
                  if (newModel != null) {
                    ref.read(aiProviderConfigProvider.notifier).updateModelFor(provider, newModel);
                  }
                },
              );
            }(),
            const SizedBox(height: 14),

            // Add Custom Model Input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customNewModelController,
                    decoration: const InputDecoration(
                      labelText: 'Add Custom Model Name',
                      hintText: 'e.g. mistral-nemo, deepseek-r1:8b',
                      prefixIcon: Icon(Icons.add_box_outlined),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _handleAddCustomModel(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: _handleAddCustomModel,
                  child: const Text('Add'),
                ),
              ],
            ),

            if (config.customSavedModels.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Saved Custom Models:',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: config.customSavedModels.map((savedModel) {
                  final isCurrent = config.customModel == savedModel;
                  return InputChip(
                    label: Text(
                      savedModel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500,
                        color: isCurrent ? iconColor : null,
                      ),
                    ),
                    selected: isCurrent,
                    onSelected: (_) {
                      ref.read(aiProviderConfigProvider.notifier).updateModelFor(provider, savedModel);
                    },
                    onDeleted: () {
                      ref.read(aiProviderConfigProvider.notifier).removeCustomSavedModel(savedModel);
                    },
                    deleteIconColor: isDark ? Colors.white60 : Colors.black54,
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 14),

            // Test Connection Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isConfigured ? 'Ready to test' : 'URL required',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isConfigured ? AppColors.income : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                  ),
                ),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  ),
                  icon: isTesting
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check_circle_outline_rounded, size: 16),
                  label: const Text('Test Connection'),
                  onPressed: isTesting ? null : () => _testKey(provider),
                ),
              ],
            ),

            if (testStatus != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: testStatus.startsWith('✅') ? AppColors.income.withAlpha(20) : AppColors.expense.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  testStatus,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: testStatus.startsWith('✅') ? AppColors.income : AppColors.expense,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, String url) {
    return ActionChip(
      visualDensity: VisualDensity.compact,
      label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      onPressed: () {
        _customBaseUrlController.text = url;
        ref.read(aiProviderConfigProvider.notifier).updateCustomBaseUrl(url);
      },
    );
  }
}
