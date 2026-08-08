import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart' show kBrandBlue, kInkDark, kInkMuted;
import '../utils/push_notifications.dart';
import 'teacher_dashboard.dart';
import 'student_dashboard.dart';
import 'parent_dashboard.dart';
import 'admin_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  void _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email and password!')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 1. Sign in with Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      // 2. Fetch the role from Cloud Firestore
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (userDoc.exists) {
        String role = userDoc['role'];

        // Best-effort; never blocks the login flow (see push_notifications.dart).
        unawaited(registerPushToken());

        if (!mounted) return;

        // 3. Route the user to the dashboard matching their role.
        // pushAndRemoveUntil (not pushReplacement) - clears WelcomeScreen/
        // LoginScreen off the stack entirely, same as register_screen.dart's
        // post-signup routing. Without this, WelcomeScreen stays buried at
        // the bottom of the navigator stack forever, and any screen that
        // later does Navigator.popUntil(context, (route) => route.isFirst)
        // (e.g. the quiz leaderboard's "Done" button) lands back on the
        // login page even though the session is still valid.
        Widget destination;
        switch (role) {
          case 'Teacher':
            destination = const TeacherDashboard();
            break;
          case 'Student':
            destination = const StudentDashboard();
            break;
          case 'Parent':
            destination = const ParentDashboard();
            break;
          case 'Admin':
            destination = const AdminDashboard();
            break;
          default:
            throw 'Unrecognized role in the system.';
        }

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => destination),
          (route) => false,
        );
      } else {
        throw 'User data not found in the database. Make sure the account is registered in Firestore.';
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF4FAF7), Color(0xFFEAF3FB)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: kInkDark),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      _buildArenaMatrixBranding(),
                      const SizedBox(height: 28),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Welcome back',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: kInkDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Log in to continue to your chats',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: kInkMuted),
                            ),
                            const SizedBox(height: 24),
                            TextField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _passwordController,
                              decoration: const InputDecoration(
                                labelText: 'Password',
                                prefixIcon: Icon(Icons.lock_outline),
                              ),
                              obscureText: true,
                              onSubmitted: (_) => _login(),
                            ),
                            const SizedBox(height: 22),
                            SizedBox(
                              height: 52,
                              child: _isLoading
                                  ? const Center(
                                      child: CircularProgressIndicator(),
                                    )
                                  : ElevatedButton(
                                      onPressed: _login,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: kBrandBlue,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text(
                                        'Log In',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Short blurb about Pusat Tuisyen Arena Matrix, the tuition centre this
  // TuturEdu platform serves. Logo loads from
  // assets/images/arena_matrix_logo.png - falls back to a placeholder icon
  // if that file hasn't been added yet (avoids a crash).
  Widget _buildArenaMatrixBranding() {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.asset(
            'assets/images/arena_matrix_logo.png',
            // Source is 874x714 (~1.22:1), not square - BoxFit.cover was
            // cropping the shield's left/right points to force it into a
            // square box. BoxFit.contain + a box matching that aspect
            // ratio shows the whole logo uncropped.
            height: 130,
            width: 159,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Container(
              height: 130,
              width: 159,
              decoration: BoxDecoration(
                color: kBrandBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.school, size: 42, color: kBrandBlue),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Pusat Tuisyen Arena Matrix',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: kInkDark,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'TuturEdu is the official chat platform for Pusat Tuisyen Arena '
          'Matrix, connecting students, parents & tutors in one safe '
          'conversation space, in line with the tuition centre\'s operating '
          'hours.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: kInkMuted, height: 1.4),
        ),
      ],
    );
  }
}
