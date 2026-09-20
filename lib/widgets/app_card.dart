// lib/widgets/app_card.dart
//
// Shared claymorphic surface used across dashboard/list screens instead of
// each screen hand-rolling its own Card or shadowed Container (see
// quiz_list_screen.dart's original hand-built version and
// admin_dashboard.dart's old private _menuCard for the two patterns this
// generalizes).
//
// Claymorphism: a soft, puffy 3D look built from a dual-direction shadow
// (a dark "sunken" shadow + a light "highlight", via main.dart's
// clayShadows()) rather than a single flat Material shadow or a
// contrasting fill - `color` defaults to the theme's card color, which is
// deliberately close to the scaffold background (see main.dart's
// kClaySurfaceLight/Dark) so the shadow pair does the work of reading as
// "raised", not a color contrast. A caller passing an explicit tint (e.g.
// `Colors.green.withValues(alpha: 0.06)` for a success panel) still gets
// that color, with the same clay shadow around it.

import 'package:flutter/material.dart';
import '../main.dart' show clayShadows;

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.shadow = true,
    this.borderRadius = 24,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final bool shadow;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    final decoration = BoxDecoration(
      color: color ?? Theme.of(context).cardColor,
      borderRadius: radius,
      boxShadow: shadow ? clayShadows(context) : null,
    );

    if (onTap == null) {
      return Container(padding: padding, decoration: decoration, child: child);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          padding: padding,
          decoration: decoration,
          child: child,
        ),
      ),
    );
  }
}
