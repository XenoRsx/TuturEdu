// lib/screens/teacher_list_screen.dart
//
// Screen untuk STUDENT cari & pilih teacher untuk mula chat.
// Bila student tap satu teacher, sistem akan create/reuse chat document
// dalam Firestore, then terus bawa masuk ChatScreen.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

class TeacherListScreen extends StatefulWidget {
  const TeacherListScreen({super.key});

  @override
  State<TeacherListScreen> createState() => _TeacherListScreenState();
}

class _TeacherListScreenState extends State<TeacherListScreen> {
  String _searchQuery = '';

  // Chat ID dibuat consistent dengan susun UID mengikut abjad,
  // supaya student & teacher yang sama akan selalu dapat chat ID yang sama
  // (elak duplicate chat room bila mula chat berkali-kali).
  String _generateChatId(String uid1, String uid2) {
    final ids = [uid1, uid2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  Future<void> _startChat(
    BuildContext context,
    String teacherUid,
    String teacherName,
  ) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final chatId = _generateChatId(currentUser.uid, teacherUid);
    final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);

    // Create chat document kalau belum wujud (set with merge, so kalau
    // dah ada takkan overwrite messages sedia ada)
    await chatRef.set({
      'participants': [currentUser.uid, teacherUid],
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatId: chatId,
          otherUserName: teacherName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cari Teacher'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Cari nama teacher...',
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
                  .where('role', isEqualTo: 'Teacher')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Ralat: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final teachers = snapshot.data!.docs.where((doc) {
                  final name = (doc['name'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery);
                }).toList();

                if (teachers.isEmpty) {
                  return const Center(child: Text('Tiada teacher dijumpai.'));
                }

                return ListView.builder(
                  itemCount: teachers.length,
                  itemBuilder: (context, index) {
                    final doc = teachers[index];
                    final name = doc['name'] ?? 'Tanpa Nama';
                    final subjectsList = List<String>.from(
                      (doc.data() as Map<String, dynamic>)['subjects'] ?? [],
                    );
                    final subjectsText = subjectsList.isNotEmpty
                        ? subjectsList.join(', ')
                        : 'Subjek belum ditetapkan';

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade100,
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.blue),
                        ),
                      ),
                      title: Text(name),
                      subtitle: Text(subjectsText),
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
