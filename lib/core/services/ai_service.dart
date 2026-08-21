import 'dart:convert';
import 'package:http/http.dart' as http;
import '../domain/entities/ai_assistant_entity.dart';

class AiService {
  final http.Client _httpClient;

  AiService({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  /// Test connection with user-provided API key
  Future<bool> testConnection(AiProviderConfig config) async {
    if (!config.isConfigured) return false;

    try {
      final response = await _generateRawText(
        config: config,
        systemPrompt: 'You are a test ping responder.',
        userPrompt: 'Respond with exactly the single word "OK".',
      );
      return response.trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Generate a structured financial audit report using selected AI provider
  Future<AiAuditReport> generateFinancialAudit({
    required AiProviderConfig config,
    required String financialSummaryText,
  }) async {
    const systemPrompt = '''
You are an expert personal finance strategist and fiduciary advisor for EmptyPocket, a privacy-focused personal finance mobile app.
Analyze the user's offline financial numbers objectively.
Return a structured, insightful response with clear sections:
1. EXECUTIVE OVERVIEW (2-3 sentences summarizing their current financial standing)
2. KEY STRENGTHS (3 specific bullet points highlighting what they are doing well)
3. RISK FLAGS (2-3 specific risks or areas needing improvement)
4. ACTIONABLE RECOMMENDATIONS (3 concrete, prioritized steps for this month)
Keep the tone encouraging, realistic, and practical for Indian / global personal finance standards (mention ₹ amounts where relevant).
''';

    final userPrompt = '''
Here is my current offline financial summary:
$financialSummaryText

Please provide my comprehensive financial audit.
''';

    final text = await _generateRawText(
      config: config,
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
    );

    return _parseAuditResponse(text);
  }

  /// Send a contextual chat message to the assistant
  Future<String> sendChatMessage({
    required AiProviderConfig config,
    required List<AiChatMessage> history,
    required String userMessage,
    required String financialContext,
  }) async {
    final systemPrompt = '''
You are "PocketAI", a helpful, friendly, and analytical personal finance assistant inside EmptyPocket.
You have access to the user's private financial metrics (Income, Expenses, Budgets, Savings Goals, Loans/Liabilities, Investments, Net Worth, Health Score).
Context:
$financialContext

Guidelines:
- Give concise, highly relevant, and mathematically grounded answers.
- Use currency formatting (₹) when discussing amounts.
- If asked whether they can afford a purchase, evaluate their liquid balance, monthly savings, and emergency buffer before answering.
- Be supportive, practical, and clear. Avoid robotic boilerplate.
''';

    return await _generateRawText(
      config: config,
      systemPrompt: systemPrompt,
      userPrompt: userMessage,
      history: history,
    );
  }

  /// Generic LLM dispatch router for Gemini & Groq
  Future<String> _generateRawText({
    required AiProviderConfig config,
    required String systemPrompt,
    required String userPrompt,
    List<AiChatMessage>? history,
  }) async {
    switch (config.providerType) {
      case AiProviderType.gemini:
        return await _callGemini(config: config, systemPrompt: systemPrompt, userPrompt: userPrompt, history: history);
      case AiProviderType.groq:
        return await _callGroq(config: config, systemPrompt: systemPrompt, userPrompt: userPrompt, history: history);
    }
  }

  /// Google Gemini REST API Implementation
  Future<String> _callGemini({
    required AiProviderConfig config,
    required String systemPrompt,
    required String userPrompt,
    List<AiChatMessage>? history,
  }) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/${config.selectedModel}:generateContent?key=${config.apiKey.trim()}',
    );

    final List<Map<String, dynamic>> contents = [];

    // System instruction / context
    contents.add({
      'role': 'user',
      'parts': [
        {'text': '[SYSTEM INSTRUCTION]\n$systemPrompt'}
      ],
    });
    contents.add({
      'role': 'model',
      'parts': [
        {'text': 'Understood. I will act as the financial advisor according to these instructions.'}
      ],
    });

    // Conversation history
    if (history != null && history.isNotEmpty) {
      for (final msg in history.take(8)) {
        contents.add({
          'role': msg.isUser ? 'user' : 'model',
          'parts': [
            {'text': msg.text}
          ],
        });
      }
    }

    // Current user prompt
    contents.add({
      'role': 'user',
      'parts': [
        {'text': userPrompt}
      ],
    });

    final response = await _httpClient.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': contents,
        'generationConfig': {
          'temperature': 0.7,
          'maxOutputTokens': 1500,
        },
      }),
    );

