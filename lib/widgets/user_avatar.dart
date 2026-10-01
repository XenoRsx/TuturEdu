// lib/widgets/user_avatar.dart
//
// Shared avatar for any user across the app: a tinted initial circle,
// colored by their role (roleColor(), lib/utils/role_colors.dart - Teacher=
// green, Student=blue, Parent=orange, Admin=purple) instead of a
// screen-by-screen fixed color. Replaces the hand-rolled CircleAvatar+Text
// pattern that used to be duplicated across chat_list_screen.dart,
// user_profile_screen.dart, user_search_screen.dart, group_info_screen.dart,
// manage_users_screen.dart, and settings_screen.dart.
//
// Deliberately uses NO Theme.of(context) - every color here is either an
// explicit param or comes from roleColor(), so this is safe to use in any
// screen regardless of Light/Dark/System mode, including the Quiz module's
// permanently-light screens if ever needed there.
//
// Photo upload was tried and pulled back out (2026-09) - Flutter Web's
// image renderer fetches Storage-hosted photos via a background HTTP
// request that's CORS-checked, and the project's Storage bucket has no CORS
// policy configured. Fixing that needs a one-time `gsutil cors set` from an
// authenticated Google Cloud SDK terminal, which was judged not worth the
// setup hassle for this feature - deemed out of scope, not a bug to chase.

import 'package:flutter/material.dart';
import '../utils/role_colors.dart';

class UserAvatar extends StatelessWidget {
  final String name;
  final String? role;
  final double radius;

  const UserAvatar({
    super.key,
    required this.name,
    required this.role,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final color = roleColor(role);
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.15),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.7,
        ),
      ),
    );
  }
}
