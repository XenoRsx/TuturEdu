// lib/screens/attempt_quiz_screen.dart
//
// Student screen: attempt (or review) a Self-Paced quiz (see BLUEPRINT.md
// 9.6). No timer, no host - answer every question at your own pace, then
// submit once. quizAttempts/{quizId}_{studentUid} is a deterministic doc ID
// - one attempt doc per student per quiz, reused (overwritten) on every
// retake, so there's still a single get() to check status, no query/index
// needed. Retakes (see 9.6a) don't keep per-attempt history - only the
// latest submission's score/answers are kept, `attemptsUsed` just counts
// how many times this doc has been overwritten.

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
  String? _loadError;
  List<QueryDocumentSnapshot> _questions = [];
  final Map<String, int> _selectedAnswers = {};

  bool _reviewMode = false;
  Map<String, dynamic>? _existingAnswers;
  int _finalScore = 0;
  int _totalPoints = 0;
  bool _submitting = false;

  // Retake + due date (see BLUEPRINT.md 9.6a) - maxAttempts defaults to 1
  // (no retake) for quizzes created before this feature existed.
  int _maxAttempts = 1;
  int _attemptsUsed = 0;
  DateTime? _dueDate;

  bool get _pastDue => _dueDate != null && DateTime.now().isAfter(_dueDate!);
  bool get _canRetake => _attemptsUsed < _maxAttempts && !_pastDue;

  DocumentReference get _attemptRef => FirebaseFirestore.instance
      .collection('quizAttempts')
      .doc('${widget.quizId}_${_currentUser!.uid}');

  @override
  void initState() {
    super.initState();
    if (_currentUser != null) _load();
  }

  Future<void> _load() async {
    try {
      final quizDoc = await FirebaseFirestore.instance
          .collection('quizzes')
          .doc(widget.quizId)
          .get();
      final quizData = quizDoc.data();

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
        _maxAttempts = quizData?['maxAttempts'] as int? ?? 1;
        _dueDate = (quizData?['dueDate'] as Timestamp?)?.toDate();
        _attemptsUsed = attemptData?['attemptsUsed'] as int? ?? 0;
        if (attemptData != null && attemptData['status'] == 'completed') {
          _reviewMode = true;
          _existingAnswers = Map<String, dynamic>.from(
            attemptData['answers'] ?? {},
          );
          _finalScore = attemptData['score'] as int? ?? 0;
        }
        _loading = false;
      });
    } catch (e) {
      // Without this, any failed read here (e.g. a permissions rule
      // mis-evaluating on a not-yet-existing quizAttempts doc - a real bug
      // this project hit once already, see firestore.rules' quizAttempts
      // comment) left _loading stuck true forever with no visible error -
      // "loading non-stop" with nothing in the UI to explain why.
      if (!mounted) return;
      setState(() {
        _loadError = 'Could not load this quiz: $e';
        _loading = false;
      });
    }
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
      'attemptsUsed': _attemptsUsed + 1,
    });

    if (mounted) {
      setState(() {
        _reviewMode = true;
        _existingAnswers = Map<String, dynamic>.from(_selectedAnswers);
        _finalScore = score;
        _attemptsUsed += 1;
        _submitting = false;
      });
    }
  }

  // Only reachable when _canRetake is true (attempts remain and the quiz
  // isn't past its due date) - drops back into answering mode with a clean
  // slate. The PREVIOUS attempt's score/answers are overwritten wholesale
  // on the next _submit(), not kept as history (see file header).
  void _retake() {
    setState(() {
      _reviewMode = false;
      _selectedAnswers.clear();
      _existingAnswers = null;
    });
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
          : _loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _loadError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
            )
          : (!_reviewMode && _pastDue)
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.event_busy_outlined,
                      size: 56,
                      color: Colors.black26,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "This quiz's due date has passed. You can no longer "
                      'attempt it.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            )
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
          if (_maxAttempts > 1) ...[
            const SizedBox(height: 6),
            Text(
              'Attempts used: $_attemptsUsed / $_maxAttempts',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
          if (_canRetake) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _retake,
              icon: const Icon(Icons.replay, color: Colors.white, size: 16),
              label: const Text(
                'Retake Quiz',
                style: TextStyle(color: Colors.white),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white),
              ),
            ),
          ],
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
