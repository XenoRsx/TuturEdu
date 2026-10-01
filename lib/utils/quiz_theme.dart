// lib/utils/quiz_theme.dart
//
// Shared visual language for the Interactive Quiz module - a vibrant,
// game-show style palette (4 answer colors + shapes, matching the
// Kahoot/Wayground convention students already recognize) so option
// styling stays consistent across the host and student screens.
//
// QuizCard/QuizBadge (below) are the module's shared card/pill widgets -
// deliberately built with ONLY fixed literal colors (never
// Theme.of(context)), so they're safe to drop into ANY quiz screen without
// re-opening the dark-mode trap documented on the class-level CLAUDE.md
// entry for this module: several quiz screens are permanently light
// regardless of the app's Light/Dark/System setting, and a theme-following
// widget dropped in without checking has broken that before.

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

  static const double cardRadius = 16;

  static List<BoxShadow> cardShadow({
    double opacity = 0.08,
    double blur = 10,
    double dy = 4,
  }) => [
    BoxShadow(
      color: primary.withValues(alpha: opacity),
      blurRadius: blur,
      offset: Offset(0, dy),
    ),
  ];
}

// Shared white rounded card with QuizTheme's soft purple-tinted shadow -
// replaces the Container(decoration: BoxDecoration(color: Colors.white,
// borderRadius: ..., boxShadow: [...])) block that used to be hand-copied
// across several quiz list/detail screens. `accentColor`, when given, draws
// a thin color stripe down the left edge (per-item variety in a list of
// otherwise-identical white cards). `onTap` wraps the card in an InkWell
// instead of a plain Container when given.
class QuizCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? accentColor;
  final VoidCallback? onTap;

  const QuizCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.accentColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(QuizTheme.cardRadius);
    final card = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: radius,
        boxShadow: QuizTheme.cardShadow(),
        border: accentColor != null
            ? Border(left: BorderSide(color: accentColor!, width: 4))
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                child: Padding(padding: padding, child: child),
              ),
            ),
    );
    return card;
  }
}

// Small tinted pill (icon + label) for compact metadata that has no other
// visual home in a list row - quiz mode, question count, due date, attempts
// used. Fixed literal colors only, same reasoning as QuizCard above.
class QuizBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const QuizBadge({
    super.key,
    required this.icon,
    required this.label,
    this.color = QuizTheme.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
