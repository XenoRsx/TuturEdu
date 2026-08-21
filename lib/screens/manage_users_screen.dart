// lib/screens/manage_users_screen.dart
//
// Admin screen: list of all users in the system. Admin can:
// - Change a user's role (e.g. accidentally registered as Student, change to Teacher)
// - Delete an account (Firebase Authentication + Firestore profile, both)
//
// Full deletion (not just the Firestore doc) goes through the
// deleteUserAccount Cloud Function (functions/index.js) - the client SDK can
// only ever delete the CURRENTLY signed-in user's own Auth account (see
// settings_screen.dart's self-service delete), there's no client-side way to
// remove someone else's. The function re-checks caller-is-Admin server-side
// before doing anything, same as every other Admin-only write already
// covered by firestore.rules' isAdmin() helper.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'link_parent_child_screen.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  String _searchQuery = '';
  String _roleFilter = 'All';
  final Map<String, String> _childNameCache = {};

  final List<String> _roleOptions = ['Student', 'Teacher', 'Parent', 'Admin'];
  final List<String> _filterOptions = [
    'All',
    'Student',
    'Teacher',
    'Parent',
    'Admin',
  ];

  Future<String> _getChildName(String childUid) async {
    final cached = _childNameCache[childUid];
    if (cached != null) return cached;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(childUid)
        .get();
    final name = doc.data()?['name'] ?? 'Unknown';
    _childNameCache[childUid] = name;
    return name;
  }

  Future<void> _linkChild(String parentUid, String parentName) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            LinkParentChildScreen(parentUid: parentUid, parentName: parentName),
      ),
    );
  }

  Future<void> _unlinkChild(String parentUid, String childUid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Unlink Child'),
        content: const Text('Remove this parent-student link?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Unlink', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final batch = FirebaseFirestore.instance.batch();
    batch.update(
      FirebaseFirestore.instance.collection('users').doc(parentUid),
      {'childUid': FieldValue.delete()},
    );
    batch.update(FirebaseFirestore.instance.collection('users').doc(childUid), {
      'parentUid': FieldValue.delete(),
    });
    await batch.commit();
  }

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
          'Permanently delete "$name"? This removes both their profile '
          'data and login account. This cannot be undone.',
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

    if (confirmed != true) return;

    try {
      await FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      ).httpsCallable('deleteUserAccount').call({'uid': uid});
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete "$name": ${e.message}')),
      );
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
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .snapshots(),
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
                  final matchesFilter =
                      _roleFilter == 'All' || role == _roleFilter;
                  return matchesSearch && matchesFilter;
                }).toList();

                if (users.isEmpty) {
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
                          'No users found.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
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
                    final childUid = data['childUid'] as String?;

                    Widget subtitle;
                    if ((role == 'Teacher' || role == 'Student') &&
                        subjects.isNotEmpty) {
                      subtitle = Text('$email\n${subjects.join(', ')}');
                    } else if (role == 'Parent' && childUid != null) {
                      subtitle = FutureBuilder<String>(
                        future: _getChildName(childUid),
                        builder: (context, snapshot) {
                          final childName = snapshot.data;
                          return Text(
                            childName == null
                                ? email
                                : '$email\nLinked to: $childName',
                          );
                        },
                      );
                    } else if (role == 'Parent') {
                      subtitle = Text('$email\nNot linked to a student yet');
                    } else {
                      subtitle = Text(email);
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 4,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: _roleColor(
                            role,
                          ).withValues(alpha: 0.15),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: TextStyle(color: _roleColor(role)),
                          ),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: subtitle,
                        isThreeLine:
                            ((role == 'Teacher' || role == 'Student') &&
                                subjects.isNotEmpty) ||
                            role == 'Parent',
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Chip(
                              label: Text(
                                role,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                ),
                              ),
                              backgroundColor: _roleColor(role),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'role') {
                                  _changeRole(doc.id, role);
                                }
                                if (value == 'subjects') {
                                  _editSubjects(doc.id, subjects);
                                }
                                if (value == 'link') _linkChild(doc.id, name);
                                if (value == 'unlink' && childUid != null) {
                                  _unlinkChild(doc.id, childUid);
                                }
                                if (value == 'delete') {
                                  _deleteUser(doc.id, name);
                                }
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
                                if (role == 'Parent')
                                  PopupMenuItem(
                                    value: childUid == null ? 'link' : 'unlink',
                                    child: Text(
                                      childUid == null
                                          ? 'Link Child'
                                          : 'Unlink Child',
                                    ),
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
