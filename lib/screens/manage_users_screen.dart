// lib/screens/manage_users_screen.dart
//
// Admin screen: list of all users in the system. Admin can:
// - Change a user's role (e.g. accidentally registered as Student, change to Teacher)
// - Delete an account (removes it from the Firestore users collection)
//
// Note: Delete here only removes the Firestore document, NOT the Firebase
// Authentication account (that needs Admin SDK/Cloud Function - see the note
// in _deleteUser). For MVP purposes, this is enough to effectively
// "deactivate" a user (they can no longer log in with a valid role).

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  String _searchQuery = '';
  String _roleFilter = 'All';

  final List<String> _roleOptions = ['Student', 'Teacher', 'Parent', 'Admin'];
  final List<String> _filterOptions = ['All', 'Student', 'Teacher', 'Parent', 'Admin'];

  Future<void> _changeRole(String uid, String currentRole) async {
    String selectedRole = currentRole;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Role'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => DropdownButtonFormField<String>(
            initialValue: selectedRole,
            items: _roleOptions
                .map((role) => DropdownMenuItem(value: role, child: Text(role)))
                .toList(),
            onChanged: (value) {
              if (value != null) setDialogState(() => selectedRole = value);
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .update({'role': selectedRole});
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _editSubjects(String uid, List<String> currentSubjects) async {
    final catalogSnapshot = await FirebaseFirestore.instance
        .collection('subjectCatalog')
        .orderBy('name')
        .get();
    final allSubjects = catalogSnapshot.docs
        .map((doc) => (doc.data())['name'] as String? ?? '')
        .where((name) => name.isNotEmpty)
        .toList();

    if (!mounted) return;

    if (allSubjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Subject catalog is empty. Add subjects in "Manage Subjects" first.',
          ),
        ),
      );
      return;
    }

    final selected = Set<String>.from(currentSubjects);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Subjects'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: allSubjects.map((subject) {
                final checked = selected.contains(subject);
                return CheckboxListTile(
                  value: checked,
                  title: Text(subject),
                  onChanged: (value) {
                    setDialogState(() {
                      if (value == true) {
                        selected.add(subject);
                      } else {
                        selected.remove(subject);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .update({'subjects': selected.toList()});
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteUser(String uid, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text(
          'Remove "$name" from the system? This deletes their profile data. '
          '(Their login account is not deleted automatically - remove it '
          'separately from Firebase Authentication console if needed.)',
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
      await FirebaseFirestore.instance.collection('users').doc(uid).delete();
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'Teacher':
        return Colors.green;
      case 'Parent':
        return Colors.orange;
      case 'Admin':
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Users'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search by name...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) =>
                      setState(() => _searchQuery = value.toLowerCase()),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    spacing: 8,
                    children: _filterOptions.map((role) {
                      final isSelected = _roleFilter == role;
                      return ChoiceChip(
                        label: Text(role),
                        selected: isSelected,
                        onSelected: (_) => setState(() => _roleFilter = role),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var users = snapshot.data!.docs;

                users = users.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final role = data['role'] ?? '';
                  final matchesSearch = name.contains(_searchQuery);
                  final matchesFilter = _roleFilter == 'All' || role == _roleFilter;
                  return matchesSearch && matchesFilter;
                }).toList();

                if (users.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 56, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text('No users found.', style: TextStyle(color: Colors.grey.shade600)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final doc = users[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final name = data['name'] ?? 'Unnamed';
                    final email = data['email'] ?? '';
                    final role = data['role'] ?? 'Student';
                    final subjects = List<String>.from(data['subjects'] ?? []);

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      leading: CircleAvatar(
                        backgroundColor: _roleColor(role).withValues(alpha: 0.15),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: TextStyle(color: _roleColor(role)),
                        ),
                      ),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        (role == 'Teacher' || role == 'Student') && subjects.isNotEmpty
                            ? '$email\n${subjects.join(', ')}'
                            : email,
                      ),
                      isThreeLine:
                          (role == 'Teacher' || role == 'Student') && subjects.isNotEmpty,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Chip(
                            label: Text(
                              role,
                              style: const TextStyle(fontSize: 11, color: Colors.white),
                            ),
                            backgroundColor: _roleColor(role),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ),
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'role') _changeRole(doc.id, role);
                              if (value == 'subjects') _editSubjects(doc.id, subjects);
                              if (value == 'delete') _deleteUser(doc.id, name);
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'role',
                                child: Text('Change Role'),
                              ),
                              if (role == 'Teacher' || role == 'Student')
                                const PopupMenuItem(
                                  value: 'subjects',
                                  child: Text('Edit Subjects'),
                                ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete User'),
                              ),
                            ],
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
