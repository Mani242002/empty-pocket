import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app/app.dart';
import 'core/services/log_service.dart';
import 'core/utilities/currency_formatter.dart';
import 'features/overlay/presentation/screens/floating_bubble_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Pre-load user currency preference before initial render
  try {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString('app_currency_code');
    if (savedCode != null) {
      CurrencyFormatter.setCurrencyByCode(savedCode);
    }
  } catch (e) {
    LogService.debug('Main', 'Failed to pre-load currency preference: $e');
  }

  // Catch synchronous Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    LogService.error('FlutterError', details.exceptionAsString(), details.exception, details.stack);
  };

  // Catch unhandled asynchronous Dart and platform errors
  PlatformDispatcher.instance.onError = (error, stack) {
    LogService.error('AsyncPlatformError', error.toString(), error, stack);
    return true; // Handled, prevents crashing the app process
  };

  runApp(
    const ProviderScope(
      child: EmptyPocketApp(),
    ),
  );
}

/// Dedicated entrypoint for the Android 24/7 Floating Bubble / System Alert Window
@pragma("vm:entry-point")
void overlayMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString('app_currency_code');
    if (savedCode != null) {
      CurrencyFormatter.setCurrencyByCode(savedCode);
    }
  } catch (_) {}
  runApp(const FloatingBubbleOverlayApp());
}
