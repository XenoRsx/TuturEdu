// lib/screens/manage_subjects_screen.dart
//
// Admin screen: urus senarai "Subject Level" yang sah dalam sistem
// (contoh: "Add Maths Form 4"). Ini predefined catalog supaya Teacher/
// Student tak taip subjek sendiri (elak typo/inconsistency, contoh
// "Add Maths Form 4" vs "add maths f4").
//
// Firestore: collection top-level `subjectCatalog`, setiap dokumen ada
// field `name` (string, contoh "Add Maths Form 4").

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageSubjectsScreen extends StatefulWidget {
  const ManageSubjectsScreen({super.key});

  @override
  State<ManageSubjectsScreen> createState() => _ManageSubjectsScreenState();
}

class _ManageSubjectsScreenState extends State<ManageSubjectsScreen> {
  final _subjectController = TextEditingController();
  final _levelController = TextEditingController();

  @override
  void dispose() {
    _subjectController.dispose();
    _levelController.dispose();
    super.dispose();
  }

  Future<void> _addSubject() async {
    final subject = _subjectController.text.trim();
    final level = _levelController.text.trim();

    if (subject.isEmpty || level.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in both Subject and Level.')),
      );
      return;
    }

    final combined = '$subject $level';

    await FirebaseFirestore.instance.collection('subjectCatalog').add({
      'name': combined,
      'createdAt': FieldValue.serverTimestamp(),
    });

    _subjectController.clear();
    _levelController.clear();
  }

  Future<void> _deleteSubject(String docId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Subject'),
        content: Text('Remove "$name" from the catalog?'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Subjects'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _subjectController,
                        decoration: const InputDecoration(
                          labelText: 'Subject',
                          hintText: 'e.g. Add Maths',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _levelController,
                        decoration: const InputDecoration(
                          labelText: 'Level',
                          hintText: 'e.g. Form 4',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
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
          const Divider(height: 1),
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

                final subjects = snapshot.data!.docs;

                if (subjects.isEmpty) {
                  return const Center(
                    child: Text('No subjects added yet.'),
                  );
                }

                return ListView.builder(
                  itemCount: subjects.length,
                  itemBuilder: (context, index) {
                    final doc = subjects[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final name = data['name'] ?? '';

                    return ListTile(
                      leading: const Icon(Icons.menu_book, color: Colors.blue),
                      title: Text(name),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _deleteSubject(doc.id, name),
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
