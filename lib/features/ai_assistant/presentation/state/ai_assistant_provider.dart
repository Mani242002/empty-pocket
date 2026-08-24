import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/calculation/financial_calculator.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/domain/entities/ai_assistant_entity.dart';
import '../../../../core/services/ai_service.dart';
import '../../../debts/presentation/state/debts_provider.dart';
import '../../../investments/presentation/state/investments_provider.dart';
import '../../../net_worth/presentation/state/net_worth_provider.dart';
import '../../../savings/presentation/state/savings_goals_provider.dart';
import '../../../transactions/presentation/state/transactions_provider.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final aiServiceProvider = Provider<AiService>((ref) => AiService());

class AiProviderConfigNotifier extends StateNotifier<AiProviderConfig> {
  static const String _keyProvider = 'ai_provider_type';
  static const String _keyGeminiApiKey = 'ai_gemini_api_key';
  static const String _keyGroqApiKey = 'ai_groq_api_key';
  static const String _keyGeminiModel = 'ai_gemini_model';
  static const String _keyGroqModel = 'ai_groq_model';
  static const String _keyLegacyApiKey = 'ai_api_key';

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  AiProviderConfigNotifier() : super(const AiProviderConfig()) {
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final providerStr = prefs.getString(_keyProvider) ?? 'gemini';
      final geminiModel = prefs.getString(_keyGeminiModel) ?? 'gemini-3.7-flash';
      final groqModel = prefs.getString(_keyGroqModel) ?? 'qwen/qwen3.6-27b';

      String? geminiKey;
      String? groqKey;

      try {
        geminiKey = await _secureStorage.read(key: _keyGeminiApiKey);
        groqKey = await _secureStorage.read(key: _keyGroqApiKey);
      } catch (e) {
        debugPrint('[AiProviderConfigNotifier] Secure storage read error: $e');
      }

      // Fallback & Migration: Check SharedPreferences if secure storage was empty
      if (geminiKey == null || geminiKey.isEmpty) {
        geminiKey = prefs.getString(_keyGeminiApiKey) ?? '';
        if (geminiKey.isNotEmpty) {
          try {
            await _secureStorage.write(key: _keyGeminiApiKey, value: geminiKey);
            await prefs.remove(_keyGeminiApiKey);
          } catch (_) {}
        }
      }

      if (groqKey == null || groqKey.isEmpty) {
        groqKey = prefs.getString(_keyGroqApiKey) ?? '';
        if (groqKey.isNotEmpty) {
          try {
            await _secureStorage.write(key: _keyGroqApiKey, value: groqKey);
            await prefs.remove(_keyGroqApiKey);
          } catch (_) {}
        }
      }

      // Migrate legacy key if present and delete stale credential
      if ((geminiKey.isEmpty) && prefs.containsKey(_keyLegacyApiKey)) {
        final legacyKey = prefs.getString(_keyLegacyApiKey) ?? '';
        if (legacyKey.isNotEmpty) {
          geminiKey = legacyKey;
          try {
            await _secureStorage.write(key: _keyGeminiApiKey, value: legacyKey);
          } catch (_) {}
          await prefs.remove(_keyLegacyApiKey);
        }
      }

      final provider = providerStr == 'groq' ? AiProviderType.groq : AiProviderType.gemini;

      state = AiProviderConfig(
        providerType: provider,
        geminiApiKey: geminiKey,
        groqApiKey: groqKey,
        geminiModel: geminiModel,
        groqModel: groqModel,
      );
    } catch (e) {
      debugPrint('[AiProviderConfigNotifier] _loadConfig failed: $e');
    }
  }

  Future<void> updateProvider(AiProviderType provider) async {
    state = state.copyWith(providerType: provider);
    await _saveConfig();
  }

  Future<void> updateGeminiApiKey(String apiKey) async {
    final key = apiKey.trim();
    state = state.copyWith(geminiApiKey: key);
    try {
      if (key.isEmpty) {
        await _secureStorage.delete(key: _keyGeminiApiKey);
      } else {
        await _secureStorage.write(key: _keyGeminiApiKey, value: key);
      }
    } catch (e) {
      debugPrint('[AiProviderConfigNotifier] Secure storage write error: $e');
    }
    await _saveConfig();
  }

  Future<void> updateGroqApiKey(String apiKey) async {
    final key = apiKey.trim();
    state = state.copyWith(groqApiKey: key);
    try {
      if (key.isEmpty) {
        await _secureStorage.delete(key: _keyGroqApiKey);
      } else {
        await _secureStorage.write(key: _keyGroqApiKey, value: key);
      }
    } catch (e) {
      debugPrint('[AiProviderConfigNotifier] Secure storage write error: $e');
    }
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
      await prefs.setString(_keyGeminiModel, state.geminiModel);
      await prefs.setString(_keyGroqModel, state.groqModel);
    } catch (e) {
      debugPrint('[AiProviderConfigNotifier] _saveConfig failed: $e');
    }
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

