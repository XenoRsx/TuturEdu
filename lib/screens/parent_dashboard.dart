// lib/screens/parent_dashboard.dart
//
// A Parent's home screen is the chat list itself, same pattern as
// TeacherDashboard/StudentDashboard (see BLUEPRINT.md 5.9) - this configures
// ChatListScreen with the parent's brand color and a FAB that offers
// "Message a Teacher" (search + start a 1:1 chat, same as a Student finding
// a Teacher). The nav bar adds two parent-specific views: "My Child"
// (linked student's attendance/performance) and "Warning Letters".

import 'package:flutter/material.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/stat_tile.dart';
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

  Widget _buildHeader(
    BuildContext context, {
    required int totalUnread,
    required int totalChats,
    required int totalGroups,
  }) {
    return DashboardHeader(
      stats: [
        StatTile(value: '$totalUnread', label: 'Unread', color: Colors.orange),
        StatTile(
          value: '$totalChats',
          label: 'Total Chats',
          color: Colors.blue,
        ),
      ],
      actions: [
        QuickAction(
          icon: Icons.family_restroom,
          label: 'My Child',
          color: Colors.orange,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ChildOverviewScreen()),
          ),
        ),
        QuickAction(
          icon: Icons.warning_amber_rounded,
          label: 'Warning Letters',
          color: Colors.red,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ParentWarningLettersScreen(),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChatListScreen(
      appBarColor: Colors.orange,
      homeHeader: _buildHeader,
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openMenu(context),
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add),
      ),
    );
  }
}
