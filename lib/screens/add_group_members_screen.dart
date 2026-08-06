// lib/screens/add_group_members_screen.dart
//
// GroupAdmin-only screen: add more students to an existing group chat.
// Lists students enrolled in the group's subject who aren't already a
// participant, lets the admin check off who to add, then merges them into
// chats/{chatId}.participants via arrayUnion.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddGroupMembersScreen extends StatefulWidget {
  final String chatId;
  final String? subject;
  final List<String> existingParticipants;

  const AddGroupMembersScreen({
    super.key,
    required this.chatId,
    required this.subject,
    required this.existingParticipants,
  });

  @override
  State<AddGroupMembersScreen> createState() => _AddGroupMembersScreenState();
}

class _AddGroupMembersScreenState extends State<AddGroupMembersScreen> {
  final Set<String> _selectedUids = {};
  bool _saving = false;

  Future<void> _addSelected() async {
    if (_selectedUids.isEmpty) return;

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
        'participants': FieldValue.arrayUnion(_selectedUids.toList()),
      });
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Members'),
        backgroundColor: Colors.green,
      ),
      body: widget.subject == null
          ? const Center(child: Text('This group has no subject set.'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'Student')
                  .where('subjects', arrayContains: widget.subject)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final candidates = snapshot.data!.docs
                    .where((doc) => !widget.existingParticipants.contains(doc.id))
                    .toList();

                if (candidates.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 56, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text(
                            'Every student enrolled in "${widget.subject}" is '
                            'already in this group.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemCount: candidates.length,
                        itemBuilder: (context, index) {
                          final doc = candidates[index];
                          final name = doc['name'] ?? 'Unnamed';
                          final selected = _selectedUids.contains(doc.id);

                          return CheckboxListTile(
                            value: selected,
                            selected: selected,
                            selectedTileColor: Colors.green.withValues(alpha: 0.06),
                            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
                            secondary: CircleAvatar(
                              backgroundColor: Colors.green.shade100,
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: const TextStyle(color: Colors.green),
                              ),
                            ),
                            activeColor: Colors.green,
                            onChanged: (checked) {
                              setState(() {
                                if (checked == true) {
                                  _selectedUids.add(doc.id);
                                } else {
                                  _selectedUids.remove(doc.id);
                                }
                              });
                            },
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
                            onPressed: _selectedUids.isEmpty || _saving ? null : _addSelected,
                            icon: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.group_add),
                            label: Text(
                              _selectedUids.isEmpty
                                  ? 'Select students to add'
                                  : 'Add ${_selectedUids.length} member(s)',
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
                );
              },
            ),
    );
  }
}
