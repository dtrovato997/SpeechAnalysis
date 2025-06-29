// lib/providers/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_speech_recognition/ui/core/themes/theme.dart';

enum AppTheme {
  light,
  lightMediumContrast,
  lightHighContrast,
  dark,
  darkMediumContrast,
  darkHighContrast,
}

class ThemeProvider extends ChangeNotifier {
  AppTheme _currentTheme = AppTheme.light;
  final MaterialTheme _materialTheme;

  ThemeProvider(TextTheme textTheme) : _materialTheme = MaterialTheme(textTheme) {
    _loadTheme();
  }

  AppTheme get currentTheme => _currentTheme;

  ThemeData get themeData {
    switch (_currentTheme) {
      case AppTheme.light:
        return _materialTheme.light();
      case AppTheme.lightMediumContrast:
        return _materialTheme.lightMediumContrast();
      case AppTheme.lightHighContrast:
        return _materialTheme.lightHighContrast();
      case AppTheme.dark:
        return _materialTheme.dark();
      case AppTheme.darkMediumContrast:
        return _materialTheme.darkMediumContrast();
      case AppTheme.darkHighContrast:
        return _materialTheme.darkHighContrast();
    }
  }

  String get themeDisplayName {
    switch (_currentTheme) {
      case AppTheme.light:
        return 'Light';
      case AppTheme.lightMediumContrast:
        return 'Light Medium Contrast';
      case AppTheme.lightHighContrast:
        return 'Light High Contrast';
      case AppTheme.dark:
        return 'Dark';
      case AppTheme.darkMediumContrast:
        return 'Dark Medium Contrast';
      case AppTheme.darkHighContrast:
        return 'Dark High Contrast';
    }
  }

  static String getThemeDisplayName(AppTheme theme) {
    switch (theme) {
      case AppTheme.light:
        return 'Light';
      case AppTheme.lightMediumContrast:
        return 'Light Medium Contrast';
      case AppTheme.lightHighContrast:
        return 'Light High Contrast';
      case AppTheme.dark:
        return 'Dark';
      case AppTheme.darkMediumContrast:
        return 'Dark Medium Contrast';
      case AppTheme.darkHighContrast:
        return 'Dark High Contrast';
    }
  }

  Future<void> setTheme(AppTheme theme) async {
    _currentTheme = theme;
    notifyListeners();
    await _saveTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeIndex = prefs.getInt('app_theme') ?? 0;
      if (themeIndex >= 0 && themeIndex < AppTheme.values.length) {
        _currentTheme = AppTheme.values[themeIndex];
        notifyListeners();
      }
    } catch (e) {
      // If loading fails, keep default theme
    }
  }

  Future<void> _saveTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('app_theme', _currentTheme.index);
    } catch (e) {
      // Handle save error silently
    }
  }
}