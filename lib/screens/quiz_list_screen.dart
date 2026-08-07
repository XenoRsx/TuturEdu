// lib/screens/quiz_list_screen.dart
//
// Teacher screen: "My Quizzes" - lists quizzes this teacher created.
// Tapping a quiz starts hosting a new Live Session for it (generates a
// join code, opens HostQuizSessionScreen). See BLUEPRINT.md section 9.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/quiz_theme.dart';
import 'create_quiz_screen.dart';
import 'host_quiz_session_screen.dart';

class QuizListScreen extends StatelessWidget {
  const QuizListScreen({super.key});

  Future<void> _deleteQuiz(BuildContext context, String quizId, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Quiz'),
        content: Text('Remove "$title"? This also removes its questions.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final quizRef = FirebaseFirestore.instance.collection('quizzes').doc(quizId);
    final questions = await quizRef.collection('questions').get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in questions.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(quizRef);
    await batch.commit();
  }

  Future<void> _hostSession(BuildContext context, String quizId, String title) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final joinCode = await _generateUniqueJoinCode();

    final sessionRef = await FirebaseFirestore.instance.collection('quizSessions').add({
      'quizId': quizId,
      'hostUid': currentUser.uid,
      'joinCode': joinCode,
      'status': 'waiting',
      'currentQuestionIndex': 0,
      'startedAt': null,
      'endedAt': null,
    });

    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HostQuizSessionScreen(
          sessionId: sessionRef.id,
          quizTitle: title,
        ),
      ),
    );
  }

  Future<String> _generateUniqueJoinCode() async {
    final random = DateTime.now().millisecondsSinceEpoch;
    for (var attempt = 0; attempt < 10; attempt++) {
      final code = ((random + attempt * 7919) % 900000 + 100000).toString();
      final existing = await FirebaseFirestore.instance
          .collection('quizSessions')
          .where('joinCode', isEqualTo: code)
          .get();
      final stillActive = existing.docs.any((doc) {
        final status = doc.data()['status'];
        return status == 'waiting' || status == 'active';
      });
      if (!stillActive) return code;
    }
    // Extremely unlikely fallback - just use current time-based code.
    return (random % 900000 + 100000).toString();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('Please log in again.')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Quizzes'),
        backgroundColor: QuizTheme.primary,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateQuizScreen()),
          );
        },
        backgroundColor: QuizTheme.primary,
        icon: const Icon(Icons.add),
        label: const Text('New Quiz'),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: QuizTheme.pageGradient),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('quizzes')
              .where('createdBy', isEqualTo: currentUser.uid)
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final quizzes = snapshot.data!.docs;

            if (quizzes.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: QuizTheme.primary.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.quiz_outlined, size: 40, color: QuizTheme.primary),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No quizzes yet. Tap "New Quiz" to create one.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
              itemCount: quizzes.length,
              itemBuilder: (context, index) {
                final doc = quizzes[index];
                final data = doc.data() as Map<String, dynamic>;
                final title = data['title'] ?? 'Untitled Quiz';
                final subject = data['subjectLevel'] ?? '';
                final questionCount = data['questionCount'] ?? 0;
                final color = QuizTheme.optionColors[title.hashCode.abs() % QuizTheme.optionColors.length];

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: QuizTheme.primary.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.quiz_rounded, color: Colors.white),
                    ),
                    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('$subject · $questionCount question(s)'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          tooltip: 'Delete',
                          onPressed: () => _deleteQuiz(context, doc.id, title),
                        ),
                        const Icon(Icons.play_circle_fill, color: QuizTheme.primary, size: 28),
                      ],
                    ),
                    onTap: () => _hostSession(context, doc.id, title),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
