// lib/screens/student_announcements_screen.dart
//
// Student screen: announcements for every subject this student is enrolled
// in (see BLUEPRINT.md 5.19), newest first. Unread ones (student's uid not
// in announcements.readBy) are tinted/bold like
// parent_warning_letters_screen.dart's unacknowledged letters; opening one
// shows the full message and marks it read via arrayUnion - firestore.rules
// only lets a student append their OWN uid to readBy, nothing else.
//
// Query is `subjectLevel whereIn mySubjects` with no orderBy (sorted
// client-side) so it needs no composite index. whereIn caps at 30 values,
// far more subjects than any one student has; an empty subjects list is
// handled up front since an empty whereIn is an invalid query.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';

class StudentAnnouncementsScreen extends StatelessWidget {
  const StudentAnnouncementsScreen({super.key});

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

  Future<void> _open(
    BuildContext context,
    String uid,
    String id,
    Map<String, dynamic> data,
    bool isRead,
  ) async {
    // Marking read is best-effort - a failed write must never stop the
    // student from actually reading the announcement.
    if (!isRead) {
      try {
        await FirebaseFirestore.instance
            .collection('announcements')
            .doc(id)
            .update({
              'readBy': FieldValue.arrayUnion([uid]),
            });
      } catch (_) {}
    }
    if (!context.mounted) return;

    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['title'] ?? '',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${data['subjectLevel'] ?? ''} · ${data['teacherName'] ?? 'Teacher'}'
                  '${createdAt != null ? ' · ${_formatDate(createdAt)}' : ''}',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Theme.of(sheetContext).textTheme.bodySmall?.color,
                  ),
                ),
                const SizedBox(height: 16),
                SelectableText(
                  data['body'] ?? '',
                  style: const TextStyle(fontSize: 15, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Please log in again.')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcements'),
        backgroundColor: Colors.blue,
      ),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
        builder: (context, userSnapshot) {
          if (userSnapshot.hasError) {
            return Center(child: Text('Error: ${userSnapshot.error}'));
          }
          if (!userSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final subjects = List<String>.from(
            userSnapshot.data!.data()?['subjects'] ?? [],
          );
          if (subjects.isEmpty) {
            return const EmptyState(
              icon: Icons.menu_book_outlined,
              title: 'No subjects yet',
              subtitle:
                  'Announcements from your teachers will show up here once '
                  "you're enrolled in a subject.",
            );
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('announcements')
                .where('subjectLevel', whereIn: subjects.take(30).toList())
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
                  icon: Icons.campaign_outlined,
                  title: 'No announcements yet',
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final readBy = List<String>.from(data['readBy'] ?? []);
                  final isRead = readBy.contains(uid);
                  final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(
                      color: isRead
                          ? null
                          : Colors.blue.withValues(alpha: 0.08),
                      onTap: () => _open(context, uid, doc.id, data, isRead),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.campaign_outlined,
                            color: isRead ? Colors.grey : Colors.blue,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['title'] ?? '',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: isRead
                                        ? FontWeight.w500
                                        : FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${data['subjectLevel'] ?? ''} · ${data['teacherName'] ?? 'Teacher'}'
                                  '${createdAt != null ? ' · ${_formatDate(createdAt)}' : ''}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(
                                      context,
                                    ).textTheme.bodySmall?.color,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  data['body'] ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (!isRead)
                            Container(
                              width: 10,
                              height: 10,
                              margin: const EdgeInsets.only(left: 8, top: 4),
                              decoration: const BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// A just-sent announcement has a null createdAt until the server timestamp
// resolves - treat it as "newest" so it doesn't briefly sort to the bottom.
int _newestFirst(QueryDocumentSnapshot a, QueryDocumentSnapshot b) {
  final ta = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
  final tb = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
  if (ta == null && tb == null) return 0;
  if (ta == null) return -1;
  if (tb == null) return 1;
  return tb.compareTo(ta);
}
