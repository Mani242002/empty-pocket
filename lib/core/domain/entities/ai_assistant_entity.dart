import 'package:flutter/material.dart';

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
        return 'gemini-1.5-flash';
      case AiProviderType.groq:
        return 'llama-3.3-70b-versatile';
    }
  }

  List<String> get availableModels {
    switch (this) {
      case AiProviderType.gemini:
        return ['gemini-1.5-flash', 'gemini-2.0-flash', 'gemini-1.5-pro'];
      case AiProviderType.groq:
        return ['llama-3.3-70b-versatile', 'llama-3.1-8b-instant', 'mixtral-8x7b-32768'];
    }
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
  final String apiKey;
  final String selectedModel;

  const AiProviderConfig({
    this.providerType = AiProviderType.gemini,
    this.apiKey = '',
    String? selectedModel,
  }) : selectedModel = selectedModel ?? (providerType == AiProviderType.gemini ? 'gemini-1.5-flash' : 'llama-3.3-70b-versatile');

  bool get isConfigured => apiKey.trim().isNotEmpty;

  AiProviderConfig copyWith({
    AiProviderType? providerType,
    String? apiKey,
    String? selectedModel,
  }) {
    final newProvider = providerType ?? this.providerType;
    return AiProviderConfig(
      providerType: newProvider,
      apiKey: apiKey ?? this.apiKey,
      selectedModel: selectedModel ?? (providerType != null ? newProvider.defaultModel : this.selectedModel),
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
}
