# Changelog

All notable changes to TuturEdu are documented here, grouped by development
milestone in chronological order. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/), adapted for an FYP project
without formal version tags — each entry is dated by when that milestone
was committed.

## [Unreleased]

### Fixed

- **Self-Paced Quiz stuck loading forever on first open** — `quizAttempts`'
  read rule checked `resource.data.studentUid` without guarding against
  `resource` being `null` on the very first read (before any attempt
  exists), so Firestore denied it and `attempt_quiz_screen.dart` had no
  error handling to surface that — just an infinite spinner. Fixed with the
  same `resource == null ||` guard already used for `attendance`, plus
  proper error handling in `_load()` so any future failure shows a message
  instead of spinning forever.

### Added

- **Self-Paced Quiz: retake, due date, and Teacher results** — teachers can
  now optionally allow retakes (choose a max attempt count) and/or set a due
  date when creating a Self-Paced quiz. Students see a "Retake Quiz" button
  after completing one (while attempts remain and before the due date), and
  are blocked from starting a quiz at all past its due date if they haven't
  attempted it. A new `quiz_results_screen.dart` (reachable from "My
  Quizzes") lets a teacher see every enrolled student's result — completed
  score/percentage/attempts or "not attempted yet" — for one quiz.
- **Claymorphism visual style** — every raised surface across the shared
  widget layer (`AppCard`, `IconTile`, `StatTile`, `MenuRow`, the received
  side of `MessageBubble`) now uses a soft dual-direction shadow (`main.dart`'s
  `clayShadows()` — a dark "sunken" shadow one side, a light "highlight" the
  other) instead of a single flat shadow. Surface fill colors sit close to
  the new pastel scaffold background (`kClayBaseLight`/`Dark`,
  `kClaySurfaceLight`/`Dark`) rather than contrasting white, since the puffy
  3D look comes from the shadow pair, not color contrast; buttons/icons
  stay solid brand blue/green. The Interactive Quiz's own gameplay screens
  keep their existing Kahoot-style look, unchanged.

- **Dark Mode** — a Light/Dark/System toggle in Settings' new "Appearance"
  section, saved to the account (`users/{uid}.themeMode`) rather than the
  device, so it follows the user to any device they sign into.
  `main.dart` listens for the signed-in account's preference and applies it
  app-wide via a global `ValueNotifier<ThemeMode>` as soon as it's known.
  `WelcomeScreen`/`LoginScreen`/`RegisterScreen`/`MfaVerificationScreen`
  intentionally keep their fixed appearance regardless of the toggle (no
  account is known yet at that point in the flow).
- **App-wide UI/UX polish pass** — a new shared widget layer
  (`lib/widgets/`: `AppCard`, `IconTile`, `StatTile`, `SectionLabel`,
  `EmptyState`, `LinearStatBar`, `MenuRow`, `DashboardHeader`,
  `MessageBubble`) generalizes the best hand-rolled patterns already in the
  app. Teacher/Student/Parent dashboards gained a real "home" header (a
  stat row + quick-action grid) instead of being just a chat list with a
  few AppBar icons; chat bubbles gained a subtle shadow and asymmetric
  corner; Attendance and Class Performance now show an actual progress bar
  for percentages instead of just numbers; quiz lists, Manage Users/
  Subjects, Admin Reports, and Settings all use consistent cards and empty
  states.
- **Multi-child support for the Parent Module** — a parent can now be
  linked to 2 or more students. `users/{parentUid}.childUid` (a single
  string) became `childUids` (an array, via `FieldValue.arrayUnion`/
  `arrayRemove`). `link_parent_child_screen.dart` can link additional
  children without clobbering earlier links; `manage_users_screen.dart`
  gained a "Manage Children" action listing every linked child with its
  own unlink button; `child_overview_screen.dart` shows a dropdown child
  picker in the AppBar once there's more than one (hidden entirely for
  the common single-child case, so no UX change for most parents).
  `firestore.rules`' `attendance` rule changed from an equality check to
  an array-membership check (`studentUid in ...childUids`) —
  `performance`/`warningLetters` rules already keyed off `parentUid`
  directly on each record and needed no changes.
