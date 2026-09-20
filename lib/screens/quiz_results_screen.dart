// lib/screens/quiz_results_screen.dart
//
// Teacher screen: view every enrolled student's Self-Paced result for one
// quiz (see BLUEPRINT.md 9.6a) - completed score/percentage, attempts used,
// or "not attempted yet". Reachable from quiz_list_screen.dart's "View
// Results" action. Live Session results aren't shown here - those are
// scored via quizSessions/{sessionId}/participants, a completely separate
// path from quizAttempts (which only Self-Paced writes to), and already
// have their own real-time leaderboard in host_quiz_session_screen.dart.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/quiz_theme.dart';

class _StudentResult {
  final String uid;
  final String name;
  final bool attempted;
  final int score;
  final int totalPoints;
  final int attemptsUsed;

  const _StudentResult({
    required this.uid,
    required this.name,
    required this.attempted,
    required this.score,
    required this.totalPoints,
    required this.attemptsUsed,
  });
}

class QuizResultsScreen extends StatefulWidget {
  final String quizId;
  final String quizTitle;
  final String subjectLevel;

  const QuizResultsScreen({
    super.key,
    required this.quizId,
    required this.quizTitle,
    required this.subjectLevel,
  });

  @override
  State<QuizResultsScreen> createState() => _QuizResultsScreenState();
}

class _QuizResultsScreenState extends State<QuizResultsScreen> {
  bool _loading = true;
  String? _error;
  List<_StudentResult> _results = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final studentsSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'Student')
          .where('subjects', arrayContains: widget.subjectLevel)
          .get();

      final attemptsSnap = await FirebaseFirestore.instance
          .collection('quizAttempts')
          .where('quizId', isEqualTo: widget.quizId)
          .get();

      final attemptsByUid = {
        for (final doc in attemptsSnap.docs)
          doc.data()['studentUid'] as String: doc.data(),
      };

      final results = studentsSnap.docs.map((doc) {
        final data = doc.data();
        final name = data['name'] as String? ?? 'Unnamed';
        final attempt = attemptsByUid[doc.id];
        final completed = attempt != null && attempt['status'] == 'completed';
        return _StudentResult(
          uid: doc.id,
          name: name,
          attempted: completed,
          score: attempt?['score'] as int? ?? 0,
          totalPoints: attempt?['totalPoints'] as int? ?? 0,
          attemptsUsed: attempt?['attemptsUsed'] as int? ?? 0,
        );
      }).toList()..sort((a, b) => a.name.compareTo(b.name));

      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load results: $e';
        _loading = false;
      });
    }
  }

  Widget _summaryStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: QuizTheme.primaryDark,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.black54),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final attemptedCount = _results.where((r) => r.attempted).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.quizTitle),
        backgroundColor: QuizTheme.primary,
      ),
      // Forced light Theme - see create_quiz_screen.dart's build() for why:
      // this page's fixed light QuizTheme.pageGradient must never follow
      // the app's Light/Dark/System setting.
      body: Theme(
        data: ThemeData.light(useMaterial3: true),
        child: Container(
          decoration: const BoxDecoration(gradient: QuizTheme.pageGradient),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ),
                )
              : _results.isEmpty
              ? const Center(
                  child: Text(
                    'No students enrolled in this subject yet.',
                    style: TextStyle(color: Colors.black54),
                  ),
                )
              : Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.all(16),
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
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _summaryStat('$attemptedCount', 'Completed'),
                          _summaryStat(
                            '${_results.length - attemptedCount}',
                            'Not Attempted',
                          ),
                          _summaryStat('${_results.length}', 'Total Students'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final r = _results[index];
                          final percentage = r.totalPoints == 0
                              ? 0
                              : (r.score / r.totalPoints * 100).round();
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: QuizTheme.primary.withValues(
                                    alpha: 0.06,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: r.attempted
                                    ? Colors.green.shade100
                                    : Colors.grey.shade200,
                                child: Text(
                                  r.name.isNotEmpty
                                      ? r.name[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    color: r.attempted
                                        ? Colors.green
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                              title: Text(
                                r.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              subtitle: Text(
                                r.attempted
                                    ? 'Score: ${r.score}/${r.totalPoints}'
                                          '${r.attemptsUsed > 1 ? ' · ${r.attemptsUsed} attempts' : ''}'
                                    : 'Not attempted yet',
                                style: TextStyle(
                                  color: r.attempted
                                      ? Colors.black54
                                      : Colors.black38,
                                ),
                              ),
                              trailing: r.attempted
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '$percentage%',
                                        style: const TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.hourglass_empty,
                                      color: Colors.grey,
                                    ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
