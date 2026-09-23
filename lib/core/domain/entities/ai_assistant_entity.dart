import 'package:flutter/material.dart';

class AiModelOption {
  final String id;
  final String displayName;

  const AiModelOption({
    required this.id,
    required this.displayName,
  });
}

enum AiProviderType {
  gemini,
  openAi,
  anthropic,
  groq,
  openRouter,
  deepSeek,
  custom;

  String get displayName {
    switch (this) {
      case AiProviderType.gemini:
        return 'Google Gemini';
      case AiProviderType.openAi:
        return 'OpenAI';
      case AiProviderType.anthropic:
        return 'Anthropic Claude';
      case AiProviderType.groq:
        return 'Groq (Fast LPUs)';
      case AiProviderType.openRouter:
        return 'Meta / OpenRouter';
      case AiProviderType.deepSeek:
        return 'DeepSeek';
      case AiProviderType.custom:
        return 'Custom Endpoint';
    }
  }

  String get defaultModel {
    switch (this) {
      case AiProviderType.gemini:
        return 'gemini-3.8-flash';
      case AiProviderType.openAi:
        return 'gpt-6-astra';
      case AiProviderType.anthropic:
        return 'claude-opus-5-5';
      case AiProviderType.groq:
        return 'qwen/qwen3.8-27b';
      case AiProviderType.openRouter:
        return 'meta-llama/llama-4-maverick';
      case AiProviderType.deepSeek:
        return 'deepseek-flash';
      case AiProviderType.custom:
        return 'llama-4-scout';
    }
  }

