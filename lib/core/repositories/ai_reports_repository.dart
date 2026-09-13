import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../domain/entities/ai_assistant_entity.dart';

/// Abstract repository for generated AI reports persistence and retrieval
abstract class AiReportsRepository {
  Future<List<AiReportItem>> getAllReports();
  Future<void> saveReport(AiReportItem report);
  Future<void> deleteReport(String id);
  Future<void> clearAllReports();
}

/// SQLite Production Implementation
class SqliteAiReportsRepository implements AiReportsRepository {
  final AppDatabase _db;

  SqliteAiReportsRepository({AppDatabase? db}) : _db = db ?? AppDatabase.instance;

  @override
  Future<List<AiReportItem>> getAllReports() async {
    final maps = await _db.getAllAiReports();
    return maps.map((m) => AiReportItem.fromMap(m)).toList();
  }

  @override
  Future<void> saveReport(AiReportItem report) async {
    await _db.insertAiReport(report.toMap());
  }

  @override
  Future<void> deleteReport(String id) async {
    await _db.deleteAiReport(id);
  }

  @override
  Future<void> clearAllReports() async {
    await _db.clearAllAiReports();
  }
}

/// In-Memory Mock Implementation for Testing
class InMemoryAiReportsRepository implements AiReportsRepository {
  final List<AiReportItem> _reports = [];

  @override
  Future<List<AiReportItem>> getAllReports() async {
    final sorted = List<AiReportItem>.from(_reports)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sorted;
  }

  @override
  Future<void> saveReport(AiReportItem report) async {
    _reports.removeWhere((r) => r.id == report.id);
    _reports.add(report);
  }

  @override
  Future<void> deleteReport(String id) async {
    _reports.removeWhere((r) => r.id == id);
  }

  @override
  Future<void> clearAllReports() async {
    _reports.clear();
  }
}

final aiReportsRepositoryProvider = Provider<AiReportsRepository>((ref) {
  return SqliteAiReportsRepository();
});
