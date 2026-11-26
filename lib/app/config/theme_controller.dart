import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controller managing dynamic Light and Dark [ThemeMode] across the app.
class ThemeController extends ChangeNotifier {
  /// Creates a [ThemeController], optionally backed by [prefs] for persistence.
  ThemeController({
    SharedPreferences? prefs,
    ThemeMode initialMode = ThemeMode.light,
  }) : _prefs = prefs,
       _themeMode = _loadInitialMode(prefs, initialMode);

  static const String _prefsKey = 'dm_theme_mode';

  final SharedPreferences? _prefs;
  ThemeMode _themeMode;

  /// Active application theme mode (`ThemeMode.light` or `ThemeMode.dark`).
  ThemeMode get themeMode => _themeMode;

  /// Convenience flag returning `true` when dark mode is active.
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  static ThemeMode _loadInitialMode(
    SharedPreferences? prefs,
    ThemeMode fallback,
  ) {
    final saved = prefs?.getString(_prefsKey);
    return switch (saved) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      _ => fallback,
    };
  }

  /// Toggles cleanly between [ThemeMode.light] and [ThemeMode.dark].
  void toggleTheme() {
    setThemeMode(isDarkMode ? ThemeMode.light : ThemeMode.dark);
  }

  /// Applies [mode] and persists the user's preference when available.
  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    _prefs?.setString(_prefsKey, mode == ThemeMode.dark ? 'dark' : 'light');
  }
}
