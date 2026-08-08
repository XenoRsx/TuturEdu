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
- Overtime Mode & Schedule Message — outside business hours, teachers can reply immediately ("Reply Now") or schedule a reply to auto-send once business hours resume; students/parents can schedule a message the same way (no "Reply Now" bypass for them, since that's specifically a teacher choosing to break their own hours)
- On-Duty / Off-Duty Toggle — a teacher can manually go Off-Duty (e.g. sudden meeting, sick leave) to lock their chats even during scheduled office hours, live-synced to anyone with the chat open
- Interactive Quiz — Live Session — Kahoot/Wayground-style: teacher creates a multiple-choice quiz and hosts a live session with a 6-digit join code; students join in real time, answer against a synced countdown timer, and see a final podium leaderboard
- Interactive Quiz — Self-Paced — same quiz questions, attempted on the student's own time (no timer, no host); one attempt per student per quiz, with an instant score + answer review afterward
- Class Performance Overview — teacher picks a subject, sees a class health score and a Safe/At-Risk/Barred breakdown, grades each student (0–100), and gets an auto-computed trend (Steady/Dropping/Critical) based on the change since their last grade
- Warning Letter — teacher can send a warning letter to a student's linked parent when their trend turns Critical, with a per-student sending history
- Attendance — teacher takes attendance per subject/date (Present/Absent, "Mark All" shortcuts); student sees their attendance rate, a Safe/Low breakdown, and a low-attendance warning below 75%
- Parent Module — Admin links a Parent account to a Student account; the parent then gets a real chat-list dashboard (message any teacher), a read-only "My Child" view (attendance + performance), and a Warning Letters inbox they can mark as read
- Admin Dashboard — manage user accounts (view, change role, remove), manage the subject/level catalog, and a Reports screen with live system-wide stats (users, chats, quizzes, attempts, warning letters)
- Push Notifications — a Cloud Function sends a real push notification on new chat messages and new warning letters, delivered even when the app isn't open. Live on Web (VAPID key configured and deployed) — see BLUEPRINT.md 5.12.
- Settings — every role gets Edit Profile, Change Password (re-authenticates first), a Push Notifications on/off toggle, Log Out, and self-service Delete Account (re-authenticates, then removes their own Firestore profile and Firebase Auth account — no Cloud Function needed for deleting your *own* account, unlike Admin deleting someone else's). Teachers additionally get Leave/Holiday dates, which auto-lock their chats for that date range on top of the manual On-Duty/Off-Duty toggle.
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
│   ├── parent_dashboard.dart         # = ChatListScreen configured for Parent
│   ├── user_search_screen.dart       # Generic search: find a Teacher (Student/Parent) or Student (Teacher)
│   ├── user_profile_screen.dart      # Read-only profile + "Message" button
│   ├── chat_screen.dart              # Real-time chat (1:1 and group), attachments, quick replies, office hour lock
│   ├── chat_list_screen.dart         # Tabs (All/Individual/Groups) + unread badges + read receipts
│   ├── create_group_chat_screen.dart # Teacher: create a group chat for a subject/class
│   ├── group_info_screen.dart        # Group members list; admin add/remove, others can leave
│   ├── add_group_members_screen.dart # Group admin: add members to an existing group
│   ├── full_image_screen.dart        # Full-screen viewer for image attachments
│   ├── admin_dashboard.dart          # Admin hub with quick stats
│   ├── manage_users_screen.dart      # Admin: manage user accounts + assign subjects + link/unlink Parent-Student
│   ├── link_parent_child_screen.dart # Admin: link a Parent account to a Student account
│   ├── manage_subjects_screen.dart   # Admin: manage subject/level catalog
│   ├── create_quiz_screen.dart       # Teacher: create a quiz (4-option questions)
│   ├── quiz_list_screen.dart         # Teacher: "My Quizzes", start hosting a session
│   ├── host_quiz_session_screen.dart # Teacher: join code, waiting room, control questions, leaderboard
│   ├── join_quiz_screen.dart         # Student: enter a join code
│   ├── live_quiz_play_screen.dart    # Student: play the quiz in real time, timer, leaderboard
│   ├── quiz_leaderboard_view.dart    # Shared podium/leaderboard widget (host + student)
│   ├── self_paced_quiz_list_screen.dart # Student: browse Self-Paced quizzes for their subjects
│   ├── attempt_quiz_screen.dart      # Student: attempt/review a Self-Paced quiz (dual-mode screen)
│   ├── class_performance_screen.dart # Teacher: health score, per-student trend, Warning Letter
│   ├── take_attendance_screen.dart   # Teacher: mark Present/Absent per subject/date
│   ├── attendance_overview_screen.dart # Student: attendance rate, subject filter, history
│   ├── child_overview_screen.dart    # Parent: read-only attendance + performance for linked child
│   ├── parent_warning_letters_screen.dart # Parent: warning letters for their child, mark as read
│   ├── admin_reports_screen.dart     # Admin: system-wide stats (count aggregation queries)
│   └── settings_screen.dart          # All roles: profile, password, push toggle, leave dates (Teacher), logout, delete account
└── utils/
    ├── office_hours.dart             # Business hour check logic
    ├── unread_badge.dart             # OS-level badge, conditional export (web/stub)
    ├── file_validator.dart           # File upload validation (size + extension + magic number)
    ├── quiz_theme.dart               # Shared Kahoot/Wayground-style color+shape palette for the Quiz module
    └── push_notifications.dart       # Register/unregister this device's FCM token

web/
└── firebase-messaging-sw.js          # Service worker required for Web Push

functions/                            # Separate Node.js project (not Dart/Flutter)
├── package.json                      # firebase-admin, firebase-functions v2
└── index.js                          # onNewChatMessage + onNewWarningLetter triggers
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
        ├── subjects: array<string>   # e.g. ["Add Maths Form 4"]
        ├── parentUid (optional)      # Student only - set by Admin when linking to a Parent
        ├── childUid (optional)       # Parent only - set by Admin when linking to a Student
        ├── dutyStatus (optional)     # Teacher only - "on_duty" | "off_duty", manual toggle; missing = on_duty
        ├── fcmTokens (optional)      # array<string> - push notification device tokens (can be >1)
        ├── pushEnabled (optional)    # boolean - Settings preference; missing = enabled
        └── leaveStart / leaveEnd (optional) # Teacher only - leave/holiday date range, auto Off-Duty for it (Settings)

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
        │     # mode: "live" | "self_paced" | "both"
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

quizAttempts (collection)                  # Self-Paced only
  └── {quizId}_{studentUid}                # deterministic ID - one attempt per student per quiz
        ├── quizId, studentUid, status: "completed"
        ├── startedAt, completedAt
        ├── score, totalPoints
        └── answers: map<questionId, selectedIndex>

performance (collection)
  └── {subjectLevel}                     # e.g. "Add Maths Form 4" - used as the document ID
        └── students (sub-collection)
              └── {studentUid}
                    ├── name, percentage        # 0-100, entered manually by the teacher
                    ├── trend: "steady" | "dropping" | "critical"   # auto-computed from the change since last grade
                    └── lastUpdated

warningLetters (collection)
  └── {letterId}
        ├── studentUid, teacherUid, parentUid, subjectLevel
        ├── reason
        ├── sentAt
        └── acknowledged: boolean   # parent can mark as read from the Warning Letters screen

attendance (collection)
  └── {studentUid}
        └── records (sub-collection)
              └── {recordId}                # deterministic: "{subjectLevel}_{yyyy-MM-dd}"
                    ├── subject, date, status: "present" | "absent"
                    ├── markedBy             # teacher uid
                    └── markedAt
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

## Deploy (Cloud Functions — push notifications)

```bash
cd functions
npm install
firebase deploy --only functions
```

The first-ever deploy of 2nd-gen Cloud Functions on a project can fail once with an Eventarc IAM propagation error — just retry the deploy after a minute, as the error message itself suggests.

**Web Push VAPID key:** already generated and configured in `_webVapidKey` (`lib/utils/push_notifications.dart`) — that key can only be generated by a human in Firebase Console (Project Settings → Cloud Messaging → Web configuration → "Generate key pair"), no CLI equivalent exists, so keep this in mind if the project ever needs a new one. Android/iOS don't need this step, but haven't been built/tested in this project yet — all deploys so far have been `flutter build web`.

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
- [x] Class Performance Overview + Warning Letter system
- [x] Attendance (teacher takes attendance, student sees rate + history)
- [x] Parent module (Admin links Parent↔Student, parent chat dashboard, Child Overview, Warning Letters)
- [x] On-Duty/Off-Duty manual toggle
- [x] Interactive Quiz — Self-Paced (homework mode)
- [x] Admin Reports (real system-wide stats)
- [x] Push notifications (Cloud Functions deployed and live, including Web — VAPID key configured)
- [x] Settings (Edit Profile, Change Password, push toggle, Log Out, self-service Delete Account, Teacher Leave/Holiday dates)
- [ ] Full Admin account deletion (needs a Cloud Function — the `functions/` project now exists from push notifications, so this is easier to add going forward; different from the self-service Delete Account above, which needs no Cloud Function)

## Author

MOHAMAD SYAFIQ IRFAN BIN ABDUL RAHMAN (LEAD DEVELOPER)

SUTHESWARAN TAMILARASAN (CO DEVELOPER & TESTING)

HARVINT A/L SHAMUGANATHAN (CO DEVELOPER & UI/UX)

Developed as a Final Year Project (FYP) at Politeknik Metro Tasek Gelugor, using Flutter & Firebase.
