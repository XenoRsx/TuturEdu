# CLAUDE.md

Project context for Claude Code. For full details, see `BLUEPRINT.md`.

## Project

TuturEdu — chat platform for a tuition centre (FYP, Politeknik METrO Tasek Gelugor).
Roles: **Student**, **Teacher**, **Parent**. Chat is locked outside office hours.

## Stack

- Flutter (mobile + web)
- Firebase: Authentication, Cloud Firestore, Storage, Hosting (project is on the Blaze pay-as-you-go plan)
  - Storage bucket: `tuturedu-app.firebasestorage.app` (US-EAST1, no-cost location — Firestore itself is `asia-southeast1`, different region is fine, they're independent products). `storage.rules` deployed — file attachments work end-to-end.
- Live: https://tuturedu-app.web.app/

## Conventions

- Role value in Firestore is `"Teacher"`.
- Class/subject format: `"Subject Level"` string, e.g. `"Add Maths Form 4"`. No department/program/classGroup fields.
- Office hour: global, Mon–Fri 9AM–5PM, logic lives in `lib/utils/office_hours.dart`. Always call `OfficeHours.isOfficeHourNow()` — never hardcode time checks elsewhere.
  - Has a `debugForceOpen` flag guarded by `kDebugMode` for testing. Keep the guard — don't remove it.
- Chat ID format: `{uid1}_{uid2}` with UIDs sorted alphabetically (see `user_search_screen.dart`).
- Messages are create-only — never allow update/delete (enforced in `firestore.rules` too).
- `TeacherDashboard`/`StudentDashboard` are thin wrappers around `ChatListScreen` (configured with role color + FAB) — they are the chat list itself, not a menu screen in front of it.
- Before implementing new features, check `BLUEPRINT.md` first — it's kept up to date with what's actually built vs. still speced-out (schema, logic flow, status markers ✅/🔲/💡).

## Structure

See `BLUEPRINT.md` section 7 for the full, current `lib/` file tree with status markers per file — it's kept in sync with the codebase and is more reliable than duplicating the list here.

## Status (see BLUEPRINT.md for full checklist)

Done: login/role routing + register, real-time chat, office hour lock (+ debug bypass + overtime mode), Firestore rules, chat list (tabs + unread badges + read receipts), group chat (create/manage members), user search + profile view, Admin (manage users/subjects), file upload/attachments (Storage live, rules deployed), OS-level unread app badge.
Not done yet: quick replies, class performance, attendance, parent chat module, push notifications.

## Commands

```bash
flutter pub get
flutter run
flutter build web
firebase deploy --only "firestore:rules"
firebase deploy --only firestore:indexes
firebase deploy --only storage
firebase deploy --only hosting
```
