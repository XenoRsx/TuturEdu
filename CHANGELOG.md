# Changelog

All notable changes to TuturEdu are documented here, grouped by development
milestone in chronological order. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/), adapted for an FYP project
without formal version tags — each entry is dated by when that milestone
was committed.

## [Unreleased]

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
