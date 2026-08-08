// lib/screens/parent_dashboard.dart
//
// A Parent's home screen is the chat list itself, same pattern as
// TeacherDashboard/StudentDashboard (see BLUEPRINT.md 5.9) - this configures
// ChatListScreen with the parent's brand color and a FAB that offers
// "Message a Teacher" (search + start a 1:1 chat, same as a Student finding
// a Teacher). The nav bar adds two parent-specific views: "My Child"
// (linked student's attendance/performance) and "Warning Letters".

import 'package:flutter/material.dart';
import 'chat_list_screen.dart';
import 'child_overview_screen.dart';
import 'parent_warning_letters_screen.dart';
import 'settings_screen.dart';
import 'user_search_screen.dart';

class ParentDashboard extends StatelessWidget {
  const ParentDashboard({super.key});

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
                backgroundColor: Color(0x1AFF9800),
                child: Icon(Icons.chat, color: Colors.orange),
              ),
              title: const Text('Message a Teacher'),
              subtitle: const Text(
                "Search your child's teacher and start a 1:1 chat",
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const UserSearchScreen(
                      targetRole: 'Teacher',
                      title: 'Find a Teacher',
                      accentColor: Colors.orange,
                    ),
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
      appBarColor: Colors.orange,
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
            tooltip: 'Warning Letters',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ParentWarningLettersScreen(),
                ),
              );
            },
            icon: const Icon(Icons.warning_amber_rounded, color: Colors.white),
          ),
          IconButton(
            tooltip: 'My Child',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChildOverviewScreen()),
              );
            },
            icon: const Icon(Icons.family_restroom, color: Colors.white),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openMenu(context),
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add),
      ),
    );
  }
}
