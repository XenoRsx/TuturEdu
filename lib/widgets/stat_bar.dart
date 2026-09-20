// lib/widgets/stat_bar.dart
//
// Thin rounded, tinted progress bar for showing a percentage visually
// instead of pure text - class_performance_screen.dart's "Class Health
// Score" and admin_reports_screen.dart's stats were text-only despite
// being percentage-based data.

import 'package:flutter/material.dart';

class LinearStatBar extends StatelessWidget {
  const LinearStatBar({
    super.key,
    required this.value,
    required this.color,
    this.height = 8,
    this.backgroundColor,
  });

  /// 0.0 - 1.0
  final double value;
  final Color color;
  final double height;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: height,
        backgroundColor: backgroundColor ?? color.withValues(alpha: 0.12),
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}
