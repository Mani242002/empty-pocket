import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// StateNotifier for ThemeMode with persistent local storage
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  static const String _key = 'theme_mode';

  ThemeModeNotifier() : super(ThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_key);
      if (value == 'dark') {
        state = ThemeMode.dark;
      } else if (value == 'light') {
        state = ThemeMode.light;
      } else {
        state = ThemeMode.system;
      }
    } catch (e) {
      debugPrint('[ThemeModeNotifier] _load error: $e');
    }
  }

  void setThemeMode(ThemeMode mode) {
    state = mode;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_key, mode.name);
    }).catchError((e) {
      debugPrint('[ThemeModeNotifier] setThemeMode persistence error: $e');
    });
  }

  void toggleTheme(bool isDark) {
    setThemeMode(isDark ? ThemeMode.dark : ThemeMode.light);
  }
}

/// Provider for app theme mode
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});
