import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'core/services/log_service.dart';
import 'features/overlay/presentation/screens/floating_bubble_overlay.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

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
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FloatingBubbleOverlayApp());
}
