// lib/screens/live_quiz_play_screen.dart
//
// Student screen: plays a Live Session quiz in real time. Reacts to
// quizSessions/{sessionId}.status and .currentQuestionIndex via
// StreamBuilder, same pattern as ChatScreen. Score is computed and written
// client-side on answer (no Cloud Function) - see firestore.rules note on
// quizSessions/participants for the accepted trade-off.
//
// Countdown timer: a 1-second Timer.periodic just forces a rebuild: the
// remaining time is always recomputed fresh from
// currentQuestionStartedAt + the question's timeLimitSeconds, so it
// re-syncs automatically whenever the host advances to a new question.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/quiz_theme.dart';
import 'quiz_leaderboard_view.dart';

class LiveQuizPlayScreen extends StatefulWidget {
  final String sessionId;

  const LiveQuizPlayScreen({super.key, required this.sessionId});

  @override
  State<LiveQuizPlayScreen> createState() => _LiveQuizPlayScreenState();
}

class _LiveQuizPlayScreenState extends State<LiveQuizPlayScreen> {
  List<QueryDocumentSnapshot>? _questions;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
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

  Future<void> _submitAnswer(
    String questionId,
    int selectedIndex,
    int correctIndex,
    int points,
    int timeTakenMs,
  ) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final isCorrect = selectedIndex == correctIndex;
    final participantRef = _sessionRef.collection('participants').doc(currentUser.uid);

    await participantRef.update({
      'answers.$questionId': {
        'selectedIndex': selectedIndex,
        'correct': isCorrect,
        'timeTakenMs': timeTakenMs,
      },
      if (isCorrect) 'score': FieldValue.increment(points),
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Quiz'),
        backgroundColor: QuizTheme.primary,
      ),
      body: _questions == null || currentUser == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<DocumentSnapshot>(
              stream: _sessionRef.snapshots(),
              builder: (context, sessionSnapshot) {
                if (!sessionSnapshot.hasData || !sessionSnapshot.data!.exists) {
                  return const Center(child: Text('Session not found.'));
                }

                final session = sessionSnapshot.data!.data() as Map<String, dynamic>;
                final status = session['status'] ?? 'waiting';

                if (status == 'waiting') {
                  return Container(
                    decoration: const BoxDecoration(gradient: QuizTheme.pageGradient),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 84,
                            height: 84,
                            decoration: const BoxDecoration(
                              gradient: QuizTheme.heroGradient,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.hourglass_top_rounded, size: 38, color: Colors.white),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Waiting for the host to start...',
                            style: TextStyle(fontWeight: FontWeight.w600, color: QuizTheme.primaryDark),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (status == 'ended') {
                  return StreamBuilder<QuerySnapshot>(
                    stream: _sessionRef.collection('participants').snapshots(),
                    builder: (context, participantsSnapshot) {
                      final participants = participantsSnapshot.data?.docs ?? [];
                      return QuizLeaderboardView(
                        participants: participants,
                        myUid: currentUser.uid,
                        onDone: () => Navigator.popUntil(context, (route) => route.isFirst),
                      );
                    },
                  );
                }

                return _buildActiveQuestion(session, currentUser.uid);
              },
            ),
    );
  }

  Widget _buildActiveQuestion(Map<String, dynamic> session, String myUid) {
    final questions = _questions!;
    final currentIndex = session['currentQuestionIndex'] as int? ?? 0;
    if (currentIndex >= questions.length) {
      return const Center(child: CircularProgressIndicator());
    }

    final questionDoc = questions[currentIndex];
    final question = questionDoc.data() as Map<String, dynamic>;
    final questionId = questionDoc.id;
    final options = List<String>.from(question['options'] ?? []);
    final timeLimit = question['timeLimitSeconds'] as int? ?? 20;
    final correctIndex = question['correctIndex'] as int? ?? 0;
    final points = question['points'] as int? ?? 100;

    final startedAt = session['currentQuestionStartedAt'] as Timestamp?;
    final elapsedSeconds = startedAt == null
        ? 0
        : DateTime.now().difference(startedAt.toDate()).inSeconds;
    final remaining = (timeLimit - elapsedSeconds).clamp(0, timeLimit);
    final progress = timeLimit == 0 ? 0.0 : remaining / timeLimit;

    return StreamBuilder<DocumentSnapshot>(
      stream: _sessionRef.collection('participants').doc(myUid).snapshots(),
      builder: (context, myDocSnapshot) {
        final myData = myDocSnapshot.data?.data() as Map<String, dynamic>?;
        final myAnswers = Map<String, dynamic>.from(myData?['answers'] ?? {});
        final myAnswer = myAnswers[questionId] as Map<String, dynamic>?;
        final alreadyAnswered = myAnswer != null;
        final timedOut = remaining <= 0 && !alreadyAnswered;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(gradient: QuizTheme.heroGradient),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'QUESTION ${currentIndex + 1} OF ${questions.length}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          question['text'] ?? '',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 4,
                          backgroundColor: Colors.white24,
                          valueColor: AlwaysStoppedAnimation(
                            remaining <= 5 ? Colors.redAccent : Colors.white,
                          ),
                        ),
                        Text(
                          '$remaining',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
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
                  childAspectRatio: 2.0,
                  children: List.generate(options.length, (i) {
                    final isSelected = alreadyAnswered && myAnswer['selectedIndex'] == i;
                    final revealCorrectness = alreadyAnswered;
                    final baseColor = QuizTheme.optionColors[i % QuizTheme.optionColors.length];

                    Color tileColor = baseColor;
                    double opacity = 1.0;
                    if (revealCorrectness && i != correctIndex && !isSelected) {
                      opacity = 0.35;
                    }

                    return Opacity(
                      opacity: (alreadyAnswered || timedOut) && !isSelected && i != correctIndex ? opacity : 1.0,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: (alreadyAnswered || timedOut)
                            ? null
                            : () => _submitAnswer(
                                  questionId,
                                  i,
                                  correctIndex,
                                  points,
                                  (timeLimit - remaining) * 1000,
                                ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: tileColor,
                            borderRadius: BorderRadius.circular(14),
                            border: revealCorrectness && i == correctIndex
                                ? Border.all(color: Colors.white, width: 3)
                                : null,
                            boxShadow: [
                              BoxShadow(
                                color: tileColor.withValues(alpha: 0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
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
                              if (revealCorrectness && i == correctIndex)
                                const Icon(Icons.check_circle, color: Colors.white, size: 18),
                              if (revealCorrectness && isSelected && i != correctIndex)
                                const Icon(Icons.cancel, color: Colors.white, size: 18),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      alreadyAnswered
                          ? (myAnswer['correct'] == true ? Icons.check_circle : Icons.info)
                          : Icons.timer_outlined,
                      size: 18,
                      color: alreadyAnswered
                          ? (myAnswer['correct'] == true ? Colors.green : Colors.orange)
                          : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      alreadyAnswered
                          ? (myAnswer['correct'] == true
                              ? 'Correct! Waiting for the next question...'
                              : 'Answer submitted. Waiting for the next question...')
                          : timedOut
                              ? "Time's up! Waiting for the next question..."
                              : 'Tap an answer before time runs out.',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