  List<AiModelOption> get modelOptions {
    switch (this) {
      case AiProviderType.gemini:
        return const [
          AiModelOption(id: 'gemini-3.8-flash', displayName: 'Gemini 3.8 Flash (Flagship Workhorse)'),
          AiModelOption(id: 'gemini-3.8-flash-cyber', displayName: 'Gemini 3.8 Flash Cyber (Security & Code Audit)'),
          AiModelOption(id: 'gemini-3.7-flash', displayName: 'Gemini 3.7 Flash (High Reasoning)'),
          AiModelOption(id: 'gemini-3.7-flash-thinking', displayName: 'Gemini 3.7 Flash Thinking (Extended Deliberation)'),
          AiModelOption(id: 'gemini-3.6-flash', displayName: 'Gemini 3.6 Flash (Multimodal Workflow)'),
          AiModelOption(id: 'gemini-3.5-flash', displayName: 'Gemini 3.5 Flash (Near-Pro Intelligence)'),
          AiModelOption(id: 'gemini-3.0-pro', displayName: 'Gemini 3.0 Pro (Deep Analytical)'),
          AiModelOption(id: 'gemini-3.0-flash', displayName: 'Gemini 3.0 Flash (Fast Multimodal)'),
          AiModelOption(id: 'gemini-2.5-flash', displayName: 'Gemini 2.5 Flash'),
          AiModelOption(id: 'gemini-2.5-pro', displayName: 'Gemini 2.5 Pro'),
        ];
      case AiProviderType.openAi:
        return const [
          AiModelOption(id: 'gpt-6-astra', displayName: 'GPT-6 Astra (Flagship Frontier Agentic)'),
          AiModelOption(id: 'gpt-6-sol', displayName: 'GPT-6 Sol (Balanced Coding Workhorse)'),
          AiModelOption(id: 'gpt-6-luna', displayName: 'GPT-6 Luna (Fast Cost-Efficient Chat)'),
          AiModelOption(id: 'o3', displayName: 'o3 (Frontier Deep Reasoning)'),
          AiModelOption(id: 'o3-pro', displayName: 'o3-pro (High-Compute Premium Reasoning)'),
          AiModelOption(id: 'o4-mini', displayName: 'o4-mini (Next-Gen Ultra-Fast Reasoning)'),
          AiModelOption(id: 'o3-mini', displayName: 'o3-mini (STEM & Structured Reasoning)'),
          AiModelOption(id: 'gpt-5.6', displayName: 'GPT-5.6 (Frontier Professional Workhorse)'),
          AiModelOption(id: 'gpt-5.5', displayName: 'GPT-5.5 (High-Reasoning Multimodal)'),
          AiModelOption(id: 'gpt-5.4', displayName: 'GPT-5.4 (General-Purpose Daily Chat)'),
        ];
      case AiProviderType.anthropic:
        return const [
          AiModelOption(id: 'claude-opus-5-5', displayName: 'Claude Opus 5.5 (Frontier Intelligence & Reasoning)'),
          AiModelOption(id: 'claude-fable-5-1', displayName: 'Claude Fable 5.1 (Frontier Research & Agentic)'),
          AiModelOption(id: 'claude-opus-5', displayName: 'Claude Opus 5 (Enterprise Complex Coding)'),
          AiModelOption(id: 'claude-sonnet-5', displayName: 'Claude Sonnet 5 (Balanced Intelligence Workhorse)'),
          AiModelOption(id: 'claude-haiku-4-5', displayName: 'Claude Haiku 4.5 (High-Volume Low-Latency)'),
          AiModelOption(id: 'claude-fable-5', displayName: 'Claude Fable 5'),
          AiModelOption(id: 'claude-sonnet-4-5', displayName: 'Claude Sonnet 4.5'),
          AiModelOption(id: 'claude-opus-4-5', displayName: 'Claude Opus 4.5'),
          AiModelOption(id: 'claude-3-7-sonnet', displayName: 'Claude 3.7 Sonnet (Hybrid Reasoning)'),
          AiModelOption(id: 'claude-3-5-sonnet', displayName: 'Claude 3.5 Sonnet (Benchmark Workhorse)'),
        ];
      case AiProviderType.groq:
        return const [
          AiModelOption(id: 'qwen/qwen3.8-27b', displayName: 'Qwen 3.8 27B (Multimodal 131K Context)'),
          AiModelOption(id: 'meta-llama/llama-4-scout', displayName: 'Llama 4 Scout (Multimodal LPU Speed)'),
          AiModelOption(id: 'llama-3.3-70b-versatile', displayName: 'Llama 3.3 70B Versatile'),
          AiModelOption(id: 'llama-3.1-8b-instant', displayName: 'Llama 3.1 8B Instant (Ultra-Low Latency)'),
          AiModelOption(id: 'llama-3.2-90b-vision-preview', displayName: 'Llama 3.2 90B Vision (Multimodal)'),
          AiModelOption(id: 'llama-3.2-11b-vision-preview', displayName: 'Llama 3.2 11B Vision (Multimodal)'),
          AiModelOption(id: 'llama-3.2-3b-preview', displayName: 'Llama 3.2 3B Preview'),
          AiModelOption(id: 'openai/gpt-oss-120b', displayName: 'GPT OSS Large (120B Open Enterprise)'),
          AiModelOption(id: 'openai/gpt-oss-20b', displayName: 'GPT OSS Mini (20B Open Lightweight)'),
          AiModelOption(id: 'groq/compound', displayName: 'Groq Compound (Multi-Agent Routing)'),
        ];
      case AiProviderType.openRouter:
        return const [
          AiModelOption(id: 'meta-llama/llama-4-maverick', displayName: 'Llama 4 Maverick (128-Expert MoE Multimodal)'),
          AiModelOption(id: 'meta-llama/llama-4-scout', displayName: 'Llama 4 Scout (17B Multimodal 1M Context)'),
          AiModelOption(id: 'meta/muse-spark', displayName: 'Meta Muse Spark (Frontier Multimodal API)'),
          AiModelOption(id: 'meta/muse-glimmer', displayName: 'Meta Muse Glimmer (30B Open Weights)'),
          AiModelOption(id: 'meta-llama/llama-3.3-70b-instruct', displayName: 'Llama 3.3 70B Instruct (Multilingual & Reasoning)'),
          AiModelOption(id: 'meta-llama/llama-3.2-90b-vision-instruct', displayName: 'Llama 3.2 90B Vision Instruct'),
          AiModelOption(id: 'meta-llama/llama-3.2-11b-vision-instruct', displayName: 'Llama 3.2 11B Vision Instruct'),
          AiModelOption(id: 'meta-llama/llama-3.2-3b-instruct', displayName: 'Llama 3.2 3B Instruct (Edge Mobile Chat)'),
          AiModelOption(id: 'meta-llama/llama-3.2-1b-instruct', displayName: 'Llama 3.2 1B Instruct (Ultra-Compact)'),
          AiModelOption(id: 'meta-llama/llama-3.1-405b-instruct', displayName: 'Llama 3.1 405B Instruct (Massive Reasoning)'),
        ];
      case AiProviderType.deepSeek:
        return const [
          AiModelOption(id: 'deepseek-flash', displayName: 'DeepSeek-V4.1-Flash (552B MoE Multimodal + Thinking)'),
          AiModelOption(id: 'deepseek-v4-pro', displayName: 'DeepSeek-V4 Pro (Flagship Agentic Model)'),
          AiModelOption(id: 'deepseek-chat', displayName: 'DeepSeek Chat (Standard Conversational)'),
          AiModelOption(id: 'deepseek-reasoner', displayName: 'DeepSeek Reasoner (Deliberate Chain-of-Thought)'),
          AiModelOption(id: 'deepseek-coder', displayName: 'DeepSeek Coder (Financial Logic & Code)'),
        ];
      case AiProviderType.custom:
        return const [
          AiModelOption(id: 'llama-4-scout', displayName: 'Llama 4 Scout (Ollama / LocalAI / vLLM)'),
          AiModelOption(id: 'qwen3.8', displayName: 'Qwen 3.8 Multimodal (Local)'),
          AiModelOption(id: 'deepseek-flash', displayName: 'DeepSeek Flash (Local / Self-Hosted)'),
          AiModelOption(id: 'llama3.3:70b', displayName: 'Llama 3.3 70B (Local)'),
          AiModelOption(id: 'llama3.2-vision', displayName: 'Llama 3.2 Vision 11B (Local Multimodal)'),
          AiModelOption(id: 'llama3.2:3b', displayName: 'Llama 3.2 3B (Compact Laptop/Device)'),
          AiModelOption(id: 'mistral-large', displayName: 'Mistral Large (Local / vLLM)'),
          AiModelOption(id: 'gemma2:27b', displayName: 'Gemma 2 27B (Local)'),
          AiModelOption(id: 'phi-4', displayName: 'Phi-4 (Local Reasoning)'),
          AiModelOption(id: 'command-r-plus', displayName: 'Command R+ (Enterprise Retrieval)'),
        ];
    }
  }

