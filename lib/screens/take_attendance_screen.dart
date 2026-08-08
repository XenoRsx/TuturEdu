// lib/screens/take_attendance_screen.dart
//
// Teacher screen: mark attendance for one of their subjects on a given
// date (see BLUEPRINT.md 5.8). One record per student per subject+date,
// keyed by a deterministic document ID ("{subject}_{yyyy-MM-dd}") so
// re-marking the same class/date overwrites instead of duplicating.
//
// Existing statuses for the selected subject+date are fetched with plain
// one-time get()s (not a stream) - same pattern as
// host_quiz_session_screen.dart's _loadQuestions, appropriate here since
// class rosters are small and this screen doesn't need live updates.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TakeAttendanceScreen extends StatefulWidget {
  const TakeAttendanceScreen({super.key});

  @override
  State<TakeAttendanceScreen> createState() => _TakeAttendanceScreenState();
}

class _TakeAttendanceScreenState extends State<TakeAttendanceScreen> {
  bool _loadingSubjects = true;
  List<String> _teacherSubjects = [];
  String? _selectedSubject;
  DateTime _selectedDate = DateTime.now();

  bool _loadingRoster = false;
  List<QueryDocumentSnapshot> _students = [];
  final Map<String, bool> _presentMap = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadTeacherSubjects();
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

    if (_selectedSubject != null) await _loadRoster();
  }

  String get _dateStr =>
      '${_selectedDate.year.toString().padLeft(4, '0')}-'
      '${_selectedDate.month.toString().padLeft(2, '0')}-'
      '${_selectedDate.day.toString().padLeft(2, '0')}';

  String _recordIdFor(String subject) => '${subject}_$_dateStr';

  Future<void> _loadRoster() async {
    final subject = _selectedSubject;
    if (subject == null) return;

    setState(() => _loadingRoster = true);

    final studentsSnap = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'Student')
        .where('subjects', arrayContains: subject)
        .get();

    final students = studentsSnap.docs;
    final recordId = _recordIdFor(subject);

    final entries = await Future.wait(
      students.map((s) async {
        final recordDoc = await FirebaseFirestore.instance
            .collection('attendance')
            .doc(s.id)
            .collection('records')
            .doc(recordId)
            .get();
        return MapEntry(s.id, recordDoc.data()?['status'] as String?);
      }),
    );

    if (!mounted) return;
    setState(() {
      _students = students;
      _presentMap
        ..clear()
        ..addEntries(entries.map((e) => MapEntry(e.key, e.value != 'absent')));
      _loadingRoster = false;
    });
  }

  void _onSubjectChanged(String? value) {
    setState(() => _selectedSubject = value);
    _loadRoster();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() => _selectedDate = picked);
    await _loadRoster();
  }

  void _markAll(bool present) {
    setState(() {
      for (final s in _students) {
        _presentMap[s.id] = present;
      }
    });
  }

  Future<void> _save() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final subject = _selectedSubject;
    if (currentUser == null || subject == null || _students.isEmpty) return;

    setState(() => _saving = true);

    try {
      final batch = FirebaseFirestore.instance.batch();
      final recordId = _recordIdFor(subject);
      final dateOnly = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );

      for (final s in _students) {
        final present = _presentMap[s.id] ?? true;
        final ref = FirebaseFirestore.instance
            .collection('attendance')
            .doc(s.id)
            .collection('records')
            .doc(recordId);
        batch.set(ref, {
          'subject': subject,
          'date': Timestamp.fromDate(dateOnly),
          'status': present ? 'present' : 'absent',
          'markedBy': currentUser.uid,
          'markedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Attendance saved.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Take Attendance'),
        backgroundColor: Colors.green,
      ),
      body: _loadingSubjects
          ? const Center(child: CircularProgressIndicator())
          : _teacherSubjects.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.menu_book_outlined,
                      size: 56,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No subjects assigned to your account yet. Ask an '
                      'Admin to set your subjects first.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Card(
                  margin: const EdgeInsets.all(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Subject / Class',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedSubject,
                          items: _teacherSubjects
                              .map(
                                (s) =>
                                    DropdownMenuItem(value: s, child: Text(s)),
                              )
                              .toList(),
                          onChanged: _onSubjectChanged,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Date',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: _pickDate,
                          child: InputDecorator(
                            decoration: const InputDecoration(),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_formatDate(_selectedDate)),
                                const Icon(
                                  Icons.calendar_today,
                                  size: 18,
                                  color: Colors.green,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: _loadingRoster
                      ? const Center(child: CircularProgressIndicator())
                      : _students.isEmpty
                      ? Center(
                          child: Text(
                            'No students enrolled in this subject yet.',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${_students.length} student(s)',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      TextButton(
                                        onPressed: () => _markAll(true),
                                        child: const Text('Mark All Present'),
                                      ),
                                      TextButton(
                                        onPressed: () => _markAll(false),
                                        child: const Text('Mark All Absent'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ListView.builder(
                                itemCount: _students.length,
                                itemBuilder: (context, index) {
                                  final doc = _students[index];
                                  final name = doc['name'] ?? 'Unnamed';
                                  final present = _presentMap[doc.id] ?? true;

                                  return SwitchListTile(
                                    value: present,
                                    onChanged: (value) => setState(
                                      () => _presentMap[doc.id] = value,
                                    ),
                                    activeThumbColor: Colors.green,
                                    secondary: CircleAvatar(
                                      backgroundColor: Colors.green.shade100,
                                      child: Text(
                                        name.isNotEmpty
                                            ? name[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          color: Colors.green,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    subtitle: Text(
                                      present ? 'Present' : 'Absent',
                                      style: TextStyle(
                                        color: present
                                            ? Colors.green
                                            : Colors.red,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                ),
                if (_students.isNotEmpty)
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save),
                          label: Text(
                            _saving ? 'Saving...' : 'Save Attendance',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
