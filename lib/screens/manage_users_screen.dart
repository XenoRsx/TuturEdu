// lib/screens/manage_users_screen.dart
//
// Admin screen: senarai semua user dalam sistem. Admin boleh:
// - Tukar role user (contoh: silap daftar sebagai Student, tukar jadi Teacher)
// - Padam akaun (buang dari Firestore users collection)
//
// Nota: Padam di sini hanya buang dokumen Firestore, BUKAN akaun Firebase
// Authentication (perlu Admin SDK/Cloud Function untuk itu - rujuk nota
// dalam _deleteUser). Untuk MVP, ini memadai untuk "deactivate" secara
// praktikal (user tak boleh login dengan role yang sah lagi).

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
                    border: OutlineInputBorder(),
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
                  return const Center(child: Text('No users found.'));
                }

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final doc = users[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final name = data['name'] ?? 'Unnamed';
                    final email = data['email'] ?? '';
                    final role = data['role'] ?? 'Student';

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _roleColor(role).withValues(alpha: 0.15),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: TextStyle(color: _roleColor(role)),
                        ),
                      ),
                      title: Text(name),
                      subtitle: Text(email),
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
                              if (value == 'delete') _deleteUser(doc.id, name);
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(value: 'role', child: Text('Change Role')),
                              PopupMenuItem(value: 'delete', child: Text('Delete User')),
                            ],
                          ),
                        ],
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