/// Combined state containing persistent chat sessions, active messages, and generation state
class AiChatState {
  final AiChatSession? currentSession;
  final List<AiChatSession> sessions;
  final List<AiChatMessage> messages;
  final bool isGenerating;
  final bool isLoadingHistory;

  const AiChatState({
    this.currentSession,
    this.sessions = const [],
    this.messages = const [],
    this.isGenerating = false,
    this.isLoadingHistory = false,
  });

  AiChatState copyWith({
    AiChatSession? currentSession,
    bool clearCurrentSession = false,
    List<AiChatSession>? sessions,
    List<AiChatMessage>? messages,
    bool? isGenerating,
    bool? isLoadingHistory,
  }) {
    return AiChatState(
      currentSession: clearCurrentSession ? null : (currentSession ?? this.currentSession),
      sessions: sessions ?? this.sessions,
      messages: messages ?? this.messages,
      isGenerating: isGenerating ?? this.isGenerating,
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
    );
  }
}

class AiChatNotifier extends StateNotifier<AiChatState> {
  final Ref ref;
  final AppDatabase _db = AppDatabase.instance;

  static const String _defaultWelcomeText =
      'Hello! I am PocketAI, your private financial advisor. I can analyze your income, expenses, budgets, savings goals, loans, and investment portfolio to answer any financial planning questions.\n\nHow can I assist you today?';

  AiChatNotifier(this.ref) : super(const AiChatState()) {
    loadChatData();
  }

  AiChatMessage _createWelcomeMessage([String sessionId = '']) {
    return AiChatMessage(
      id: 'welcome',
      sessionId: sessionId,
      text: _defaultWelcomeText,
      isUser: false,
      timestamp: DateTime.now(),
    );
  }

  Future<void> loadChatData() async {
    state = state.copyWith(isLoadingHistory: true);
    try {
      final sessions = await _db.getAllChatSessions();
      // If user has already initiated an in-flight prompt, avoid clobbering state
      if (state.messages.any((m) => m.isUser)) {
        state = state.copyWith(
          sessions: sessions,
          isLoadingHistory: false,
        );
        return;
      }

      if (sessions.isNotEmpty) {
        final activeSession = sessions.first;
        final messages = await _db.getMessagesForSession(activeSession.id);
        state = state.copyWith(
          sessions: sessions,
          currentSession: activeSession,
          messages: messages.isNotEmpty ? messages : [_createWelcomeMessage(activeSession.id)],
          isLoadingHistory: false,
        );
      } else {
        // No past sessions in database: initialize clean state with welcome message
        state = state.copyWith(
          sessions: [],
          clearCurrentSession: true,
          messages: [_createWelcomeMessage()],
          isLoadingHistory: false,
        );
      }
    } catch (e) {
      debugPrint('[AiChatNotifier] loadChatData error: $e');
      state = state.copyWith(
        sessions: [],
        clearCurrentSession: true,
        messages: [_createWelcomeMessage()],
        isLoadingHistory: false,
      );
    }
  }

  Future<void> startNewChat() async {
    if (state.isGenerating) return;

    state = state.copyWith(
      clearCurrentSession: true,
      messages: [_createWelcomeMessage()],
    );
  }

  Future<void> selectSession(String sessionId) async {
    if (state.isGenerating) return;
    if (state.currentSession?.id == sessionId) return;

    try {
      final session = await _db.getChatSessionById(sessionId);
      if (session == null) return;

      final messages = await _db.getMessagesForSession(sessionId);
      state = state.copyWith(
        currentSession: session,
        messages: messages.isNotEmpty ? messages : [_createWelcomeMessage(sessionId)],
      );
    } catch (e) {
      debugPrint('[AiChatNotifier] selectSession error: $e');
    }
  }

  Future<void> renameSession(String sessionId, String newTitle) async {
    final trimmed = newTitle.trim();
    if (trimmed.isEmpty) return;

    try {
      final session = await _db.getChatSessionById(sessionId);
      if (session == null) return;

      final updated = session.copyWith(title: trimmed, updatedAt: DateTime.now());
      await _db.updateChatSession(updated);

      final updatedSessions = state.sessions.map((s) => s.id == sessionId ? updated : s).toList();
      state = state.copyWith(
        sessions: updatedSessions,
        currentSession: state.currentSession?.id == sessionId ? updated : state.currentSession,
      );
    } catch (e) {
      debugPrint('[AiChatNotifier] renameSession error: $e');
    }
  }

  Future<void> deleteSession(String sessionId) async {
    try {
      await _db.deleteChatSession(sessionId);
      final updatedSessions = state.sessions.where((s) => s.id != sessionId).toList();

      if (state.currentSession?.id == sessionId) {
        if (updatedSessions.isNotEmpty) {
          final nextSession = updatedSessions.first;
          final messages = await _db.getMessagesForSession(nextSession.id);
          state = state.copyWith(
            sessions: updatedSessions,
            currentSession: nextSession,
            messages: messages.isNotEmpty ? messages : [_createWelcomeMessage(nextSession.id)],
          );
        } else {
          state = state.copyWith(
            sessions: [],
            clearCurrentSession: true,
            messages: [_createWelcomeMessage()],
          );
        }
      } else {
        state = state.copyWith(sessions: updatedSessions);
      }
    } catch (e) {
      debugPrint('[AiChatNotifier] deleteSession error: $e');
    }
  }

