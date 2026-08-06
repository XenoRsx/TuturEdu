// lib/screens/user_profile_screen.dart
//
// Read-only profile view for another user: avatar, name, role, email, and
// subjects (for Teacher/Student). Reachable from a chat's AppBar (1:1 chats)
// and from UserSearchScreen's info icon. Offers a "Message" button to
// start/open a 1:1 chat directly from the profile, unless it's your own.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

class UserProfileScreen extends StatelessWidget {
  final String uid;

  const UserProfileScreen({super.key, required this.uid});

  Color _roleColor(String role) {
    switch (role) {
      case 'Teacher':
        return Colors.green;
      case 'Parent':
        return Colors.orange;
      case 'Admin':
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }

  String _generateChatId(String uid1, String uid2) {
    final ids = [uid1, uid2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  Future<void> _messageUser(BuildContext context, String name) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final chatId = _generateChatId(currentUser.uid, uid);
    final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);

    await chatRef.set({
      'participants': [currentUser.uid, uid],
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(chatId: chatId, otherUserName: name, otherUserUid: uid),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwnProfile = currentUser?.uid == uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.data!.exists) {
            return const Center(child: Text('User not found.'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final name = data['name'] ?? 'Unnamed';
          final email = data['email'] ?? '';
          final role = data['role'] ?? 'Student';
          final subjects = List<String>.from(data['subjects'] ?? []);
          final color = _roleColor(role);

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: color),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  name,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Chip(
                  label: Text(role, style: const TextStyle(color: Colors.white, fontSize: 12)),
                  backgroundColor: color,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(height: 28),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _infoRow(Icons.email_outlined, 'Email', email.isNotEmpty ? email : '-'),
                      if (role == 'Teacher' || role == 'Student') ...[
                        const Divider(height: 24),
                        _infoRow(
                          Icons.menu_book_outlined,
                          'Subjects',
                          subjects.isNotEmpty ? subjects.join(', ') : 'No subjects assigned yet',
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (!isOwnProfile) ...[
                const SizedBox(height: 24),
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => _messageUser(context, name),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Message'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 14.5)),
            ],
          ),
        ),
      ],
    );
  }
}
