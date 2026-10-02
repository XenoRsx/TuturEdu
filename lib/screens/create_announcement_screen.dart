// lib/screens/create_announcement_screen.dart
//
// Teacher screen: post an announcement to every Student enrolled in one of
// the teacher's own subjects (see BLUEPRINT.md 5.19). Writes a single
// announcements/{id} doc - functions/index.js' onNewAnnouncement then pushes
// a notification to each enrolled student. firestore.rules re-checks that
// the subject really is one this teacher teaches, so the dropdown being
// limited to the teacher's own subjects is UX, not the security boundary.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../l10n/app_strings.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/section_label.dart';

class CreateAnnouncementScreen extends StatefulWidget {
  const CreateAnnouncementScreen({super.key});

  @override
  State<CreateAnnouncementScreen> createState() =>
      _CreateAnnouncementScreenState();
}

class _CreateAnnouncementScreenState extends State<CreateAnnouncementScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  bool _loading = true;
  bool _sending = false;
  List<String> _subjects = [];
  String? _selectedSubject;
  String _teacherName = '';

  @override
  void initState() {
    super.initState();
    _loadTeacher();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _loadTeacher() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final data = doc.data();
    final subjects = List<String>.from(data?['subjects'] ?? []);
    if (!mounted) return;
    setState(() {
      _subjects = subjects;
      _selectedSubject = subjects.isNotEmpty ? subjects.first : null;
      _teacherName = data?['name'] ?? 'Teacher';
      _loading = false;
    });
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _send() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (_selectedSubject == null) {
      _showSnack(context.tr('Please choose a subject.'));
      return;
    }
    if (title.isEmpty || body.isEmpty) {
      _showSnack(context.tr('Please fill in both the title and the message.'));
      return;
    }

    setState(() => _sending = true);
    try {
      await FirebaseFirestore.instance.collection('announcements').add({
        'title': title,
        'body': body,
        'subjectLevel': _selectedSubject,
        'teacherUid': uid,
        'teacherName': _teacherName,
        'createdAt': FieldValue.serverTimestamp(),
        'readBy': <String>[],
      });
      if (!mounted) return;
      _showSnack(
        context.tr('Announcement sent to {subject} students.', {
          'subject': _selectedSubject,
        }),
      );
      Navigator.pop(context);
    } catch (e) {
      _showSnack(context.tr('Failed to send announcement: {e}', {'e': e}));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('New Announcement')),
        backgroundColor: Colors.green,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _subjects.isEmpty
          ? EmptyState(
              icon: Icons.menu_book_outlined,
              title: context.tr('No subjects assigned yet'),
              subtitle: context.tr(
                'Pick your subjects in Settings first, then you can send '
                'announcements to those classes.',
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SectionLabel(context.tr('Send to')),
                AppCard(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedSubject,
                    decoration: InputDecoration(
                      labelText: context.tr('Subject / Class'),
                      prefixIcon: Icon(Icons.groups_outlined),
                    ),
                    items: _subjects
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedSubject = value),
                  ),
                ),
                const SizedBox(height: 16),
                SectionLabel(context.tr('Announcement')),
                AppCard(
                  child: Column(
                    children: [
                      TextField(
                        controller: _titleController,
                        textCapitalization: TextCapitalization.sentences,
                        maxLength: 80,
                        decoration: InputDecoration(
                          labelText: context.tr('Title'),
                          hintText: context.tr(
                            'e.g. Extra class this Saturday',
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _bodyController,
                        textCapitalization: TextCapitalization.sentences,
                        minLines: 4,
                        maxLines: 10,
                        maxLength: 1000,
                        decoration: InputDecoration(
                          labelText: context.tr('Message'),
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.campaign_outlined),
                    label: Text(
                      _sending
                          ? context.tr('Sending...')
                          : context.tr('Send Announcement'),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
