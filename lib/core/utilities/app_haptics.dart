import 'package:flutter/services.dart';

/// Universal Haptics Engine for EmptyPocket
/// Provides responsive, tactile feedback for user actions
class AppHaptics {
  /// Light click for standard button taps, chips, and selections
  static void buttonPress() {
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
  }

  /// Subtle click for navigation tab or segmented control changes
  static void selectionClick() {
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}
  }

  /// Medium pulse on successful transaction save or goal contribution
  static void success() {
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Warning or error pulse for validation alerts
  static void warning() {
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// Distinct vibration for destructive operations (delete transaction/account)
  static void deleteAction() {
    try {
      HapticFeedback.vibrate();
    } catch (_) {}
  }
}
