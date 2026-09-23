// lib/screens/user_profile_screen.dart
//
// Read-only profile view for another user: avatar, name, role, email, and
// subjects (for Teacher/Student). Reachable from a chat's AppBar (1:1 chats)
// and from UserSearchScreen's info icon. Offers a "Message" button to
// start/open a 1:1 chat directly from the profile, unless it's your own.
//
// A Teacher viewing a Student's profile also gets an "Edit" action on the
// Subjects row - assigning subjects to a student was Admin-only before;
// firestore.rules' users/{userId} write rule now additionally allows a
// Teacher to update ONLY the `subjects` field of a Student doc (nothing
// else), so this doesn't need a Cloud Function.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

class _ProfileData {
  final Map<String, dynamic> target;
  final String? viewerRole;

  const _ProfileData(this.target, this.viewerRole);
}

class UserProfileScreen extends StatelessWidget {
  final String uid;

  const UserProfileScreen({super.key, required this.uid});

  Future<_ProfileData?> _load(String? currentUid) async {
    final targetDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (!targetDoc.exists) return null;

    String? viewerRole;
    if (currentUid != null && currentUid != uid) {
      final viewerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .get();
      viewerRole = viewerDoc.data()?['role'] as String?;
    }

    return _ProfileData(targetDoc.data() as Map<String, dynamic>, viewerRole);
  }

  Future<void> _editSubjects(
    BuildContext context,
    List<String> currentSubjects,
  ) async {
    final catalogSnapshot = await FirebaseFirestore.instance
        .collection('subjectCatalog')
        .orderBy('name')
        .get();
    final allSubjects = catalogSnapshot.docs
        .map((doc) => (doc.data())['name'] as String? ?? '')
        .where((name) => name.isNotEmpty)
        .toList();

    if (!context.mounted) return;

    if (allSubjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Subject catalog is empty. Ask an Admin to add subjects first.',
          ),
        ),
      );
      return;
    }

    final selected = Set<String>.from(currentSubjects);

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Edit Subjects'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: allSubjects.map((subject) {
                final checked = selected.contains(subject);
                return CheckboxListTile(
                  value: checked,
                  title: Text(subject),
                  onChanged: (value) {
                    setDialogState(() {
                      if (value == true) {
                        selected.add(subject);
                      } else {
                        selected.remove(subject);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .update({'subjects': selected.toList()});
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

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
        builder: (_) =>
            ChatScreen(chatId: chatId, otherUserName: name, otherUserUid: uid),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwnProfile = currentUser?.uid == uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: FutureBuilder<_ProfileData?>(
        future: _load(currentUser?.uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final result = snapshot.data;
          if (result == null) {
            return const Center(child: Text('User not found.'));
          }

          final data = result.target;
          final name = data['name'] ?? 'Unnamed';
          final email = data['email'] ?? '';
          final role = data['role'] ?? 'Student';
          final subjects = List<String>.from(data['subjects'] ?? []);
          final color = _roleColor(role);
          final canEditSubjects =
              result.viewerRole == 'Teacher' && role == 'Student';

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Chip(
                  label: Text(
                    role,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
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
                      _infoRow(
                        context,
                        Icons.email_outlined,
                        'Email',
                        email.isNotEmpty ? email : '-',
                      ),
                      if (role == 'Teacher' || role == 'Student') ...[
                        const Divider(height: 24),
                        _infoRow(
                          context,
                          Icons.menu_book_outlined,
                          'Subjects',
                          subjects.isNotEmpty
                              ? subjects.join(', ')
                              : 'No subjects assigned yet',
                          trailing: canEditSubjects
                              ? TextButton(
                                  onPressed: () =>
                                      _editSubjects(context, subjects),
                                  child: const Text('Edit'),
                                )
                              : null,
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

  Widget _infoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    Widget? trailing,
  }) {
    final muted = Theme.of(context).textTheme.bodySmall?.color;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: muted),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11.5, color: muted)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 14.5)),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}
