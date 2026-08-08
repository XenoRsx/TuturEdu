// lib/utils/push_notifications.dart
//
// Push notifications (FCM, see BLUEPRINT.md 5.12). Registers this device's
// token onto the current user's profile (users/{uid}.fcmTokens, an array
// since one account can be signed in on multiple devices/tabs) so the
// Cloud Functions in functions/index.js can notify them of new chat
// messages / warning letters when they're not actively looking at the app.
//
// Best-effort throughout: every call is wrapped so a permission denial,
// unsupported browser, or missing VAPID key never breaks login - same
// philosophy as unread_badge.dart.
//
// Web Push specifically needs a VAPID key generated from Firebase Console
// (Project Settings > Cloud Messaging > Web configuration > Generate key
// pair). Paste it into _webVapidKey below once generated - until then,
// token registration on Web silently no-ops (native platforms don't need
// this constant at all).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

const String _webVapidKey =
    'BG5DcX-LFCmkPhr9yBQF2WoZB92e888RiQAhW9hETXA5cqAWu-6T7CIChRaY3L975h9Da_c-V071fhOjLP3LQ0g';

Future<String?> _currentToken() {
  return FirebaseMessaging.instance.getToken(
    vapidKey: _webVapidKey.isEmpty ? null : _webVapidKey,
  );
}

/// Requests notification permission and, if granted, saves this device's
/// FCM token onto the signed-in user's profile. Call after login/register.
///
/// Skips silently if the user has turned notifications off from Settings
/// (users/{uid}.pushEnabled == false) - otherwise logging back in on the
/// same device would quietly re-enable something they explicitly disabled.
/// Missing field = enabled, preserving behavior for every account that
/// existed before this preference was added.
Future<void> registerPushToken() async {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) return;
  if (kIsWeb && _webVapidKey.isEmpty) return;

  try {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();
    if (userDoc.data()?['pushEnabled'] == false) return;

    final settings = await FirebaseMessaging.instance.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    final token = await _currentToken();
    if (token == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .update({
          'fcmTokens': FieldValue.arrayUnion([token]),
        });
  } catch (_) {
    // Unsupported browser, permission denied, missing VAPID key, etc. -
    // push notifications are a nice-to-have, never block login over this.
  }
}

/// Removes this device's FCM token from the signed-in user's profile.
/// Call before signing out, so a shared/public device stops receiving
/// notifications meant for the account that was using it.
Future<void> unregisterPushToken() async {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) return;
  if (kIsWeb && _webVapidKey.isEmpty) return;

  try {
    final token = await _currentToken();
    if (token == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .update({
          'fcmTokens': FieldValue.arrayRemove([token]),
        });
  } catch (_) {}
}
