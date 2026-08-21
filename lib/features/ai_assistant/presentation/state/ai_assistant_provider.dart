import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/calculation/financial_calculator.dart';
import '../../../../core/domain/entities/ai_assistant_entity.dart';
import '../../../../core/services/ai_service.dart';
import '../../../debts/presentation/state/debts_provider.dart';
import '../../../investments/presentation/state/investments_provider.dart';
import '../../../net_worth/presentation/state/net_worth_provider.dart';
import '../../../savings/presentation/state/savings_goals_provider.dart';
import '../../../transactions/presentation/state/transactions_provider.dart';

final aiServiceProvider = Provider<AiService>((ref) => AiService());

class AiProviderConfigNotifier extends StateNotifier<AiProviderConfig> {
  static const String _keyProvider = 'ai_provider_type';
  static const String _keyApiKey = 'ai_api_key';
  static const String _keyModel = 'ai_model';

  AiProviderConfigNotifier() : super(const AiProviderConfig()) {
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final providerStr = prefs.getString(_keyProvider) ?? 'gemini';
      final apiKey = prefs.getString(_keyApiKey) ?? '';
      final model = prefs.getString(_keyModel);

      final provider = providerStr == 'groq' ? AiProviderType.groq : AiProviderType.gemini;

      state = AiProviderConfig(
        providerType: provider,
        apiKey: apiKey,
        selectedModel: model ?? provider.defaultModel,
      );
    } catch (_) {}
  }

  Future<void> updateProvider(AiProviderType provider) async {
    state = state.copyWith(providerType: provider, selectedModel: provider.defaultModel);
    await _saveConfig();
  }

  Future<void> updateApiKey(String apiKey) async {
    state = state.copyWith(apiKey: apiKey.trim());
    await _saveConfig();
  }

  Future<void> updateModel(String model) async {
    state = state.copyWith(selectedModel: model);
    await _saveConfig();
  }

  Future<void> _saveConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyProvider, state.providerType.name);
      await prefs.setString(_keyApiKey, state.apiKey);
      await prefs.setString(_keyModel, state.selectedModel);
    } catch (_) {}
  }
}

final aiProviderConfigProvider =
    StateNotifierProvider<AiProviderConfigNotifier, AiProviderConfig>((ref) {
  return AiProviderConfigNotifier();
});

/// Context provider giving up-to-date financial numbers formatted for AI reasoning
final aiFinancialContextProvider = Provider<String>((ref) {
  final financialSummary = ref.watch(monthlyFinancialSummaryProvider);
  final savingsSummary = ref.watch(overallSavingsSummaryProvider);
  final portfolioSummary = ref.watch(overallPortfolioSummaryProvider);
  final liabilitiesSummary = ref.watch(overallLiabilitiesSummaryProvider);
  final healthSummary = ref.watch(financialHealthSummaryProvider);

  return FinancialCalculator.generateFinancialContextSummary(
    monthlyIncome: financialSummary.totalIncome,
    monthlyExpense: financialSummary.totalExpense,
    monthlyNetBalance: financialSummary.netBalance,
    savingsRate: financialSummary.savingsRate,
    savingsSummary: savingsSummary,
    portfolioSummary: portfolioSummary,
    liabilitiesSummary: liabilitiesSummary,
    healthSummary: healthSummary,
  );
});

class AiAuditNotifier extends StateNotifier<AsyncValue<AiAuditReport?>> {
  final Ref ref;

  AiAuditNotifier(this.ref) : super(const AsyncValue.data(null));

  Future<void> generateAudit() async {
    final config = ref.read(aiProviderConfigProvider);
    if (!config.isConfigured) {
      state = AsyncValue.error(
        'Please enter your ${config.providerType.displayName} API key in AI Settings first.',
        StackTrace.current,
      );
      return;
    }

    state = const AsyncValue.loading();
    try {
      final contextText = ref.read(aiFinancialContextProvider);
      final aiService = ref.read(aiServiceProvider);
      final report = await aiService.generateFinancialAudit(
        config: config,
        financialSummaryText: contextText,
      );
      state = AsyncValue.data(report);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final aiAuditProvider =
    StateNotifierProvider<AiAuditNotifier, AsyncValue<AiAuditReport?>>((ref) {
  return AiAuditNotifier(ref);
});

class AiChatNotifier extends StateNotifier<List<AiChatMessage>> {
  final Ref ref;
  bool isGenerating = false;

  AiChatNotifier(this.ref)
      : super([
          AiChatMessage(
            id: 'welcome',
            text:
                'Hello! I am PocketAI, your private financial advisor. I can analyze your income, expenses, budgets, savings goals, loans, and investment portfolio to answer any financial planning questions. How can I help you today?',
            isUser: false,
            timestamp: DateTime.now(),
          ),
        ]);

  Future<void> sendMessage(String userText) async {
    if (userText.trim().isEmpty || isGenerating) return;

    final config = ref.read(aiProviderConfigProvider);
    final userMsg = AiChatMessage(
      id: const Uuid().v4(),
      text: userText.trim(),
      isUser: true,
      timestamp: DateTime.now(),
    );

    state = [...state, userMsg];

    if (!config.isConfigured) {
      final errorMsg = AiChatMessage(
        id: const Uuid().v4(),
        text:
            '⚠️ Please configure your ${config.providerType.displayName} API Key in AI Settings above to chat with PocketAI.',
        isUser: false,
        timestamp: DateTime.now(),
      );
      state = [...state, errorMsg];
      return;
    }

    isGenerating = true;
    final loadingMsgId = const Uuid().v4();
    final placeholderMsg = AiChatMessage(
      id: loadingMsgId,
      text: 'Analyzing your finances...',
      isUser: false,
      timestamp: DateTime.now(),
    );
    state = [...state, placeholderMsg];

    try {
      final contextText = ref.read(aiFinancialContextProvider);
      final aiService = ref.read(aiServiceProvider);
      final responseText = await aiService.sendChatMessage(
        config: config,
        history: state.where((m) => m.id != loadingMsgId).toList(),
        userMessage: userText.trim(),
        financialContext: contextText,
      );

      state = state.map((m) {
        if (m.id == loadingMsgId) {
          return AiChatMessage(
            id: loadingMsgId,
            text: responseText,
            isUser: false,
            timestamp: DateTime.now(),
          );
        }
        return m;
      }).toList();
    } catch (e) {
      state = state.map((m) {
        if (m.id == loadingMsgId) {
          return AiChatMessage(
            id: loadingMsgId,
            text: 'Error connecting to ${config.providerType.displayName}: $e',
            isUser: false,
            timestamp: DateTime.now(),
          );
        }
        return m;
      }).toList();
    } finally {
      isGenerating = false;
    }
  }

  void clearChat() {
    state = [
      AiChatMessage(
        id: const Uuid().v4(),
        text: 'Chat history cleared. How can I assist your financial planning?',
        isUser: false,
        timestamp: DateTime.now(),
      ),
    ];
  }
}

final aiChatProvider =
    StateNotifierProvider<AiChatNotifier, List<AiChatMessage>>((ref) {
  return AiChatNotifier(ref);
});
