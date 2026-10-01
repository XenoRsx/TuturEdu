// lib/screens/quiz_leaderboard_view.dart
//
// Shared leaderboard UI for quiz Live Sessions - used for both the FINAL
// leaderboard (status 'ended') and the interim PER-QUESTION results screen
// (status 'question_results', see BLUEPRINT.md 9.5) by both the host
// (Teacher) and player (Student) screens, so the visual language stays
// identical. Top 3 shown as a podium, the rest as a plain ranked list.
//
// `pointsThisRound` (optional) drives the "+N pts" badge shown per player
// for the interim per-question screen - omit it for the final leaderboard,
// which only shows cumulative `score`. `footer` (optional) replaces the
// default "Done" button - the host passes a "Next Question"/"Show Final
// Leaderboard" button here for the interim screen, the student passes a
// passive "waiting for host" row (no action - only the host can write
// quizSessions, see firestore.rules).

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/quiz_theme.dart';

class QuizLeaderboardView extends StatelessWidget {
  final List<QueryDocumentSnapshot> participants;
  final VoidCallback? onDone;
  final String? myUid;
  final String title;
  final String? subtitle;
  final Map<String, int>? pointsThisRound;
  final Widget? footer;

  const QuizLeaderboardView({
    super.key,
    required this.participants,
    this.onDone,
    this.myUid,
    this.title = 'Final Leaderboard',
    this.subtitle,
    this.pointsThisRound,
    this.footer,
  });

  // Derives how many points each participant earned for ONE specific
  // question from their stored `answers.{questionId}.correct` flag - no
  // extra field needs writing on submit, this is computed fresh from data
  // that's already there. Not-yet-answered participants get 0.
  static Map<String, int> pointsEarnedForQuestion(
    List<QueryDocumentSnapshot> participants,
    String questionId,
    int questionPoints,
  ) {
    final result = <String, int>{};
    for (final doc in participants) {
      final data = doc.data() as Map<String, dynamic>;
      final answers = data['answers'] as Map<String, dynamic>?;
      final answer = answers?[questionId] as Map<String, dynamic>?;
      result[doc.id] = (answer?['correct'] == true) ? questionPoints : 0;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...participants]
      ..sort((a, b) {
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
          child: Column(
            children: [
              const Icon(
                Icons.emoji_events_rounded,
                size: 44,
                color: Colors.amberAccent,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ],
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
                    final delta = pointsThisRound?[doc.id];

                    return Container(
                      color: isMe
                          ? QuizTheme.primary.withValues(alpha: 0.06)
                          : null,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.deepPurple.shade50,
                          child: Text(
                            '${rank + 1}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          isMe ? '$name (You)' : name,
                          style: TextStyle(
                            fontWeight: isMe
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        trailing: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$score pts',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: QuizTheme.primaryDark,
                              ),
                            ),
                            if (delta != null)
                              Text(
                                delta > 0 ? '+$delta this round' : 'no points',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: delta > 0
                                      ? Colors.green.shade600
                                      : Colors.grey.shade500,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                footer ??
                (onDone != null
                    ? SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton(
                          onPressed: onDone,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: QuizTheme.primary,
                          ),
                          child: const Text('Done'),
                        ),
                      )
                    : const SizedBox.shrink()),
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
          final delta = pointsThisRound?[doc.id];

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
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                  Text(
                    '$score pts',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  if (delta != null)
                    Text(
                      delta > 0 ? '+$delta this round' : 'no points',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: delta > 0
                            ? Colors.green.shade600
                            : Colors.grey.shade500,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Container(
                    height: heights[rank],
                    decoration: BoxDecoration(
                      color: medal,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(10),
                      ),
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
