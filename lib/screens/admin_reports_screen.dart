// lib/screens/admin_reports_screen.dart
//
// Admin screen: system-wide stats (replaces the old "Coming Soon"
// placeholder in admin_dashboard.dart, see BLUEPRINT.md 5.11). Uses
// Firestore count() aggregation queries on top-level collections only -
// cheap (no document bodies read) and no composite indexes needed, since
// none of these queries filter on more than one field.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/section_label.dart';
import '../widgets/stat_tile.dart';

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
                SectionLabel('Users ($totalUsers total)'),
                Row(
                  children: [
                    StatTile(
                      value: '${s['students']}',
                      label: 'Students',
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 10),
                    StatTile(
                      value: '${s['teachers']}',
                      label: 'Teachers',
                      color: Colors.green,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    StatTile(
                      value: '${s['parents']}',
                      label: 'Parents',
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 10),
                    StatTile(
                      value: '${s['admins']}',
                      label: 'Admins',
                      color: Colors.deepPurple,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const SectionLabel('Communication'),
                Row(
                  children: [
                    StatTile(
                      value: '${s['chats']}',
                      label: 'Total Chats',
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 10),
                    StatTile(
                      value: '${s['groupChats']}',
                      label: 'Group Chats',
                      color: Colors.green,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const SectionLabel('Interactive Quiz'),
                Row(
                  children: [
                    StatTile(
                      value: '${s['quizzes']}',
                      label: 'Quizzes Created',
                      color: Colors.deepPurple,
                    ),
                    const SizedBox(width: 10),
                    StatTile(
                      value: '${s['quizSessions']}',
                      label: 'Live Sessions',
                      color: Colors.deepPurple,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    StatTile(
                      value: '${s['quizAttempts']}',
                      label: 'Self-Paced Attempts',
                      color: Colors.deepPurple,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const SectionLabel('Academic'),
                Row(
                  children: [
                    StatTile(
                      value: '${s['subjects']}',
                      label: 'Subjects in Catalog',
                      color: Colors.teal,
                    ),
                    const SizedBox(width: 10),
                    StatTile(
                      value: '${s['warningLetters']}',
                      label: 'Warning Letters Sent',
                      color: Colors.red,
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
}