  Future<void> clearAllChats() async {
    try {
      await _db.clearAllChatHistory();
      state = state.copyWith(
        sessions: [],
        clearCurrentSession: true,
        messages: [_createWelcomeMessage()],
      );
    } catch (e) {
      debugPrint('[AiChatNotifier] clearAllChats error: $e');
    }
  }

  /// Legacy clearChat compatibility
  void clearChat() {
    startNewChat();
  }

  Future<void> sendMessage(String userText) async {
    final trimmedText = userText.trim();
    if (trimmedText.isEmpty || state.isGenerating) return;

    final config = ref.read(aiProviderConfigProvider);

    // 1. Ensure active session exists in DB
    AiChatSession activeSession;
    final now = DateTime.now();

    if (state.currentSession == null) {
      // Auto-generate title from first prompt
      String title = trimmedText;
      if (title.length > 35) {
        title = '${title.substring(0, 35)}...';
      }
      activeSession = AiChatSession(
        id: const Uuid().v4(),
        title: title,
        provider: config.providerType.name,
        modelUsed: config.activeModelDisplayName,
        createdAt: now,
        updatedAt: now,
      );
      await _db.insertChatSession(activeSession);
      state = state.copyWith(
        currentSession: activeSession,
        sessions: [activeSession, ...state.sessions],
      );
    } else {
      activeSession = state.currentSession!;
      final updated = activeSession.copyWith(updatedAt: now);
      await _db.updateChatSession(updated);
      activeSession = updated;
      final updatedSessions = [
        activeSession,
        ...state.sessions.where((s) => s.id != activeSession.id),
      ];
      state = state.copyWith(
        currentSession: activeSession,
        sessions: updatedSessions,
      );
    }

    final userMsg = AiChatMessage(
      id: const Uuid().v4(),
      sessionId: activeSession.id,
      text: trimmedText,
      isUser: true,
      timestamp: now,
    );

    // Save user message to SQLite
    await _db.insertChatMessage(userMsg);

    // Filter out welcome placeholder from UI list if present
    final currentMsgs = state.messages.where((m) => m.id != 'welcome').toList();
    final updatedMessages = [...currentMsgs, userMsg];

    if (!config.isConfigured) {
      final errorMsg = AiChatMessage(
        id: const Uuid().v4(),
        sessionId: activeSession.id,
        text:
            '⚠️ **API Key Missing**: Please configure your ${config.providerType.displayName} API Key in AI Settings above to chat with PocketAI.',
        isUser: false,
        timestamp: DateTime.now(),
      );
      await _db.insertChatMessage(errorMsg);
      state = state.copyWith(messages: [...updatedMessages, errorMsg]);
      return;
    }

    final loadingMsgId = const Uuid().v4();
    final placeholderMsg = AiChatMessage(
      id: loadingMsgId,
      sessionId: activeSession.id,
      text: '⏳ *Analyzing your private financial metrics...*',
      isUser: false,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...updatedMessages, placeholderMsg],
      isGenerating: true,
    );

    try {
      final contextText = ref.read(aiFinancialContextProvider);
      final aiService = ref.read(aiServiceProvider);
      final responseText = await aiService.sendChatMessage(
        config: config,
        history: state.messages.where((m) => m.id != loadingMsgId && m.id != 'welcome').toList(),
        userMessage: trimmedText,
        financialContext: contextText,
      );

      final assistantMsg = AiChatMessage(
        id: const Uuid().v4(),
        sessionId: activeSession.id,
        text: responseText,
        isUser: false,
        timestamp: DateTime.now(),
      );

      // Save assistant message to SQLite
      await _db.insertChatMessage(assistantMsg);

      final nextMessages = state.messages.map((m) {
        if (m.id == loadingMsgId) {
          return assistantMsg;
        }
        return m;
      }).toList();

      state = state.copyWith(messages: nextMessages, isGenerating: false);
    } catch (e) {
      final errorMsg = AiChatMessage(
        id: const Uuid().v4(),
        sessionId: activeSession.id,
        text: '❌ **Error connecting to ${config.providerType.displayName}**:\n$e',
        isUser: false,
        timestamp: DateTime.now(),
      );

      await _db.insertChatMessage(errorMsg);

      final nextMessages = state.messages.map((m) {
        if (m.id == loadingMsgId) {
          return errorMsg;
        }
        return m;
      }).toList();

      state = state.copyWith(messages: nextMessages, isGenerating: false);
    }
  }

  Future<void> deleteMessage(String id) async {
    try {
      await _db.deleteChatMessage(id);
      final filtered = state.messages.where((m) => m.id != id).toList();
      state = state.copyWith(messages: filtered);
    } catch (e) {
      debugPrint('[AiChatNotifier] deleteMessage error: $e');
    }
  }
}

final aiChatProvider =
    StateNotifierProvider<AiChatNotifier, AiChatState>((ref) {
  return AiChatNotifier(ref);
});
