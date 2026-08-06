// lib/screens/create_group_chat_screen.dart
//
// Teacher screen: create a group chat for one of the subjects/classes they
// teach. Teacher picks a subject, selects which students (who are enrolled
// in that subject) to include, names the group, then a single chat document
// is created with isGroup: true and chatType: "group".
//
// Note: the group does NOT auto-update when a new student later enrolls in
// the same subject - the teacher would need to create a new group (see
// BLUEPRINT.md section 5.2a).

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

class CreateGroupChatScreen extends StatefulWidget {
  const CreateGroupChatScreen({super.key});

  @override
  State<CreateGroupChatScreen> createState() => _CreateGroupChatScreenState();
}

class _CreateGroupChatScreenState extends State<CreateGroupChatScreen> {
  final _groupNameController = TextEditingController();

  bool _loadingSubjects = true;
  bool _creating = false;
  List<String> _teacherSubjects = [];
  String? _selectedSubject;
  final Set<String> _selectedStudentUids = {};

  @override
  void initState() {
    super.initState();
    _loadTeacherSubjects();
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
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
  }

  void _onSubjectChanged(String? subject) {
    setState(() {
      _selectedSubject = subject;
      _selectedStudentUids.clear();
    });
  }

  Future<void> _createGroup() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final groupName = _groupNameController.text.trim();

    if (groupName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group name.')),
      );
      return;
    }

    if (_selectedStudentUids.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one student.')),
      );
      return;
    }

    setState(() => _creating = true);

    try {
      final participants = [currentUser.uid, ..._selectedStudentUids];

      final groupRef = FirebaseFirestore.instance.collection('chats').doc();

      await groupRef.set({
        'participants': participants,
        'isGroup': true,
        'chatType': 'group',
        'groupName': groupName,
        'groupAdmin': currentUser.uid,
        'subject': _selectedSubject,
        'lastUpdated': FieldValue.serverTimestamp(),
        'lastMessage': 'Group created',
      });

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: groupRef.id,
            otherUserName: groupName,
            isGroup: true,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Group Chat'),
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
                        Icon(Icons.menu_book_outlined, size: 56, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        const Text(
                          'No subjects assigned to your account yet. Ask an '
                          'Admin to set your subjects before creating a group.',
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
                                    (s) => DropdownMenuItem(value: s, child: Text(s)),
                                  )
                                  .toList(),
                              onChanged: _onSubjectChanged,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Group Name',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _groupNameController,
                              decoration: const InputDecoration(
                                hintText: 'e.g. Add Maths Form 4 - Batch A',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: _selectedSubject == null
                          ? Center(
                              child: Text(
                                'Select a subject first.',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            )
                          : StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('users')
                                  .where('role', isEqualTo: 'Student')
                                  .where('subjects', arrayContains: _selectedSubject)
                                  .snapshots(),
                              builder: (context, snapshot) {
                                if (snapshot.hasError) {
                                  return Center(
                                    child: Text('Error: ${snapshot.error}'),
                                  );
                                }
                                if (!snapshot.hasData) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }

                                final students = snapshot.data!.docs;

                                if (students.isEmpty) {
                                  return Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.people_outline,
                                          size: 56,
                                          color: Colors.grey.shade300,
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'No students enrolled in this subject yet.',
                                          style: TextStyle(color: Colors.grey.shade600),
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                final allSelected =
                                    _selectedStudentUids.length == students.length;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '${_selectedStudentUids.length} / ${students.length} selected',
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              color: Colors.black54,
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              setState(() {
                                                if (allSelected) {
                                                  _selectedStudentUids.clear();
                                                } else {
                                                  _selectedStudentUids
                                                    ..clear()
                                                    ..addAll(students.map((d) => d.id));
                                                }
                                              });
                                            },
                                            child: Text(
                                              allSelected ? 'Deselect All' : 'Select All',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: ListView.builder(
                                        itemCount: students.length,
                                        itemBuilder: (context, index) {
                                          final doc = students[index];
                                          final name = doc['name'] ?? 'Unnamed';
                                          final selected =
                                              _selectedStudentUids.contains(doc.id);

                                          return CheckboxListTile(
                                            value: selected,
                                            selected: selected,
                                            selectedTileColor: Colors.green.withValues(alpha: 0.06),
                                            title: Text(
                                              name,
                                              style: const TextStyle(fontWeight: FontWeight.w500),
                                            ),
                                            secondary: CircleAvatar(
                                              backgroundColor: Colors.green.shade100,
                                              child: Text(
                                                name.isNotEmpty
                                                    ? name[0].toUpperCase()
                                                    : '?',
                                                style: const TextStyle(color: Colors.green),
                                              ),
                                            ),
                                            activeColor: Colors.green,
                                            onChanged: (checked) {
                                              setState(() {
                                                if (checked == true) {
                                                  _selectedStudentUids.add(doc.id);
                                                } else {
                                                  _selectedStudentUids.remove(doc.id);
                                                }
                                              });
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _creating ? null : _createGroup,
                            icon: _creating
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.groups),
                            label: Text(_creating ? 'Creating...' : 'Create Group'),
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
