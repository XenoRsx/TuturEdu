// lib/screens/self_paced_quiz_list_screen.dart
//
// Student screen: browse quizzes available for their subjects in
// Self-Paced mode (see BLUEPRINT.md 9.6) - attempt anytime, no host/join
// code/timer. Fetches quizzes where mode is "self_paced" or "both" (a
// single Firestore `whereIn` clause - Firestore only allows one per
// query), then filters by the student's own subjects client-side since a
// second `in` clause on subjectLevel isn't possible in the same query.
// No composite index needed as a result.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/quiz_theme.dart';
import 'attempt_quiz_screen.dart';

class SelfPacedQuizListScreen extends StatefulWidget {
  const SelfPacedQuizListScreen({super.key});

  @override
  State<SelfPacedQuizListScreen> createState() =>
      _SelfPacedQuizListScreenState();
}

class _SelfPacedQuizListScreenState extends State<SelfPacedQuizListScreen> {
  List<String> _mySubjects = [];
  bool _loadingSubjects = true;

  @override
  void initState() {
    super.initState();
    _loadMySubjects();
  }

  Future<void> _loadMySubjects() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    if (mounted) {
      setState(() {
        _mySubjects = List<String>.from(doc.data()?['subjects'] ?? []);
        _loadingSubjects = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('Please log in again.')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Self-Paced Quizzes'),
        backgroundColor: QuizTheme.primary,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: QuizTheme.pageGradient),
        child: _loadingSubjects
            ? const Center(child: CircularProgressIndicator())
            : StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('quizzes')
                    .where('mode', whereIn: ['self_paced', 'both'])
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final quizzes =
                      snapshot.data!.docs.where((doc) {
                        final subject =
                            (doc.data()
                                as Map<String, dynamic>)['subjectLevel'];
                        return _mySubjects.contains(subject);
                      }).toList()..sort((a, b) {
                        final titleA =
                            ((a.data() as Map<String, dynamic>)['title'] ?? '')
                                .toString();
                        final titleB =
                            ((b.data() as Map<String, dynamic>)['title'] ?? '')
                                .toString();
                        return titleA.compareTo(titleB);
                      });

                  if (quizzes.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 84,
                              height: 84,
                              decoration: BoxDecoration(
                                color: QuizTheme.primary.withValues(
                                  alpha: 0.08,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.assignment_outlined,
                                size: 40,
                                color: QuizTheme.primary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No self-paced quizzes available for your subjects yet.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: quizzes.length,
                    itemBuilder: (context, index) {
                      final doc = quizzes[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final title = data['title'] ?? 'Untitled Quiz';
                      final subject = data['subjectLevel'] ?? '';
                      final questionCount = data['questionCount'] ?? 0;
                      final color =
                          QuizTheme.optionColors[title.hashCode.abs() %
                              QuizTheme.optionColors.length];

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
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.assignment_outlined,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '$subject · $questionCount question(s)',
                          ),
                          trailing: FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('quizAttempts')
                                .doc('${doc.id}_${currentUser.uid}')
                                .get(),
                            builder: (context, attemptSnapshot) {
                              final attemptData =
                                  attemptSnapshot.data?.data()
                                      as Map<String, dynamic>?;
                              final completed =
                                  attemptData?['status'] == 'completed';
                              if (!completed) {
                                return const Icon(
                                  Icons.chevron_right,
                                  color: Colors.grey,
                                );
                              }
                              final score = attemptData?['score'] ?? 0;
                              final total = attemptData?['totalPoints'] ?? 0;
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$score/$total',
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            },
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AttemptQuizScreen(
                                  quizId: doc.id,
                                  quizTitle: title,
                                ),
                              ),
                            );
                          },
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
