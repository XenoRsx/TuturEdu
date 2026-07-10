// lib/screens/lecturer_list_screen.dart
//
// Screen untuk STUDENT cari & pilih lecturer untuk mula chat.
// Bila student tap satu lecturer, sistem akan create/reuse chat document
// dalam Firestore, then terus bawa masuk ChatScreen.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

class LecturerListScreen extends StatefulWidget {
  const LecturerListScreen({super.key});

  @override
  State<LecturerListScreen> createState() => _LecturerListScreenState();
}

class _LecturerListScreenState extends State<LecturerListScreen> {
  String _searchQuery = '';

  // Chat ID dibuat consistent dengan susun UID mengikut abjad,
  // supaya student & lecturer yang sama akan selalu dapat chat ID yang sama
  // (elak duplicate chat room bila mula chat berkali-kali).
  String _generateChatId(String uid1, String uid2) {
    final ids = [uid1, uid2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  Future<void> _startChat(
    BuildContext context,
    String lecturerUid,
    String lecturerName,
  ) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final chatId = _generateChatId(currentUser.uid, lecturerUid);
    final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);

    // Create chat document kalau belum wujud (set with merge, so kalau
    // dah ada takkan overwrite messages sedia ada)
    await chatRef.set({
      'participants': [currentUser.uid, lecturerUid],
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatId: chatId,
          otherUserName: lecturerName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cari Pensyarah'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Cari nama pensyarah...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
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
                  .where('role', isEqualTo: 'Lecturer')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Ralat: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final lecturers = snapshot.data!.docs.where((doc) {
                  final name = (doc['name'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery);
                }).toList();

                if (lecturers.isEmpty) {
                  return const Center(child: Text('Tiada pensyarah dijumpai.'));
                }

                return ListView.builder(
                  itemCount: lecturers.length,
                  itemBuilder: (context, index) {
                    final doc = lecturers[index];
                    final name = doc['name'] ?? 'Tanpa Nama';
                    final email = doc['email'] ?? '';

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade100,
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.blue),
                        ),
                      ),
                      title: Text(name),
                      subtitle: Text(email),
                      trailing: const Icon(Icons.chat_bubble_outline),
                      onTap: () => _startChat(context, doc.id, name),
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
