// lib/screens/join_quiz_screen.dart
//
// Student screen: enter a 6-digit join code to enter a teacher's Live
// Session. Only allowed while the session is still "waiting" (matches
// Kahoot-style behavior - no joining mid-quiz). See BLUEPRINT.md 9.3.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/quiz_theme.dart';
import 'live_quiz_play_screen.dart';

class JoinQuizScreen extends StatefulWidget {
  const JoinQuizScreen({super.key});

  @override
  State<JoinQuizScreen> createState() => _JoinQuizScreenState();
}

class _JoinQuizScreenState extends State<JoinQuizScreen> {
  final _codeController = TextEditingController();
  bool _joining = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _joinSession() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      _showSnack('Enter the 6-digit join code.');
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() => _joining = true);

    try {
      final matches = await FirebaseFirestore.instance
          .collection('quizSessions')
          .where('joinCode', isEqualTo: code)
          .where('status', isEqualTo: 'waiting')
          .limit(1)
          .get();

      if (matches.docs.isEmpty) {
        _showSnack('No open session found for that code. Check with your teacher.');
        return;
      }

      final sessionDoc = matches.docs.first;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final myName = userDoc.data()?['name'] ?? 'Student';

      await sessionDoc.reference.collection('participants').doc(currentUser.uid).set({
        'name': myName,
        'score': 0,
        'answers': {},
      });

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LiveQuizPlayScreen(sessionId: sessionDoc.id),
        ),
      );
    } catch (e) {
      _showSnack('Failed to join: $e');
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: QuizTheme.pageGradient),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: const BoxDecoration(
                            gradient: QuizTheme.heroGradient,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.rocket_launch_rounded, size: 44, color: Colors.white),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          "Let's Play!",
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: QuizTheme.primaryDark),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Ask your teacher for the 6-digit game code',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                        const SizedBox(height: 28),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: QuizTheme.primary.withValues(alpha: 0.15),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              TextField(
                                controller: _codeController,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 32,
                                  letterSpacing: 10,
                                  fontWeight: FontWeight.w800,
                                  color: QuizTheme.primaryDark,
                                ),
                                decoration: InputDecoration(
                                  counterText: '',
                                  hintText: '------',
                                  hintStyle: TextStyle(color: Colors.grey.shade300, letterSpacing: 10),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: QuizTheme.primary.withValues(alpha: 0.06),
                                ),
                                onSubmitted: (_) => _joining ? null : _joinSession(),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: _joining ? null : _joinSession,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: QuizTheme.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 2,
                                  ),
                                  child: _joining
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Text(
                                          'Enter Game',
                                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
