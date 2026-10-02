// lib/utils/quiz_answer_keys.dart
//
// Teacher-side access to a quiz's answer keys (quizzes/{quizId}/answerKeys/
// {questionId}, see BLUEPRINT.md 9.8). Answer keys used to live on the
// question docs themselves as `correctIndex`, readable by any signed-in
// student; they now live in a subcollection only the quiz's own teacher can
// read, and scoring happens in Cloud Functions instead of on the student's
// device.
//
// loadAnswerKeysForOwnQuiz() also migrates a legacy quiz on the spot: any
// question doc still carrying `correctIndex` gets that value copied into
// answerKeys and the field stripped from the question. The Cloud Functions
// do the same migration server-side the first time a legacy quiz is played;
// this covers legacy quizzes nobody has played yet, as soon as their teacher
// opens them (quiz_list_screen.dart, create_quiz_screen.dart's edit mode,
// host_quiz_session_screen.dart).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<Map<String, int>> loadAnswerKeysForOwnQuiz(String quizId) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return {};

  final quizRef = FirebaseFirestore.instance.collection('quizzes').doc(quizId);
  final results = await Future.wait([
    quizRef.collection('answerKeys').where('createdBy', isEqualTo: uid).get(),
    quizRef.collection('questions').get(),
  ]);

  final keys = <String, int>{
    for (final doc in results[0].docs)
      if (doc.data()['correctIndex'] is int)
        doc.id: doc.data()['correctIndex'] as int,
  };

  final batch = FirebaseFirestore.instance.batch();
  var pending = false;
  for (final question in results[1].docs) {
    final legacy = question.data()['correctIndex'];
    if (legacy is! int) continue;
    keys.putIfAbsent(question.id, () => legacy);
    batch.set(quizRef.collection('answerKeys').doc(question.id), {
      'correctIndex': keys[question.id],
      'createdBy': uid,
    });
    batch.update(question.reference, {'correctIndex': FieldValue.delete()});
    pending = true;
  }
  if (pending) await batch.commit();

  return keys;
}
