import 'package:flutter_test/flutter_test.dart';
import 'package:empty_pocket/core/domain/entities/ai_assistant_entity.dart';
import 'package:empty_pocket/core/services/backup_service.dart';

void main() {
  group('AiChatSession & AiChatMessage Entity Tests', () {
    test('AiChatSession toMap and fromMap serialization', () {
      final now = DateTime.now();
      final session = AiChatSession(
        id: 'session-123',
        title: 'Monthly Budget Analysis',
        provider: 'gemini',
        modelUsed: 'Gemini 2.5 Flash',
        createdAt: now,
        updatedAt: now,
      );

      final map = session.toMap();
      expect(map['id'], 'session-123');
      expect(map['title'], 'Monthly Budget Analysis');
      expect(map['provider'], 'gemini');
      expect(map['model_used'], 'Gemini 2.5 Flash');
      expect(map['created_at'], now.millisecondsSinceEpoch);
      expect(map['updated_at'], now.millisecondsSinceEpoch);

      final restored = AiChatSession.fromMap(map);
      expect(restored.id, session.id);
      expect(restored.title, session.title);
      expect(restored.provider, session.provider);
      expect(restored.modelUsed, session.modelUsed);
      expect(restored.createdAt.millisecondsSinceEpoch, session.createdAt.millisecondsSinceEpoch);
      expect(restored.updatedAt.millisecondsSinceEpoch, session.updatedAt.millisecondsSinceEpoch);
    });

    test('AiChatSession copyWith works as expected', () {
      final now = DateTime.now();
      final session = AiChatSession(
        id: 'session-1',
        title: 'Initial Title',
        provider: 'groq',
        modelUsed: 'Qwen 3.6',
        createdAt: now,
        updatedAt: now,
      );

      final updated = session.copyWith(title: 'Renamed Title', modelUsed: 'Qwen 3.7');
      expect(updated.id, 'session-1');
      expect(updated.title, 'Renamed Title');
      expect(updated.provider, 'groq');
      expect(updated.modelUsed, 'Qwen 3.7');
    });

    test('AiChatMessage toMap and fromMap serialization', () {
      final now = DateTime.now();
      final message = AiChatMessage(
        id: 'msg-456',
        sessionId: 'session-123',
        text: 'How much should I invest in mutual funds?',
        isUser: true,
        timestamp: now,
      );

      final map = message.toMap();
      expect(map['id'], 'msg-456');
      expect(map['session_id'], 'session-123');
      expect(map['text'], 'How much should I invest in mutual funds?');
      expect(map['is_user'], 1);
      expect(map['timestamp'], now.millisecondsSinceEpoch);

      final restored = AiChatMessage.fromMap(map);
      expect(restored.id, message.id);
      expect(restored.sessionId, message.sessionId);
      expect(restored.text, message.text);
      expect(restored.isUser, isTrue);
      expect(restored.timestamp.millisecondsSinceEpoch, message.timestamp.millisecondsSinceEpoch);
    });
  });

  group('FullDatabaseBackup with Chat History Tests', () {
    test('Export and parse full database JSON with chat sessions and messages', () {
      final service = BackupService();
      final now = DateTime.now();

      final session = AiChatSession(
        id: 's-1',
        title: 'Emergency Fund Plan',
        provider: 'gemini',
        modelUsed: 'Gemini 2.5 Flash',
        createdAt: now,
        updatedAt: now,
      );

      final msg1 = AiChatMessage(
        id: 'm-1',
        sessionId: 's-1',
        text: 'How many months of runway do I have?',
        isUser: true,
        timestamp: now,
      );

      final msg2 = AiChatMessage(
        id: 'm-2',
        sessionId: 's-1',
        text: 'Based on your ₹45,000 monthly burn rate, your runway is 4.2 months.',
        isUser: false,
        timestamp: now.add(const Duration(seconds: 2)),
      );

      final jsonStr = service.exportFullDatabaseJson(
        transactions: [],
        budgets: [],
        savingsGoals: [],
        savingsContributions: [],
        debts: [],
        debtPayments: [],
        investments: [],
        recurringExpenses: [],
        chatSessions: [session],
        chatMessages: [msg1, msg2],
      );

      expect(jsonStr, contains('Emergency Fund Plan'));
      expect(jsonStr, contains('runway is 4.2 months'));

      final parsed = service.parseBackupJson(jsonStr);
      expect(parsed.metadata.schemaVersion, 8);
      expect(parsed.metadata.chatSessionsCount, 1);
      expect(parsed.metadata.chatMessagesCount, 2);
      expect(parsed.chatSessions.length, 1);
      expect(parsed.chatSessions.first.title, 'Emergency Fund Plan');
      expect(parsed.chatMessages.length, 2);
      expect(parsed.chatMessages.first.text, 'How many months of runway do I have?');
    });

    test('Backward compatibility: parse older backup JSON without chat fields', () {
      final service = BackupService();
      const legacyJson = '''
      {
        "metadata": {
          "schemaVersion": 6,
          "exportedAt": "2026-08-24T12:00:00.000Z",
          "transactionsCount": 0,
          "budgetsCount": 0,
          "savingsGoalsCount": 0,
          "savingsContributionsCount": 0,
          "debtsCount": 0,
          "debtPaymentsCount": 0,
          "investmentsCount": 0,
          "recurringExpensesCount": 0
        },
        "transactions": [],
        "budgets": [],
        "savingsGoals": [],
        "savingsContributions": [],
        "debts": [],
        "debtPayments": [],
        "investments": [],
        "recurringExpenses": []
      }
      ''';

      final parsed = service.parseBackupJson(legacyJson);
      expect(parsed.metadata.schemaVersion, 6);
      expect(parsed.metadata.chatSessionsCount, 0);
      expect(parsed.metadata.chatMessagesCount, 0);
      expect(parsed.chatSessions, isEmpty);
      expect(parsed.chatMessages, isEmpty);
    });
  });
}
