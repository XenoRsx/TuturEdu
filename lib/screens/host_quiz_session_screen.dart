// lib/screens/host_quiz_session_screen.dart
//
// Teacher screen: hosts a Live Session for a quiz (see BLUEPRINT.md 9.3).
// Three phases driven by quizSessions/{sessionId}.status:
//   waiting -> shows the join code + live roster of joined students
//   active  -> shows the current question + live "X/Y answered" count,
//              "Next Question" advances currentQuestionIndex (and resets
//              currentQuestionStartedAt so every student's timer re-syncs)
//   ended   -> final leaderboard, podium-style for the top 3

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/quiz_theme.dart';
import 'quiz_leaderboard_view.dart';

class HostQuizSessionScreen extends StatefulWidget {
  final String sessionId;
  final String quizTitle;

  const HostQuizSessionScreen({
    super.key,
    required this.sessionId,
    required this.quizTitle,
  });

  @override
  State<HostQuizSessionScreen> createState() => _HostQuizSessionScreenState();
}

class _HostQuizSessionScreenState extends State<HostQuizSessionScreen> {
  List<QueryDocumentSnapshot>? _questions;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    final sessionDoc = await FirebaseFirestore.instance
        .collection('quizSessions')
        .doc(widget.sessionId)
        .get();
    final quizId = sessionDoc.data()?['quizId'];

    final questionsSnap = await FirebaseFirestore.instance
        .collection('quizzes')
        .doc(quizId)
        .collection('questions')
        .orderBy('order')
        .get();

    if (mounted) setState(() => _questions = questionsSnap.docs);
  }

  DocumentReference get _sessionRef =>
      FirebaseFirestore.instance.collection('quizSessions').doc(widget.sessionId);

  Future<void> _startQuiz() async {
    await _sessionRef.update({
      'status': 'active',
      'currentQuestionIndex': 0,
      'startedAt': FieldValue.serverTimestamp(),
      'currentQuestionStartedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _nextQuestionOrEnd(int currentIndex) async {
    final questions = _questions;
    if (questions == null) return;

    if (currentIndex >= questions.length - 1) {
      await _sessionRef.update({
        'status': 'ended',
        'endedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await _sessionRef.update({
        'currentQuestionIndex': currentIndex + 1,
        'currentQuestionStartedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.quizTitle),
        backgroundColor: QuizTheme.primary,
      ),
      body: _questions == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<DocumentSnapshot>(
              stream: _sessionRef.snapshots(),
              builder: (context, sessionSnapshot) {
                if (!sessionSnapshot.hasData || !sessionSnapshot.data!.exists) {
                  return const Center(child: CircularProgressIndicator());
                }

                final session = sessionSnapshot.data!.data() as Map<String, dynamic>;
                final status = session['status'] ?? 'waiting';
                final joinCode = session['joinCode'] ?? '------';
                final currentIndex = session['currentQuestionIndex'] as int? ?? 0;

                return StreamBuilder<QuerySnapshot>(
                  stream: _sessionRef.collection('participants').snapshots(),
                  builder: (context, participantsSnapshot) {
                    final participants = participantsSnapshot.data?.docs ?? [];

                    if (status == 'waiting') {
                      return _buildWaitingRoom(joinCode, participants);
                    } else if (status == 'active') {
                      return _buildActiveQuestion(currentIndex, participants);
                    } else {
                      return QuizLeaderboardView(
                        participants: participants,
                        onDone: () => Navigator.pop(context),
                      );
                    }
                  },
                );
              },
            ),
    );
  }

  Widget _buildWaitingRoom(String joinCode, List<QueryDocumentSnapshot> participants) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(gradient: QuizTheme.heroGradient),
          padding: const EdgeInsets.symmetric(vertical: 36),
          child: Column(
            children: [
              const Text(
                'JOIN CODE',
                style: TextStyle(fontSize: 13, color: Colors.white70, letterSpacing: 2, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 16, offset: const Offset(0, 6)),
                  ],
                ),
                child: Text(
                  joinCode,
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 10,
                    color: QuizTheme.primaryDark,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.people_alt, size: 18, color: QuizTheme.primary),
              const SizedBox(width: 6),
              Text(
                '${participants.length} player(s) joined',
                style: const TextStyle(fontWeight: FontWeight.w700, color: QuizTheme.primaryDark),
              ),
            ],
          ),
        ),
        Expanded(
          child: participants.isEmpty
              ? Center(
                  child: Text(
                    'Waiting for players to join...',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: participants.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final name = data['name'] ?? 'Student';
                      final color = QuizTheme.optionColors[name.hashCode.abs() % QuizTheme.optionColors.length];
                      return Chip(
                        avatar: CircleAvatar(
                          backgroundColor: color,
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                        label: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        backgroundColor: color.withValues(alpha: 0.08),
                        side: BorderSide(color: color.withValues(alpha: 0.3)),
                      );
                    }).toList(),
                  ),
                ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: participants.isEmpty ? null : _startQuiz,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Start Quiz', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: QuizTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveQuestion(int currentIndex, List<QueryDocumentSnapshot> participants) {
    final questions = _questions!;
    if (currentIndex >= questions.length) {
      return const Center(child: CircularProgressIndicator());
    }

    final question = questions[currentIndex].data() as Map<String, dynamic>;
    final questionId = questions[currentIndex].id;
    final options = List<String>.from(question['options'] ?? []);
    final answeredCount = participants.where((p) {
      final answers = (p.data() as Map<String, dynamic>)['answers'] as Map<String, dynamic>?;
      return answers != null && answers.containsKey(questionId);
    }).length;
    final isLastQuestion = currentIndex >= questions.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(gradient: QuizTheme.heroGradient),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'QUESTION ${currentIndex + 1} OF ${questions.length}',
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1),
              ),
              const SizedBox(height: 8),
              Text(
                question['text'] ?? '',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.2,
              children: List.generate(options.length, (i) {
                final isCorrect = i == question['correctIndex'];
                final color = QuizTheme.optionColors[i % QuizTheme.optionColors.length];
                return Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(14),
                    border: isCorrect ? Border.all(color: Colors.white, width: 3) : null,
                    boxShadow: [
                      BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 4)),
                    ],
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(QuizTheme.optionIcons[i % QuizTheme.optionIcons.length],
                          color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          options[i],
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                      if (isCorrect) const Icon(Icons.check_circle, color: Colors.white, size: 18),
                    ],
                  ),
                );
              }),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '$answeredCount / ${participants.length} player(s) answered',
            style: const TextStyle(fontWeight: FontWeight.w700, color: QuizTheme.primaryDark),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => _nextQuestionOrEnd(currentIndex),
                icon: Icon(isLastQuestion ? Icons.flag_rounded : Icons.arrow_forward_rounded),
                label: Text(
                  isLastQuestion ? 'End Quiz' : 'Next Question',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: QuizTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
