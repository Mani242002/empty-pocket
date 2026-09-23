import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:empty_pocket/core/domain/entities/ai_assistant_entity.dart';
import 'package:empty_pocket/core/services/ai_service.dart';
import 'package:empty_pocket/features/ai_assistant/presentation/screens/ai_settings_screen.dart';

void main() {
  group('AiProviderType & Curated Models', () {
    test('contains all 7 expected AI providers', () {
      expect(AiProviderType.values.length, equals(7));
      expect(AiProviderType.values, containsAll([
        AiProviderType.gemini,
        AiProviderType.openAi,
        AiProviderType.anthropic,
        AiProviderType.groq,
        AiProviderType.openRouter,
        AiProviderType.deepSeek,
        AiProviderType.custom,
      ]));
    });

    test('each provider has valid display name, keyUrl, and non-empty model options', () {
      for (final provider in AiProviderType.values) {
        expect(provider.displayName, isNotEmpty);
        expect(provider.keyUrl, isNotEmpty);
        expect(provider.modelOptions, isNotEmpty);
        expect(provider.defaultModel, isNotEmpty);
        expect(
          provider.modelOptions.any((m) => m.id == provider.defaultModel),
          isTrue,
          reason: '${provider.displayName} defaultModel must be present in its modelOptions',
        );
      }
    });

    test('all model options contain only chat or multimodal models (no audio or image gen)', () {
      for (final provider in AiProviderType.values) {
        for (final model in provider.modelOptions) {
          final idLower = model.id.toLowerCase();
          final nameLower = model.displayName.toLowerCase();

          // Reject audio/whisper/speech models
          expect(idLower.contains('whisper'), isFalse, reason: '${model.id} should not be whisper');
          expect(idLower.contains('tts'), isFalse, reason: '${model.id} should not be tts');
          expect(idLower.contains('speech'), isFalse, reason: '${model.id} should not be speech');

          // Reject image generation models (dall-e, imagen)
          expect(idLower.contains('dall-e'), isFalse, reason: '${model.id} should not be dall-e');
          expect(idLower.contains('imagen'), isFalse, reason: '${model.id} should not be imagen');

          // Reject text embeddings
          expect(idLower.contains('embedding'), isFalse, reason: '${model.id} should not be embedding');
          expect(nameLower.contains('embedding'), isFalse, reason: '${model.displayName} should not be embedding');
        }
      }
    });
  });

  group('AiProviderConfig Independent Key Storage & Switching', () {
    test('maintains independent API keys and models for all providers without overwriting', () {
      const config = AiProviderConfig(
        providerType: AiProviderType.gemini,
        geminiApiKey: 'gemini-secret-123',
        openAiApiKey: 'openai-secret-456',
        anthropicApiKey: 'claude-secret-789',
        groqApiKey: 'groq-secret-abc',
        openRouterApiKey: 'openrouter-secret-def',
        deepSeekApiKey: 'deepseek-secret-ghi',
        customApiKey: 'custom-secret-jkl',
        customBaseUrl: 'http://localhost:11434/v1',
      );

      // Active key should reflect the selected provider
      expect(config.activeApiKey, equals('gemini-secret-123'));
      expect(config.activeModel, equals('gemini-3.8-flash'));

      // Switch to OpenAI
      final openAiConfig = config.copyWith(providerType: AiProviderType.openAi);
      expect(openAiConfig.activeApiKey, equals('openai-secret-456'));
      expect(openAiConfig.activeModel, equals('gpt-6-astra'));
      // Gemini key remains intact
      expect(openAiConfig.geminiApiKey, equals('gemini-secret-123'));

      // Switch to Anthropic
      final anthropicConfig = openAiConfig.copyWith(providerType: AiProviderType.anthropic);
      expect(anthropicConfig.activeApiKey, equals('claude-secret-789'));
      expect(anthropicConfig.activeModel, equals('claude-opus-5-5'));
      expect(anthropicConfig.openAiApiKey, equals('openai-secret-456'));

      // Switch to Custom
      final customConfig = anthropicConfig.copyWith(providerType: AiProviderType.custom);
      expect(customConfig.activeApiKey, equals('custom-secret-jkl'));
      expect(customConfig.customBaseUrl, equals('http://localhost:11434/v1'));
      expect(customConfig.anthropicApiKey, equals('claude-secret-789'));
    });

    test('isProviderConfigured correctly checks each provider individually', () {
      const partialConfig = AiProviderConfig(
        geminiApiKey: 'key-1',
        openAiApiKey: 'key-2',
        anthropicApiKey: '', // Not configured
        groqApiKey: 'key-3',
        openRouterApiKey: '', // Not configured
        deepSeekApiKey: '', // Not configured
        customApiKey: '', // Optional for custom
        customBaseUrl: 'http://localhost:11434/v1',
        customModel: 'llama-4-scout',
      );

      expect(partialConfig.isProviderConfigured(AiProviderType.gemini), isTrue);
      expect(partialConfig.isProviderConfigured(AiProviderType.openAi), isTrue);
      expect(partialConfig.isProviderConfigured(AiProviderType.anthropic), isFalse);
      expect(partialConfig.isProviderConfigured(AiProviderType.groq), isTrue);
      expect(partialConfig.isProviderConfigured(AiProviderType.openRouter), isFalse);
      expect(partialConfig.isProviderConfigured(AiProviderType.deepSeek), isFalse);
      expect(partialConfig.isProviderConfigured(AiProviderType.custom), isTrue);

      final configured = partialConfig.configuredProviders;
      expect(configured, containsAll([
        AiProviderType.gemini,
        AiProviderType.openAi,
        AiProviderType.groq,
        AiProviderType.custom,
      ]));
      expect(configured.contains(AiProviderType.anthropic), isFalse);
    });

    test('custom endpoint activeModelOptions merges customSavedModels dynamically', () {
      const config = AiProviderConfig(
        providerType: AiProviderType.custom,
        customSavedModels: ['my-finetuned-llama', 'deepseek-r1:8b'],
      );

      final options = config.activeModelOptions;
      expect(options.any((o) => o.id == 'my-finetuned-llama'), isTrue);
      expect(options.any((o) => o.id == 'deepseek-r1:8b'), isTrue);
      // Predefined options still present
      expect(options.any((o) => o.id == 'llama-4-scout'), isTrue);
    });

    test('copyWith updates selectedModel for whichever provider is currently active', () {
      const config = AiProviderConfig(providerType: AiProviderType.openAi);
      final updated = config.copyWith(selectedModel: 'gpt-6-sol');

      expect(updated.openAiModel, equals('gpt-6-sol'));
      expect(updated.geminiModel, equals('gemini-3.8-flash')); // unchanged
    });
  });

  group('AiService Multi-Provider REST Implementation', () {
    test('OpenAI request sends proper Authorization Bearer header and parses choices', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), equals('https://api.openai.com/v1/chat/completions'));
        expect(request.headers['Authorization'], equals('Bearer test-openai-key'));
        expect(request.headers['Content-Type'], contains('application/json'));

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['model'], equals('gpt-6-astra'));
        expect(body['messages'], isList);

        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'role': 'assistant',
                  'content': 'OpenAI response to financial question.',
                },
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final aiService = AiService(httpClient: mockClient);
      const config = AiProviderConfig(
        providerType: AiProviderType.openAi,
        openAiApiKey: 'test-openai-key',
        openAiModel: 'gpt-6-astra',
      );

      final reply = await aiService.sendChatMessage(
        config: config,
        history: const [],
        financialContext: '',
        userMessage: 'How is my monthly budget?',
      );

      expect(reply, equals('OpenAI response to financial question.'));
    });

    test('Anthropic request sends x-api-key, anthropic-version, and top-level system prompt', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), equals('https://api.anthropic.com/v1/messages'));
        expect(request.headers['x-api-key'], equals('test-claude-key'));
        expect(request.headers['anthropic-version'], equals('2023-06-01'));
        expect(request.headers['content-type'], contains('application/json'));

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['model'], equals('claude-opus-5-5'));
        expect(body['system'], isNotEmpty);
        expect(body['messages'], isList);

        return http.Response(
          jsonEncode({
            'content': [
              {
                'type': 'text',
                'text': 'Claude analysis of liquid assets.',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final aiService = AiService(httpClient: mockClient);
      const config = AiProviderConfig(
        providerType: AiProviderType.anthropic,
        anthropicApiKey: 'test-claude-key',
        anthropicModel: 'claude-opus-5-5',
      );

      final reply = await aiService.sendChatMessage(
        config: config,
        history: const [],
        financialContext: '',
        userMessage: 'Check my emergency runway.',
      );

      expect(reply, equals('Claude analysis of liquid assets.'));
    });

    test('Custom endpoint normalizes base URL to /chat/completions and omits auth header when empty', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), equals('http://localhost:11434/v1/chat/completions'));
        // Local Ollama default has no authorization header
        expect(request.headers.containsKey('Authorization'), isFalse);

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['model'], equals('llama-4-scout'));

        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'role': 'assistant',
                  'content': 'Local Ollama response.',
                },
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final aiService = AiService(httpClient: mockClient);
      const config = AiProviderConfig(
        providerType: AiProviderType.custom,
        customBaseUrl: 'http://localhost:11434/v1',
        customApiKey: '', // Empty key for local instance
        customModel: 'llama-4-scout',
      );

      final reply = await aiService.sendChatMessage(
        config: config,
        history: const [],
        financialContext: '',
        userMessage: 'Hello local model',
      );

      expect(reply, equals('Local Ollama response.'));
    });

    test('Custom endpoint includes Bearer token when customApiKey is provided', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), equals('https://my-proxy.company.internal/v1/chat/completions'));
        expect(request.headers['Authorization'], equals('Bearer secret-custom-token'));

        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'role': 'assistant',
                  'content': 'Protected custom endpoint reply.',
                },
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final aiService = AiService(httpClient: mockClient);
      const config = AiProviderConfig(
        providerType: AiProviderType.custom,
        customBaseUrl: 'https://my-proxy.company.internal/v1/chat/completions',
        customApiKey: 'secret-custom-token',
        customModel: 'custom-fin-v2',
      );

      final reply = await aiService.sendChatMessage(
        config: config,
        history: const [],
        financialContext: '',
        userMessage: 'Test proxy authentication',
      );

      expect(reply, equals('Protected custom endpoint reply.'));
    });

    test('testConnection returns true for 200 response and false for error', () async {
      final okClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'choices': [
              {'message': {'role': 'assistant', 'content': 'OK'}},
            ],
          }),
          200,
        );
      });

      final failClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': {'message': 'Invalid API Key'}}),
          401,
        );
      });

      const config = AiProviderConfig(
        providerType: AiProviderType.openAi,
        openAiApiKey: 'key-123',
      );

      final serviceOk = AiService(httpClient: okClient);
      expect(await serviceOk.testConnection(config), isTrue);

      final serviceFail = AiService(httpClient: failClient);
      expect(await serviceFail.testConnection(config), isFalse);
    });

    test('getModelOptionsFor returns provider-specific options regardless of active provider', () {
      const config = AiProviderConfig(
        providerType: AiProviderType.gemini,
        customSavedModels: ['my-custom-model'],
      );

      final customOptions = config.getModelOptionsFor(AiProviderType.custom);
      expect(customOptions.any((m) => m.id == 'my-custom-model'), isTrue);
      expect(customOptions.any((m) => m.id == 'llama-4-scout'), isTrue);

      final openAiOptions = config.getModelOptionsFor(AiProviderType.openAi);
      expect(openAiOptions.any((m) => m.id == 'gpt-6-astra'), isTrue);
      expect(openAiOptions.any((m) => m.id == 'llama-4-scout'), isFalse);
    });
  });

  group('AiSettingsScreen Widget Rendering & Dropdown Integrity', () {
    testWidgets('renders AiSettingsScreen without error when Gemini is default active provider', (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AiSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AI Providers & BYOK Vault'), findsOneWidget);
      expect(find.text('Google Gemini'), findsWidgets);
      expect(find.text('Custom Endpoint'), findsOneWidget);
    });
  });
}
