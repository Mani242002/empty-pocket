import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app/app.dart';
import 'core/services/log_service.dart';
import 'core/services/notification_service.dart';
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

  // Initialize offline local notifications service and ensure scheduled reminders are active
  try {
    await NotificationService.instance.initialize();
    final prefs = await SharedPreferences.getInstance();
    final streakEnabled = prefs.getBool(kPrefDailyStreakReminder) ?? true;
    if (streakEnabled) {
      await NotificationService.instance.requestPermission();
      await NotificationService.instance.scheduleDailyStreakReminder();
    }
  } catch (e) {
    LogService.debug('Main', 'Failed to initialize NotificationService: $e');
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

  // Defensive fallback error boundary to prevent default grey/red crash box
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: const Color(0xFF0C1117),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF10B981).withAlpha(30),
                    border: Border.all(color: const Color(0xFF10B981).withAlpha(80)),
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: Color(0xFF10B981),
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Something went wrong',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Your offline records are safe. Try restarting the app.',
                  style: TextStyle(
                    color: Colors.white.withAlpha(180),
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
  } catch (e) {
    LogService.debug('MainOverlay', 'Failed to pre-load currency preference: $e');
  }
  runApp(const FloatingBubbleOverlayApp());
}