- **Clean auth error dialogs** — Login and Sign Up no longer show raw
  Firebase exception text (e.g.
  `[firebase_auth/wrong-password] The password is invalid...`). A new
  `lib/utils/auth_error_dialog.dart` maps known `FirebaseAuthException`
  codes to plain-language messages and shows them in an `AlertDialog`
  instead of a `SnackBar` (a login failure shouldn't be missable).
  `user-not-found` and `wrong-password`/`invalid-credential` deliberately
  share one message ("Incorrect email or password") to avoid leaking
  which registered emails exist.
- **MFA (email OTP)** — mandatory second factor for every role on every
  fresh sign-in (login and self-registration alike). After password auth
  succeeds, both flows route through a new `MfaVerificationScreen` that
  requests a 6-digit code (via new `sendMfaCode`/`verifyMfaCode` Cloud
  Functions, emailed through Gmail SMTP/nodemailer) before letting the
  user reach their dashboard. Firebase Auth has no built-in "email OTP"
  multi-factor option (native support is SMS/TOTP only), so this is a
  from-scratch implementation: codes are SHA-256-hashed and stored in
  `mfaCodes/{uid}` with a 5-minute expiry and a 5-attempt cap; Firestore
  rules deny all client access to that collection outright. Scope note:
  this only fires on an actual sign-in call, not on `AuthGate` silently
  resuming a persisted session (Android/iOS) — see BLUEPRINT.md 5.17 for
  the full trade-off rationale. Required a one-time manual setup (a Gmail
  App Password set as Cloud Functions secrets, sending from
  `tuturedu.support@gmail.com`) — done and confirmed working end-to-end.
  The email itself uses a branded HTML template (`buildMfaEmailHtml()` in
  `functions/index.js`) instead of plain text — a blue header bar, the
  code in a large letter-spaced box, and a footer with the centre's name.
- **Delete Message** (soft-delete) — long-press a chat bubble to delete it.
  Sender can delete their own message within 15 minutes of sending; an
  Admin can delete any message any time (moderation). This is one narrow,
  server-verified exception to messages otherwise being create-only
  (`firestore.rules`' `messages/{messageId}` now allows an `update` that
  is restricted to exactly the `deleted`/`deletedAt` fields — the original
  content is never cleared, just hidden behind the flag, so an audit trail
  survives). Deleted messages render as "This message was deleted" for
  everyone in the chat. See BLUEPRINT.md section 5.16.

### Changed

- `WelcomeScreen` reworked: added a top-right quick-access bar with small
  "Log In"/"Sign Up" links (in addition to the existing full-size buttons
  further down); the middle section is wrapped in a scrollable layout so
  nothing gets clipped on shorter screens/windows; and the "About Pusat
  Tuisyen Arena Matriks" content (story, "What We Offer", Operating Hours)
  now continues directly on the same page below the Log In/Sign Up
  buttons, rather than living on a separate screen you navigate to. The
  standalone `about_arena_matriks_screen.dart` (added 2026-08-16) was
  removed as part of this — the content moved, it wasn't dropped. The
  now-dangling "Learn more about us" link in `login_screen.dart` was
  removed along with it (its own existing blurb already names the centre).
  Followed up with a visual polish pass: the About story and "What We
  Offer" items now sit in elevated white cards, and a footer was added
  with links to the centre's real Facebook/Instagram/TikTok accounts
  (circular brand-colored buttons via the new `font_awesome_flutter`
  dependency, since Material Icons has no Instagram/TikTok logo) plus a
  copyright line.

---

## 2026-08-21 — Full Admin account deletion & URL phishing detection

### Added

- **Full Admin account deletion** — "Delete User" in Manage Users now calls
  a new `deleteUserAccount` callable Cloud Function (`functions/index.js`,
  `asia-southeast1`) that removes both the Firestore profile and the
  Firebase Authentication account in one call. Previously only the
  Firestore document was removed (the login account stayed active) since
  the client SDK can only ever delete the *currently signed-in* user's own
  Auth account — deleting someone else's needs the Admin SDK, hence the
  Cloud Function. The function re-verifies caller-is-Admin server-side
  before doing anything, never trusting the client alone.
- **URL Phishing Detection** (`lib/utils/phishing_detector.dart`) — chat
  messages are scanned for URLs and flagged if they match common phishing
  patterns: raw IP-literal hosts, the `@` URL trick, known link shorteners,
  punycode/IDN domains, and a short list of commonly-abused TLDs.
  Heuristic-only, client-side, no external API. This also introduces
  tappable links in chat text for the first time — previously message text
  was always static, only file-attachment links were tappable. Safe links
  open directly; flagged ones show a warning icon and require confirming
  an "Open Anyway" dialog first. Speced in BLUEPRINT.md section 11.

### Fixed

- Live Web deploy showed a blank page with no console error — the prior
  `flutter build web` had silently produced an incomplete `build/web`
  (missing `favicon.png`, `manifest.json`, `icons/`, and
  `flutter_service_worker.js`), likely from a stray `dart.exe` process
  locking files mid-build. `index.html` referenced those missing files,
  and Firebase Hosting's SPA rewrite served `index.html` for the
  unmatched requests instead of a 404, so the service worker fetched HTML
  instead of JS. Deleted `build/web`, rebuilt clean, verified all expected
  files existed, redeployed.

---

## 2026-08-16 — About page & Web file upload fix

### Added

- **About page** (`about_arena_matriks_screen.dart`) — a static "About Pusat
  Tuisyen Arena Matriks" page reachable before login from both the Welcome
  and Login screens. Gradient hero header with the centre's logo, a mission
  story section, a "What We Offer" list, and an Operating Hours banner
  (pulled live from `OfficeHours.officeHourText()`). No Firestore/Auth
  dependency by design, so it needed no security rule changes.

### Fixed

- Teachers (and every role) couldn't upload chat file attachments on Web —
  `storage.rules`' write check for `chats/{chatId}/attachments/{fileName}`
  did a `firestore.get(...).data.participants` lookup that never resolves
  during Web's resumable-upload session-start request (same category of
  bug as an earlier, already-documented `request.resource.size` quirk in
  the same rule). Confirmed via a live diagnostic test, then relaxed the
  write rule to `request.auth != null` — safe in practice since
  `firestore.rules`' message-create rule still requires a genuine
  participant before a file can appear as a real message to anyone. Read
  access (a plain GET, not resumable) stays strictly participant-only.

