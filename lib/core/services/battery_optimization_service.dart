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
}