  List<String> get availableModels => modelOptions.map((m) => m.id).toList();

  String getModelDisplayName(String modelId) {
    final match = modelOptions.where((m) => m.id == modelId);
    if (match.isNotEmpty) return match.first.displayName;
    return modelId;
  }

  String get keyUrl {
    switch (this) {
      case AiProviderType.gemini:
        return 'https://aistudio.google.com/app/apikey';
      case AiProviderType.openAi:
        return 'https://platform.openai.com/api-keys';
      case AiProviderType.anthropic:
        return 'https://console.anthropic.com/settings/keys';
      case AiProviderType.groq:
        return 'https://console.groq.com/keys';
      case AiProviderType.openRouter:
        return 'https://openrouter.ai/keys';
      case AiProviderType.deepSeek:
        return 'https://platform.deepseek.com/api_keys';
      case AiProviderType.custom:
        return 'Local instance (Ollama/LM Studio/vLLM)';
    }
  }

  IconData get icon {
    switch (this) {
      case AiProviderType.gemini:
        return Icons.auto_awesome_rounded;
      case AiProviderType.openAi:
        return Icons.psychology_rounded;
      case AiProviderType.anthropic:
        return Icons.bubble_chart_rounded;
      case AiProviderType.groq:
        return Icons.bolt_rounded;
      case AiProviderType.openRouter:
        return Icons.hub_rounded;
      case AiProviderType.deepSeek:
        return Icons.explore_rounded;
      case AiProviderType.custom:
        return Icons.dns_rounded;
    }
  }
}

