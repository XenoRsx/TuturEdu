// lib/screens/manage_subjects_screen.dart
//
// Admin screen: manages the list of valid "Subject Level" entries in the
// system (e.g. "Add Maths Form 4"). This is a predefined catalog so
// Teachers/Students don't type subject names freely (avoids typos/
// inconsistency, e.g. "Add Maths Form 4" vs "add maths f4").
//
// Firestore: top-level collection `subjectCatalog`, each document has a
// `name` field (string, e.g. "Add Maths Form 4"). Note that `users.subjects`
// stores that name as a plain string, not a reference to the catalog
// document - renaming or deleting a catalog entry here does NOT retroactively
// touch any user profile that already has the old name assigned, so both
// actions warn the admin with how many profiles currently use it.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageSubjectsScreen extends StatefulWidget {
  const ManageSubjectsScreen({super.key});

  @override
  State<ManageSubjectsScreen> createState() => _ManageSubjectsScreenState();
}

class _ManageSubjectsScreenState extends State<ManageSubjectsScreen> {
  static const _otherOption = 'Other (type manually)';

  static const List<String> _subjectOptions = [
    'Bahasa Malaysia',
    'English',
    'Mathematics',
    'Add Maths',
    'Science',
    'Physics',
    'Chemistry',
    'Biology',
    'History',
    'Geography',
    'Accounting',
    'Economics',
    'Business Studies',
    'ICT',
    'Pendidikan Islam',
    'Moral Education',
    _otherOption,
  ];

  static const List<String> _levelOptions = [
    'Year 1',
    'Year 2',
    'Year 3',
    'Year 4',
    'Year 5',
    'Year 6',
    'Form 1',
    'Form 2',
    'Form 3',
    'Form 4',
    'Form 5',
    'Lower Six',
    'Upper Six',
    _otherOption,
  ];

  String? _selectedSubject;
  String? _selectedLevel;
  final _customSubjectController = TextEditingController();
  final _customLevelController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _customSubjectController.dispose();
    _customLevelController.dispose();
    super.dispose();
  }

  Future<bool> _nameExists(String name, {String? excludingDocId}) async {
    final matches = await FirebaseFirestore.instance
        .collection('subjectCatalog')
        .where('name', isEqualTo: name)
        .get();
    return matches.docs.any((doc) => doc.id != excludingDocId);
  }

  Future<int> _usageCount(String name) async {
    final result = await FirebaseFirestore.instance
        .collection('users')
        .where('subjects', arrayContains: name)
        .count()
        .get();
    return result.count ?? 0;
  }

  Future<void> _addSubject() async {
    final subject = _selectedSubject == _otherOption
        ? _customSubjectController.text.trim()
        : (_selectedSubject ?? '');
    final level = _selectedLevel == _otherOption
        ? _customLevelController.text.trim()
        : (_selectedLevel ?? '');

    if (subject.isEmpty || level.isEmpty) {
      _showSnack('Please choose both Subject and Level.');
      return;
    }

    final combined = '$subject $level';

    if (await _nameExists(combined)) {
      _showSnack('"$combined" is already in the catalog.');
      return;
    }

    await FirebaseFirestore.instance.collection('subjectCatalog').add({
      'name': combined,
      'createdAt': FieldValue.serverTimestamp(),
    });

    setState(() {
      _selectedSubject = null;
      _selectedLevel = null;
      _customSubjectController.clear();
      _customLevelController.clear();
    });
  }

  Future<void> _editSubject(String docId, String currentName) async {
    final controller = TextEditingController(text: currentName);
    final usageCount = await _usageCount(currentName);

    if (!mounted) return;

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Subject'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Subject Level'),
            ),
            if (usageCount > 0) ...[
              const SizedBox(height: 10),
              Text(
                'Currently assigned to $usageCount profile(s). Renaming here '
                'won\'t update those profiles automatically - re-assign them '
                'from Manage Users if needed.',
                style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty || newName == currentName) return;

    if (await _nameExists(newName, excludingDocId: docId)) {
      _showSnack('"$newName" already exists in the catalog.');
      return;
    }

    await FirebaseFirestore.instance
        .collection('subjectCatalog')
        .doc(docId)
        .update({'name': newName});
  }

  Future<void> _deleteSubject(String docId, String name) async {
    final usageCount = await _usageCount(name);

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Subject'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Remove "$name" from the catalog?'),
            if (usageCount > 0) ...[
              const SizedBox(height: 10),
              Text(
                'Currently assigned to $usageCount profile(s). Deleting it '
                'here won\'t remove it from those profiles.',
                style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseFirestore.instance
          .collection('subjectCatalog')
          .doc(docId)
          .delete();
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Subjects'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedSubject,
                          decoration: const InputDecoration(labelText: 'Subject'),
                          isExpanded: true,
                          items: _subjectOptions
                              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                              .toList(),
                          onChanged: (value) => setState(() => _selectedSubject = value),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedLevel,
                          decoration: const InputDecoration(labelText: 'Level'),
                          isExpanded: true,
                          items: _levelOptions
                              .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                              .toList(),
                          onChanged: (value) => setState(() => _selectedLevel = value),
                        ),
                      ),
                    ],
                  ),
                  if (_selectedSubject == _otherOption) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _customSubjectController,
                      decoration: const InputDecoration(
                        labelText: 'Custom Subject',
                        hintText: 'e.g. Mandarin',
                      ),
                    ),
                  ],
                  if (_selectedLevel == _otherOption) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _customLevelController,
                      decoration: const InputDecoration(
                        labelText: 'Custom Level',
                        hintText: 'e.g. Form 6',
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: _addSubject,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Subject'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search subjects...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('subjectCatalog')
                  .orderBy('name')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final subjects = snapshot.data!.docs.where((doc) {
                  final name = ((doc.data() as Map<String, dynamic>)['name'] ?? '')
                      .toString()
                      .toLowerCase();
                  return name.contains(_searchQuery);
                }).toList();

                if (subjects.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.menu_book_outlined, size: 56, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No subjects added yet.'
                              : 'No subjects match your search.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: subjects.length,
                  itemBuilder: (context, index) {
                    final doc = subjects[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final name = data['name'] ?? '';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade50,
                          child: const Icon(Icons.menu_book, color: Colors.blue),
                        ),
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                              tooltip: 'Edit',
                              onPressed: () => _editSubject(doc.id, name),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              tooltip: 'Delete',
                              onPressed: () => _deleteSubject(doc.id, name),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
