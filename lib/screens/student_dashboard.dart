// lib/screens/student_dashboard.dart
//
// A Student's home screen is the chat list itself (no button-menu step in
// front of it) - this just configures ChatListScreen with the student's
// brand color and a FAB that offers "Find a Teacher" (search + start a 1:1
// chat) or "Join a Quiz" (enter a Live Session join code).

import 'package:flutter/material.dart';
import '../l10n/app_strings.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/stat_tile.dart';
import 'attendance_overview_screen.dart';
import 'chat_list_screen.dart';
import 'join_quiz_screen.dart';
import 'self_paced_quiz_list_screen.dart';
import 'settings_screen.dart';
import 'user_search_screen.dart';

class StudentDashboard extends StatelessWidget {
  const StudentDashboard({super.key});

  void _openMenu(BuildContext context) {
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
                backgroundColor: Color(0x1A2E86C1),
                child: Icon(Icons.chat, color: Colors.blue),
              ),
              title: Text(context.tr('Find a Teacher')),
              subtitle: Text(
                context.tr('Search a teacher and start a 1:1 chat'),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserSearchScreen(
                      targetRole: 'Teacher',
                      title: context.tr('Find a Teacher'),
                      accentColor: Colors.blue,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0x1A2E86C1),
                child: Icon(Icons.quiz, color: Colors.blue),
              ),
              title: Text(context.tr('Join a Quiz')),
              subtitle: Text(
                context.tr('Enter a 6-digit code from your teacher'),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const JoinQuizScreen()),
                );
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0x1A2E86C1),
                child: Icon(Icons.fact_check_outlined, color: Colors.blue),
              ),
              title: Text(context.tr('My Attendance')),
              subtitle: Text(
                context.tr('View your attendance rate and history'),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AttendanceOverviewScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0x1A2E86C1),
                child: Icon(Icons.assignment_outlined, color: Colors.blue),
              ),
              title: Text(context.tr('Self-Paced Quizzes')),
              subtitle: Text(context.tr('Attempt a quiz on your own time')),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SelfPacedQuizListScreen(),
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

  Widget _buildHeader(
    BuildContext context, {
    required int totalUnread,
    required int totalChats,
    required int totalGroups,
  }) {
    return DashboardHeader(
      stats: [
        StatTile(
          value: '$totalUnread',
          label: context.tr('Unread'),
          color: Colors.blue,
        ),
        StatTile(
          value: '$totalChats',
          label: context.tr('Total Chats'),
          color: Colors.green,
        ),
        StatTile(
          value: '$totalGroups',
          label: context.tr('Groups'),
          color: Colors.deepPurple,
        ),
      ],
      actions: [
        QuickAction(
          icon: Icons.assignment_outlined,
          label: context.tr('Self-Paced Quizzes'),
          color: Colors.blue,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SelfPacedQuizListScreen()),
          ),
        ),
        QuickAction(
          icon: Icons.fact_check_outlined,
          label: context.tr('My Attendance'),
          color: Colors.green,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AttendanceOverviewScreen()),
          ),
        ),
        QuickAction(
          icon: Icons.quiz_outlined,
          label: context.tr('Join a Quiz'),
          color: Colors.deepPurple,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const JoinQuizScreen()),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChatListScreen(
      appBarColor: Colors.blue,
      homeHeader: _buildHeader,
      extraActions: [
        IconButton(
          tooltip: context.tr('Settings'),
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
        ),
      ],
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openMenu(context),
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add),
      ),
    );
  }
}
