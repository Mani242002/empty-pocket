import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class OverlayService {
  static const MethodChannel _channel = MethodChannel('dev.emptypocket.app/overlay');

  /// Check if the device has granted "Display over other apps" permission
  static Future<bool> isPermissionGranted() async {
    try {
      return await FlutterOverlayWindow.isPermissionGranted();
    } catch (_) {
      return false;
    }
  }

  /// Request the system alert window permission from the user
  static Future<bool?> requestPermission() async {
    try {
      return await FlutterOverlayWindow.requestPermission();
    } catch (_) {
      return false;
    }
  }

  /// Check if the overlay window is currently active/open
  static Future<bool> isActive() async {
    try {
      return await FlutterOverlayWindow.isActive();
    } catch (_) {
      return false;
    }
  }

  /// Show the floating bubble on top of other apps
  static Future<void> showFloatingBubble() async {
    final granted = await isPermissionGranted();
    if (!granted) {
      final res = await requestPermission();
      if (res != true) return;
    }

    try {
      // Close any previous instance first to avoid duplicates
      await FlutterOverlayWindow.closeOverlay();
    } catch (_) {}

    try {
      await FlutterOverlayWindow.showOverlay(
        enableDrag: true,
        overlayTitle: "EmptyPocket Quick-Add",
        overlayContent: "Tap to quickly log expense or income",
        flag: OverlayFlag.defaultFlag,
        visibility: NotificationVisibility.visibilityPrivate,
        positionGravity: PositionGravity.none,
        height: 80,
        width: 80,
      );
    } catch (_) {}
  }

  /// Open the Quick-Add dialog in the main app
  static Future<void> openQuickAdd() async {
    try {
      await _channel.invokeMethod('openQuickAdd');
    } catch (_) {}
  }

  /// Minimize the app back to previous task (Paytm, etc.)
  static Future<void> minimizeApp() async {
    try {
      await _channel.invokeMethod('minimizeApp');
    } catch (_) {}
  }

  /// Close the overlay completely
  static Future<void> closeOverlay() async {
    try {
      await FlutterOverlayWindow.closeOverlay();
    } catch (_) {}
  }
}
