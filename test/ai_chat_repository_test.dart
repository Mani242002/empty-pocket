import 'package:flutter_test/flutter_test.dart';
import 'package:empty_pocket/core/domain/entities/ai_assistant_entity.dart';
import 'package:empty_pocket/core/repositories/ai_chat_repository.dart';

void main() {
  group('InMemoryAiChatRepository Tests', () {
    late InMemoryAiChatRepository repository;

    setUp(() {
      repository = InMemoryAiChatRepository();
    });

    test('saveSession, getSessionById and getAllSessions', () async {
      final now = DateTime.now();
      final session1 = AiChatSession(
        id: 's-1',
        title: 'Session 1',
        provider: 'gemini',
        modelUsed: 'Gemini 3.7 Flash',
        createdAt: now.subtract(const Duration(minutes: 5)),
        updatedAt: now.subtract(const Duration(minutes: 5)),
      );

      final session2 = AiChatSession(
        id: 's-2',
        title: 'Session 2',
        provider: 'groq',
        modelUsed: 'Qwen 3.6',
        createdAt: now,
        updatedAt: now,
      );

      await repository.saveSession(session1);
      await repository.saveSession(session2);

      final retrieved = await repository.getSessionById('s-1');
      expect(retrieved, isNotNull);
      expect(retrieved!.title, 'Session 1');

      final all = await repository.getAllSessions();
      expect(all.length, 2);
      // Most recently updated session should be first
      expect(all.first.id, 's-2');
    });

    test('saveMessage and getMessagesForSession ordered by timestamp', () async {
      final now = DateTime.now();
      final msg1 = AiChatMessage(
        id: 'm-1',
        sessionId: 's-1',
        text: 'First question',
        isUser: true,
        timestamp: now,
      );

      final msg2 = AiChatMessage(
        id: 'm-2',
        sessionId: 's-1',
        text: 'Second answer',
        isUser: false,
        timestamp: now.add(const Duration(seconds: 5)),
      );

      await repository.saveMessage(msg2);
      await repository.saveMessage(msg1);

      final sessionMessages = await repository.getMessagesForSession('s-1');
      expect(sessionMessages.length, 2);
      expect(sessionMessages[0].id, 'm-1');
      expect(sessionMessages[1].id, 'm-2');
    });

    test('deleteSession removes session and associated messages', () async {
      final now = DateTime.now();
      final session = AiChatSession(
        id: 's-del',
        title: 'To Delete',
        provider: 'gemini',
        modelUsed: 'Gemini 3.7 Flash',
        createdAt: now,
        updatedAt: now,
      );

      final msg = AiChatMessage(
        id: 'm-del',
        sessionId: 's-del',
        text: 'Test message',
        isUser: true,
        timestamp: now,
      );

      await repository.saveSession(session);
      await repository.saveMessage(msg);

      expect((await repository.getAllSessions()).length, 1);
      expect((await repository.getMessagesForSession('s-del')).length, 1);

      await repository.deleteSession('s-del');

      expect(await repository.getSessionById('s-del'), isNull);
      expect((await repository.getAllSessions()).length, 0);
      expect((await repository.getMessagesForSession('s-del')).length, 0);
    });

    test('batchSaveSessions and batchSaveMessages', () async {
      final now = DateTime.now();
      final sessions = [
        AiChatSession(
          id: 'b-1',
          title: 'Batch 1',
          provider: 'gemini',
          modelUsed: 'gemini-3.7-flash',
          createdAt: now,
          updatedAt: now,
        ),
        AiChatSession(
          id: 'b-2',
          title: 'Batch 2',
          provider: 'groq',
          modelUsed: 'qwen-3.6',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final messages = [
        AiChatMessage(
          id: 'bm-1',
          sessionId: 'b-1',
          text: 'Question 1',
          isUser: true,
          timestamp: now,
        ),
        AiChatMessage(
          id: 'bm-2',
          sessionId: 'b-2',
          text: 'Question 2',
          isUser: true,
          timestamp: now,
        ),
      ];

      await repository.batchSaveSessions(sessions);
      await repository.batchSaveMessages(messages);

      expect((await repository.getAllSessions()).length, 2);
      expect((await repository.getAllMessages()).length, 2);
    });

    test('clearAllChatHistory clears all sessions and messages', () async {
      final now = DateTime.now();
      await repository.saveSession(
        AiChatSession(
          id: 's-1',
          title: 'Session 1',
          provider: 'gemini',
          modelUsed: 'Gemini',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await repository.saveMessage(
        AiChatMessage(
          id: 'm-1',
          sessionId: 's-1',
          text: 'Hello',
          isUser: true,
          timestamp: now,
        ),
      );

      await repository.clearAllChatHistory();

      expect((await repository.getAllSessions()).isEmpty, isTrue);
      expect((await repository.getAllMessages()).isEmpty, isTrue);
    });
  });
}