    if (response.statusCode != 200) {
      final errorBody = jsonDecode(response.body);
      final message = errorBody['error']?['message'] ?? 'Gemini API call failed (${response.statusCode})';
      throw Exception(message);
    }

    final data = jsonDecode(response.body);
    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('No response generated by Gemini model.');
    }

    final parts = candidates.first['content']?['parts'] as List?;
    if (parts == null || parts.isEmpty) {
      throw Exception('Empty content returned by Gemini.');
    }

    return parts.first['text'] as String;
  }

  /// Groq OpenAI-Compatible REST API Implementation
  Future<String> _callGroq({
    required AiProviderConfig config,
    required String systemPrompt,
    required String userPrompt,
    List<AiChatMessage>? history,
  }) async {
    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

    final List<Map<String, String>> messages = [
      {'role': 'system', 'content': systemPrompt},
    ];

    if (history != null && history.isNotEmpty) {
      for (final msg in history.take(8)) {
        messages.add({
          'role': msg.isUser ? 'user' : 'assistant',
          'content': msg.text,
        });
      }
    }

    messages.add({'role': 'user', 'content': userPrompt});

    final response = await _httpClient.post(
      url,
      headers: {
        'Authorization': 'Bearer ${config.apiKey.trim()}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': config.selectedModel,
        'messages': messages,
        'temperature': 0.7,
        'max_tokens': 1500,
      }),
    );

    if (response.statusCode != 200) {
      final errorBody = jsonDecode(response.body);
      final message = errorBody['error']?['message'] ?? 'Groq API call failed (${response.statusCode})';
      throw Exception(message);
    }

    final data = jsonDecode(response.body);
    final choices = data['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw Exception('No choices returned by Groq.');
    }

    return choices.first['message']['content'] as String;
  }

  AiAuditReport _parseAuditResponse(String text) {
    final lines = text.split('\n');
    final List<String> strengths = [];
    final List<String> risks = [];
    final List<String> recommendations = [];
    final List<String> overviewLines = [];

    String currentSection = 'overview';

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final upper = trimmed.toUpperCase();
      if (upper.contains('STRENGTH')) {
        currentSection = 'strengths';
        continue;
      } else if (upper.contains('RISK') || upper.contains('WEAKNESS') || upper.contains('CONCERN')) {
        currentSection = 'risks';
        continue;
      } else if (upper.contains('RECOMMENDATION') || upper.contains('ACTION') || upper.contains('NEXT STEP')) {
        currentSection = 'recommendations';
        continue;
      }

      final cleanLine = trimmed.replaceAll(RegExp(r'^[\*\-\d\.\)]+\s*'), '');

      if (currentSection == 'strengths') {
        if (cleanLine.isNotEmpty) strengths.add(cleanLine);
      } else if (currentSection == 'risks') {
        if (cleanLine.isNotEmpty) risks.add(cleanLine);
      } else if (currentSection == 'recommendations') {
        if (cleanLine.isNotEmpty) recommendations.add(cleanLine);
      } else {
        if (!upper.contains('EXECUTIVE') && !upper.contains('OVERVIEW')) {
          overviewLines.add(trimmed);
        }
      }
    }

    return AiAuditReport(
      overview: overviewLines.isNotEmpty ? overviewLines.join(' ') : text.substring(0, text.length.clamp(0, 300)),
      strengths: strengths.isNotEmpty ? strengths : ['Disciplined financial logging and tracking active in EmptyPocket.'],
      risks: risks.isNotEmpty ? risks : ['Review monthly discretionary spending and liability balances.'],
      recommendations: recommendations.isNotEmpty
          ? recommendations
          : ['Maintain 3-6 months emergency runway.', 'Automate monthly savings goals and SIP investments.'],
      timestamp: DateTime.now(),
    );
  }
}
