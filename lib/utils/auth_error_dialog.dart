// lib/utils/auth_error_dialog.dart
//
// Maps Firebase Auth errors to plain-language messages and shows them in
// an AlertDialog - not Firebase's raw
// "[firebase_auth/wrong-password] The password is invalid..." exception
// text, and not a SnackBar (too easy to miss/dismiss for something as
// important as "why didn't my login work").
//
// "Incorrect email or password" deliberately covers BOTH user-not-found
// and wrong-password/invalid-credential with the same message - revealing
// which one it was lets an attacker enumerate which emails have accounts.

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart' show kBrandBlue;

String _friendlyAuthMessage(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password. Please try again.';
      case 'invalid-email':
        return 'That doesn\'t look like a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled. Contact an Admin for help.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'email-already-in-use':
        return 'This email is already registered. Please log in instead.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
  // Custom messages thrown elsewhere in this codebase (e.g. "User data not
  // found in the database...") are already written to be human-readable -
  // show them as-is rather than hiding them behind a generic fallback.
  if (error is String) return error;
  return 'Something went wrong. Please try again.';
}

Future<void> showAuthErrorDialog(
  BuildContext context, {
  required String title,
  required Object error,
}) {
  return showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent),
          const SizedBox(width: 8),
          Expanded(child: Text(title)),
        ],
      ),
      content: Text(_friendlyAuthMessage(error)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          style: TextButton.styleFrom(foregroundColor: kBrandBlue),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
