# TuturEdu

TuturEdu is a chat platform connecting Students, Lecturers, and Parents, built using Flutter and Firebase. The system restricts conversations to office hours only, ensuring a clear boundary between working hours and personal time for lecturers.

This project is developed as a Final Year Project (FYP) at Politeknik METrO Tasek Gelugor.

Live demo: https://tuturedu-app.web.app/

## Features

- Login & Role-based Access — the system identifies user roles (Student / Lecturer / Parent) after login and routes them to their respective dashboards
- Real-time Chat — conversations update live using Cloud Firestore
- Find Lecturer — students can search for and start a conversation with a lecturer
- Office Hour Lock — chat is automatically locked outside office hours (Monday–Friday, 9:00 AM–5:00 PM)
- Firestore Security Rules — each conversation can only be accessed by its participants

## Tech Stack

- Framework: Flutter
- Backend: Firebase (Authentication, Cloud Firestore, Hosting)
- Language: Dart

## Project Structure

```
lib/
├── main.dart                  # App entry point
├── firebase_options.dart      # Firebase configuration (auto-generated)
├── models/
│   └── user_model.dart        # User data model
├── screens/
│   ├── login_screen.dart      # Login screen
│   ├── student_dashboard.dart
│   ├── lecturer_dashboard.dart
│   ├── parent_dashboard.dart
│   ├── lecturer_list_screen.dart  # Student search & select lecturer
│   └── chat_screen.dart       # Real-time chat screen
└── utils/
    └── office_hours.dart      # Office hour check logic
```

## Firestore

### Data Structure

```
users (collection)
  └── {uid}
        ├── uid
        ├── email
        ├── name
        └── role: "Student" | "Lecturer" | "Parent"

chats (collection)
  └── {chatId}
        ├── participants: [uid1, uid2]
        ├── lastMessage
        ├── lastUpdated
        └── messages (sub-collection)
              └── {messageId}
                    ├── senderId
                    ├── text
                    └── timestamp
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

- [x] Login & role-based routing
- [x] Firebase Authentication + Firestore integration
- [x] Real-time chat between student & lecturer
- [x] Office hour lock logic
- [x] Firestore security rules
- [ ] Register screen (self sign-up)
- [ ] Notifications for new messages
- [ ] Chat list (active conversations overview)
- [ ] Parent module (monitoring / chat with lecturer)

## Author
MOHAMAD SYAFIQ IRFAN BIN ABDUL RAHMAN (LEAD DEVELOPER)

SUTHESWARAN TAMILARASAN (CO DEVELOPER & TESTING)

HARVINT  A/L SHAMUGANATHAN (CO DEVELOPER & UI/UX)

Developed as a Final Year Project (FYP) at Politeknik METrO Tasek Gelugor, using Flutter & Firebase.
