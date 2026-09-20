// lib/widgets/stat_tile.dart
//
// Tinted number+label tile for dashboard stat rows - generalizes
// admin_dashboard.dart's old private _statCard so every dashboard can share
// the same "at a glance" stat row instead of just AppBar icons. Claymorphic
// dual shadow (main.dart's clayShadows()) instead of a flat tint box.

import 'package:flutter/material.dart';
import '../main.dart' show clayShadows;

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
          boxShadow: clayShadows(context, intensity: 0.7),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
