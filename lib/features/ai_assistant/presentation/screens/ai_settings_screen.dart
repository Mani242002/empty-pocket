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
  final TextEditingController _groqKeyController = TextEditingController();

  bool _obscureGeminiKey = true;
  bool _obscureGroqKey = true;
  bool _isTestingGemini = false;
  bool _isTestingGroq = false;
  String? _geminiTestStatus;
  String? _groqTestStatus;

  @override
  void initState() {
    super.initState();
    final config = ref.read(aiProviderConfigProvider);
    _geminiKeyController.text = config.geminiApiKey;
    _groqKeyController.text = config.groqApiKey;
  }

  @override
  void dispose() {
    _geminiKeyController.dispose();
    _groqKeyController.dispose();
    super.dispose();
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                        'Your API keys are encrypted on-device. When generating AI reports or chatting with PocketAI, your aggregated financial metrics are sent directly to your chosen AI endpoint using your key. No third-party servers or telemetry are involved.',
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

          // Active Provider Toggle
          Text(
            'Default Active AI Provider',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
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
          const SizedBox(height: 24),

          // Section 1: Google Gemini Card
          _buildProviderCard(
            context: context,
            title: 'Google Gemini',
            icon: Icons.auto_awesome_rounded,
            iconColor: AppColors.primaryEmerald,
            isActive: config.providerType == AiProviderType.gemini,
            controller: _geminiKeyController,
            obscureKey: _obscureGeminiKey,
            onToggleObscure: () => setState(() => _obscureGeminiKey = !_obscureGeminiKey),
            onKeyChanged: (val) => ref.read(aiProviderConfigProvider.notifier).updateGeminiApiKey(val),
            selectedModel: config.geminiModel,
            modelOptions: AiProviderType.gemini.modelOptions,
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
          const SizedBox(height: 20),

          // Section 2: Groq Card
          _buildProviderCard(
            context: context,
            title: 'Groq (Open Models)',
            icon: Icons.bolt_rounded,
            iconColor: AppColors.info,
            isActive: config.providerType == AiProviderType.groq,
            controller: _groqKeyController,
            obscureKey: _obscureGroqKey,
            onToggleObscure: () => setState(() => _obscureGroqKey = !_obscureGroqKey),
            onKeyChanged: (val) => ref.read(aiProviderConfigProvider.notifier).updateGroqApiKey(val),
            selectedModel: config.groqModel,
            modelOptions: AiProviderType.groq.modelOptions,
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
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildProviderCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color iconColor,
    required bool isActive,
    required TextEditingController controller,
    required bool obscureKey,
    required VoidCallback onToggleObscure,
    required ValueChanged<String> onKeyChanged,
    required String selectedModel,
    required List<AiModelOption> modelOptions,
    required ValueChanged<String?> onModelChanged,
    required String keyUrl,
    required bool isTesting,
    required String? testStatus,
    required VoidCallback onTestKey,
    required bool isDark,
    required AppFinancialColors financialColors,
  }) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isActive ? iconColor.withAlpha(120) : financialColors.cardBorder,
          width: isActive ? 1.8 : 1,
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: iconColor.withAlpha(30),
                      ),
                      child: Icon(icon, color: iconColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                if (isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: iconColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('ACTIVE', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w900)),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Model Selection Dropdown
            DropdownButtonFormField<String>(
              initialValue: selectedModel,
              decoration: const InputDecoration(
                labelText: 'Select AI Model',
                prefixIcon: Icon(Icons.memory_rounded),
              ),
              items: modelOptions.map((opt) {
                return DropdownMenuItem(
                  value: opt.id,
                  child: Text(opt.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                );
              }).toList(),
              onChanged: onModelChanged,
            ),
            const SizedBox(height: 14),

            // API Key Input
            TextFormField(
              controller: controller,
              obscureText: obscureKey,
              decoration: InputDecoration(
                labelText: '$title API Key',
                prefixIcon: const Icon(Icons.key_rounded),
                suffixIcon: IconButton(
                  icon: Icon(obscureKey ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: onToggleObscure,
                ),
              ),
              onChanged: onKeyChanged,
            ),
            const SizedBox(height: 12),

            // Link & Test Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    'Get key: $keyUrl',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: iconColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  ),
                  icon: isTesting
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check_circle_outline_rounded, size: 16),
                  label: const Text('Test Key'),
                  onPressed: isTesting ? null : onTestKey,
                ),
              ],
            ),
            if (testStatus != null) ...[
              const SizedBox(height: 8),
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
}
