// lib/screens/settings_screen.dart
//
// Account settings, available to every role (see BLUEPRINT.md 5.14):
// - Edit Profile (name)
// - Change Password (re-authenticates first, since Firebase requires a
//   recent login for sensitive operations)
// - Leave / Holiday dates (Teacher only) - auto Off-Duty for that date
//   range, on top of the manual On-Duty/Off-Duty toggle (see 5.10) and the
//   automatic office-hour schedule. Consumed by chat_screen.dart's
//   _computeIsOfficeHour() via the same live teacher-duty listener.
// - Push Notifications on/off (users/{uid}.pushEnabled)
// - Notification Sound (users/{uid}.notificationSound, one of 3 options in
//   assets/sounds/ - default "Marimba" if unset, see lib/utils/
//   notification_sounds.dart and BLUEPRINT.md 5.15)
// - Log Out
// - Delete Account (self-service - re-authenticates, then deletes the
//   Firestore profile and the Firebase Auth account itself. Firebase lets a
//   user delete their OWN Auth account client-side with no Admin SDK, unlike
//   Admin deleting SOMEONE ELSE'S account which still needs a Cloud
//   Function - see BLUEPRINT.md 4.2. Any other account that links to this
//   one, e.g. parentUid/childUid, is NOT cleaned up - same accepted
//   trade-off as Admin's "Delete User" not touching Firebase Auth.)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../main.dart' show kBrandBlue, kInkDark, kInkMuted;
import '../utils/notification_sounds.dart';
import '../utils/push_notifications.dart';
import 'login_screen.dart';
import 'welcome_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;

  User get _authUser => FirebaseAuth.instance.currentUser!;

  DocumentReference<Map<String, dynamic>> get _userRef =>
      FirebaseFirestore.instance.collection('users').doc(_authUser.uid);

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _reauthenticate(String password) async {
    final email = _authUser.email;
    if (email == null || password.isEmpty) return false;
    try {
      await _authUser.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
      return true;
    } on FirebaseAuthException {
      return false;
    }
  }

  // ----- Edit Profile -----
  Future<void> _openEditProfileDialog(String currentName) async {
    final controller = TextEditingController(text: currentName);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Profile'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Full Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;
    await _userRef.update({'name': result});
    _showSnack('Profile updated.');
  }

  // ----- Change Password -----
  Future<void> _openChangePasswordDialog() async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current Password'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New Password'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm New Password',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Change'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final newPassword = newController.text;
    if (newPassword.length < 6) {
      _showSnack('New password must be at least 6 characters.');
      return;
    }
    if (newPassword != confirmController.text) {
      _showSnack('New passwords do not match.');
      return;
    }

    setState(() => _busy = true);
    try {
      final ok = await _reauthenticate(currentController.text);
      if (!ok) {
        _showSnack('Current password is incorrect.');
        return;
      }
      await _authUser.updatePassword(newPassword);
      _showSnack('Password changed successfully.');
    } on FirebaseAuthException catch (e) {
      _showSnack('Error: ${e.message}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ----- Leave / Holiday dates (Teacher only, see BLUEPRINT.md 5.14) -----
  Future<void> _pickLeaveDates(
    DateTime? currentStart,
    DateTime? currentEnd,
  ) async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      initialDateRange: currentStart != null && currentEnd != null
          ? DateTimeRange(start: currentStart, end: currentEnd)
          : null,
    );
    if (range == null) return;

    final start = DateTime(
      range.start.year,
      range.start.month,
      range.start.day,
    );
    final end = DateTime(
      range.end.year,
      range.end.month,
      range.end.day,
      23,
      59,
      59,
    );

    await _userRef.update({
      'leaveStart': Timestamp.fromDate(start),
      'leaveEnd': Timestamp.fromDate(end),
    });
    _showSnack(
      'Leave dates set. Chats will lock automatically during this period.',
    );
  }

  Future<void> _clearLeaveDates() async {
    await _userRef.update({
      'leaveStart': FieldValue.delete(),
      'leaveEnd': FieldValue.delete(),
    });
    _showSnack('Leave dates cleared.');
  }

  // ----- Push notifications on/off -----
  Future<void> _togglePush(bool enabled) async {
    await _userRef.update({'pushEnabled': enabled});
    if (enabled) {
      await registerPushToken();
    } else {
      await unregisterPushToken();
    }
  }

  // ----- Notification sound -----
  Future<void> _selectSound(String soundId) async {
    await _userRef.update({'notificationSound': soundId});
    await playNotificationSound(soundId);
  }

  // ----- Log out -----
  Future<void> _logout() async {
    await unregisterPushToken();
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  // ----- Delete account -----
  Future<void> _openDeleteAccountDialog() async {
    final passwordController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This permanently deletes your account and profile. This '
              'cannot be undone. Enter your password to confirm.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
          ],
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
              'Delete Account',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final ok = await _reauthenticate(passwordController.text);
      if (!ok) {
        _showSnack('Password is incorrect.');
        return;
      }

      await unregisterPushToken();
      await _userRef.delete();
      await _authUser.delete();

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      _showSnack('Error: ${e.message}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.blueGrey,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _userRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data()!;
          final name = data['name'] ?? '';
          final email = data['email'] ?? _authUser.email ?? '';
          final role = data['role'] ?? '';
          final pushEnabled = data['pushEnabled'] != false;
          final selectedSound =
              (data['notificationSound'] as String?) ??
              defaultNotificationSoundId;
          final leaveStart = (data['leaveStart'] as Timestamp?)?.toDate();
          final leaveEnd = (data['leaveEnd'] as Timestamp?)?.toDate();

          return AbsorbPointer(
            absorbing: _busy,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: kBrandBlue.withValues(alpha: 0.15),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: kBrandBlue,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: kInkDark,
                                ),
                              ),
                              Text(
                                email,
                                style: const TextStyle(
                                  color: kInkMuted,
                                  fontSize: 12.5,
                                ),
                              ),
                              Text(
                                role,
                                style: const TextStyle(
                                  color: kInkMuted,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Edit Profile',
                          onPressed: () => _openEditProfileDialog(name),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                if (role == 'Teacher') ...[
                  _sectionLabel('Leave / Holiday'),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(
                            Icons.beach_access_outlined,
                            color: kBrandBlue,
                          ),
                          title: Text(
                            leaveStart != null && leaveEnd != null
                                ? 'On leave: ${_formatDate(leaveStart)} - ${_formatDate(leaveEnd)}'
                                : 'No leave dates set',
                          ),
                          subtitle: const Text(
                            'Chats lock automatically for this date range, same as manual Off-Duty.',
                          ),
                          trailing: TextButton(
                            onPressed: () =>
                                _pickLeaveDates(leaveStart, leaveEnd),
                            child: const Text('Set'),
                          ),
                        ),
                        if (leaveStart != null && leaveEnd != null)
                          ListTile(
                            leading: const Icon(Icons.close, color: Colors.red),
                            title: const Text('Clear leave dates'),
                            onTap: _clearLeaveDates,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                _sectionLabel('Notifications'),
                Card(
                  child: SwitchListTile(
                    secondary: const Icon(
                      Icons.notifications_outlined,
                      color: kBrandBlue,
                    ),
                    title: const Text('Push Notifications'),
                    subtitle: const Text('New messages and warning letters'),
                    value: pushEnabled,
                    onChanged: _togglePush,
                  ),
                ),
                const SizedBox(height: 16),

                _sectionLabel('Notification Sound'),
                Card(
                  child: RadioGroup<String>(
                    groupValue: selectedSound,
                    onChanged: (value) {
                      if (value != null) _selectSound(value);
                    },
                    child: Column(
                      children: notificationSoundOptions.map((option) {
                        return RadioListTile<String>(
                          value: option.id,
                          activeColor: kBrandBlue,
                          title: Text(option.label),
                          secondary: IconButton(
                            icon: const Icon(Icons.play_circle_outline),
                            tooltip: 'Preview',
                            onPressed: () => playNotificationSound(option.id),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                _sectionLabel('Account'),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(
                          Icons.lock_outline,
                          color: kBrandBlue,
                        ),
                        title: const Text('Change Password'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _openChangePasswordDialog,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.logout, color: kInkMuted),
                        title: const Text('Log Out'),
                        onTap: _logout,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                _sectionLabel('Delete account'),
                Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.delete_forever,
                      color: Colors.red,
                    ),
                    title: const Text(
                      'Delete Account',
                      style: TextStyle(color: Colors.red),
                    ),
                    subtitle: const Text(
                      'Permanently delete your account and profile',
                    ),
                    onTap: _openDeleteAccountDialog,
                  ),
                ),
                if (_busy) ...[
                  const SizedBox(height: 16),
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12.5,
          color: kInkMuted,
        ),
      ),
    );
  }
}
