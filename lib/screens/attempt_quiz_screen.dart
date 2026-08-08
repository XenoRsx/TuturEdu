// lib/screens/attempt_quiz_screen.dart
//
// Student screen: attempt (or review) a Self-Paced quiz (see BLUEPRINT.md
// 9.6). No timer, no host - answer every question at your own pace, then
// submit once. quizAttempts/{quizId}_{studentUid} is a deterministic doc ID
// (one attempt per student per quiz, no retakes) - so checking "have I
// already done this" is a single get(), no query/index needed.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/quiz_theme.dart';

class AttemptQuizScreen extends StatefulWidget {
  final String quizId;
  final String quizTitle;

  const AttemptQuizScreen({
    super.key,
    required this.quizId,
    required this.quizTitle,
  });

  @override
  State<AttemptQuizScreen> createState() => _AttemptQuizScreenState();
}

class _AttemptQuizScreenState extends State<AttemptQuizScreen> {
  final _currentUser = FirebaseAuth.instance.currentUser;

  bool _loading = true;
  List<QueryDocumentSnapshot> _questions = [];
  final Map<String, int> _selectedAnswers = {};

  bool _reviewMode = false;
  Map<String, dynamic>? _existingAnswers;
  int _finalScore = 0;
  int _totalPoints = 0;
  bool _submitting = false;

  DocumentReference get _attemptRef => FirebaseFirestore.instance
      .collection('quizAttempts')
      .doc('${widget.quizId}_${_currentUser!.uid}');

  @override
  void initState() {
    super.initState();
    if (_currentUser != null) _load();
  }

  Future<void> _load() async {
    final questionsSnap = await FirebaseFirestore.instance
        .collection('quizzes')
        .doc(widget.quizId)
        .collection('questions')
        .orderBy('order')
        .get();

    final attemptDoc = await _attemptRef.get();
    final attemptData = attemptDoc.data() as Map<String, dynamic>?;

    if (!mounted) return;
    setState(() {
      _questions = questionsSnap.docs;
      _totalPoints = _questions.fold<int>(
        0,
        (total, q) =>
            total +
            ((q.data() as Map<String, dynamic>)['points'] as int? ?? 100),
      );
      if (attemptData != null && attemptData['status'] == 'completed') {
        _reviewMode = true;
        _existingAnswers = Map<String, dynamic>.from(
          attemptData['answers'] ?? {},
        );
        _finalScore = attemptData['score'] as int? ?? 0;
      }
      _loading = false;
    });
  }

  Future<void> _submit() async {
    if (_selectedAnswers.length < _questions.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please answer every question before submitting.'),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Submit Quiz'),
        content: const Text(
          "Submit your answers? You won't be able to change them after this.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: QuizTheme.primary),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Submit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _submitting = true);

    var score = 0;
    for (final q in _questions) {
      final data = q.data() as Map<String, dynamic>;
      if (_selectedAnswers[q.id] == data['correctIndex']) {
        score += (data['points'] as int? ?? 100);
      }
    }

    await _attemptRef.set({
      'quizId': widget.quizId,
      'studentUid': _currentUser!.uid,
      'status': 'completed',
      'startedAt': FieldValue.serverTimestamp(),
      'completedAt': FieldValue.serverTimestamp(),
      'score': score,
      'totalPoints': _totalPoints,
      'answers': _selectedAnswers,
    });

    if (mounted) {
      setState(() {
        _reviewMode = true;
        _existingAnswers = Map<String, dynamic>.from(_selectedAnswers);
        _finalScore = score;
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Scaffold(body: Center(child: Text('Please log in again.')));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.quizTitle),
        backgroundColor: QuizTheme.primary,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              decoration: const BoxDecoration(gradient: QuizTheme.pageGradient),
              child: Column(
                children: [
                  if (_reviewMode) _buildScoreHeader(),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _questions.length,
                      itemBuilder: (context, index) =>
                          _buildQuestionCard(index),
                    ),
                  ),
                  if (!_reviewMode)
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: _submitting ? null : _submit,
                            icon: _submitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.check_circle_outline),
                            label: Text(
                              _submitting ? 'Submitting...' : 'Submit Quiz',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: QuizTheme.primary,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildScoreHeader() {
    final percentage = _totalPoints == 0
        ? 0
        : (_finalScore / _totalPoints * 100).round();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: QuizTheme.heroGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.emoji_events_rounded,
            size: 36,
            color: Colors.amberAccent,
          ),
          const SizedBox(height: 6),
          Text(
            '$_finalScore / $_totalPoints points ($percentage%)',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Quiz completed — review your answers below',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(int index) {
    final q = _questions[index];
    final data = q.data() as Map<String, dynamic>;
    final options = List<String>.from(data['options'] ?? []);
    final correctIndex = data['correctIndex'] as int? ?? 0;
    final selected = _reviewMode
        ? (_existingAnswers?[q.id] as num?)?.toInt()
        : _selectedAnswers[q.id];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Question ${index + 1}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: QuizTheme.primaryDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            data['text'] ?? '',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          ...List.generate(options.length, (i) {
            final optionColor =
                QuizTheme.optionColors[i % QuizTheme.optionColors.length];
            final isSelected = selected == i;
            final showCorrectness = _reviewMode;

            var opacity = 1.0;
            if (showCorrectness && i != correctIndex && !isSelected) {
              opacity = 0.35;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Opacity(
                opacity: opacity,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _reviewMode
                      ? null
                      : () => setState(() => _selectedAnswers[q.id] = i),
                  child: Container(
                    decoration: BoxDecoration(
                      color: optionColor,
                      borderRadius: BorderRadius.circular(12),
                      border: !showCorrectness && isSelected
                          ? Border.all(color: QuizTheme.primaryDark, width: 3)
                          : (showCorrectness && i == correctIndex)
                          ? Border.all(color: Colors.white, width: 3)
                          : null,
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(
                          QuizTheme.optionIcons[i %
                              QuizTheme.optionIcons.length],
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            options[i],
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (showCorrectness && i == correctIndex)
                          const Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 18,
                          ),
                        if (showCorrectness && isSelected && i != correctIndex)
                          const Icon(
                            Icons.cancel,
                            color: Colors.white,
                            size: 18,
                          ),
                        if (!showCorrectness && isSelected)
                          const Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 18,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