class AiProviderConfig {
  final AiProviderType providerType;
  final String geminiApiKey;
  final String openAiApiKey;
  final String anthropicApiKey;
  final String groqApiKey;
  final String openRouterApiKey;
  final String deepSeekApiKey;
  final String customApiKey;

  final String geminiModel;
  final String openAiModel;
  final String anthropicModel;
  final String groqModel;
  final String openRouterModel;
  final String deepSeekModel;
  final String customModel;

  final String customBaseUrl;
  final List<String> customSavedModels;

  const AiProviderConfig({
    this.providerType = AiProviderType.gemini,
    this.geminiApiKey = '',
    this.openAiApiKey = '',
    this.anthropicApiKey = '',
    this.groqApiKey = '',
    this.openRouterApiKey = '',
    this.deepSeekApiKey = '',
    this.customApiKey = '',
    this.geminiModel = 'gemini-3.8-flash',
    this.openAiModel = 'gpt-6-astra',
    this.anthropicModel = 'claude-opus-5-5',
    this.groqModel = 'qwen/qwen3.8-27b',
    this.openRouterModel = 'meta-llama/llama-4-maverick',
    this.deepSeekModel = 'deepseek-flash',
    this.customModel = 'llama-4-scout',
    this.customBaseUrl = 'http://10.0.2.2:11434/v1',
    this.customSavedModels = const [
      'llama-4-scout',
      'qwen3.8',
      'deepseek-flash',
      'llama3.3:70b',
      'llama3.2-vision',
      'mistral-large',
    ],
  });

  /// Active API key based on currently selected provider
  String get activeApiKey {
    switch (providerType) {
      case AiProviderType.gemini:
        return geminiApiKey;
      case AiProviderType.openAi:
        return openAiApiKey;
      case AiProviderType.anthropic:
        return anthropicApiKey;
      case AiProviderType.groq:
        return groqApiKey;
      case AiProviderType.openRouter:
        return openRouterApiKey;
      case AiProviderType.deepSeek:
        return deepSeekApiKey;
      case AiProviderType.custom:
        return customApiKey;
    }
  }

  /// Active model identifier based on currently selected provider
  String get activeModel {
    switch (providerType) {
      case AiProviderType.gemini:
        return geminiModel;
      case AiProviderType.openAi:
        return openAiModel;
      case AiProviderType.anthropic:
        return anthropicModel;
      case AiProviderType.groq:
        return groqModel;
      case AiProviderType.openRouter:
        return openRouterModel;
      case AiProviderType.deepSeek:
        return deepSeekModel;
      case AiProviderType.custom:
        return customModel;
    }
  }

  /// Returns effective model options for a specific provider
  List<AiModelOption> getModelOptionsFor(AiProviderType provider) {
    if (provider == AiProviderType.custom) {
      final defaultOptions = AiProviderType.custom.modelOptions;
      final existingIds = defaultOptions.map((o) => o.id).toSet();
      final customOptions = <AiModelOption>[...defaultOptions];
      for (final saved in customSavedModels) {
        if (!existingIds.contains(saved) && saved.trim().isNotEmpty) {
          customOptions.add(AiModelOption(id: saved, displayName: '$saved (Custom)'));
        }
      }
      return customOptions;
    }
    return provider.modelOptions;
  }

  /// Returns effective model options including custom user-saved models for active provider
  List<AiModelOption> get activeModelOptions => getModelOptionsFor(providerType);

  /// Display name of the active model
  String get activeModelDisplayName {
    final options = activeModelOptions;
    final match = options.where((m) => m.id == activeModel);
    if (match.isNotEmpty) return match.first.displayName;
    return activeModel;
  }

