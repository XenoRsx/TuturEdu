// lib/utils/notification_sounds.dart
//
// The 3 notification sound choices (assets/sounds/, see BLUEPRINT.md 5.15).
// Selection lives on users/{uid}.notificationSound - missing field defaults
// to `defaultNotificationSoundId` ("option2_marimba", the user's chosen
// default). Each option's `id` doubles as the Android raw resource name
// (android/app/src/main/res/raw/{id}.mp3 - same files, copied there too)
// so functions/index.js can set it as the FCM payload's
// android.notification.sound for background/system notifications. Used
// for:
// - Foreground playback (main.dart's FirebaseMessaging.onMessage) via
//   audioplayers - works on every platform.
// - Settings screen preview (tap to hear before choosing).
// Web Push has no cross-browser custom-sound support, so a background push
// arriving on Web just uses the browser/OS default notification sound -
// only Android gets the actual chosen sound file for background pushes.

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationSoundOption {
  final String id;
  final String label;
  final String assetPath;

  const NotificationSoundOption({
    required this.id,
    required this.label,
    required this.assetPath,
  });
}

const List<NotificationSoundOption> notificationSoundOptions = [
  NotificationSoundOption(
    id: 'option1_pop',
    label: 'Pop',
    assetPath: 'sounds/option1_pop.mp3',
  ),
  NotificationSoundOption(
    id: 'option2_marimba',
    label: 'Marimba',
    assetPath: 'sounds/option2_marimba.mp3',
  ),
  NotificationSoundOption(
    id: 'option3_double_tap',
    label: 'Double Tap',
    assetPath: 'sounds/option3_double_tap.mp3',
  ),
];

const String defaultNotificationSoundId = 'option2_marimba';

NotificationSoundOption notificationSoundById(String? id) {
  return notificationSoundOptions.firstWhere(
    (o) => o.id == id,
    orElse: () => notificationSoundOptions.firstWhere(
      (o) => o.id == defaultNotificationSoundId,
    ),
  );
}

final AudioPlayer _player = AudioPlayer();

/// Plays the given sound (or the default if [soundId] is null/unrecognized).
/// Best-effort - a playback failure (autoplay blocked, unsupported
/// platform, etc.) never throws.
Future<void> playNotificationSound(String? soundId) async {
  try {
    final option = notificationSoundById(soundId);
    await _player.play(AssetSource(option.assetPath));
  } catch (_) {}
}

/// Looks up the signed-in user's chosen sound and plays it. Used by the
/// foreground push-notification handler in main.dart.
Future<void> playNotificationSoundForCurrentUser() async {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) return;
  try {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();
    await playNotificationSound(doc.data()?['notificationSound'] as String?);
  } catch (_) {}
}
