// lib/screens/parent_dashboard.dart
//
// Parent home screen. The Parent chat module (view child's attendance,
// message the child's teacher) isn't built yet - see BLUEPRINT.md section
// 4.2 - so this stays a simple placeholder rather than pointing at a chat
// list that would always be empty.

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';

class ParentDashboard extends StatelessWidget {
  const ParentDashboard({super.key});

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parent Dashboard'),
        backgroundColor: Colors.orange.shade700,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: Colors.orange.shade100,
                child: Icon(Icons.family_restroom, size: 36, color: Colors.orange.shade700),
              ),
              const SizedBox(height: 20),
              const Text(
                'Welcome, Parent!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Viewing your child\'s attendance and messaging their '
                'teacher is coming soon to TuturEdu.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