  /// True if active provider has necessary configuration
  bool get isConfigured {
    if (providerType == AiProviderType.custom) {
      return customBaseUrl.trim().isNotEmpty && customModel.trim().isNotEmpty;
    }
    return activeApiKey.trim().isNotEmpty;
  }

  /// Check whether a specific provider has valid configuration
  bool isProviderConfigured(AiProviderType provider) {
    switch (provider) {
      case AiProviderType.gemini:
        return geminiApiKey.trim().isNotEmpty;
      case AiProviderType.openAi:
        return openAiApiKey.trim().isNotEmpty;
      case AiProviderType.anthropic:
        return anthropicApiKey.trim().isNotEmpty;
      case AiProviderType.groq:
        return groqApiKey.trim().isNotEmpty;
      case AiProviderType.openRouter:
        return openRouterApiKey.trim().isNotEmpty;
      case AiProviderType.deepSeek:
        return deepSeekApiKey.trim().isNotEmpty;
      case AiProviderType.custom:
        return customBaseUrl.trim().isNotEmpty && customModel.trim().isNotEmpty;
    }
  }

  bool get isGeminiConfigured => isProviderConfigured(AiProviderType.gemini);
  bool get isOpenAiConfigured => isProviderConfigured(AiProviderType.openAi);
  bool get isAnthropicConfigured => isProviderConfigured(AiProviderType.anthropic);
  bool get isGroqConfigured => isProviderConfigured(AiProviderType.groq);
  bool get isOpenRouterConfigured => isProviderConfigured(AiProviderType.openRouter);
  bool get isDeepSeekConfigured => isProviderConfigured(AiProviderType.deepSeek);
  bool get isCustomConfigured => isProviderConfigured(AiProviderType.custom);

  /// List of providers that have been configured
  List<AiProviderType> get configuredProviders {
    return AiProviderType.values.where(isProviderConfigured).toList();
  }

  String getApiKeyFor(AiProviderType type) {
    switch (type) {
      case AiProviderType.gemini:
        return geminiApiKey;
      case AiProviderType.openAi:
        return openAiApiKey;
      case AiProviderType.anthropic:
        return anthropicApiKey;
      case AiProviderType.groq:
        return groqApiKey;
      case AiProviderType.openRouter:
        return openRouterApiKey;
      case AiProviderType.deepSeek:
        return deepSeekApiKey;
      case AiProviderType.custom:
        return customApiKey;
    }
  }

  String getModelFor(AiProviderType type) {
    switch (type) {
      case AiProviderType.gemini:
        return geminiModel;
      case AiProviderType.openAi:
        return openAiModel;
      case AiProviderType.anthropic:
        return anthropicModel;
      case AiProviderType.groq:
        return groqModel;
      case AiProviderType.openRouter:
        return openRouterModel;
      case AiProviderType.deepSeek:
        return deepSeekModel;
      case AiProviderType.custom:
        return customModel;
    }
  }

