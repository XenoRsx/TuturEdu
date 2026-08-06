# TuturEdu

TuturEdu is a chat platform connecting Students, Teachers, and Parents, built using Flutter and Firebase. The system restricts conversations to business hours only, ensuring a clear boundary between working hours and personal time for teachers.

This project is developed as a Final Year Project (FYP) at Politeknik Metro Tasek Gelugor, with a tuition centre as the target stakeholder and use case.

Live demo: https://tuturedu-app.web.app/

## Features

- Welcome Screen — landing page with TuturEdu branding and options to log in or sign up
- Sign Up (Self Registration) — users can create their own account; Firebase Authentication and Firestore profile are created together
- Login & Role-based Access — the system identifies user roles (Student / Teacher / Parent / Admin) after login and routes them to their respective dashboards
- Real-time Chat — conversations update live using Cloud Firestore
- Group Chat (in progress) — screen code written for teachers to create group conversations for a class; not yet integrated into the live app
- Find Teacher — students can search for and start a conversation with a teacher
- Business Hour Lock — chat is automatically locked outside business hours (Monday–Friday, 9:00 AM–5:00 PM)
- Overtime Mode — outside business hours, teachers can reply immediately ("Reply Now") or schedule a reply to auto-send once business hours resume
- Admin Dashboard — manage user accounts (view, change role, remove) and manage the subject/level catalog used across the app
- Firestore Security Rules — each conversation can only be accessed by its participants; admin actions are restricted to accounts with the Admin role

## Tech Stack

- Framework: Flutter
- Backend: Firebase (Authentication, Cloud Firestore, Hosting)
- Language: Dart

## Project Structure

```
lib/
├── main.dart                     # App entry point (loads WelcomeScreen)
├── firebase_options.dart         # Firebase configuration (auto-generated)
├── models/
│   └── user_model.dart           # User data model
├── screens/
│   ├── welcome_screen.dart       # Landing screen (Log In / Sign Up)
│   ├── register_screen.dart      # Self sign-up screen
│   ├── login_screen.dart         # Login screen
│   ├── student_dashboard.dart
│   ├── teacher_dashboard.dart
│   ├── parent_dashboard.dart
│   ├── teacher_list_screen.dart  # Student search & select teacher
│   ├── chat_screen.dart          # Real-time chat screen (1:1 and group) with office hour lock
│   ├── chat_list_screen.dart     # List of active conversations
│   ├── create_group_chat_screen.dart # Teacher: create a group chat (written, not yet integrated)
│   ├── admin_dashboard.dart      # Admin hub with quick stats
│   ├── manage_users_screen.dart  # Admin: manage user accounts
│   └── manage_subjects_screen.dart # Admin: manage subject/level catalog (written, not yet integrated)
└── utils/
    ├── office_hours.dart         # Business hour check logic
    └── file_validator.dart       # File upload validation (extension + magic number) — not yet wired into chat_screen.dart
```

## Firestore

### Data Structure

```
users (collection)
  └── {uid}
        ├── uid
        ├── email
        ├── name
        ├── role: "Student" | "Teacher" | "Parent" | "Admin"
        └── subjects: array<string>   # e.g. ["Add Maths Form 4"]

subjectCatalog (collection)
  └── {autoId}
        ├── name          # e.g. "Add Maths Form 4"
        └── createdAt

chats (collection)
  └── {chatId}
        ├── participants: [uid1, uid2, ...]   # 2 for 1:1, N for group
        ├── isGroup: boolean
        ├── groupName (optional)              # only for group chats
        ├── groupAdmin (optional)             # uid of group creator
        ├── lastMessage
        ├── lastUpdated
        ├── messages (sub-collection)
        │     └── {messageId}
        │           ├── senderId
        │           ├── text
        │           ├── timestamp
        │           ├── attachmentUrl (optional, planned - not yet coded)
        │           ├── attachmentType (optional, planned - not yet coded)
        │           └── attachmentName (optional, planned - not yet coded)
        └── scheduledReplies (sub-collection)   # Overtime Mode
              └── {replyId}
                    ├── senderId
                    ├── text
                    ├── scheduledFor
                    └── status: "pending" | "sent"
```

### Deploy Security Rules

```bash
firebase deploy --only "firestore:rules"
```

## Deploy (Web)

```bash
flutter build web
firebase deploy --only hosting
```

## Development Status

- [x] Welcome screen
- [x] Sign up (self registration)
- [x] Login & role-based routing
- [x] Firebase Authentication + Firestore integration
- [x] Real-time chat between student & teacher
- [ ] Group chat (teacher-created, per subject/class) — code written, not yet integrated
- [x] Chat list (active conversations overview)
- [x] Business hour lock logic
- [x] Overtime Mode (Reply Now / Schedule Reply)
- [x] Admin dashboard, manage users
- [ ] Manage subjects (Admin) — code written, not yet integrated
- [x] Firestore security rules
- [ ] File upload with 3-layer validation (spec complete, not yet coded)
- [ ] Quick reply chips
- [ ] Interactive quiz (live session + self-paced)
- [ ] Class performance overview + warning letter system
- [ ] Attendance overview (student)
- [ ] Parent module (monitoring / chat with teacher)
- [ ] Push notifications

## Author

MOHAMAD SYAFIQ IRFAN BIN ABDUL RAHMAN (LEAD DEVELOPER)

SUTHESWARAN TAMILARASAN (CO DEVELOPER & TESTING)

HARVINT A/L SHAMUGANATHAN (CO DEVELOPER & UI/UX)

Developed as a Final Year Project (FYP) at Politeknik Metro Tasek Gelugor, using Flutter & Firebase.
