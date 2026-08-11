// lib/screens/auth_gate.dart
//
// App root widget. Firebase Auth already persists the session across app
// restarts on its own - the bug was that main.dart's `home` was hardcoded
// to WelcomeScreen, so every cold start showed the login flow again even
// with a valid session sitting right there in FirebaseAuth.instance.
// currentUser. This widget checks that first and routes straight to the
// matching dashboard, falling back to WelcomeScreen only when genuinely
// signed out.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart' show kBrandBlue, kAppBackground;
import '../utils/push_notifications.dart';
import 'welcome_screen.dart';
import 'teacher_dashboard.dart';
import 'student_dashboard.dart';
import 'parent_dashboard.dart';
import 'admin_dashboard.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<Widget> _resolveDestination(User user) async {
    // Best-effort; never blocks routing (see push_notifications.dart).
    unawaited(registerPushToken());

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final role = doc.data()?['role'] as String?;
      switch (role) {
        case 'Teacher':
          return const TeacherDashboard();
        case 'Student':
          return const StudentDashboard();
        case 'Parent':
          return const ParentDashboard();
        case 'Admin':
          return const AdminDashboard();
        default:
          // No matching Firestore user doc (deleted/corrupt account) -
          // don't strand the user on a blank screen with a dead session.
          await FirebaseAuth.instance.signOut();
          return const WelcomeScreen();
      }
    } catch (_) {
      await FirebaseAuth.instance.signOut();
      return const WelcomeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _SplashLoading();
        }

        final user = authSnapshot.data;
        if (user == null) {
          return const WelcomeScreen();
        }

        return FutureBuilder<Widget>(
          future: _resolveDestination(user),
          builder: (context, destSnapshot) {
            if (destSnapshot.connectionState != ConnectionState.done) {
              return const _SplashLoading();
            }
            return destSnapshot.data ?? const WelcomeScreen();
          },
        );
      },
    );
  }
}

class _SplashLoading extends StatelessWidget {
  const _SplashLoading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: kAppBackground,
      body: Center(
        child: CircularProgressIndicator(color: kBrandBlue),
      ),
    );
  }
}
