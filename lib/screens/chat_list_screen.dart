// lib/screens/chat_list_screen.dart
//
// Skrin senarai perbualan aktif untuk user yang login (Teacher/Student/Parent).
// Papar semua chat document di mana user ni jadi salah satu participant,
// susun ikut lastUpdated terkini.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  Future<String> _getOtherUserName(String otherUid) async {
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(otherUid).get();
    if (doc.exists) {
      return doc.data()?['name'] ?? 'Pengguna';
    }
    return 'Pengguna';
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('Sila log masuk semula.')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat Saya'),
        backgroundColor: Colors.blue,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: currentUser.uid)
            .orderBy('lastUpdated', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Ralat: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final chats = snapshot.data!.docs;

          if (chats.isEmpty) {
            return const Center(
              child: Text('Belum ada perbualan lagi.'),
            );
          }

          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final doc = chats[index];
              final data = doc.data() as Map<String, dynamic>;
              final participants = List<String>.from(data['participants'] ?? []);
              final otherUid = participants.firstWhere(
                (uid) => uid != currentUser.uid,
                orElse: () => '',
              );
              final lastMessage = data['lastMessage'] ?? 'Mula perbualan...';

              if (otherUid.isEmpty) return const SizedBox.shrink();

              return FutureBuilder<String>(
                future: _getOtherUserName(otherUid),
                builder: (context, nameSnapshot) {
                  final name = nameSnapshot.data ?? 'Memuatkan...';

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.blue),
                      ),
                    ),
                    title: Text(name),
                    subtitle: Text(
                      lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            chatId: doc.id,
                            otherUserName: name,
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