---

## 2026-08-11 — Session persistence fixes

### Fixed

- App was requiring a fresh login every time it was opened, even with a
  valid session. Root cause: `main.dart`'s `home:` was hardcoded to
  `WelcomeScreen`, ignoring Firebase Auth's own session persistence. Added
  an `AuthGate` root widget that checks `authStateChanges()` first and
  routes straight to the matching dashboard when a session exists.
- Corrected the tuition centre's name from "Arena Matrix" to the actual
  spelling, "Arena Matriks", across the login screen, README, BLUEPRINT,
  and web manifest/meta description.

### Changed

- Web builds now call `FirebaseAuth.setPersistence(Persistence.NONE)`
  before `runApp()`, so the Web app always requires a fresh sign-in on
  reload/reopen (shared/public browser assumption) — Android/iOS keep the
  persisted session from `AuthGate` as before.

---

## 2026-08-08 — Android release polish

### Added

- TuturEdu launcher icon replacing the default Flutter icon, across all 5
  Android mipmap densities.
- Selectable notification sounds: 3 options (Pop, Marimba, Double Tap) in
  Settings, stored on `users/{uid}.notificationSound`, Marimba as default.
  Plays in-app via `audioplayers` for foreground pushes, and drives the
  Android system notification sound for background pushes via the Cloud
  Function's FCM payload (Android-only; Web Push has no cross-browser API
  for custom background sound).

### Fixed

- The Android launcher icon was cropped with asymmetric margins, reading
  as tilted at small sizes — re-cropped tight to the mark's true content
  bounds and centered with equal margins on all densities.
- The Welcome screen's TuturEdu logo rendered tiny because the source PNG
  had ~60% blank canvas padding baked in on either side (a ~9.6:1 aspect
  ratio in a narrow column) — swapped in a trimmed copy and sized it up.
- The Login screen's Arena Matriks stakeholder logo (874×714, not square)
  was forced into an 84×84 `BoxFit.cover` box, cropping its edges —
  switched to `BoxFit.contain` in a box matching its real aspect ratio.

---

## 2026-08-08 — Class Performance, Attendance, Parent Module, Push, Settings

