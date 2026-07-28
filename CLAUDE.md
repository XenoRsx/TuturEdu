# CLAUDE.md

Project context for Claude Code. For full details, see `BLUEPRINT.md`.

## Project

TuturEdu — chat platform for a tuition centre (FYP, Politeknik METrO Tasek Gelugor).
Roles: **Student**, **Teacher**, **Parent**. Chat is locked outside office hours.

## Stack

- Flutter (mobile + web)
- Firebase: Authentication, Cloud Firestore, Hosting
- Live: https://tuturedu-app.web.app/

## Conventions

- Role value in Firestore is `"Teacher"`.
- Class/subject format: `"Subject Level"` string, e.g. `"Add Maths Form 4"`. No department/program/classGroup fields.
- Office hour: global, Mon–Fri 9AM–5PM, logic lives in `lib/utils/office_hours.dart`. Always call `OfficeHours.isOfficeHourNow()` — never hardcode time checks elsewhere.
  - Has a `debugForceOpen` flag guarded by `kDebugMode` for testing. Keep the guard — don't remove it.
- Chat ID format: `{uid1}_{uid2}` with UIDs sorted alphabetically (see `teacher_list_screen.dart`).
- Messages are create-only — never allow update/delete (enforced in `firestore.rules` too).
- Before implementing new features, check `BLUEPRINT.md` first — several are already speced out there (file upload validation, overtime mode, class performance, etc.) with schema and logic flow decided.

## Structure

```
lib/
├── main.dart
├── firebase_options.dart
├── models/user_model.dart
├── screens/
│   ├── login_screen.dart
│   ├── student_dashboard.dart
│   ├── teacher_dashboard.dart
│   ├── parent_dashboard.dart
│   ├── teacher_list_screen.dart
│   ├── chat_list_screen.dart
│   └── chat_screen.dart
└── utils/office_hours.dart
```

## Status (see BLUEPRINT.md for full checklist)

Done: login/role routing, real-time chat, office hour lock (+ debug bypass), Firestore rules, chat list, tuition-centre data model.
Not done yet: file upload validation, overtime mode, quick replies, class performance, attendance, parent chat module, register screen, push notifications.

## Commands

```bash
flutter pub get
flutter run
flutter build web
firebase deploy --only "firestore:rules"
firebase deploy --only firestore:indexes
firebase deploy --only hosting
```
