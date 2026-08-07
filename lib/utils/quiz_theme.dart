// lib/utils/quiz_theme.dart
//
// Shared visual language for the Interactive Quiz module - a vibrant,
// game-show style palette (4 answer colors + shapes, matching the
// Kahoot/Wayground convention students already recognize) so option
// styling stays consistent across the host and student screens.

import 'package:flutter/material.dart';

class QuizTheme {
  static const List<Color> optionColors = [
    Color(0xFFE21B3C), // red
    Color(0xFF1368CE), // blue
    Color(0xFFD89E00), // gold
    Color(0xFF26890C), // green
  ];

  static const List<IconData> optionIcons = [
    Icons.change_history_rounded, // triangle
    Icons.diamond_rounded,
    Icons.circle,
    Icons.square_rounded,
  ];

  static const Color primary = Color(0xFF7C3AED);
  static const Color primaryDark = Color(0xFF4C1D95);

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );

  static const LinearGradient pageGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF3EBFF), Color(0xFFEAF3FB)],
  );

  static Color medalColor(int rank) {
    switch (rank) {
      case 0:
        return const Color(0xFFFFD700); // gold
      case 1:
        return const Color(0xFFC0C0C0); // silver
      case 2:
        return const Color(0xFFCD7F32); // bronze
      default:
        return Colors.deepPurple.shade50;
    }
  }

  static Color medalForeground(int rank) {
    return rank < 3 ? Colors.white : Colors.deepPurple;
  }
}
