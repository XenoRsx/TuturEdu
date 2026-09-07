// lib/screens/child_overview_screen.dart
//
// Parent screen: read-only view of a linked child's attendance and
// performance (see BLUEPRINT.md 5.9). Mirrors the calculations in
// attendance_overview_screen.dart (student-facing) and
// class_performance_screen.dart (teacher-facing) but scoped to one of the
// parent's linked children (users/{myUid}.childUids - a parent can have
// more than one) instead of the current user, with no editing/warning-
// letter actions - viewing only. A dropdown in the AppBar lets the parent
// switch which child they're looking at when there's more than one.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Same thresholds as attendance_overview_screen.dart / class_performance_screen.dart.
const int _kLowAttendanceThreshold = 75;
const int _kSafeMinPercentage = 70;
const int _kAtRiskMinPercentage = 50;

class ChildOverviewScreen extends StatefulWidget {
  const ChildOverviewScreen({super.key});

  @override
  State<ChildOverviewScreen> createState() => _ChildOverviewScreenState();
}

class _ChildInfo {
  final String uid;
  final String name;
  final List<String> subjects;

  const _ChildInfo({
    required this.uid,
    required this.name,
    required this.subjects,
  });
}

class _ChildOverviewScreenState extends State<ChildOverviewScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  bool _loading = true;
  List<_ChildInfo> _children = [];
  int _selectedIndex = 0;

  _ChildInfo? get _selectedChild =>
      _children.isEmpty ? null : _children[_selectedIndex];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadChildren();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadChildren() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final myDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();
    final childUids = List<String>.from(myDoc.data()?['childUids'] ?? []);

    if (childUids.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final childDocs = await Future.wait(
      childUids.map(
        (uid) => FirebaseFirestore.instance.collection('users').doc(uid).get(),
      ),
    );

    if (mounted) {
      setState(() {
        _children = childDocs
            .map(
              (doc) => _ChildInfo(
                uid: doc.id,
                name: doc.data()?['name'] ?? 'Student',
                subjects: List<String>.from(doc.data()?['subjects'] ?? []),
              ),
            )
            .toList();
        _selectedIndex = 0;
        _loading = false;
      });
    }
  }

  String _categoryFor(num percentage) {
    if (percentage >= _kSafeMinPercentage) return 'Safe';
    if (percentage >= _kAtRiskMinPercentage) return 'At-Risk';
    return 'Barred';
  }

  Color _categoryColor(num percentage) {
    if (percentage >= _kSafeMinPercentage) return Colors.green;
    if (percentage >= _kAtRiskMinPercentage) return Colors.orange;
    return Colors.red;
  }

  String _trendLabel(String trend) {
    switch (trend) {
      case 'critical':
        return 'Critical';
      case 'dropping':
        return 'Dropping';
      default:
        return 'Steady';
    }
  }

  Color _trendColor(String trend) {
    switch (trend) {
      case 'critical':
        return Colors.red;
      case 'dropping':
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  void _onChildChanged(int? index) {
    if (index == null) return;
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedChild;
    return Scaffold(
      appBar: AppBar(
        title: Text(_loading ? 'My Child' : (selected?.name ?? 'My Child')),
        backgroundColor: Colors.orange,
        actions: [
          // Child picker - only shown once there's actually a choice to
          // make (a parent can have more than one child linked, see
          // link_parent_child_screen.dart).
          if (_children.length > 1)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedIndex,
                    dropdownColor: Colors.orange.shade600,
                    iconEnabledColor: Colors.white,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    onChanged: _onChildChanged,
                    items: [
                      for (var i = 0; i < _children.length; i++)
                        DropdownMenuItem(
                          value: i,
                          child: Text(_children[i].name),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
        bottom: selected == null
            ? null
            : TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: const [
                  Tab(text: 'Attendance'),
                  Tab(text: 'Performance'),
                ],
              ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : selected == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.family_restroom,
                      size: 56,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Your account isn't linked to a student yet. "
                      'Please contact an Admin to link your child.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : TabBarView(
              // Keyed by uid so switching child rebuilds these tabs fresh
              // (the StreamBuilders/FutureBuilders inside would otherwise
              // keep showing the previous child's data momentarily).
              key: ValueKey(selected.uid),
              controller: _tabController,
              children: [
                _buildAttendanceTab(selected.uid),
                _buildPerformanceTab(selected.uid, selected.subjects),
              ],
            ),
    );
  }

  Widget _buildAttendanceTab(String childUid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('attendance')
          .doc(childUid)
          .collection('records')
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final records = snapshot.data!.docs;

        if (records.isEmpty) {
          return Center(
            child: Text(
              'No attendance records yet.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          );
        }

        final attended = records
            .where(
              (r) => (r.data() as Map<String, dynamic>)['status'] == 'present',
            )
            .length;
        final rate = attended / records.length * 100;
        final isLow = rate < _kLowAttendanceThreshold;

        return Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (isLow ? Colors.red : Colors.orange).withValues(
                  alpha: 0.06,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: (isLow ? Colors.red : Colors.orange).withValues(
                    alpha: 0.2,
                  ),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    '${rate.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: isLow ? Colors.red : Colors.orange,
                    ),
                  ),
                  const Text(
                    'Attendance Rate',
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$attended / ${records.length} classes attended',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (isLow) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.red,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Low attendance warning (below $_kLowAttendanceThreshold%)',
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                itemCount: records.length,
                itemBuilder: (context, index) {
                  final data = records[index].data() as Map<String, dynamic>;
                  final date = (data['date'] as Timestamp?)?.toDate();
                  final subject = data['subject'] ?? '';
                  final present = data['status'] == 'present';

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: Icon(
                        present ? Icons.check_circle : Icons.cancel,
                        color: present ? Colors.green : Colors.red,
                      ),
                      title: Text(subject),
                      subtitle: Text(date != null ? _formatDate(date) : ''),
                      trailing: Text(
                        present ? 'Present' : 'Absent',
                        style: TextStyle(
                          color: present ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPerformanceTab(String childUid, List<String> childSubjects) {
    if (childSubjects.isEmpty) {
      return Center(
        child: Text(
          'No subjects enrolled yet.',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    return FutureBuilder<List<DocumentSnapshot>>(
      future: Future.wait(
        childSubjects.map(
          (subject) => FirebaseFirestore.instance
              .collection('performance')
              .doc(subject)
              .collection('students')
              .doc(childUid)
              .get(),
        ),
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!;

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: childSubjects.length,
          itemBuilder: (context, index) {
            final subject = childSubjects[index];
            final data = docs[index].data() as Map<String, dynamic>?;
            final percentage = data?['percentage'] as num?;
            final trend = data?['trend'] as String? ?? 'steady';

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                title: Text(
                  subject,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: percentage == null
                    ? const Text('Not graded yet')
                    : Row(
                        children: [
                          Text(
                            _trendLabel(trend),
                            style: TextStyle(
                              color: _trendColor(trend),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: _categoryColor(
                                percentage,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _categoryFor(percentage),
                              style: TextStyle(
                                fontSize: 11,
                                color: _categoryColor(percentage),
                              ),
                            ),
                          ),
                        ],
                      ),
                trailing: percentage == null
                    ? null
                    : Text(
                        '${percentage.round()}%',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            );
          },
        );
      },
    );
  }
}
