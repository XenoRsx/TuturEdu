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
//   one, e.g. parentUid/childUids, is NOT cleaned up - same accepted
//   trade-off as Admin's "Delete User" not touching Firebase Auth.)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../l10n/app_strings.dart';
import '../main.dart' show kBrandBlue, kInkMuted;
import '../utils/notification_sounds.dart';
import '../utils/push_notifications.dart';
import '../widgets/app_card.dart';
import '../widgets/section_label.dart';
import '../widgets/user_avatar.dart';
import 'login_screen.dart';
import 'student_announcements_screen.dart';
import 'teacher_announcements_screen.dart';
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
        title: Text(context.tr('Edit Profile')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: context.tr('Full Name')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.tr('Cancel')),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(context.tr('Save')),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;
    await _userRef.update({'name': result});
    if (!mounted) return;
    _showSnack(context.tr('Profile updated.'));
  }

  // ----- Change Password -----
  Future<void> _openChangePasswordDialog() async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('Change Password')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: context.tr('Current Password'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: context.tr('New Password'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: context.tr('Confirm New Password'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr('Cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.tr('Change')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final newPassword = newController.text;
    if (newPassword.length < 6) {
      if (!mounted) return;
      _showSnack(context.tr('New password must be at least 6 characters.'));
      return;
    }
    if (newPassword != confirmController.text) {
      if (!mounted) return;
      _showSnack(context.tr('New passwords do not match.'));
      return;
    }

    setState(() => _busy = true);
    try {
      final ok = await _reauthenticate(currentController.text);
      if (!ok) {
        if (!mounted) return;
        _showSnack(context.tr('Current password is incorrect.'));
        return;
      }
      await _authUser.updatePassword(newPassword);
      if (!mounted) return;
      _showSnack(context.tr('Password changed successfully.'));
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showSnack(context.tr('Error: {e}', {'e': e.message}));
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
    if (!mounted) return;
    _showSnack(
      context.tr(
        'Leave dates set. Chats will lock automatically during this period.',
      ),
    );
  }

  Future<void> _clearLeaveDates() async {
    await _userRef.update({
      'leaveStart': FieldValue.delete(),
      'leaveEnd': FieldValue.delete(),
    });
    if (!mounted) return;
    _showSnack(context.tr('Leave dates cleared.'));
  }

  // ----- My Subjects (Teacher self-service, see BLUEPRINT.md) -----
  // Same subjectCatalog + checkbox-list pattern as manage_users_screen.dart's
  // Admin-only "Edit Subjects", but scoped to _userRef (always the signed-in
  // user's own doc) - a Teacher choosing their OWN subjects needs no extra
  // Firestore rule, `users/{userId}` write already allows self-edit.
  Future<void> _editMySubjects(List<String> currentSubjects) async {
    final catalogSnapshot = await FirebaseFirestore.instance
        .collection('subjectCatalog')
        .orderBy('name')
        .get();
    final allSubjects = catalogSnapshot.docs
        .map((doc) => (doc.data())['name'] as String? ?? '')
        .where((name) => name.isNotEmpty)
        .toList();

    if (!mounted) return;

    if (allSubjects.isEmpty) {
      _showSnack(
        context.tr(
          'Subject catalog is empty. Ask an Admin to add subjects first.',
        ),
      );
      return;
    }

    final selected = Set<String>.from(currentSubjects);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.tr('My Subjects')),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: allSubjects.map((subject) {
                final checked = selected.contains(subject);
                return CheckboxListTile(
                  value: checked,
                  title: Text(subject),
                  onChanged: (value) {
                    setDialogState(() {
                      if (value == true) {
                        selected.add(subject);
                      } else {
                        selected.remove(subject);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.tr('Cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                await _userRef.update({'subjects': selected.toList()});
                if (context.mounted) Navigator.pop(context);
              },
              child: Text(context.tr('Save')),
            ),
          ],
        ),
      ),
    );
  }

  // ----- Appearance (Light/Dark/System, see BLUEPRINT.md) -----
  // Written to the account (not local device storage) so the choice follows
  // the user to any device they sign into - main.dart's authStateChanges()
  // listener applies it app-wide as soon as it's known, not just while this
  // screen happens to be open.
  Future<void> _setThemeMode(String mode) async {
    await _userRef.update({'themeMode': mode});
  }

  // Applied app-wide by main.dart's users/{uid} listener - set the notifier
  // too so the switch is instant rather than waiting on the round trip.
  Future<void> _setLanguage(String language) async {
    languageNotifier.value = localeFromLanguage(language);
    await _userRef.update({'language': language});
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
        title: Text(context.tr('Delete Account')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr(
                'This permanently deletes your account and profile. This '
                'cannot be undone. Enter your password to confirm.',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(labelText: context.tr('Password')),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr('Cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              context.tr('Delete Account'),
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
        if (!mounted) return;
        _showSnack(context.tr('Password is incorrect.'));
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
      if (!mounted) return;
      _showSnack(context.tr('Error: {e}', {'e': e.message}));
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
        title: Text(context.tr('Settings')),
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
          final themeMode = (data['themeMode'] as String?) ?? 'system';
          final mySubjects = List<String>.from(data['subjects'] ?? []);

          return AbsorbPointer(
            absorbing: _busy,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                AppCard(
                  child: Row(
                    children: [
                      UserAvatar(name: name, role: role, radius: 28),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyLarge?.color,
                              ),
                            ),
                            Text(
                              email,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.color,
                                fontSize: 12.5,
                              ),
                            ),
                            Text(
                              context.trRole(role),
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.color,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: context.tr('Edit Profile'),
                        onPressed: () => _openEditProfileDialog(name),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                SectionLabel(context.tr('Appearance')),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: RadioGroup<String>(
                    groupValue: themeMode,
                    onChanged: (value) {
                      if (value != null) _setThemeMode(value);
                    },
                    child: Column(
                      children: [
                        RadioListTile<String>(
                          value: 'system',
                          secondary: Icon(Icons.brightness_auto_outlined),
                          title: Text(context.tr('System')),
                          activeColor: kBrandBlue,
                        ),
                        Divider(height: 1),
                        RadioListTile<String>(
                          value: 'light',
                          secondary: Icon(Icons.light_mode_outlined),
                          title: Text(context.tr('Light')),
                          activeColor: kBrandBlue,
                        ),
                        Divider(height: 1),
                        RadioListTile<String>(
                          value: 'dark',
                          secondary: Icon(Icons.dark_mode_outlined),
                          title: Text(context.tr('Dark')),
                          activeColor: kBrandBlue,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Account-level, same as Appearance (BLUEPRINT.md 5.26).
                // Unset = device language, so show whichever is in effect.
                SectionLabel(context.tr('Language')),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: RadioGroup<String>(
                    groupValue:
                        (data['language'] as String?) ??
                        (context.isMalay ? 'ms' : 'en'),
                    onChanged: (value) {
                      if (value != null) _setLanguage(value);
                    },
                    child: const Column(
                      children: [
                        RadioListTile<String>(
                          value: 'en',
                          secondary: Icon(Icons.language),
                          title: Text('English'),
                          activeColor: kBrandBlue,
                        ),
                        Divider(height: 1),
                        RadioListTile<String>(
                          value: 'ms',
                          secondary: Icon(Icons.translate),
                          title: Text('Bahasa Melayu'),
                          activeColor: kBrandBlue,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                if (role == 'Teacher') ...[
                  SectionLabel(context.tr('Leave / Holiday')),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(
                            Icons.beach_access_outlined,
                            color: kBrandBlue,
                          ),
                          title: Text(
                            leaveStart != null && leaveEnd != null
                                ? context.tr('On leave: {from} - {to}', {
                                    'from': _formatDate(leaveStart),
                                    'to': _formatDate(leaveEnd),
                                  })
                                : context.tr('No leave dates set'),
                          ),
                          subtitle: Text(
                            context.tr(
                              'Chats lock automatically for this date range, same as manual Off-Duty.',
                            ),
                          ),
                          trailing: TextButton(
                            onPressed: () =>
                                _pickLeaveDates(leaveStart, leaveEnd),
                            child: Text(context.tr('Set')),
                          ),
                        ),
                        if (leaveStart != null && leaveEnd != null)
                          ListTile(
                            leading: const Icon(Icons.close, color: Colors.red),
                            title: Text(context.tr('Clear leave dates')),
                            onTap: _clearLeaveDates,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  SectionLabel(context.tr('My Subjects')),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      leading: const Icon(
                        Icons.menu_book_outlined,
                        color: kBrandBlue,
                      ),
                      title: Text(
                        mySubjects.isEmpty
                            ? context.tr('No subjects selected yet')
                            : mySubjects.join(', '),
                      ),
                      subtitle: Text(
                        context.tr(
                          'Subjects you teach - controls which chats/classes '
                          'you can manage attendance, performance, and '
                          'quizzes for.',
                        ),
                      ),
                      trailing: TextButton(
                        onPressed: () => _editMySubjects(mySubjects),
                        child: Text(context.tr('Edit')),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  SectionLabel(context.tr('Announcements')),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      leading: const Icon(
                        Icons.campaign_outlined,
                        color: kBrandBlue,
                      ),
                      title: Text(context.tr('My Announcements')),
                      subtitle: Text(
                        context.tr(
                          'Send a notice to every student in one of your '
                          'subjects',
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TeacherAnnouncementsScreen(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (role == 'Student' || role == 'Parent') ...[
                  SectionLabel(context.tr('Announcements')),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      leading: const Icon(
                        Icons.campaign_outlined,
                        color: kBrandBlue,
                      ),
                      title: Text(context.tr('Announcements')),
                      subtitle: Text(context.tr('Notices from your teachers')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const StudentAnnouncementsScreen(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                SectionLabel(context.tr('Notifications')),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: SwitchListTile(
                    secondary: const Icon(
                      Icons.notifications_outlined,
                      color: kBrandBlue,
                    ),
                    title: Text(context.tr('Push Notifications')),
                    subtitle: Text(
                      context.tr('New messages and warning letters'),
                    ),
                    value: pushEnabled,
                    onChanged: _togglePush,
                  ),
                ),
                const SizedBox(height: 16),

                SectionLabel(context.tr('Notification Sound')),
                AppCard(
                  padding: EdgeInsets.zero,
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
                          title: Text(context.tr(option.label)),
                          secondary: IconButton(
                            icon: const Icon(Icons.play_circle_outline),
                            tooltip: context.tr('Preview'),
                            onPressed: () => playNotificationSound(option.id),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                SectionLabel(context.tr('Account')),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(
                          Icons.lock_outline,
                          color: kBrandBlue,
                        ),
                        title: Text(context.tr('Change Password')),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _openChangePasswordDialog,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.logout, color: kInkMuted),
                        title: Text(context.tr('Log Out')),
                        onTap: _logout,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                SectionLabel(context.tr('Delete account')),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    leading: const Icon(
                      Icons.delete_forever,
                      color: Colors.red,
                    ),
                    title: Text(
                      context.tr('Delete Account'),
                      style: TextStyle(color: Colors.red),
                    ),
                    subtitle: Text(
                      context.tr('Permanently delete your account and profile'),
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
}
