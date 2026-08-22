import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class OverlayService {
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
      await FlutterOverlayWindow.showOverlay(
        enableDrag: true,
        overlayTitle: "EmptyPocket Quick-Add",
        overlayContent: "Tap to record expense or income",
        flag: OverlayFlag.defaultFlag,
        visibility: NotificationVisibility.visibilityPrivate,
        positionGravity: PositionGravity.none,
        height: 70,
        width: 70,
      );
    } catch (_) {}
  }

  /// Expand the overlay to full quick-entry modal size
  static Future<void> expandOverlay() async {
    try {
      await FlutterOverlayWindow.resizeOverlay(
        360,
        520,
        false,
      );
    } catch (_) {}
  }

  /// Collapse the overlay back to small floating bubble
  static Future<void> collapseOverlay() async {
    try {
      await FlutterOverlayWindow.resizeOverlay(
        70,
        70,
        true,
      );
    } catch (_) {}
  }

  /// Close the overlay completely
  static Future<void> closeOverlay() async {
    try {
      await FlutterOverlayWindow.closeOverlay();
    } catch (_) {}
  }
}
