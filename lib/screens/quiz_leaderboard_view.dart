// lib/screens/quiz_leaderboard_view.dart
//
// Shared final-leaderboard UI for quiz Live Sessions - used by both the
// host (Teacher) and player (Student) screens so the visual language stays
// identical. Top 3 shown as a podium, the rest as a plain ranked list.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/quiz_theme.dart';

class QuizLeaderboardView extends StatelessWidget {
  final List<QueryDocumentSnapshot> participants;
  final VoidCallback onDone;
  final String? myUid;

  const QuizLeaderboardView({
    super.key,
    required this.participants,
    required this.onDone,
    this.myUid,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = [...participants]..sort((a, b) {
        final scoreA = (a.data() as Map<String, dynamic>)['score'] as int? ?? 0;
        final scoreB = (b.data() as Map<String, dynamic>)['score'] as int? ?? 0;
        return scoreB.compareTo(scoreA);
      });

    return Column(
      children: [
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(gradient: QuizTheme.heroGradient),
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: const Column(
            children: [
              Icon(Icons.emoji_events_rounded, size: 44, color: Colors.amberAccent),
              SizedBox(height: 8),
              Text(
                'Final Leaderboard',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
        ),
        if (sorted.isNotEmpty) _buildPodium(sorted.take(3).toList()),
        Expanded(
          child: sorted.length <= 3
              ? const SizedBox.shrink()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: sorted.length - 3,
                  itemBuilder: (context, index) {
                    final rank = index + 3;
                    final doc = sorted[rank];
                    final data = doc.data() as Map<String, dynamic>;
                    final name = data['name'] ?? 'Student';
                    final score = data['score'] ?? 0;
                    final isMe = myUid != null && doc.id == myUid;

                    return Container(
                      color: isMe ? QuizTheme.primary.withValues(alpha: 0.06) : null,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.deepPurple.shade50,
                          child: Text('${rank + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        title: Text(
                          isMe ? '$name (You)' : name,
                          style: TextStyle(fontWeight: isMe ? FontWeight.bold : FontWeight.normal),
                        ),
                        trailing: Text(
                          '$score pts',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: QuizTheme.primaryDark),
                        ),
                      ),
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
              child: OutlinedButton(
                onPressed: onDone,
                style: OutlinedButton.styleFrom(foregroundColor: QuizTheme.primary),
                child: const Text('Done'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPodium(List<QueryDocumentSnapshot> top) {
    // Display order left-to-right: 2nd, 1st, 3rd (classic podium layout).
    final order = <int>[if (top.length > 1) 1, 0, if (top.length > 2) 2];
    final heights = {0: 100.0, 1: 70.0, 2: 55.0};

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: order.map((rank) {
          final doc = top[rank];
          final data = doc.data() as Map<String, dynamic>;
          final name = data['name'] ?? 'Student';
          final score = data['score'] ?? 0;
          final medal = QuizTheme.medalColor(rank);
          final isMe = myUid != null && doc.id == myUid;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: rank == 0 ? 26 : 20,
                    backgroundColor: medal,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: QuizTheme.medalForeground(rank),
                        fontWeight: FontWeight.bold,
                        fontSize: rank == 0 ? 20 : 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isMe ? '$name (You)' : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                  ),
                  Text(
                    '$score pts',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: heights[rank],
                    decoration: BoxDecoration(
                      color: medal,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                    ),
                    alignment: Alignment.topCenter,
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '${rank + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: QuizTheme.medalForeground(rank),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
