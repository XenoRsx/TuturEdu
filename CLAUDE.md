# CLAUDE.md

Project context for Claude Code. For full details, see `BLUEPRINT.md`.

## Project

TuturEdu — chat platform for a tuition centre (FYP, Politeknik METrO Tasek Gelugor).
Roles: **Student**, **Teacher**, **Parent**. Chat is locked outside office hours.

## Stack

- Flutter (mobile + web)
- Firebase: Authentication, Cloud Firestore, Storage, Hosting, Cloud Functions (2nd gen, `asia-southeast1`) — project is on the Blaze pay-as-you-go plan
  - Storage bucket: `tuturedu-app.firebasestorage.app` (US-EAST1, no-cost location — Firestore itself is `asia-southeast1`, different region is fine, they're independent products). `storage.rules` deployed — file attachments work end-to-end.
  - `functions/` is a separate Node.js project (not Dart/Flutter) — `npm install` inside it before deploying. Sends push notifications; see Status below for the one manual step still needed for Web.
- Live: https://tuturedu-app.web.app/

## Conventions

- Role value in Firestore is `"Teacher"`.
- Class/subject format: `"Subject Level"` string, e.g. `"Add Maths Form 4"`. No department/program/classGroup fields.
- Office hour: global, Mon–Fri 9AM–5PM, logic lives in `lib/utils/office_hours.dart`. Always call `OfficeHours.isOfficeHourNow()` — never hardcode time checks elsewhere.
  - Has a `debugForceOpen` flag guarded by `kDebugMode` for testing. Keep the guard — don't remove it.
  - `chat_screen.dart` doesn't use `isOfficeHourNow()` directly for gating — it wraps it in `_computeIsOfficeHour()`, which also folds in the chat's teacher's manual On-Duty/Off-Duty status (`users/{uid}.dutyStatus`) and Leave/Holiday date range (`leaveStart`/`leaveEnd`, set from Settings). Use that wrapper, not the raw office-hours check, anywhere chat-lock state is computed.
- App root is `lib/screens/auth_gate.dart` (`AuthGate`), not `WelcomeScreen` directly — `main.dart`'s `home:` points there. It's a `StreamBuilder` on `FirebaseAuth.authStateChanges()`: if a session already exists it fetches `users/{uid}.role` and routes straight to the matching dashboard, only falling back to `WelcomeScreen` when signed out (or the Firestore user doc is missing, in which case it signs out the dead session first). Without this, `home:` being hardcoded to `WelcomeScreen` was the cause of a real bug — Firebase Auth already persists sessions across app restarts, but the UI ignored that and always re-prompted for login.
- Navigation: always route post-auth screens with `pushAndRemoveUntil` (not `pushReplacement`) — `login_screen.dart`/`register_screen.dart` do this so `WelcomeScreen` never stays buried at the bottom of the stack. A stray `Navigator.popUntil(context, (route) => route.isFirst)` anywhere would otherwise land back on the login page even with a valid session (this exact bug happened once in the quiz leaderboard's "Done" button — see BLUEPRINT.md 5.13).
- Chat ID format: `{uid1}_{uid2}` with UIDs sorted alphabetically (see `user_search_screen.dart`).
- Messages are create-only — never allow update/delete (enforced in `firestore.rules` too).
- `TeacherDashboard`/`StudentDashboard`/`ParentDashboard` are thin wrappers around `ChatListScreen` (configured with role color + FAB) — they are the chat list itself, not a menu screen in front of it.
- Parent↔Student linking (`users/{uid}.parentUid`/`childUid`) is Admin-only, done via `link_parent_child_screen.dart` — there's no self-service way for a Parent to link their own child (by design, avoids anyone claiming to be any student's parent).
- Quiz `mode` is `"live"` | `"self_paced"` | `"both"`, chosen by the teacher in `create_quiz_screen.dart`. `quizAttempts/{quizId}_{studentUid}` (Self-Paced) uses a deterministic doc ID — same pattern as `attendance/{studentUid}/records/{subject}_{date}` — to get "already attempted?" checks down to a single `get()`, no query/index needed. Firestore only allows one `whereIn`/`in` clause per query, so `self_paced_quiz_list_screen.dart` filters on `mode` server-side and the student's own subjects client-side.
- Push notifications: Firestore can't call the FCM API directly — that's *why* `functions/` exists at all. `lib/utils/push_notifications.dart` only ever writes/removes this device's token to/from `users/{uid}.fcmTokens`; the actual sending happens in `functions/index.js`'s Firestore triggers. Web Push is live — `_webVapidKey` is filled in and the web build carrying it has been deployed. That key (Firebase Console → Cloud Messaging → Web configuration → "Generate key pair") is human-only, no CLI equivalent — keep that in mind if it ever needs regenerating.
- Self account deletion (Settings screen) is fully client-side — Firebase lets a user delete their *own* Auth account with no Admin SDK. Don't confuse this with Admin deleting *someone else's* account (Manage Users), which still needs the Cloud Function noted above as not built.
- Notification sound: 3 choices defined once in `lib/utils/notification_sounds.dart` (`notificationSoundOptions` + `defaultNotificationSoundId` = `option2_marimba`), selected in Settings and stored on `users/{uid}.notificationSound`. Each option's `id` doubles as the filename (`assets/sounds/{id}.mp3` for Flutter playback via `audioplayers`, and `android/app/src/main/res/raw/{id}.mp3` — a separate copy — for the Cloud Function to reference as `android.notification.sound` in the FCM payload). `functions/index.js` has its own `DEFAULT_SOUND` constant that must be kept in sync with the Dart default by hand (JS/Dart can't share a literal). Web Push has no cross-browser API for custom background sound, so this only fully works end-to-end on Android; foreground playback (any platform, app open) works via `playNotificationSoundForCurrentUser()` in `main.dart`'s `FirebaseMessaging.onMessage`.
- Android app icon is TuturEdu's own mark (all 5 `mipmap-*/ic_launcher.png` densities), not the Flutter default. `applicationId` is still the placeholder `com.example.tuturedu` and release builds are signed with the debug key — fine for sideloading (`flutter build apk --release`), not set up for Play Store distribution.
- Before implementing new features, check `BLUEPRINT.md` first — it's kept up to date with what's actually built vs. still speced-out (schema, logic flow, status markers ✅/🔲/💡).

