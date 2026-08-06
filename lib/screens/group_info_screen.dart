// lib/screens/group_info_screen.dart
//
// Group details: name, subject, and member list. The groupAdmin (the
// teacher who created it) can remove members and add new ones; any other
// member can leave. Membership changes write straight to
// chats/{chatId}.participants - firestore.rules restricts who's allowed to
// touch that field to the groupAdmin, or a member removing themselves.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_group_members_screen.dart';
import 'user_profile_screen.dart';

class GroupInfoScreen extends StatelessWidget {
  final String chatId;

  const GroupInfoScreen({super.key, required this.chatId});

  Future<void> _removeMember(BuildContext context, String uid, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text('Remove "$name" from this group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
      'participants': FieldValue.arrayRemove([uid]),
    });
  }

  Future<void> _leaveGroup(BuildContext context, String currentUid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Group'),
        content: const Text('You will no longer receive messages from this group.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
      'participants': FieldValue.arrayRemove([currentUid]),
    });

    if (context.mounted) {
      Navigator.popUntil(context, (route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Info'),
        backgroundColor: Colors.green,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('chats').doc(chatId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final groupName = data['groupName'] ?? 'Group Chat';
          final subject = data['subject'] as String?;
          final groupAdmin = data['groupAdmin'] as String?;
          final participants = List<String>.from(data['participants'] ?? []);
          final isAdmin = currentUid != null && currentUid == groupAdmin;

          return ListView(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 28),
                color: Colors.green.shade50,
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.green.shade100,
                      child: const Icon(Icons.groups, size: 40, color: Colors.green),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      groupName,
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                    ),
                    if (subject != null) ...[
                      const SizedBox(height: 4),
                      Text(subject, style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${participants.length} member(s)',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (isAdmin)
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddGroupMembersScreen(
                                chatId: chatId,
                                subject: subject,
                                existingParticipants: participants,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.person_add_alt, size: 18),
                        label: const Text('Add'),
                      ),
                  ],
                ),
              ),
              ...participants.map((uid) {
                final isThisAdmin = uid == groupAdmin;
                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
                  builder: (context, userSnapshot) {
                    final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
                    final name = userData?['name'] ?? 'Loading...';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green.shade100,
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(color: Colors.green),
                          ),
                        ),
                        title: Text(name),
                        subtitle: isThisAdmin ? const Text('Group Admin') : null,
                        trailing: isAdmin && !isThisAdmin
                            ? IconButton(
                                icon: const Icon(Icons.person_remove_alt_1, color: Colors.red),
                                tooltip: 'Remove member',
                                onPressed: () => _removeMember(context, uid, name),
                              )
                            : null,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => UserProfileScreen(uid: uid)),
                          );
                        },
                      ),
                    );
                  },
                );
              }),
              if (!isAdmin && currentUid != null) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton.icon(
                      onPressed: () => _leaveGroup(context, currentUid),
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('Leave Group'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}
