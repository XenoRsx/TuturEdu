// lib/screens/attendance_overview_screen.dart
//
// Student screen: view own attendance rate and history (see BLUEPRINT.md
// 5.8). Streams attendance/{myUid}/records ordered by date desc; the
// subject filter and rate/warning calculation happen client-side since a
// single student's own record count is always small.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Attendance rate below this percentage shows a low-attendance warning.
const int _kLowAttendanceThreshold = 75;

class AttendanceOverviewScreen extends StatefulWidget {
  const AttendanceOverviewScreen({super.key});

  @override
  State<AttendanceOverviewScreen> createState() =>
      _AttendanceOverviewScreenState();
}

class _AttendanceOverviewScreenState extends State<AttendanceOverviewScreen> {
  String _selectedSubject = 'All Subjects';

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('Please log in again.')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Attendance'),
        backgroundColor: Colors.blue,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('attendance')
            .doc(currentUser.uid)
            .collection('records')
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final allRecords = snapshot.data!.docs;

          if (allRecords.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy, size: 56, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text(
                    'No attendance records yet.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          final subjects = <String>{
            for (final r in allRecords)
              (r.data() as Map<String, dynamic>)['subject'] ?? '',
          }.where((s) => s.isNotEmpty).toList()..sort();

          final records = _selectedSubject == 'All Subjects'
              ? allRecords
              : allRecords
                    .where(
                      (r) =>
                          (r.data() as Map<String, dynamic>)['subject'] ==
                          _selectedSubject,
                    )
                    .toList();

          final attended = records
              .where(
                (r) =>
                    (r.data() as Map<String, dynamic>)['status'] == 'present',
              )
              .length;
          final total = records.length;
          final rate = total == 0 ? null : (attended / total * 100);
          final isLow = rate != null && rate < _kLowAttendanceThreshold;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedSubject,
                  decoration: const InputDecoration(labelText: 'Subject'),
                  items: ['All Subjects', ...subjects]
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (value) => setState(
                    () => _selectedSubject = value ?? 'All Subjects',
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (isLow ? Colors.red : Colors.blue).withValues(
                    alpha: 0.06,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: (isLow ? Colors.red : Colors.blue).withValues(
                      alpha: 0.2,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      rate == null ? 'No data' : '${rate.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: isLow ? Colors.red : Colors.blue,
                      ),
                    ),
                    const Text(
                      'Attendance Rate',
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$attended / $total classes attended',
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
      ),
    );
  }
}
