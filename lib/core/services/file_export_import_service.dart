import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class FileExportImportResult {
  final String content;
  final String fileName;
  final int sizeInBytes;

  const FileExportImportResult({
    required this.content,
    required this.fileName,
    required this.sizeInBytes,
  });
}

/// Helper service for native JSON file download, storage saving, file sharing, and file picker import
class FileExportImportService {
  /// Exports and saves a backup JSON file to device storage or downloads
  static Future<String> saveJsonFile({
    required String jsonContent,
    String basePrefix = 'EmptyPocket_Backup',
  }) async {
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = '${basePrefix}_$timestamp.json';
    final bytes = utf8.encode(jsonContent);

    try {
      // 1. Try native FilePicker save dialog (Desktop, Android with SAF, iOS)
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Backup File',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: Uint8List.fromList(bytes),
      );

      if (savePath != null && savePath.isNotEmpty) {
        final savedFile = File(savePath);
        if (!await savedFile.exists() || (await savedFile.length()) == 0) {
          await savedFile.writeAsString(jsonContent, flush: true);
        }
        return savePath;
      }
    } catch (e) {
      debugPrint('[FileExportImportService] FilePicker saveFile fallback: $e');
    }

    // 2. Fallback: Save to app documents or downloads directory
    Directory? targetDir;
    try {
      targetDir = await getDownloadsDirectory();
    } catch (_) {}
    targetDir ??= await getApplicationDocumentsDirectory();

    final fallbackFile = File('${targetDir.path}/$fileName');
    await fallbackFile.writeAsString(jsonContent, flush: true);
    return fallbackFile.path;
  }

  /// Shares a JSON backup file via the native system share sheet (Google Drive, WhatsApp, Files, etc.)
  static Future<void> shareJsonFile({
    required String jsonContent,
    String basePrefix = 'EmptyPocket_Backup',
  }) async {
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = '${basePrefix}_$timestamp.json';

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsString(jsonContent, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        subject: fileName,
      ),
    );
  }

  /// Opens the system file picker to select a .json backup file
  static Future<FileExportImportResult?> pickJsonFile() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select EmptyPocket Backup JSON File',
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final picked = result.files.first;
    String content;

    if (picked.bytes != null && picked.bytes!.isNotEmpty) {
      content = utf8.decode(picked.bytes!);
    } else if (picked.path != null) {
      final file = File(picked.path!);
      content = await file.readAsString();
    } else {
      throw const FormatException('Could not read selected file data.');
    }

    return FileExportImportResult(
      content: content,
      fileName: picked.name,
      sizeInBytes: picked.size,
    );
  }
}
