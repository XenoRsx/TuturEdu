// lib/widgets/icon_tile.dart
//
// Tinted rounded-square icon container for action rows/menu items - an
// icon that represents an ACTION (open Settings, view Reports, ...). Person
// avatars stay circular via CircleAvatar/initials elsewhere (chat list,
// profile) - this is deliberately not a replacement for those.
//
// Claymorphic: a small dual clay shadow (main.dart's clayShadows(), scaled
// down since this tile is small) gives it the same soft "popped out of the
// page" look as AppCard, instead of a flat tinted square.

import 'package:flutter/material.dart';
import '../main.dart' show clayShadows;

class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    required this.color,
    this.size = 44,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.32),
        boxShadow: clayShadows(context, intensity: 0.5),
      ),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}
