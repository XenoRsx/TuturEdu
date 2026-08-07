# TuturEdu

TuturEdu is a chat platform connecting Students, Teachers, and Parents, built using Flutter and Firebase. The system restricts conversations to business hours only, ensuring a clear boundary between working hours and personal time for teachers.

This project is developed as a Final Year Project (FYP) at Politeknik Metro Tasek Gelugor, with a tuition centre ("Pusat Tuisyen Arena Matrix") as the target stakeholder and use case.

Live demo: https://tuturedu-app.web.app/

For the full living spec (data model, logic flow, per-file status) see [BLUEPRINT.md](BLUEPRINT.md).

## Features

- Welcome Screen — landing page with TuturEdu branding and options to log in or sign up
- Sign Up (Self Registration) — users can create their own account; Firebase Authentication and Firestore profile are created together
- Login & Role-based Access — the system identifies user roles (Student / Teacher / Parent / Admin) after login and routes them to their respective dashboards
- Real-time Chat — conversations update live using Cloud Firestore, with read receipts (sent/read ticks) and per-chat unread badges
- Quick Reply Chips — one-tap common replies ("OK", "Yes", "No", "Thank you", "Noted", "Please wait") above the input bar
- Group Chat — teachers create a group chat per subject/class (pick enrolled students via checkbox), with a Group Info screen for the admin to add/remove members and other members to leave
- File Attachments — send documents/images in chat (PDF, Office docs, images), validated client-side in 3 layers (size, extension, magic number) before uploading to Firebase Storage; images preview inline, documents open externally
- Find Teacher / Find Student — students search for teachers and vice versa; tap a result to view a read-only profile or start a chat
- Business Hour Lock — chat is automatically locked outside business hours (Monday–Friday, 9:00 AM–5:00 PM)
- Overtime Mode — outside business hours, teachers can reply immediately ("Reply Now") or schedule a reply to auto-send once business hours resume
- Interactive Quiz — Live Session — Kahoot/Wayground-style: teacher creates a multiple-choice quiz and hosts a live session with a 6-digit join code; students join in real time, answer against a synced countdown timer, and see a final podium leaderboard (Self-Paced homework mode not yet built)
- Admin Dashboard — manage user accounts (view, change role, remove) and manage the subject/level catalog used across the app
- OS-level unread app badge (best-effort, Chromium/PWA only)
- Firestore & Storage Security Rules — each conversation/attachment can only be accessed by its participants; admin actions are restricted to accounts with the Admin role

## Tech Stack

- Framework: Flutter (mobile + web)
- Backend: Firebase (Authentication, Cloud Firestore, Storage, Hosting — Blaze plan)
- Language: Dart

## Project Structure