## Structure

See `BLUEPRINT.md` section 7 for the full, current `lib/` file tree with status markers per file — it's kept in sync with the codebase and is more reliable than duplicating the list here.

## Status (see BLUEPRINT.md for full checklist)

Done: login/role routing + register + session persistence (AuthGate, no repeated login on app restart), real-time chat, office hour lock (+ debug bypass + overtime mode + manual On-Duty/Off-Duty toggle), Firestore rules, chat list (tabs + unread badges + read receipts), group chat (create/manage members), user search + profile view, Admin (manage users/subjects, link/unlink Parent-Student, Reports), file upload/attachments (Storage live, rules deployed), OS-level unread app badge, quick reply chips, Interactive Quiz (Live Session + Self-Paced), Class Performance Overview + Warning Letter, Attendance (take attendance + student overview), Parent Module (chat dashboard, Child Overview, Warning Letters inbox), Push Notifications (Cloud Functions deployed and live, Android custom sound), Settings (profile/password/push toggle/logout/self-delete account, Teacher Leave dates, Notification Sound), Schedule Message available to all roles (not Teacher-only), Android release APK with TuturEdu launcher icon.
Not done yet: full Admin account deletion (Admin deleting *someone else's* account needs a Cloud Function — `functions/` project now exists, so this is a smaller lift than before; not to be confused with the self-service Delete Account already built into Settings).

## Commands

```bash
flutter pub get
flutter run
flutter build web
firebase deploy --only "firestore:rules"
firebase deploy --only firestore:indexes
firebase deploy --only storage
firebase deploy --only hosting
firebase deploy --only functions   # cd functions && npm install first
```
