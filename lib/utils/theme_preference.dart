// lib/utils/theme_preference.dart
//
// Maps users/{uid}.themeMode ("light" | "dark" | "system", default "system"
// when unset) to/from Flutter's ThemeMode - kept in one place since both
// main.dart (applying it) and settings_screen.dart (writing it) need the
// same mapping.

import 'package:flutter/material.dart';

ThemeMode themeModeFromString(String? value) {
  switch (value) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
}

String themeModeToString(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return 'light';
    case ThemeMode.dark:
      return 'dark';
    case ThemeMode.system:
      return 'system';
  }
}