```
lib/
├── main.dart                         # App entry point (loads WelcomeScreen), shared theme
├── firebase_options.dart             # Firebase configuration (auto-generated)
├── models/
│   └── user_model.dart               # User data model
├── screens/
│   ├── welcome_screen.dart           # Landing screen (Log In / Sign Up)
│   ├── register_screen.dart          # Self sign-up screen
│   ├── login_screen.dart             # Login screen
│   ├── student_dashboard.dart        # = ChatListScreen configured for Student
│   ├── teacher_dashboard.dart        # = ChatListScreen configured for Teacher
│   ├── parent_dashboard.dart         # Placeholder — parent chat module not yet built
│   ├── user_search_screen.dart       # Generic search: find a Teacher (Student) or Student (Teacher)
│   ├── user_profile_screen.dart      # Read-only profile + "Message" button
│   ├── chat_screen.dart              # Real-time chat (1:1 and group), attachments, quick replies, office hour lock
│   ├── chat_list_screen.dart         # Tabs (All/Individual/Groups) + unread badges + read receipts
│   ├── create_group_chat_screen.dart # Teacher: create a group chat for a subject/class
│   ├── group_info_screen.dart        # Group members list; admin add/remove, others can leave
│   ├── add_group_members_screen.dart # Group admin: add members to an existing group
│   ├── full_image_screen.dart        # Full-screen viewer for image attachments
│   ├── admin_dashboard.dart          # Admin hub with quick stats
│   ├── manage_users_screen.dart      # Admin: manage user accounts + assign subjects
│   ├── manage_subjects_screen.dart   # Admin: manage subject/level catalog
│   ├── create_quiz_screen.dart       # Teacher: create a quiz (4-option questions)
│   ├── quiz_list_screen.dart         # Teacher: "My Quizzes", start hosting a session
│   ├── host_quiz_session_screen.dart # Teacher: join code, waiting room, control questions, leaderboard
│   ├── join_quiz_screen.dart         # Student: enter a join code
│   ├── live_quiz_play_screen.dart    # Student: play the quiz in real time, timer, leaderboard
│   └── quiz_leaderboard_view.dart    # Shared podium/leaderboard widget (host + student)
└── utils/
    ├── office_hours.dart             # Business hour check logic
    ├── unread_badge.dart             # OS-level badge, conditional export (web/stub)
    ├── file_validator.dart           # File upload validation (size + extension + magic number)
    └── quiz_theme.dart               # Shared Kahoot/Wayground-style color+shape palette for the Quiz module
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
  └── {chatId}                          # 1:1: "{uid1}_{uid2}" (sorted); group: auto-generated ID
        ├── participants: [uid1, uid2, ...]
        ├── isGroup: boolean
        ├── groupName (optional)
        ├── groupAdmin (optional)             # uid of group creator
        ├── lastMessage
        ├── lastUpdated
        ├── lastRead: { uid: Timestamp }      # read receipts
        ├── unreadCount: { uid: int }         # per-participant unread count
        ├── messages (sub-collection)
        │     └── {messageId}
        │           ├── senderId
        │           ├── text
        │           ├── timestamp
        │           ├── isQuickReply (optional)
        │           ├── isOvertimeReply (optional)
        │           ├── isScheduledReply (optional)
        │           ├── attachmentUrl (optional)
        │           ├── attachmentType (optional)  # "pdf" | "image" | "document"
        │           └── attachmentName (optional)
        └── scheduledReplies (sub-collection)   # Overtime Mode
              └── {replyId}
                    ├── senderId
                    ├── text
                    ├── scheduledFor
                    └── status: "pending" | "sent"

quizzes (collection)
  └── {quizId}
        ├── title, subjectLevel, createdBy, createdAt, mode, questionCount
        └── questions (sub-collection)
              └── {questionId}
                    ├── order, text, options[4], correctIndex
                    ├── timeLimitSeconds, points
                    └── createdBy

quizSessions (collection)                  # Live Session only
  └── {sessionId}
        ├── quizId, hostUid, joinCode, status, currentQuestionIndex
        └── participants (sub-collection)
              └── {studentUid}
                    ├── name, score
                    └── answers: map<questionId, { selectedIndex, correct, timeTakenMs }>
```

### Deploy Security Rules

```bash
firebase deploy --only "firestore:rules"
firebase deploy --only firestore:indexes
firebase deploy --only storage
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
- [x] Real-time chat with read receipts & unread badges
- [x] Quick reply chips
- [x] Group chat (create, add/remove members, leave)
- [x] File upload with 3-layer validation (Firebase Storage, live end-to-end)
- [x] Chat list (tabs + unread badges)
- [x] Business hour lock logic
- [x] Overtime Mode (Reply Now / Schedule Reply)
- [x] Admin dashboard, manage users, manage subjects
- [x] Firestore & Storage security rules
- [x] Interactive Quiz — Live Session (Kahoot/Wayground-style, join code + real-time + leaderboard)
- [ ] Interactive Quiz — Self-Paced (homework mode)
- [ ] Class performance overview + warning letter system
- [ ] Attendance overview (student)
- [ ] Parent module (monitoring / chat with teacher)
- [ ] Push notifications

## Author

MOHAMAD SYAFIQ IRFAN BIN ABDUL RAHMAN (LEAD DEVELOPER)

SUTHESWARAN TAMILARASAN (CO DEVELOPER & TESTING)

HARVINT A/L SHAMUGANATHAN (CO DEVELOPER & UI/UX)

Developed as a Final Year Project (FYP) at Politeknik Metro Tasek Gelugor, using Flutter & Firebase.
