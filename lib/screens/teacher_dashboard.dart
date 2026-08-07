// lib/screens/teacher_dashboard.dart
//
// A Teacher's home screen is the chat list itself (no button-menu step in
// front of it) - this just configures ChatListScreen with the teacher's
// brand color and a FAB that offers "New Chat" (search students) or
// "New Group" (create a group chat).

import 'package:flutter/material.dart';
import 'chat_list_screen.dart';
import 'create_group_chat_screen.dart';
import 'quiz_list_screen.dart';
import 'user_search_screen.dart';

class TeacherDashboard extends StatelessWidget {
  const TeacherDashboard({super.key});

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
                  MaterialPageRoute(builder: (_) => const CreateGroupChatScreen()),
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
      tabBarTrailing: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: TextButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const QuizListScreen()),
            );
          },
          icon: const Icon(Icons.quiz_outlined, color: Colors.white, size: 18),
          label: const Text(
            'Quizzes',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openNewChatMenu(context),
        backgroundColor: Colors.green,
        child: const Icon(Icons.add),
      ),
    );
  }
}
