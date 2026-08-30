import 'package:flutter/services.dart';
import 'log_service.dart';

/// Service to check and request battery optimization whitelist exemption
/// Ensures 24/7 background resilience on aggressive OEM devices (OnePlus/OxygenOS, Xiaomi/MIUI, Moto, Samsung)
class BatteryOptimizationService {
  static const String _tag = 'BatteryOptimizationService';
  static const MethodChannel _channel = MethodChannel('dev.emptypocket.app/battery');

  /// Check if the app is currently excluded from battery optimizations
  static Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      final result = await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations');
      return result ?? false;
    } catch (e, stack) {
      LogService.error(_tag, 'isIgnoringBatteryOptimizations error', e, stack);
      return false;
    }
  }

  /// Request the system dialog to ignore battery optimizations for EmptyPocket
  static Future<bool> requestIgnoreBatteryOptimizations() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestIgnoreBatteryOptimizations');
      return result ?? false;
    } catch (e, stack) {
      LogService.error(_tag, 'requestIgnoreBatteryOptimizations error', e, stack);
      return false;
    }
  }

  /// Open system battery optimization settings
  static Future<bool> openBatterySettings() async {
    try {
      final result = await _channel.invokeMethod<bool>('openBatterySettings');
      return result ?? false;
    } catch (e, stack) {
      LogService.error(_tag, 'openBatterySettings error', e, stack);
      return false;
    }
  }

  /// Open application details settings (Battery usage, Auto-launch, and Background execution settings)
  static Future<bool> openAppDetailsSettings() async {
    try {
      final result = await _channel.invokeMethod<bool>('openAppDetailsSettings');
      return result ?? false;
    } catch (e, stack) {
      LogService.error(_tag, 'openAppDetailsSettings error', e, stack);
      return false;
    }
  }

  /// Check if notification permission is granted (required on Android 13+ for persistent 24/7 foreground services)
  static Future<bool> hasNotificationPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('hasNotificationPermission');
      return result ?? true;
    } catch (e, stack) {
      LogService.error(_tag, 'hasNotificationPermission error', e, stack);
      return true;
    }
  }

  /// Request runtime notification permission on Android 13+
  static Future<bool> requestNotificationPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestNotificationPermission');
      return result ?? true;
    } catch (e, stack) {
      LogService.error(_tag, 'requestNotificationPermission error', e, stack);
      return true;
    }
  }
}
