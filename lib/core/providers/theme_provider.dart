import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';
  SharedPreferences? _prefs;

  @override
  ThemeMode build() {
    _loadTheme(); 
    // Default to Light Mode if no preference usually, or wait for load
    return ThemeMode.light;
  }

  Future<void> _loadTheme() async {
    _prefs = await SharedPreferences.getInstance();
    final themeString = _prefs?.getString(_key);
    if (themeString == 'light') {
      state = ThemeMode.light;
    } else if (themeString == 'dark') {
      state = ThemeMode.dark;
    } else {
      state = ThemeMode.light;
    }
  }

  Future<void> setTheme(ThemeMode mode) async {
    // 1. Optimistic Update (Instant UI feedback)
    state = mode;
    
    // 2. Persist in background (don't block)
    _prefs ??= await SharedPreferences.getInstance();
    
    if (mode == ThemeMode.light) {
      await _prefs?.setString(_key, 'light');
    } else if (mode == ThemeMode.dark) {
      await _prefs?.setString(_key, 'dark');
    } else {
      await _prefs?.remove(_key);
    }
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(ThemeNotifier.new);
