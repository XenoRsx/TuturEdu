// lib/screens/admin_dashboard.dart
//
// Admin dashboard - the main hub for admins. Current scope: Manage Users
// and Manage Subjects (see BLUEPRINT.md for the full proposed scope).

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/push_notifications.dart';
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
          FutureBuilder<Map<String, int>>(
            future: _fetchStats(),
            builder: (context, snapshot) {
              final stats =
                  snapshot.data ?? {'students': 0, 'teachers': 0, 'parents': 0};
              return Row(
                children: [
                  _statCard('Students', stats['students']!, Colors.blue),
                  const SizedBox(width: 10),
                  _statCard('Teachers', stats['teachers']!, Colors.green),
                  const SizedBox(width: 10),
                  _statCard('Parents', stats['parents']!, Colors.orange),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          _menuCard(
            context,
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

          _menuCard(
            context,
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

          _menuCard(
            context,
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

          _menuCard(
            context,
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

  Widget _statCard(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 1,
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12.5)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