### Added

- **Class Performance Overview** + Warning Letter system (teacher grades
  students per subject, gets an auto-computed Steady/Dropping/Critical
  trend, can send a warning letter to the linked parent).
- **Attendance** — take attendance per subject/date, student-facing
  attendance rate + low-attendance warning below 75%.
- **Parent Module** — Admin-linked Parent↔Student accounts, a real chat-list
  dashboard for parents, a read-only Child Overview (attendance +
  performance), and a Warning Letters inbox.
- **On-Duty / Off-Duty** manual toggle so a teacher can lock their chats
  outside a sudden meeting/leave, even during scheduled office hours.
- **Interactive Quiz — Self-Paced mode** (same quizzes as Live Session, no
  timer/host, one attempt per student).
- **Admin Reports** — system-wide statistics dashboard.
- **Push Notifications** — Cloud Functions (2nd gen, `asia-southeast1`)
  triggered on new chat messages and warning letters, sent via FCM. Web
  Push VAPID key configured and live.
- **Settings screen** for every role — edit profile, change password, push
  notification toggle, logout, self-service account deletion, plus Teacher
  leave/holiday dates that auto-lock chats for that period.
- TuturEdu's own branding replacing the default Flutter web icon/title.

### Fixed

- A navigation bug where finishing a Live Session quiz's leaderboard
  ("Done" button) could land students back on the login screen despite a
  valid session, caused by `Navigator.popUntil(... route.isFirst)` landing
  on a buried `WelcomeScreen`/`LoginScreen` instead of the dashboard.

---

## 2026-08-07 — Interactive Quiz (Live Session) & Quick Replies

### Added

- **Interactive Quiz — Live Session**, Kahoot/Wayground-style: teacher
  creates a multiple-choice quiz and hosts a live session with a 6-digit
  join code; students join in real time, answer against a synced
  countdown, and see a final podium leaderboard.
- **Quick Reply chips** in chat (one-tap common replies).

### Changed

- README rewritten to match BLUEPRINT.md, which had drifted ahead
  (missing Admin, group chat, file uploads, quick replies, quiz module).

---

## 2026-08-06 — Group Chat, File Attachments, Search & Unread Badges

### Added

- **Group chat** — teacher creates a group per subject, manages members,
  members can leave; Group Info screen.
- **File attachments** — 3-layer validation (size, extension, magic
  number) before uploading to Firebase Storage; inline image previews,
  external open for documents.
- **User search + profile view**, both directions (Teacher ↔ Student).
- **Chat list redesign** — All/Individual/Groups tabs, unread badges, read
  receipts (sent/read ticks), OS-level app icon badge.
- Admin: Edit Subjects on user profiles, full subject catalog CRUD.

### Changed

- Full English UI pass across the app; shared Material 3 theme; Arena
  Matriks branding introduced.
- Tightened `firestore.rules` (group membership changes restricted to
  admin/self-leave) and added `storage.rules` for attachment access.
- Downgraded Android Gradle Plugin 9.0.1 → 8.13.0 and Gradle 9.1.0 → 8.13
  for compatibility with `file_picker`'s Kotlin build.

---

## 2026-07-29 — Admin Role

### Added

- **Admin Dashboard** with quick stats (student/teacher/parent counts).
- **Manage Users** — search, filter by role, change role, delete user.
- **Manage Subjects** — full CRUD for the `subjectCatalog` predefined
  Subject+Level list.
- `isAdmin()` Firestore rules helper; Admin permissions on `users` and
  `subjectCatalog`.

---

## 2026-07-10 — 2026-07-11 — Core Chat System

### Added

- Real-time chat between Student and Teacher via Cloud Firestore.
- **Office hour lock** — global Monday–Friday logic (`office_hours.dart`),
  plus a `kDebugMode`-guarded debug bypass for testing.
- Firestore security rules (`users`, `chats` collections).
- Chat list screen; Firestore composite index for chat queries.
- `README.md`, `BLUEPRINT.md`, and `CLAUDE.md` project documentation
  established.

---

## 2026-07-09 — Project Setup

### Added

- Initial Flutter project scaffold.
- Firebase project configuration (Authentication, Cloud Firestore).
- 3-role login system (Student / Teacher / Parent).
