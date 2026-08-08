// lib/screens/link_parent_child_screen.dart
//
// Admin screen: link a Parent account to a Student account (see
// BLUEPRINT.md 5.9). Writes both sides of the relationship in one batch -
// users/{parentUid}.childUid and users/{studentUid}.parentUid - so the two
// fields never go out of sync. Reachable from manage_users_screen.dart's
// "Link Child" action on a Parent row.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LinkParentChildScreen extends StatefulWidget {
  final String parentUid;
  final String parentName;

  const LinkParentChildScreen({
    super.key,
    required this.parentUid,
    required this.parentName,
  });

  @override
  State<LinkParentChildScreen> createState() => _LinkParentChildScreenState();
}

class _LinkParentChildScreenState extends State<LinkParentChildScreen> {
  String _searchQuery = '';
  bool _linking = false;

  Future<void> _linkTo(String studentUid, String studentName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Link Parent & Student'),
        content: Text(
          'Link ${widget.parentName} to $studentName? '
          "The parent will be able to view this student's attendance and "
          'performance, and message their teachers.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Link', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _linking = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      batch.update(
        FirebaseFirestore.instance.collection('users').doc(widget.parentUid),
        {'childUid': studentUid},
      );
      batch.update(
        FirebaseFirestore.instance.collection('users').doc(studentUid),
        {'parentUid': widget.parentUid},
      );
      await batch.commit();

      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _linking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Link Child for ${widget.parentName}'),
        backgroundColor: Colors.orange,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search students by name...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) =>
                  setState(() => _searchQuery = value.toLowerCase()),
            ),
          ),
          if (_linking) const LinearProgressIndicator(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'Student')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final students = snapshot.data!.docs.where((doc) {
                  final name =
                      ((doc.data() as Map<String, dynamic>)['name'] ?? '')
                          .toString()
                          .toLowerCase();
                  return name.contains(_searchQuery);
                }).toList();

                if (students.isEmpty) {
                  return Center(
                    child: Text(
                      'No students found.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final doc = students[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final name = data['name'] ?? 'Unnamed';
                    final email = data['email'] ?? '';
                    final alreadyLinkedToThisParent =
                        data['parentUid'] == widget.parentUid;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade100,
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.blue),
                        ),
                      ),
                      title: Text(name),
                      subtitle: Text(email),
                      trailing: alreadyLinkedToThisParent
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : null,
                      onTap: _linking || alreadyLinkedToThisParent
                          ? null
                          : () => _linkTo(doc.id, name),
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
