import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'log_service.dart';

/// Service managing the 24/7 Floating Bubble System Alert Window
class OverlayService {
  static const String _tag = 'OverlayService';
  static const String _prefPosX = 'overlay_pos_x';
  static const String _prefPosY = 'overlay_pos_y';

  static OverlayPosition? _savedPosition;
  static bool _isTransitioning = false;

  /// Standardized window size in DP (88dp window provides 14dp internal padding for 60dp bubble & contained glow)
  static const int bubbleWindowSize = 88;
  static const int expandedWidth = 360;
  static const int expandedHeight = 640;

  /// Check if the device has granted "Display over other apps" permission
  static Future<bool> isPermissionGranted() async {
    try {
      return await FlutterOverlayWindow.isPermissionGranted();
    } catch (e, stack) {
      LogService.error(_tag, 'isPermissionGranted error', e, stack);
      return false;
    }
  }

  /// Request the system alert window permission from the user
  static Future<bool?> requestPermission() async {
    try {
      return await FlutterOverlayWindow.requestPermission();
    } catch (e, stack) {
      LogService.error(_tag, 'requestPermission error', e, stack);
      return false;
    }
  }

  /// Check if the overlay window is currently active/open
  static Future<bool> isActive() async {
    try {
      return await FlutterOverlayWindow.isActive();
    } catch (e, stack) {
      LogService.error(_tag, 'isActive error', e, stack);
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
        height: bubbleWindowSize,
        width: bubbleWindowSize,
      );

      // Force initial size sync to eliminate DP vs PX disparity on launch
      await Future.delayed(const Duration(milliseconds: 150));
      await FlutterOverlayWindow.resizeOverlay(
        bubbleWindowSize,
        bubbleWindowSize,
        true,
      );
      LogService.info(_tag, 'Floating bubble overlay opened and size synchronized ($bubbleWindowSize dp).');
    } catch (e, stack) {
      LogService.error(_tag, 'showFloatingBubble error', e, stack);
    }
  }

  /// Expand the overlay to full quick-entry modal size and enable keyboard focus.
  /// Always moves to (0, 0) so the modal opens in the EXACT CENTER of the screen
  /// with 100% visibility, regardless of where the bubble was placed.
  static Future<void> expandOverlay() async {
    if (_isTransitioning) return;
    _isTransitioning = true;

    try {
      await FlutterOverlayWindow.updateFlag(OverlayFlag.focusPointer);

      final currentPos = await FlutterOverlayWindow.getOverlayPosition();
      _savedPosition = currentPos;

      // Persist position to preferences
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble(_prefPosX, currentPos.x.toDouble());
        await prefs.setDouble(_prefPosY, currentPos.y.toDouble());
      } catch (e) {
        LogService.warning(_tag, 'Failed to persist overlay position', e);
      }

      // Move to center of screen (0, 0)
      await FlutterOverlayWindow.moveOverlay(const OverlayPosition(0, 0));

      await FlutterOverlayWindow.resizeOverlay(
        expandedWidth,
        expandedHeight,
        false,
      );
    } catch (e, stack) {
      LogService.error(_tag, 'expandOverlay error', e, stack);
    } finally {
      _isTransitioning = false;
    }
  }

  /// Collapse the overlay back to small floating bubble and restore default touch flag
  static Future<void> collapseOverlay() async {
    if (_isTransitioning) return;
    _isTransitioning = true;

    try {
      await FlutterOverlayWindow.updateFlag(OverlayFlag.defaultFlag);

      // Brief delay to allow window manager to switch focus flags before resizing
      await Future.delayed(const Duration(milliseconds: 60));

      if (_savedPosition != null) {
        await FlutterOverlayWindow.moveOverlay(_savedPosition!);
      } else {
        try {
          final prefs = await SharedPreferences.getInstance();
          final x = prefs.getDouble(_prefPosX);
          final y = prefs.getDouble(_prefPosY);
          if (x != null && y != null) {
            await FlutterOverlayWindow.moveOverlay(OverlayPosition(x, y));
          }
        } catch (e) {
          LogService.warning(_tag, 'Failed to restore overlay position from prefs', e);
        }
      }

      await FlutterOverlayWindow.resizeOverlay(
        bubbleWindowSize,
        bubbleWindowSize,
        true,
      );
    } catch (e, stack) {
      LogService.error(_tag, 'collapseOverlay error', e, stack);
    } finally {
      _isTransitioning = false;
    }
  }

  /// Close the overlay completely
  static Future<void> closeOverlay() async {
    try {
      await FlutterOverlayWindow.closeOverlay();
      LogService.info(_tag, 'Overlay closed.');
    } catch (e, stack) {
      LogService.error(_tag, 'closeOverlay error', e, stack);
    }
  }
}
