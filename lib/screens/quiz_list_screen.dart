// lib/screens/quiz_list_screen.dart
//
// Teacher screen: "My Quizzes" - lists quizzes this teacher created.
// Tapping a quiz starts hosting a new Live Session for it (generates a
// join code, opens HostQuizSessionScreen). The Edit icon opens
// CreateQuizScreen in edit mode (quizId passed through) to change an
// existing quiz's title/subject/mode/questions/retake/due-date settings.
// See BLUEPRINT.md section 9.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/quiz_theme.dart';
import 'create_quiz_screen.dart';
import 'host_quiz_session_screen.dart';
import 'quiz_results_screen.dart';

class QuizListScreen extends StatelessWidget {
  const QuizListScreen({super.key});

  Future<void> _deleteQuiz(
    BuildContext context,
    String quizId,
    String title,
  ) async {
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

    final quizRef = FirebaseFirestore.instance
        .collection('quizzes')
        .doc(quizId);
    final questions = await quizRef.collection('questions').get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in questions.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(quizRef);
    await batch.commit();
  }

  void _createQuiz(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateQuizScreen()),
    );
  }

  Future<void> _hostSession(
    BuildContext context,
    String quizId,
    String title,
  ) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final joinCode = await _generateUniqueJoinCode();

    final sessionRef = await FirebaseFirestore.instance
        .collection('quizSessions')
        .add({
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
        builder: (_) =>
            HostQuizSessionScreen(sessionId: sessionRef.id, quizTitle: title),
      ),
    );
  }

  String _modeLabel(String mode) {
    switch (mode) {
      case 'self_paced':
        return 'Self-Paced';
      case 'both':
        return 'Live + Self-Paced';
      default:
        return 'Live Session';
    }
  }

  IconData _modeIcon(String mode) {
    switch (mode) {
      case 'self_paced':
        return Icons.schedule_rounded;
      case 'both':
        return Icons.call_merge_rounded;
      default:
        return Icons.flash_on_rounded;
    }
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
        // 'question_results' (see host_quiz_session_screen.dart) is still an
        // ongoing session between questions, not yet 'ended' - its join code
        // must stay reserved too.
        return status == 'waiting' ||
            status == 'active' ||
            status == 'question_results';
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
        onPressed: () => _createQuiz(context),
        backgroundColor: QuizTheme.primary,
        icon: const Icon(Icons.add),
        label: const Text('New Quiz'),
      ),
      // Forced light Theme - see create_quiz_screen.dart's build() for why:
      // this page's fixed light QuizTheme.pageGradient must never follow
      // the app's Light/Dark/System setting, and this is cheap insurance
      // against any future default-colored widget added here.
      body: Theme(
        data: ThemeData.light(useMaterial3: true),
        child: Container(
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
                // Fixed (not theme-derived) colors deliberately - this page
                // always sits on the light QuizTheme.pageGradient regardless
                // of the app's Light/Dark/System setting (see CLAUDE.md).
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
                        child: const Icon(
                          Icons.quiz_outlined,
                          size: 40,
                          color: QuizTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No quizzes yet. Tap "New Quiz" to create one.',
                        style: TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _createQuiz(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Create Your First Quiz'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: QuizTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
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
                  final mode = data['mode'] ?? 'live';
                  final canHost = mode == 'live' || mode == 'both';
                  final hasSelfPaced = mode == 'self_paced' || mode == 'both';
                  final color =
                      QuizTheme.optionColors[title.hashCode.abs() %
                          QuizTheme.optionColors.length];

                  return QuizCard(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    accentColor: color,
                    onTap: () {
                      if (!canHost) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'This quiz is Self-Paced only — students attempt it on their '
                              'own, no live session to host.',
                            ),
                          ),
                        );
                        return;
                      }
                      _hostSession(context, doc.id, title);
                    },
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [color, color.withValues(alpha: 0.75)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(alpha: 0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.quiz_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subject,
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  QuizBadge(
                                    icon: _modeIcon(mode),
                                    label: _modeLabel(mode),
                                  ),
                                  QuizBadge(
                                    icon: Icons.format_list_numbered_rounded,
                                    label: '$questionCount Qs',
                                    color: Colors.blueGrey,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        PopupMenuButton<String>(
                          icon: Icon(
                            Icons.more_vert,
                            color: Colors.grey.shade600,
                          ),
                          onSelected: (value) {
                            if (value == 'edit') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      CreateQuizScreen(quizId: doc.id),
                                ),
                              );
                            } else if (value == 'delete') {
                              _deleteQuiz(context, doc.id, title);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: ListTile(
                                leading: Icon(
                                  Icons.edit_outlined,
                                  color: QuizTheme.primary,
                                ),
                                title: Text('Edit'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: ListTile(
                                leading: Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                title: Text('Delete'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        ),
                        if (hasSelfPaced)
                          IconButton(
                            icon: const Icon(
                              Icons.leaderboard_outlined,
                              color: QuizTheme.primary,
                            ),
                            tooltip: 'View Results',
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => QuizResultsScreen(
                                  quizId: doc.id,
                                  quizTitle: title,
                                  subjectLevel: subject,
                                ),
                              ),
                            ),
                          ),
                        Icon(
                          canHost
                              ? Icons.play_circle_fill
                              : Icons.assignment_turned_in_outlined,
                          color: QuizTheme.primary,
                          size: 28,
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