  AiProviderConfig copyWith({
    AiProviderType? providerType,
    String? geminiApiKey,
    String? openAiApiKey,
    String? anthropicApiKey,
    String? groqApiKey,
    String? openRouterApiKey,
    String? deepSeekApiKey,
    String? customApiKey,
    String? geminiModel,
    String? openAiModel,
    String? anthropicModel,
    String? groqModel,
    String? openRouterModel,
    String? deepSeekModel,
    String? customModel,
    String? customBaseUrl,
    List<String>? customSavedModels,
    String? apiKey,
    String? selectedModel,
  }) {
    final activeProvider = providerType ?? this.providerType;

    String newGeminiKey = geminiApiKey ?? this.geminiApiKey;
    String newOpenAiKey = openAiApiKey ?? this.openAiApiKey;
    String newAnthropicKey = anthropicApiKey ?? this.anthropicApiKey;
    String newGroqKey = groqApiKey ?? this.groqApiKey;
    String newOpenRouterKey = openRouterApiKey ?? this.openRouterApiKey;
    String newDeepSeekKey = deepSeekApiKey ?? this.deepSeekApiKey;
    String newCustomKey = customApiKey ?? this.customApiKey;

    if (apiKey != null) {
      switch (activeProvider) {
        case AiProviderType.gemini:
          newGeminiKey = apiKey;
          break;
        case AiProviderType.openAi:
          newOpenAiKey = apiKey;
          break;
        case AiProviderType.anthropic:
          newAnthropicKey = apiKey;
          break;
        case AiProviderType.groq:
          newGroqKey = apiKey;
          break;
        case AiProviderType.openRouter:
          newOpenRouterKey = apiKey;
          break;
        case AiProviderType.deepSeek:
          newDeepSeekKey = apiKey;
          break;
        case AiProviderType.custom:
          newCustomKey = apiKey;
          break;
      }
    }

    String newGeminiModel = geminiModel ?? this.geminiModel;
    String newOpenAiModel = openAiModel ?? this.openAiModel;
    String newAnthropicModel = anthropicModel ?? this.anthropicModel;
    String newGroqModel = groqModel ?? this.groqModel;
    String newOpenRouterModel = openRouterModel ?? this.openRouterModel;
    String newDeepSeekModel = deepSeekModel ?? this.deepSeekModel;
    String newCustomModel = customModel ?? this.customModel;

    if (selectedModel != null) {
      switch (activeProvider) {
        case AiProviderType.gemini:
          newGeminiModel = selectedModel;
          break;
        case AiProviderType.openAi:
          newOpenAiModel = selectedModel;
          break;
        case AiProviderType.anthropic:
          newAnthropicModel = selectedModel;
          break;
        case AiProviderType.groq:
          newGroqModel = selectedModel;
          break;
        case AiProviderType.openRouter:
          newOpenRouterModel = selectedModel;
          break;
        case AiProviderType.deepSeek:
          newDeepSeekModel = selectedModel;
          break;
        case AiProviderType.custom:
          newCustomModel = selectedModel;
          break;
      }
    }

    return AiProviderConfig(
      providerType: activeProvider,
      geminiApiKey: newGeminiKey,
      openAiApiKey: newOpenAiKey,
      anthropicApiKey: newAnthropicKey,
      groqApiKey: newGroqKey,
      openRouterApiKey: newOpenRouterKey,
      deepSeekApiKey: newDeepSeekKey,
      customApiKey: newCustomKey,
      geminiModel: newGeminiModel,
      openAiModel: newOpenAiModel,
      anthropicModel: newAnthropicModel,
      groqModel: newGroqModel,
      openRouterModel: newOpenRouterModel,
      deepSeekModel: newDeepSeekModel,
      customModel: newCustomModel,
      customBaseUrl: customBaseUrl ?? this.customBaseUrl,
      customSavedModels: customSavedModels ?? this.customSavedModels,
    );
  }
}

