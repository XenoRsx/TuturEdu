// lib/screens/flagged_messages_screen.dart
//
// Admin screen: chat messages users have reported (see BLUEPRINT.md 5.22).
// Each open report shows who reported whom, the reason, and a snapshot of
// the message (Admin can't read `messages` directly - rules are
// participants-only - so the report carries its own copy). Two actions:
// - Delete Message: the existing Admin soft-delete on the original message
//   (deleted/deletedAt, same as chat_screen.dart), then resolve the report.
// - Dismiss: resolve the report without touching the message.
// Queried by `status` equality only and sorted client-side - no composite
// index needed, same habit as the announcements screens.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';

class FlaggedMessagesScreen extends StatefulWidget {
  const FlaggedMessagesScreen({super.key});

  @override
  State<FlaggedMessagesScreen> createState() => _FlaggedMessagesScreenState();
}

class _FlaggedMessagesScreenState extends State<FlaggedMessagesScreen> {
  final Map<String, String> _nameCache = {};
  final Set<String> _busy = {};

  Future<String> _name(String? uid) async {
    if (uid == null) return 'Unknown';
    if (_nameCache.containsKey(uid)) return _nameCache[uid]!;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final data = doc.data();
    final name = data == null
        ? 'Deleted user'
        : '${data['name'] ?? 'Unknown'} (${data['role'] ?? '-'})';
    _nameCache[uid] = name;
    return name;
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  Future<void> _resolve(
    String reportId,
    Map<String, dynamic> data, {
    required bool deleteMessage,
  }) async {
    if (deleteMessage) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Delete Message'),
          content: const Text(
            'The message will show as "This message was deleted" for '
            'everyone in the chat.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _busy.add(reportId));
    final db = FirebaseFirestore.instance;
    var action = deleteMessage ? 'deleted' : 'dismissed';
    try {
      if (deleteMessage) {
        try {
          await db
              .collection('chats')
              .doc(data['chatId'])
              .collection('messages')
              .doc(data['messageId'])
              .update({
                'deleted': true,
                'deletedAt': FieldValue.serverTimestamp(),
              });
        } on FirebaseException catch (e) {
          // The whole chat may already be gone ("Delete for Everyone") -
          // nothing left to delete, just close the report.
          if (e.code != 'not-found') rethrow;
          action = 'already_gone';
        }
      }
      await db.collection('reports').doc(reportId).update({
        'status': 'resolved',
        'action': action,
        'resolvedBy': FirebaseAuth.instance.currentUser?.uid,
        'resolvedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            deleteMessage ? 'Message deleted.' : 'Report dismissed.',
          ),
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: ${e.message}')));
    } finally {
      if (mounted) setState(() => _busy.remove(reportId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodySmall?.color;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flagged Messages'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reports')
            .where('status', isEqualTo: 'open')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = [...snapshot.data!.docs]..sort(_newestFirst);
          if (docs.isEmpty) {
            return const EmptyState(
              icon: Icons.verified_user_outlined,
              title: 'No flagged messages',
              subtitle: 'Reported chat messages will appear here.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
              final text = (data['messageText'] as String?) ?? '';
              final attachment = data['attachmentName'] as String?;
              final note = (data['note'] as String?) ?? '';
              final busy = _busy.contains(doc.id);

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.flag,
                            color: Colors.orange,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              data['reason'] ?? 'Other',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (createdAt != null)
                            Text(
                              _formatDate(createdAt),
                              style: TextStyle(fontSize: 11, color: muted),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      FutureBuilder<List<String>>(
                        future: Future.wait([
                          _name(data['reportedUid']),
                          _name(data['reportedBy']),
                        ]),
                        builder: (context, names) => Text(
                          names.hasData
                              ? 'Sender: ${names.data![0]}\n'
                                    'Reported by: ${names.data![1]}'
                              : 'Loading...\n',
                          style: TextStyle(fontSize: 12, color: muted),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          [
                            if (text.isNotEmpty) text,
                            if (attachment != null) '📎 $attachment',
                          ].join('\n'),
                        ),
                      ),
                      if (note.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Note: $note',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: muted,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      if (busy)
                        const Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: EdgeInsets.all(8),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      else
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () =>
                                  _resolve(doc.id, data, deleteMessage: false),
                              child: const Text('Dismiss'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.delete_outline, size: 18),
                              label: const Text('Delete Message'),
                              onPressed: () =>
                                  _resolve(doc.id, data, deleteMessage: true),
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
    );
  }
}

int _newestFirst(QueryDocumentSnapshot a, QueryDocumentSnapshot b) {
  final ta = ((a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?);
  final tb = ((b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?);
  if (ta == null && tb == null) return 0;
  if (ta == null) return -1;
  if (tb == null) return 1;
  return tb.compareTo(ta);
}
