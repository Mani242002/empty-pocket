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
  groq;

  String get displayName {
    switch (this) {
      case AiProviderType.gemini:
        return 'Google Gemini';
      case AiProviderType.groq:
        return 'Groq (Open Models)';
    }
  }

  String get defaultModel {
    switch (this) {
      case AiProviderType.gemini:
        return 'gemini-3.7-flash';
      case AiProviderType.groq:
        return 'qwen/qwen3.6-27b';
    }
  }

  List<AiModelOption> get modelOptions {
    switch (this) {
      case AiProviderType.gemini:
        return const [
          AiModelOption(id: 'gemini-3.7-flash', displayName: 'Gemini 3.7 Flash'),
          AiModelOption(id: 'gemini-3.6-flash', displayName: 'Gemini 3.6 Flash'),
          AiModelOption(id: 'gemini-3.5-flash', displayName: 'Gemini 3.5 Flash'),
        ];
      case AiProviderType.groq:
        return const [
          AiModelOption(id: 'qwen/qwen3.6-27b', displayName: 'Qwen 3.6'),
          AiModelOption(id: 'openai/gpt-oss-120b', displayName: 'GPT OSS Large'),
          AiModelOption(id: 'openai/gpt-oss-20b', displayName: 'GPT OSS Mini'),
          AiModelOption(id: 'groq/compound', displayName: 'Groq Compound'),
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
      case AiProviderType.groq:
        return 'https://console.groq.com/keys';
    }
  }

  IconData get icon {
    switch (this) {
      case AiProviderType.gemini:
        return Icons.auto_awesome_rounded;
      case AiProviderType.groq:
        return Icons.bolt_rounded;
    }
  }
}

class AiProviderConfig {
  final AiProviderType providerType;
  final String geminiApiKey;
  final String groqApiKey;
  final String geminiModel;
  final String groqModel;

  const AiProviderConfig({
    this.providerType = AiProviderType.gemini,
    this.geminiApiKey = '',
    this.groqApiKey = '',
    this.geminiModel = 'gemini-3.7-flash',
    this.groqModel = 'qwen/qwen3.6-27b',
  });

  /// Active key based on currently selected provider
  String get activeApiKey =>
      providerType == AiProviderType.gemini ? geminiApiKey : groqApiKey;

  /// Active model identifier based on currently selected provider
  String get activeModel =>
      providerType == AiProviderType.gemini ? geminiModel : groqModel;

  /// Display name of the active model
  String get activeModelDisplayName => providerType.getModelDisplayName(activeModel);

  /// Backwards-compatible getter for apiKey
  String get apiKey => activeApiKey;

  /// Backwards-compatible getter for selectedModel
  String get selectedModel => activeModel;

  /// True if active provider has an API key configured
  bool get isConfigured => activeApiKey.trim().isNotEmpty;

  /// True if Gemini key is configured
  bool get isGeminiConfigured => geminiApiKey.trim().isNotEmpty;

  /// True if Groq key is configured
  bool get isGroqConfigured => groqApiKey.trim().isNotEmpty;

  /// List of providers that have been configured with valid keys
  List<AiProviderType> get configuredProviders {
    final list = <AiProviderType>[];
    if (isGeminiConfigured) list.add(AiProviderType.gemini);
    if (isGroqConfigured) list.add(AiProviderType.groq);
    return list;
  }

  AiProviderConfig copyWith({
    AiProviderType? providerType,
    String? geminiApiKey,
    String? groqApiKey,
    String? geminiModel,
    String? groqModel,
    String? apiKey,
    String? selectedModel,
  }) {
    final activeProvider = providerType ?? this.providerType;
    String newGeminiKey = geminiApiKey ?? this.geminiApiKey;
    String newGroqKey = groqApiKey ?? this.groqApiKey;
    if (apiKey != null) {
      if (activeProvider == AiProviderType.gemini) {
        newGeminiKey = apiKey;
      } else {
        newGroqKey = apiKey;
      }
    }

    String newGeminiModel = geminiModel ?? this.geminiModel;
    String newGroqModel = groqModel ?? this.groqModel;
    if (selectedModel != null) {
      if (activeProvider == AiProviderType.gemini) {
        newGeminiModel = selectedModel;
      } else {
        newGroqModel = selectedModel;
      }
    }

    return AiProviderConfig(
      providerType: activeProvider,
      geminiApiKey: newGeminiKey,
      groqApiKey: newGroqKey,
      geminiModel: newGeminiModel,
      groqModel: newGroqModel,
    );
  }
}

class AiChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;

  const AiChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
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
