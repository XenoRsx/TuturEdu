import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../l10n/app_strings.dart';
import '../main.dart' show kBrandBlue;
import '../utils/auth_error_dialog.dart';
import '../utils/push_notifications.dart';
import '../widgets/app_card.dart';
import 'mfa_verification_screen.dart';
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
        SnackBar(
          content: Text(context.tr('Please enter your email and password!')),
        ),
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
            throw context.tr('Unrecognized role in the system.');
        }

        // MFA (email OTP) is mandatory for every role - see BLUEPRINT.md
        // 5.17. MfaVerificationScreen does the actual pushAndRemoveUntil
        // to `destination` once the code is verified.
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => MfaVerificationScreen(destination: destination),
          ),
          (route) => false,
        );
      } else {
        if (!mounted) return;
        throw context.tr(
          'User data not found in the database. Make sure the account is registered in Firestore.',
        );
      }
    } catch (e) {
      if (mounted) {
        showAuthErrorDialog(
          context,
          title: context.tr('Login Failed'),
          error: e,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Firebase sends the reset email itself (sendPasswordResetEmail) - no
  // Cloud Function or custom email needed. The success message is
  // deliberately the same whether or not the email has an account, same
  // anti-enumeration reasoning as auth_error_dialog.dart's merged
  // "Incorrect email or password" message.
  Future<void> _forgotPassword() async {
    final controller = TextEditingController(
      text: _emailController.text.trim(),
    );
    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('Reset Password')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.tr(
                'Enter your account\'s email and we\'ll send you a link to '
                'set a new password.',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: context.tr('Email'),
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.tr('Cancel')),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(context.tr('Send Link')),
          ),
        ],
      ),
    );
    controller.dispose();

    if (email == null || email.isEmpty) return;

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      if (e.code != 'user-not-found') {
        if (mounted) {
          showAuthErrorDialog(
            context,
            title: context.tr('Reset Failed'),
            error: e,
          );
        }
        return;
      }
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('Check Your Email')),
        content: Text(
          context.tr(
            'If an account exists for {email}, a password reset link has '
            'been sent. Check your inbox (and spam folder).',
            {'email': email},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.tr('OK')),
          ),
        ],
      ),
    );
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
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    _buildArenaMatrixBranding(context),
                    const SizedBox(height: 28),
                    AppCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            context.tr('Welcome back'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.color,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.tr('Log in to continue to your chats'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(
                                context,
                              ).textTheme.bodySmall?.color,
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              labelText: context.tr('Email'),
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _passwordController,
                            decoration: InputDecoration(
                              labelText: context.tr('Password'),
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                            obscureText: true,
                            onSubmitted: (_) => _login(),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _isLoading ? null : _forgotPassword,
                              child: Text(context.tr('Forgot password?')),
                            ),
                          ),
                          const SizedBox(height: 8),
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
                                    child: Text(
                                      context.tr('Log In'),
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
    );
  }

  // Short blurb about Pusat Tuisyen Arena Matriks, the tuition centre this
  // TuturEdu platform serves. Logo loads from
  // assets/images/arena_matrix_logo.png - falls back to a placeholder icon
  // if that file hasn't been added yet (avoids a crash).
  Widget _buildArenaMatrixBranding(BuildContext context) {
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
        Text(
          'Pusat Tuisyen Arena Matriks',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          context.tr(
            'TuturEdu is the official chat platform for Pusat Tuisyen Arena '
            'Matriks, connecting students, parents & tutors in one safe '
            'conversation space, in line with the tuition centre\'s '
            'operating hours.',
          ),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            color: Theme.of(context).textTheme.bodySmall?.color,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
