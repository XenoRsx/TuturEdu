// lib/screens/student_dashboard.dart
//
// A Student's home screen is the chat list itself (no button-menu step in
// front of it) - this just configures ChatListScreen with the student's
// brand color and a FAB that offers "Find a Teacher" (search + start a 1:1
// chat) or "Join a Quiz" (enter a Live Session join code).

import 'package:flutter/material.dart';
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
              title: const Text('Find a Teacher'),
              subtitle: const Text('Search a teacher and start a 1:1 chat'),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const UserSearchScreen(
                      targetRole: 'Teacher',
                      title: 'Find a Teacher',
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
              title: const Text('Join a Quiz'),
              subtitle: const Text('Enter a 6-digit code from your teacher'),
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
              title: const Text('My Attendance'),
              subtitle: const Text('View your attendance rate and history'),
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
              title: const Text('Self-Paced Quizzes'),
              subtitle: const Text('Attempt a quiz on your own time'),
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

  @override
  Widget build(BuildContext context) {
    return ChatListScreen(
      appBarColor: Colors.blue,
      extraActions: [
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
            tooltip: 'Self-Paced Quizzes',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SelfPacedQuizListScreen(),
                ),
              );
            },
            icon: const Icon(Icons.assignment_outlined, color: Colors.white),
          ),
          IconButton(
            tooltip: 'My Attendance',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AttendanceOverviewScreen(),
                ),
              );
            },
            icon: const Icon(Icons.fact_check_outlined, color: Colors.white),
          ),
          IconButton(
            tooltip: 'Join a Quiz',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const JoinQuizScreen()),
              );
            },
            icon: const Icon(Icons.quiz_outlined, color: Colors.white),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openMenu(context),
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add),
      ),
    );
  }
}
