import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../domain/entities/ai_assistant_entity.dart';

/// Abstract repository for AI Chat sessions and message history
abstract class AiChatRepository {
  Future<List<AiChatSession>> getAllSessions();
  Future<AiChatSession?> getSessionById(String id);
  Future<void> saveSession(AiChatSession session);
  Future<void> deleteSession(String id);
  Future<void> batchSaveSessions(List<AiChatSession> sessions);

  Future<List<AiChatMessage>> getMessagesForSession(String sessionId);
  Future<List<AiChatMessage>> getAllMessages();
  Future<void> saveMessage(AiChatMessage message);
  Future<void> deleteMessage(String id);
  Future<void> batchSaveMessages(List<AiChatMessage> messages);

  Future<void> clearAllChatHistory();
}

/// SQLite Implementation
class SqliteAiChatRepository implements AiChatRepository {
  final AppDatabase _db;

  SqliteAiChatRepository({AppDatabase? db}) : _db = db ?? AppDatabase.instance;

  @override
  Future<List<AiChatSession>> getAllSessions() async {
    return await _db.getAllChatSessions();
  }

  @override
  Future<AiChatSession?> getSessionById(String id) async {
    return await _db.getChatSessionById(id);
  }

  @override
  Future<void> saveSession(AiChatSession session) async {
    final existing = await _db.getChatSessionById(session.id);
    if (existing != null) {
      await _db.updateChatSession(session);
    } else {
      await _db.insertChatSession(session);
    }
  }

  @override
  Future<void> deleteSession(String id) async {
    await _db.deleteChatSession(id);
  }

  @override
  Future<void> batchSaveSessions(List<AiChatSession> sessions) async {
    await _db.batchInsertChatSessions(sessions);
  }

  @override
  Future<List<AiChatMessage>> getMessagesForSession(String sessionId) async {
    return await _db.getMessagesForSession(sessionId);
  }

  @override
  Future<List<AiChatMessage>> getAllMessages() async {
    return await _db.getAllChatMessages();
  }

  @override
  Future<void> saveMessage(AiChatMessage message) async {
    await _db.insertChatMessage(message);
  }

  @override
  Future<void> deleteMessage(String id) async {
    await _db.deleteChatMessage(id);
  }

  @override
  Future<void> batchSaveMessages(List<AiChatMessage> messages) async {
    await _db.batchInsertChatMessages(messages);
  }

  @override
  Future<void> clearAllChatHistory() async {
    await _db.clearAllChatHistory();
  }
}

/// In-Memory implementation for unit and widget testing without SQLite FFI
class InMemoryAiChatRepository implements AiChatRepository {
  final List<AiChatSession> _sessions = [];
  final List<AiChatMessage> _messages = [];

  @override
  Future<List<AiChatSession>> getAllSessions() async {
    return List.unmodifiable(
      [..._sessions]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
    );
  }

  @override
  Future<AiChatSession?> getSessionById(String id) async {
    final match = _sessions.where((s) => s.id == id);
    return match.isNotEmpty ? match.first : null;
  }

  @override
  Future<void> saveSession(AiChatSession session) async {
    _sessions.removeWhere((s) => s.id == session.id);
    _sessions.add(session);
  }

  @override
  Future<void> deleteSession(String id) async {
    _sessions.removeWhere((s) => s.id == id);
    _messages.removeWhere((m) => m.sessionId == id);
  }

  @override
  Future<void> batchSaveSessions(List<AiChatSession> sessions) async {
    for (final s in sessions) {
      _sessions.removeWhere((existing) => existing.id == s.id);
      _sessions.add(s);
    }
  }

  @override
  Future<List<AiChatMessage>> getMessagesForSession(String sessionId) async {
    final sessionMsgs = _messages.where((m) => m.sessionId == sessionId).toList();
    sessionMsgs.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return sessionMsgs;
  }

  @override
  Future<List<AiChatMessage>> getAllMessages() async {
    final all = [..._messages];
    all.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return all;
  }

  @override
  Future<void> saveMessage(AiChatMessage message) async {
    _messages.removeWhere((m) => m.id == message.id);
    _messages.add(message);
  }

  @override
  Future<void> deleteMessage(String id) async {
    _messages.removeWhere((m) => m.id == id);
  }

  @override
  Future<void> batchSaveMessages(List<AiChatMessage> messages) async {
    for (final m in messages) {
      _messages.removeWhere((existing) => existing.id == m.id);
      _messages.add(m);
    }
  }

  @override
  Future<void> clearAllChatHistory() async {
    _sessions.clear();
    _messages.clear();
  }
}

/// Global Riverpod Provider for AiChatRepository
final aiChatRepositoryProvider = Provider<AiChatRepository>((ref) {
  return SqliteAiChatRepository();
});
