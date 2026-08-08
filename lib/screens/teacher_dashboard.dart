// lib/screens/teacher_dashboard.dart
//
// A Teacher's home screen is the chat list itself (no button-menu step in
// front of it) - this just configures ChatListScreen with the teacher's
// brand color and a FAB that offers "New Chat" (search students) or
// "New Group" (create a group chat).
//
// AppBar also gets an On-Duty/Off-Duty toggle (users/{uid}.dutyStatus, see
// BLUEPRINT.md 5.10) - a manual override on top of the automatic office-hour
// schedule. Going Off-Duty locks this teacher's chats immediately (same
// locked-banner/Overtime-Mode UI as being outside office hours, see
// chat_screen.dart's _computeIsOfficeHour), even during scheduled hours -
// e.g. a sudden meeting or sick leave without waiting for the clock.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_list_screen.dart';
import 'class_performance_screen.dart';
import 'create_group_chat_screen.dart';
import 'quiz_list_screen.dart';
import 'settings_screen.dart';
import 'take_attendance_screen.dart';
import 'user_search_screen.dart';

class TeacherDashboard extends StatelessWidget {
  const TeacherDashboard({super.key});

  Future<void> _toggleDutyStatus(
    BuildContext context,
    String uid,
    bool currentlyOffDuty,
  ) async {
    final newStatus = currentlyOffDuty ? 'on_duty' : 'off_duty';
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'dutyStatus': newStatus,
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus == 'off_duty'
                ? "You're now Off-Duty. Your chats are locked until you go back on-duty."
                : "You're now On-Duty. Your chats follow the normal office-hour schedule again.",
          ),
        ),
      );
    }
  }

  // Leave dates (set from Settings, see BLUEPRINT.md 5.14) and the manual
  // dutyStatus toggle are independent fields - a teacher can be "on_duty"
  // yet still within a leave period, in which case chats are locked either
  // way (chat_screen.dart's _isTeacherOnLeave takes precedence). Show the
  // leave state distinctly here so the icon doesn't look wrong when that
  // happens - tapping still only toggles dutyStatus; leave dates are
  // managed from Settings.
  bool _isOnLeave(Map<String, dynamic>? data) {
    final start = (data?['leaveStart'] as Timestamp?)?.toDate();
    final end = (data?['leaveEnd'] as Timestamp?)?.toDate();
    if (start == null || end == null) return false;
    final now = DateTime.now();
    return !now.isBefore(start) && !now.isAfter(end);
  }

  Widget _buildDutyToggle(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final offDuty = data?['dutyStatus'] == 'off_duty';
        final onLeave = _isOnLeave(data);

        return IconButton(
          tooltip: onLeave
              ? 'You are on leave (set in Settings) — chats are locked'
              : offDuty
              ? 'You are Off-Duty — tap to go On-Duty'
              : 'You are On-Duty — tap to go Off-Duty',
          icon: Icon(
            onLeave
                ? Icons.beach_access_outlined
                : (offDuty ? Icons.work_off_outlined : Icons.work_outline),
            color: (onLeave || offDuty) ? Colors.red.shade100 : Colors.white,
          ),
          onPressed: () => _toggleDutyStatus(context, currentUser.uid, offDuty),
        );
      },
    );
  }

  void _openNewChatMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0x1A1B8E5A),
                child: Icon(Icons.person_add_alt, color: Colors.green),
              ),
              title: const Text('New Chat'),
              subtitle: const Text('Search a student and start a 1:1 chat'),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const UserSearchScreen(
                      targetRole: 'Student',
                      title: 'Find a Student',
                      accentColor: Colors.green,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0x1A1B8E5A),
                child: Icon(Icons.group_add, color: Colors.green),
              ),
              title: const Text('New Group'),
              subtitle: const Text('Create a group chat for a subject/class'),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CreateGroupChatScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChatListScreen(
      appBarColor: Colors.green,
      extraActions: [
        _buildDutyToggle(context),
        IconButton(
          tooltip: 'Settings',
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
        ),
      ],
      tabBarTrailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Take Attendance',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TakeAttendanceScreen()),
              );
            },
            icon: const Icon(Icons.fact_check_outlined, color: Colors.white),
          ),
          IconButton(
            tooltip: 'Class Performance',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ClassPerformanceScreen(),
                ),
              );
            },
            icon: const Icon(Icons.insights_outlined, color: Colors.white),
          ),
          IconButton(
            tooltip: 'Quizzes',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const QuizListScreen()),
              );
            },
            icon: const Icon(Icons.quiz_outlined, color: Colors.white),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openNewChatMenu(context),
        backgroundColor: Colors.green,
        child: const Icon(Icons.add),
      ),
    );
  }
}
