// lib/screens/parent_warning_letters_screen.dart
//
// Parent screen: warning letters sent about the parent's linked child (see
// BLUEPRINT.md 5.9). Tapping an unacknowledged letter marks it read -
// firestore.rules already allowed this update (parentUid can update the
// `acknowledged` field only) since the Class Performance module was built,
// this is the first screen that actually exercises it.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ParentWarningLettersScreen extends StatelessWidget {
  const ParentWarningLettersScreen({super.key});

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  Future<void> _acknowledge(String letterId) async {
    await FirebaseFirestore.instance
        .collection('warningLetters')
        .doc(letterId)
        .update({'acknowledged': true});
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('Please log in again.')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Warning Letters'),
        backgroundColor: Colors.orange,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('warningLetters')
            .where('parentUid', isEqualTo: currentUser.uid)
            .orderBy('sentAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final letters = snapshot.data!.docs;

          if (letters.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.mark_email_read_outlined,
                    size: 56,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No warning letters.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: letters.length,
            itemBuilder: (context, index) {
              final doc = letters[index];
              final data = doc.data() as Map<String, dynamic>;
              final subject = data['subjectLevel'] ?? '';
              final reason = data['reason'] ?? '';
              final sentAt = (data['sentAt'] as Timestamp?)?.toDate();
              final acknowledged = data['acknowledged'] == true;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: acknowledged ? null : Colors.red.withValues(alpha: 0.04),
                child: ListTile(
                  leading: Icon(
                    Icons.warning_amber_rounded,
                    color: acknowledged ? Colors.grey : Colors.red,
                  ),
                  title: Text(
                    subject,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '$reason\n${sentAt != null ? _formatDate(sentAt) : ''}',
                  ),
                  isThreeLine: true,
                  trailing: acknowledged
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : TextButton(
                          onPressed: () => _acknowledge(doc.id),
                          child: const Text('Mark Read'),
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
