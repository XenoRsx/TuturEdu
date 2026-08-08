// lib/screens/admin_reports_screen.dart
//
// Admin screen: system-wide stats (replaces the old "Coming Soon"
// placeholder in admin_dashboard.dart, see BLUEPRINT.md 5.11). Uses
// Firestore count() aggregation queries on top-level collections only -
// cheap (no document bodies read) and no composite indexes needed, since
// none of these queries filter on more than one field.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  late Future<Map<String, int>> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = _fetchStats();
  }

  Future<int> _count(String collection) async {
    final result = await FirebaseFirestore.instance
        .collection(collection)
        .count()
        .get();
    return result.count ?? 0;
  }

  Future<int> _countWhere(
    String collection,
    String field,
    dynamic value,
  ) async {
    final result = await FirebaseFirestore.instance
        .collection(collection)
        .where(field, isEqualTo: value)
        .count()
        .get();
    return result.count ?? 0;
  }

  Future<Map<String, int>> _fetchStats() async {
    final results = await Future.wait([
      _countWhere('users', 'role', 'Student'),
      _countWhere('users', 'role', 'Teacher'),
      _countWhere('users', 'role', 'Parent'),
      _countWhere('users', 'role', 'Admin'),
      _count('chats'),
      _countWhere('chats', 'isGroup', true),
      _count('subjectCatalog'),
      _count('quizzes'),
      _count('quizSessions'),
      _count('quizAttempts'),
      _count('warningLetters'),
    ]);

    return {
      'students': results[0],
      'teachers': results[1],
      'parents': results[2],
      'admins': results[3],
      'chats': results[4],
      'groupChats': results[5],
      'subjects': results[6],
      'quizzes': results[7],
      'quizSessions': results[8],
      'quizAttempts': results[9],
      'warningLetters': results[10],
    };
  }

  Future<void> _refresh() async {
    final future = _fetchStats();
    setState(() => _statsFuture = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
        ],
      ),
      body: FutureBuilder<Map<String, int>>(
        future: _statsFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final s = snapshot.data!;
          final totalUsers =
              s['students']! + s['teachers']! + s['parents']! + s['admins']!;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _sectionTitle('Users ($totalUsers total)'),
                Row(
                  children: [
                    _statCard('Students', s['students']!, Colors.blue),
                    const SizedBox(width: 10),
                    _statCard('Teachers', s['teachers']!, Colors.green),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _statCard('Parents', s['parents']!, Colors.orange),
                    const SizedBox(width: 10),
                    _statCard('Admins', s['admins']!, Colors.deepPurple),
                  ],
                ),
                const SizedBox(height: 24),
                _sectionTitle('Communication'),
                Row(
                  children: [
                    _statCard('Total Chats', s['chats']!, Colors.blue),
                    const SizedBox(width: 10),
                    _statCard('Group Chats', s['groupChats']!, Colors.green),
                  ],
                ),
                const SizedBox(height: 24),
                _sectionTitle('Interactive Quiz'),
                Row(
                  children: [
                    _statCard(
                      'Quizzes Created',
                      s['quizzes']!,
                      Colors.deepPurple,
                    ),
                    const SizedBox(width: 10),
                    _statCard(
                      'Live Sessions',
                      s['quizSessions']!,
                      Colors.deepPurple,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _statCard(
                  'Self-Paced Attempts',
                  s['quizAttempts']!,
                  Colors.deepPurple,
                  fullWidth: true,
                ),
                const SizedBox(height: 24),
                _sectionTitle('Academic'),
                Row(
                  children: [
                    _statCard(
                      'Subjects in Catalog',
                      s['subjects']!,
                      Colors.teal,
                    ),
                    const SizedBox(width: 10),
                    _statCard(
                      'Warning Letters Sent',
                      s['warningLetters']!,
                      Colors.red,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: Colors.black54,
        ),
      ),
    );
  }

  Widget _statCard(
    String label,
    int count,
    Color color, {
    bool fullWidth = false,
  }) {
    final card = Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
    return fullWidth
        ? SizedBox(width: double.infinity, child: card)
        : Expanded(child: card);
  }
}
