// lib/utils/presence.dart
//
// Online status (BLUEPRINT.md 5.23): a `users/{uid}.lastSeen` heartbeat,
// written on sign-in, every [_interval] while the app is in the foreground,
// and once more when it goes to the background. Anyone reading it treats
// "lastSeen within [onlineWindow]" as Online. Started/stopped from
// main.dart's auth listener - no rules change needed, a user can already
// write any field on their own doc.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';

class Presence {
  Presence._();

  static const _interval = Duration(seconds: 60);

  /// Slightly over 2 heartbeats, so one late/missed write doesn't flicker
  /// someone to "offline".
  static const onlineWindow = Duration(minutes: 2);

  static String? _uid;
  static Timer? _timer;
  static AppLifecycleListener? _lifecycle;

  static void start(String uid) {
    if (_uid == uid) return;
    stop();
    _uid = uid;
    _beat();
    _timer = Timer.periodic(_interval, (_) => _beat());
    _lifecycle = AppLifecycleListener(
      onResume: () {
        _beat();
        _timer?.cancel();
        _timer = Timer.periodic(_interval, (_) => _beat());
      },
      onPause: () {
        _beat();
        _timer?.cancel();
      },
    );
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
    _lifecycle?.dispose();
    _lifecycle = null;
    _uid = null;
  }

  static Future<void> _beat() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Best-effort - a missing doc / offline device just skips a beat.
    }
  }

  static bool isOnline(DateTime? lastSeen) =>
      lastSeen != null && DateTime.now().difference(lastSeen) < onlineWindow;

  /// "Online", "Last seen 14:05" (today), or "Last seen 03/10/2026".
  static String describe(DateTime? lastSeen) {
    if (lastSeen == null) return '';
    if (isOnline(lastSeen)) return 'Online';
    final now = DateTime.now();
    final sameDay =
        now.year == lastSeen.year &&
        now.month == lastSeen.month &&
        now.day == lastSeen.day;
    String two(int n) => n.toString().padLeft(2, '0');
    return sameDay
        ? 'Last seen ${two(lastSeen.hour)}:${two(lastSeen.minute)}'
        : 'Last seen ${two(lastSeen.day)}/${two(lastSeen.month)}/${lastSeen.year}';
  }
}
