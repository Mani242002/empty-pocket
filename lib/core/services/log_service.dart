import 'package:flutter/foundation.dart';

/// Centralized logging service for EmptyPocket.
///
/// Handles debug output in development, prevents sensitive leaks,
/// and provides structured logging categories.
class LogService {
  LogService._();

  static void debug(String tag, String message) {
    if (kDebugMode) {
      debugPrint('[DEBUG][$tag] $message');
    }
  }

  static void info(String tag, String message) {
    if (kDebugMode) {
      debugPrint('[INFO][$tag] $message');
    }
  }

  static void warning(String tag, String message, [Object? error, StackTrace? stack]) {
    if (kDebugMode) {
      debugPrint('[WARN][$tag] $message');
      if (error != null) debugPrint('[WARN][$tag] Error: $error');
      if (stack != null) debugPrint('[WARN][$tag] Stack: $stack');
    }
  }

  static void error(String tag, String message, [Object? error, StackTrace? stack]) {
    debugPrint('[ERROR][$tag] $message');
    if (error != null) debugPrint('[ERROR][$tag] Details: $error');
    if (stack != null && kDebugMode) debugPrint('[ERROR][$tag] Stack: $stack');
  }
}
