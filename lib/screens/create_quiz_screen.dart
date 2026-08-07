// lib/screens/create_quiz_screen.dart
//
// Teacher screen: create a multiple-choice quiz for one of the subjects
// they teach (see BLUEPRINT.md section 9). Each question has 4 options, one
// marked correct, a per-question time limit (used in Live Session mode)
// and a points value. Saves to quizzes/{quizId} + a questions subcollection.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/quiz_theme.dart';

class _QuestionDraft {
  final TextEditingController textController = TextEditingController();
  final List<TextEditingController> optionControllers =
      List.generate(4, (_) => TextEditingController());
  int correctIndex = 0;
  int timeLimitSeconds = 20;
  int points = 100;

  void dispose() {
    textController.dispose();
    for (final c in optionControllers) {
      c.dispose();
    }
  }
}

class CreateQuizScreen extends StatefulWidget {
  const CreateQuizScreen({super.key});

  @override
  State<CreateQuizScreen> createState() => _CreateQuizScreenState();
}

class _CreateQuizScreenState extends State<CreateQuizScreen> {
  final _titleController = TextEditingController();
  final List<_QuestionDraft> _questions = [_QuestionDraft()];

  bool _loadingSubjects = true;
  bool _saving = false;
  List<String> _teacherSubjects = [];
  String? _selectedSubject;

  @override
  void initState() {
    super.initState();
    _loadTeacherSubjects();
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (final q in _questions) {
      q.dispose();
    }
    super.dispose();
  }

  Future<void> _loadTeacherSubjects() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    final subjects = List<String>.from(doc.data()?['subjects'] ?? []);

    if (mounted) {
      setState(() {
        _teacherSubjects = subjects;
        _selectedSubject = subjects.isNotEmpty ? subjects.first : null;
        _loadingSubjects = false;
      });
    }
  }

  void _addQuestion() {
    setState(() => _questions.add(_QuestionDraft()));
  }

  void _removeQuestion(int index) {
    setState(() {
      _questions[index].dispose();
      _questions.removeAt(index);
    });
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _saveQuiz() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showSnack('Please enter a quiz title.');
      return;
    }
    if (_selectedSubject == null) {
      _showSnack('Please select a subject.');
      return;
    }

    for (var i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      if (q.textController.text.trim().isEmpty) {
        _showSnack('Question ${i + 1} needs question text.');
        return;
      }
      for (var j = 0; j < 4; j++) {
        if (q.optionControllers[j].text.trim().isEmpty) {
          _showSnack('Question ${i + 1}, option ${j + 1} is empty.');
          return;
        }
      }
    }

    setState(() => _saving = true);

    try {
      final quizRef = FirebaseFirestore.instance.collection('quizzes').doc();
      final batch = FirebaseFirestore.instance.batch();

      batch.set(quizRef, {
        'title': title,
        'subjectLevel': _selectedSubject,
        'createdBy': currentUser.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'mode': 'live',
        'questionCount': _questions.length,
      });

      for (var i = 0; i < _questions.length; i++) {
        final q = _questions[i];
        final questionRef = quizRef.collection('questions').doc();
        batch.set(questionRef, {
          'order': i,
          'text': q.textController.text.trim(),
          'options': q.optionControllers.map((c) => c.text.trim()).toList(),
          'correctIndex': q.correctIndex,
          'timeLimitSeconds': q.timeLimitSeconds,
          'points': q.points,
          'createdBy': currentUser.uid,
        });
      }

      await batch.commit();

      if (mounted) {
        _showSnack('Quiz created!');
        Navigator.pop(context);
      }
    } catch (e) {
      _showSnack('Failed to save quiz: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Quiz'),
        backgroundColor: QuizTheme.primary,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: QuizTheme.pageGradient),
        child: _loadingSubjects
            ? const Center(child: CircularProgressIndicator())
            : _teacherSubjects.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.menu_book_outlined, size: 56, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          const Text(
                            'No subjects assigned to your account yet. Ask an '
                            'Admin to set your subjects before creating a quiz.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      Container(
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
                            const Text('Quiz Title', style: TextStyle(fontWeight: FontWeight.w700, color: QuizTheme.primaryDark)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _titleController,
                              decoration: InputDecoration(
                                hintText: 'e.g. Add Maths Chapter 3 Quiz',
                                filled: true,
                                fillColor: QuizTheme.primary.withValues(alpha: 0.05),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text('Subject / Class', style: TextStyle(fontWeight: FontWeight.w700, color: QuizTheme.primaryDark)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedSubject,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: QuizTheme.primary.withValues(alpha: 0.05),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              items: _teacherSubjects
                                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                  .toList(),
                              onChanged: (value) => setState(() => _selectedSubject = value),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...List.generate(_questions.length, (index) {
                        return _buildQuestionCard(index);
                      }),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _addQuestion,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Question'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: QuizTheme.primary,
                          side: const BorderSide(color: QuizTheme.primary),
                          minimumSize: const Size.fromHeight(46),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _saving ? null : _saveQuiz,
                          icon: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.save),
                          label: Text(
                            _saving ? 'Saving...' : 'Save Quiz',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: QuizTheme.primary,
                            foregroundColor: Colors.white,
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildQuestionCard(int index) {
    final q = _questions[index];
    final badgeColor = QuizTheme.optionColors[index % QuizTheme.optionColors.length];

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(8)),
                    alignment: Alignment.center,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Question ${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: QuizTheme.primaryDark),
                  ),
                ],
              ),
              if (_questions.length > 1)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _removeQuestion(index),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: q.textController,
            decoration: InputDecoration(
              hintText: 'Question text',
              filled: true,
              fillColor: QuizTheme.primary.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text('Options (select the correct one)', style: TextStyle(fontSize: 12.5, color: Colors.black54)),
          RadioGroup<int>(
            groupValue: q.correctIndex,
            onChanged: (value) => setState(() => q.correctIndex = value ?? 0),
            child: Column(
              children: List.generate(4, (optionIndex) {
                final optionColor = QuizTheme.optionColors[optionIndex % QuizTheme.optionColors.length];
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(QuizTheme.optionIcons[optionIndex % QuizTheme.optionIcons.length],
                          color: optionColor, size: 18),
                      const SizedBox(width: 6),
                      Radio<int>(value: optionIndex, activeColor: QuizTheme.primary),
                      Expanded(
                        child: TextField(
                          controller: q.optionControllers[optionIndex],
                          decoration: InputDecoration(
                            hintText: 'Option ${optionIndex + 1}',
                            isDense: true,
                            filled: true,
                            fillColor: optionColor.withValues(alpha: 0.06),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: q.timeLimitSeconds.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Time limit (sec)'),
                  onChanged: (value) => q.timeLimitSeconds = int.tryParse(value) ?? 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  initialValue: q.points.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Points'),
                  onChanged: (value) => q.points = int.tryParse(value) ?? 100,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
