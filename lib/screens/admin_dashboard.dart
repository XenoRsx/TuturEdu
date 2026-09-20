// lib/screens/admin_dashboard.dart
//
// Admin dashboard - the main hub for admins. Current scope: Manage Users
// and Manage Subjects (see BLUEPRINT.md for the full proposed scope).

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/push_notifications.dart';
import '../widgets/menu_row.dart';
import '../widgets/section_label.dart';
import '../widgets/stat_tile.dart';
import 'admin_reports_screen.dart';
import 'login_screen.dart';
import 'manage_users_screen.dart';
import 'manage_subjects_screen.dart';
import 'settings_screen.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  Future<Map<String, int>> _fetchStats() async {
    final usersSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .get();

    int studentCount = 0;
    int teacherCount = 0;
    int parentCount = 0;

    for (final doc in usersSnapshot.docs) {
      final role = doc.data()['role'];
      if (role == 'Student') studentCount++;
      if (role == 'Teacher') teacherCount++;
      if (role == 'Parent') parentCount++;
    }

    return {
      'students': studentCount,
      'teachers': teacherCount,
      'parents': parentCount,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await unregisterPushToken();
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionLabel('Overview'),
          FutureBuilder<Map<String, int>>(
            future: _fetchStats(),
            builder: (context, snapshot) {
              final stats =
                  snapshot.data ?? {'students': 0, 'teachers': 0, 'parents': 0};
              return Row(
                children: [
                  StatTile(
                    value: '${stats['students']}',
                    label: 'Students',
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 10),
                  StatTile(
                    value: '${stats['teachers']}',
                    label: 'Teachers',
                    color: Colors.green,
                  ),
                  const SizedBox(width: 10),
                  StatTile(
                    value: '${stats['parents']}',
                    label: 'Parents',
                    color: Colors.orange,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          const SectionLabel('Manage'),

          MenuRow(
            icon: Icons.people_alt,
            title: 'Manage Users',
            subtitle: 'View accounts, change roles, remove users',
            color: Colors.blue,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ManageUsersScreen()),
            ),
          ),
          const SizedBox(height: 12),

          MenuRow(
            icon: Icons.menu_book,
            title: 'Manage Subjects',
            subtitle: 'Add or remove subject & level combinations',
            color: Colors.green,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ManageSubjectsScreen()),
            ),
          ),
          const SizedBox(height: 12),

          MenuRow(
            icon: Icons.bar_chart,
            title: 'Reports',
            subtitle: 'Users, chats, quizzes, and attendance stats',
            color: Colors.deepPurple,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminReportsScreen()),
            ),
          ),
          const SizedBox(height: 12),

          MenuRow(
            icon: Icons.settings_outlined,
            title: 'Settings',
            subtitle: 'Profile, password, notifications, delete account',
            color: Colors.blueGrey,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
    );
  }
}