class AiChatSession {
  final String id;
  final String title;
  final String provider;
  final String modelUsed;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AiChatSession({
    required this.id,
    required this.title,
    required this.provider,
    required this.modelUsed,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'provider': provider,
        'model_used': modelUsed,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  factory AiChatSession.fromMap(Map<String, dynamic> map) => AiChatSession(
        id: map['id'] as String,
        title: (map['title'] as String?) ?? 'Conversation',
        provider: (map['provider'] as String?) ?? 'gemini',
        modelUsed: (map['model_used'] as String?) ?? '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (map['created_at'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
        ),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          (map['updated_at'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
        ),
      );

  AiChatSession copyWith({
    String? title,
    String? provider,
    String? modelUsed,
    DateTime? updatedAt,
  }) =>
      AiChatSession(
        id: id,
        title: title ?? this.title,
        provider: provider ?? this.provider,
        modelUsed: modelUsed ?? this.modelUsed,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

class AiChatMessage {
  final String id;
  final String sessionId;
  final String text;
  final bool isUser;
  final DateTime timestamp;

  const AiChatMessage({
    required this.id,
    this.sessionId = '',
    required this.text,
    required this.isUser,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'session_id': sessionId,
        'text': text,
        'is_user': isUser ? 1 : 0,
        'timestamp': timestamp.millisecondsSinceEpoch,
      };

  factory AiChatMessage.fromMap(Map<String, dynamic> map) => AiChatMessage(
        id: map['id'] as String,
        sessionId: (map['session_id'] as String?) ?? '',
        text: (map['text'] as String?) ?? '',
        isUser: map['is_user'] == 1 || map['is_user'] == true,
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          (map['timestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
        ),
      );
}

enum AiReportType {
  fullAudit,
  budgetOptimization,
  debtPayoff,
  investmentReview,
  emergencyRunway,
  custom;

  String get title {
    switch (this) {
      case AiReportType.fullAudit:
        return 'Full Financial Health Audit';
      case AiReportType.budgetOptimization:
        return 'Budget & Expense Optimization';
      case AiReportType.debtPayoff:
        return 'Debt Freedom & Payoff Plan';
      case AiReportType.investmentReview:
        return 'Investment & Asset Review';
      case AiReportType.emergencyRunway:
        return 'Emergency Runway & Buffer Analysis';
      case AiReportType.custom:
        return 'Custom Financial Insight';
    }
  }

  IconData get icon {
    switch (this) {
      case AiReportType.fullAudit:
        return Icons.verified_rounded;
      case AiReportType.budgetOptimization:
        return Icons.pie_chart_rounded;
      case AiReportType.debtPayoff:
        return Icons.credit_card_off_rounded;
      case AiReportType.investmentReview:
        return Icons.trending_up_rounded;
      case AiReportType.emergencyRunway:
        return Icons.shield_rounded;
      case AiReportType.custom:
        return Icons.auto_awesome_rounded;
    }
  }

  String get displayName => title;
}

class AiReportItem {
  final String id;
  final String title;
  final AiReportType type;
  final String markdownContent;
  final String modelUsed;
  final String modelDisplayName;
  final AiProviderType providerUsed;
  final DateTime timestamp;

  DateTime get createdAt => timestamp;

  const AiReportItem({
    required this.id,
    required this.title,
    required this.type,
    required this.markdownContent,
    required this.modelUsed,
    required this.modelDisplayName,
    required this.providerUsed,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'type': type.name,
      'markdown_content': markdownContent,
      'model_used': modelUsed,
      'model_display_name': modelDisplayName,
      'provider_used': providerUsed.name,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory AiReportItem.fromMap(Map<String, dynamic> map) {
    return AiReportItem(
      id: map['id'] as String,
      title: map['title'] as String,
      type: AiReportType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => AiReportType.custom,
      ),
      markdownContent: map['markdown_content'] as String,
      modelUsed: map['model_used'] as String? ?? '',
      modelDisplayName: map['model_display_name'] as String? ?? '',
      providerUsed: AiProviderType.values.firstWhere(
        (p) => p.name == map['provider_used'],
        orElse: () => AiProviderType.gemini,
      ),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}

class AiAuditReport {
  final String overview;
  final List<String> strengths;
  final List<String> risks;
  final List<String> recommendations;
  final DateTime timestamp;

  const AiAuditReport({
    required this.overview,
    required this.strengths,
    required this.risks,
    required this.recommendations,
    required this.timestamp,
  });

  /// Convert to full markdown representation
  String toMarkdown() {
    final buffer = StringBuffer();
    buffer.writeln('### Executive Overview');
    buffer.writeln(overview);
    buffer.writeln('\n### Key Strengths');
    for (final s in strengths) {
      buffer.writeln('- $s');
    }
    buffer.writeln('\n### Risk Areas');
    for (final r in risks) {
      buffer.writeln('- $r');
    }
    buffer.writeln('\n### Action Recommendations');
    for (final rec in recommendations) {
      buffer.writeln('- $rec');
    }
    return buffer.toString();
  }
}
