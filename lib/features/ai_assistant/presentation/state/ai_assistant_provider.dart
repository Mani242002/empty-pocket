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
  static const String _keyGeminiApiKey = 'ai_gemini_api_key';
  static const String _keyGroqApiKey = 'ai_groq_api_key';
  static const String _keyGeminiModel = 'ai_gemini_model';
  static const String _keyGroqModel = 'ai_groq_model';
  static const String _keyLegacyApiKey = 'ai_api_key';

  AiProviderConfigNotifier() : super(const AiProviderConfig()) {
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final providerStr = prefs.getString(_keyProvider) ?? 'gemini';
      var geminiKey = prefs.getString(_keyGeminiApiKey) ?? '';
      final groqKey = prefs.getString(_keyGroqApiKey) ?? '';
      final geminiModel = prefs.getString(_keyGeminiModel) ?? 'gemini-3.7-flash';
      final groqModel = prefs.getString(_keyGroqModel) ?? 'qwen/qwen3.6-27b';

      // Migrate legacy key if present
      if (geminiKey.isEmpty && prefs.containsKey(_keyLegacyApiKey)) {
        geminiKey = prefs.getString(_keyLegacyApiKey) ?? '';
      }

      final provider = providerStr == 'groq' ? AiProviderType.groq : AiProviderType.gemini;

      state = AiProviderConfig(
        providerType: provider,
        geminiApiKey: geminiKey,
        groqApiKey: groqKey,
        geminiModel: geminiModel,
        groqModel: groqModel,
      );
    } catch (_) {}
  }

  Future<void> updateProvider(AiProviderType provider) async {
    state = state.copyWith(providerType: provider);
    await _saveConfig();
  }

  Future<void> updateGeminiApiKey(String apiKey) async {
    state = state.copyWith(geminiApiKey: apiKey.trim());
    await _saveConfig();
  }

  Future<void> updateGroqApiKey(String apiKey) async {
    state = state.copyWith(groqApiKey: apiKey.trim());
    await _saveConfig();
  }

  Future<void> updateGeminiModel(String model) async {
    state = state.copyWith(geminiModel: model);
    await _saveConfig();
  }

  Future<void> updateGroqModel(String model) async {
    state = state.copyWith(groqModel: model);
    await _saveConfig();
  }

  Future<void> updateApiKey(String apiKey) async {
    if (state.providerType == AiProviderType.gemini) {
      await updateGeminiApiKey(apiKey);
    } else {
      await updateGroqApiKey(apiKey);
    }
  }

  Future<void> updateModel(String model) async {
    if (state.providerType == AiProviderType.gemini) {
      await updateGeminiModel(model);
    } else {
      await updateGroqModel(model);
    }
  }

  Future<void> _saveConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyProvider, state.providerType.name);
      await prefs.setString(_keyGeminiApiKey, state.geminiApiKey);
      await prefs.setString(_keyGroqApiKey, state.groqApiKey);
      await prefs.setString(_keyGeminiModel, state.geminiModel);
      await prefs.setString(_keyGroqModel, state.groqModel);
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

/// Manages generated AI reports with full markdown support, regeneration, and deletion
class AiReportsNotifier extends StateNotifier<AsyncValue<List<AiReportItem>>> {
  final Ref ref;

  AiReportsNotifier(this.ref) : super(const AsyncValue.data([]));

  Future<void> generateReport({
    required AiReportType type,
    String? customPrompt,
  }) async {
    final config = ref.read(aiProviderConfigProvider);
    if (!config.isConfigured) {
      state = AsyncValue.error(
        'Please enter your ${config.providerType.displayName} API key in AI Settings first.',
        StackTrace.current,
      );
      return;
    }

    final currentReports = state.value ?? [];
    state = const AsyncValue.loading();

    try {
      final contextText = ref.read(aiFinancialContextProvider);
      final aiService = ref.read(aiServiceProvider);
      final newReport = await aiService.generateSpecializedReport(
        config: config,
        type: type,
        financialContext: contextText,
        customPromptText: customPrompt,
      );

      // Prepend newest report
      state = AsyncValue.data([newReport, ...currentReports]);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> regenerateReport(String id, {AiProviderType? provider, String? model}) async {
    final currentReports = state.value ?? [];
    final existingIndex = currentReports.indexWhere((r) => r.id == id);
    if (existingIndex == -1) return;

    final targetReport = currentReports[existingIndex];
    var config = ref.read(aiProviderConfigProvider);

    if (provider != null) {
      config = config.copyWith(providerType: provider);
    }
    if (model != null) {
      if (config.providerType == AiProviderType.gemini) {
        config = config.copyWith(geminiModel: model);
      } else {
        config = config.copyWith(groqModel: model);
      }
    }

    if (!config.isConfigured) {
      state = AsyncValue.error(
        'Please configure the API key for ${config.providerType.displayName} to regenerate.',
        StackTrace.current,
      );
      return;
    }

    state = const AsyncValue.loading();
    try {
      final contextText = ref.read(aiFinancialContextProvider);
      final aiService = ref.read(aiServiceProvider);
      final updatedReport = await aiService.generateSpecializedReport(
        config: config,
        type: targetReport.type,
        financialContext: contextText,
      );

      final updatedList = List<AiReportItem>.from(currentReports);
      updatedList[existingIndex] = updatedReport;
      state = AsyncValue.data(updatedList);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void deleteReport(String id) {
    final currentReports = state.value ?? [];
    final filtered = currentReports.where((r) => r.id != id).toList();
    state = AsyncValue.data(filtered);
  }

  void clearAllReports() {
    state = const AsyncValue.data([]);
  }
}

final aiReportsProvider =
    StateNotifierProvider<AiReportsNotifier, AsyncValue<List<AiReportItem>>>((ref) {
  return AiReportsNotifier(ref);
});

/// Legacy compatibility wrapper for Audit notifier
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

      // Also create an AiReportItem in aiReportsProvider
      ref.read(aiReportsProvider.notifier).generateReport(type: AiReportType.fullAudit);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void clearAudit() {
    state = const AsyncValue.data(null);
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
                'Hello! I am PocketAI, your private financial advisor. I can analyze your income, expenses, budgets, savings goals, loans, and investment portfolio to answer any financial planning questions.\n\nHow can I assist you today?',
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
            '⚠️ **API Key Missing**: Please configure your ${config.providerType.displayName} API Key in AI Settings above to chat with PocketAI.',
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
      text: '⏳ *Analyzing your private financial metrics...*',
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
            text: '❌ **Error connecting to ${config.providerType.displayName}**:\n$e',
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

  void deleteMessage(String id) {
    state = state.where((m) => m.id != id).toList();
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
