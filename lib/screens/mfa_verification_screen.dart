// lib/screens/mfa_verification_screen.dart
//
// Mandatory second factor (email OTP) shown right after a successful
// password sign-in or self-registration, before the user reaches their
// dashboard - see BLUEPRINT.md 5.17. Only login_screen.dart and
// register_screen.dart push this, passing the already-resolved dashboard
// `destination` widget to navigate to once verified, so this file never
// needs its own copy of the role -> dashboard switch logic.
//
// Scope note (see CLAUDE.md): this only runs at a FRESH sign-in. AuthGate
// still persists sessions across app restarts on Android/iOS same as
// before - this screen is not re-shown just because the app reopened with
// an already-valid session, only when signInWithEmailAndPassword /
// createUserWithEmailAndPassword actually run.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../main.dart' show kBrandBlue, kInkDark, kInkMuted;
import 'welcome_screen.dart';

class MfaVerificationScreen extends StatefulWidget {
  final Widget destination;

  const MfaVerificationScreen({super.key, required this.destination});

  @override
  State<MfaVerificationScreen> createState() => _MfaVerificationScreenState();
}

class _MfaVerificationScreenState extends State<MfaVerificationScreen> {
  final _codeController = TextEditingController();
  bool _sending = true;
  bool _verifying = false;
  String? _error;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  @override
  void initState() {
    super.initState();
    _sendCode();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _sendCode() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await _functions.httpsCallable('sendMfaCode').call();
      _startCooldown();
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        setState(() => _error = e.message ?? 'Could not send the code.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _resendCooldown = 30);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendCooldown--;
        if (_resendCooldown <= 0) timer.cancel();
      });
    });
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code.');
      return;
    }

    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await _functions.httpsCallable('verifyMfaCode').call({'code': code});
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => widget.destination),
        (route) => false,
      );
    } on FirebaseFunctionsException catch (e) {
      if (mounted) setState(() => _error = e.message ?? 'Incorrect code.');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  // "Cancel" signs out entirely rather than just popping - this screen is
  // the only route left on the stack (login/register already cleared
  // everything below via pushAndRemoveUntil), so there is no previous
  // screen to pop back to.
  Future<void> _cancel() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? 'your email';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.mark_email_read_outlined,
                  size: 56,
                  color: kBrandBlue,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Check your email',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: kInkDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _sending
                      ? 'Sending a 6-digit code to $email…'
                      : 'We sent a 6-digit code to $email',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13.5, color: kInkMuted),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    letterSpacing: 8,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: const InputDecoration(
                    counterText: '',
                    hintText: '------',
                  ),
                  onSubmitted: (_) => _verify(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.red, fontSize: 12.5),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  height: 50,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _verifying ? null : _verify,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kBrandBlue,
                      foregroundColor: Colors.white,
                    ),
                    child: _verifying
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Verify',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: (_resendCooldown > 0 || _sending)
                      ? null
                      : _sendCode,
                  child: Text(
                    _resendCooldown > 0
                        ? 'Resend code in ${_resendCooldown}s'
                        : 'Resend code',
                  ),
                ),
                TextButton(
                  onPressed: _cancel,
                  style: TextButton.styleFrom(foregroundColor: kInkMuted),
                  child: const Text('Cancel and sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
