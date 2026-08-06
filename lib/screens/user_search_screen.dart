// lib/screens/user_search_screen.dart
//
// Generic "start a new chat" screen: search users of a given role
// (Student searches Teachers, Teacher searches Students) and either start a
// 1:1 chat with one of them or open their profile first. Tapping a row
// starts/reuses the chat; the info icon opens UserProfileScreen instead.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';
import 'user_profile_screen.dart';

class UserSearchScreen extends StatefulWidget {
  final String targetRole;
  final String title;
  final Color accentColor;

  const UserSearchScreen({
    super.key,
    required this.targetRole,
    required this.title,
    this.accentColor = Colors.blue,
  });

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  String _searchQuery = '';

  // Chat ID is built from the UIDs sorted alphabetically, so the same pair
  // always get the same chat ID (avoids duplicate chat rooms when starting
  // a chat with the same person more than once).
  String _generateChatId(String uid1, String uid2) {
    final ids = [uid1, uid2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  Future<void> _startChat(
    BuildContext context,
    String otherUid,
    String otherName,
  ) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final chatId = _generateChatId(currentUser.uid, otherUid);
    final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);

    // Create the chat document if it doesn't exist yet (set with merge, so
    // if it already exists this won't overwrite existing messages)
    await chatRef.set({
      'participants': [currentUser.uid, otherUid],
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatId: chatId,
          otherUserName: otherName,
          otherUserUid: otherUid,
        ),
      ),
    );
  }

  void _viewProfile(BuildContext context, String uid) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserProfileScreen(uid: uid)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: widget.accentColor,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search ${widget.targetRole.toLowerCase()} name...',
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value.toLowerCase());
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: widget.targetRole)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final users = snapshot.data!.docs.where((doc) {
                  final name = (doc['name'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery);
                }).toList();

                if (users.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 56, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          'No ${widget.targetRole.toLowerCase()}s found.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final doc = users[index];
                    final name = doc['name'] ?? 'No Name';
                    final subjectsList = List<String>.from(
                      (doc.data() as Map<String, dynamic>)['subjects'] ?? [],
                    );
                    final subjectsText = subjectsList.isNotEmpty
                        ? subjectsList.join(', ')
                        : 'No subjects assigned yet';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      child: ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        leading: CircleAvatar(
                          backgroundColor: widget.accentColor.withValues(alpha: 0.15),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: TextStyle(color: widget.accentColor),
                          ),
                        ),
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(subjectsText),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.info_outline, color: Colors.grey),
                              tooltip: 'View profile',
                              onPressed: () => _viewProfile(context, doc.id),
                            ),
                            Icon(Icons.chat_bubble_outline, color: widget.accentColor),
                          ],
                        ),
                        onTap: () => _startChat(context, doc.id, name),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
