// lib/utils/role_colors.dart
//
// Single source of truth for the app's Student/Teacher/Parent/Admin color
// mapping - matches TeacherDashboard/StudentDashboard/ParentDashboard's
// appBarColor (green/blue/orange) and Admin's purple, used wherever a role
// needs a color: avatars (UserAvatar), role chips (manage_users_screen.dart),
// and the group-chat sender-name label (chat_screen.dart).

import 'package:flutter/material.dart';

Color roleColor(String? role) {
  switch (role) {
    case 'Teacher':
      return Colors.green;
    case 'Parent':
      return Colors.orange;
    case 'Admin':
      return Colors.purple;
    default:
      return Colors.blue; // Student, and fallback for an unknown/missing role
  }
}
