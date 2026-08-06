// lib/screens/student_dashboard.dart
//
// A Student's home screen is the chat list itself (no button-menu step in
// front of it) - this just configures ChatListScreen with the student's
// brand color and a "Find a Teacher" FAB for starting a new 1:1 chat.

import 'package:flutter/material.dart';
import 'chat_list_screen.dart';
import 'user_search_screen.dart';

class StudentDashboard extends StatelessWidget {
  const StudentDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return ChatListScreen(
      appBarColor: Colors.blue,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
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
        backgroundColor: Colors.blue,
        child: const Icon(Icons.chat),
      ),
    );
  }
}
