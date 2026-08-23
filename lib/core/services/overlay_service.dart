import 'package:flutter/foundation.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class OverlayService {
  /// Check if the device has granted "Display over other apps" permission
  static Future<bool> isPermissionGranted() async {
    try {
      return await FlutterOverlayWindow.isPermissionGranted();
    } catch (e) {
      debugPrint('[OverlayService] isPermissionGranted error: $e');
      return false;
    }
  }

  /// Request the system alert window permission from the user
  static Future<bool?> requestPermission() async {
    try {
      return await FlutterOverlayWindow.requestPermission();
    } catch (e) {
      debugPrint('[OverlayService] requestPermission error: $e');
      return false;
    }
  }

  /// Check if the overlay window is currently active/open
  static Future<bool> isActive() async {
    try {
      return await FlutterOverlayWindow.isActive();
    } catch (e) {
      debugPrint('[OverlayService] isActive error: $e');
      return false;
    }
  }

  /// Show the floating bubble on top of other apps centered on screen.
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
        alignment: OverlayAlignment.center,
        positionGravity: PositionGravity.none,
        height: 120,
        width: 120,
      );
    } catch (e) {
      debugPrint('[OverlayService] showFloatingBubble error: $e');
    }
  }

  static OverlayPosition? _savedPosition;
  static const int _bubbleSize = 120;
  static const int _expandedWidth = 350;
  static const int _expandedHeight = 500;

  /// Expand the overlay to full quick-entry modal size and enable keyboard focus.
  /// Always moves to (0, 0) so the modal opens in the EXACT CENTER of the screen
  /// with 100% visibility, regardless of where the bubble was placed.
  static Future<void> expandOverlay() async {
    try {
      await FlutterOverlayWindow.updateFlag(OverlayFlag.focusPointer);

      _savedPosition = await FlutterOverlayWindow.getOverlayPosition();
      
      // Move to center of screen (0, 0)
      await FlutterOverlayWindow.moveOverlay(const OverlayPosition(0, 0));

      await FlutterOverlayWindow.resizeOverlay(
        _expandedWidth,
        _expandedHeight,
        false,
      );
    } catch (e) {
      debugPrint('[OverlayService] expandOverlay error: $e');
    }
  }

  /// Collapse the overlay back to small floating bubble and restore default touch flag
  static Future<void> collapseOverlay() async {
    try {
      await FlutterOverlayWindow.updateFlag(OverlayFlag.defaultFlag);

      if (_savedPosition != null) {
        await FlutterOverlayWindow.moveOverlay(_savedPosition!);
      }

      await FlutterOverlayWindow.resizeOverlay(
        _bubbleSize,
        _bubbleSize,
        true,
      );
    } catch (e) {
      debugPrint('[OverlayService] collapseOverlay error: $e');
    }
  }

  /// Close the overlay completely
  static Future<void> closeOverlay() async {
    try {
      await FlutterOverlayWindow.closeOverlay();
    } catch (e) {
      debugPrint('[OverlayService] closeOverlay error: $e');
    }
  }
}
