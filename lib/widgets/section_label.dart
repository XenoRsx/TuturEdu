// lib/widgets/section_label.dart
//
// Small bold muted caption used to group content into labelled sections -
// generalizes settings_screen.dart's original private _sectionLabel.

import 'package:flutter/material.dart';

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: Theme.of(context).textTheme.bodySmall?.color,
        ),
      ),
    );
  }
}
