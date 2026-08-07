# TuturEdu — Project Blueprint

Final Year Project (FYP) — Politeknik METrO Tasek Gelugor
Stakeholder / Use-case: Pusat Tuisyen
Platform perbualan (chat) antara Student, Teacher, dan Parent dengan sekatan waktu pejabat (office hour lock).

---

## 1. Ringkasan Projek

TuturEdu ialah aplikasi chat berasaskan Flutter + Firebase yang membenarkan tiga jenis pengguna — **Student**, **Teacher**, dan **Parent** — berkomunikasi dalam satu platform, dengan sekatan masa perbualan mengikut waktu pejabat (office hour) teacher. Matlamat utama sistem ini adalah mewujudkan sempadan yang jelas antara waktu mengajar dan waktu peribadi teacher, sambil kekal membenarkan komunikasi akademik yang cekap antara pusat tuisyen, student, dan parent.

Projek ini dibangunkan sebagai Final Year Project (FYP) di Politeknik METrO Tasek Gelugor, dengan pusat tuisyen sebagai stakeholder/use-case sasaran sistem.

**Platform:** Flutter (mobile & web, responsive)
**Backend:** Firebase (Authentication, Cloud Firestore, Storage, Hosting)
**Bahasa pengaturcaraan:** Dart

---

## 2. Peranan Pengguna (User Roles)

| Role | Fungsi Utama |
|---|---|
| **Student** | Chat dengan teacher, lihat attendance/performance sendiri, ada info parent dalam profile |
| **Teacher** | Chat dengan student & parent, urus On-Duty/Off-Duty status, lihat class performance overview, hantar warning letter |
| **Parent** | Monitor anak (attendance, performance), chat dengan teacher berkaitan hal anak |
| **Admin** | Urus akaun pengguna (tukar role, padam), urus katalog subjek (subjectCatalog), akses masa depan: reports & monitor system activities |

---

## 3. Struktur Firestore

### 3.1 Collection: `users`

```
users (collection)
  └── {uid}
        ├── uid: string
        ├── email: string
        ├── name: string
        ├── role: "Student" | "Teacher" | "Parent" | "Admin"   // ✅ Admin ditambah — dicipta manual via Firebase Console (bukan public Sign Up)
        ├── studentId / staffId: string        // ID pendaftaran pusat tuisyen
        ├── subjects: array<string>               // format "Subjek Tahap", contoh: ["Add Maths Form 4", "Physics Form 5"]
                                                    // Teacher: subjek yang diajar (boleh lebih dari satu)
                                                    // Student: subjek yang diambil (boleh lebih dari satu)
        ├── parentUid: string                     // untuk Student, rujuk ke uid Parent
        ├── childUid: string                      // untuk Parent, rujuk ke uid Student
        ├── dutyStatus: "on_duty" | "off_duty"    // untuk Teacher, toggle manual
        └── workingHours: { start: string, end: string }  // custom per-teacher (future)
```

### 3.2 Collection: `chats`

```
chats (collection)
  └── {chatId}                          // 1:1 chat: "{uid1}_{uid2}" (uid disusun abjad); Group chat: auto-generated ID
        ├── participants: array<string>  // 1:1: [uid1, uid2]; Group: [uid1, uid2, uid3, ...]
        ├── chatType: "student_teacher" | "parent_teacher" | "group"   // ✅ "group" ditambah
        ├── isGroup: boolean              // ✅ true untuk group chat, false/tiada untuk 1:1
        ├── groupName: string (optional)  // ✅ hanya untuk group chat, contoh "Add Maths Form 4 - Batch A"
        ├── groupAdmin: string (optional) // ✅ uid pencipta group (kelak untuk permission tambah/buang ahli)
        ├── lastMessage: string
        ├── lastUpdated: timestamp
        ├── messages (sub-collection)
        │     └── {messageId}
        │           ├── senderId: string
        │           ├── text: string
        │           ├── timestamp: timestamp
        │           ├── isOvertimeReply: boolean (optional)   // ✅ true jika dihantar via "Reply Now (Overtime Mode)"
        │           ├── isScheduledReply: boolean (optional)  // ✅ true jika dihantar via auto-send "Schedule Reply"
        │           ├── attachmentUrl: string (optional)      // 💡 rujuk Seksyen 8, belum dikod
        │           ├── attachmentType: "pdf" | "image" | "document" (optional)  // 💡 rujuk Seksyen 8, belum dikod
        │           ├── attachmentName: string (optional)     // 💡 rujuk Seksyen 8, belum dikod
        │           └── isQuickReply: boolean (optional)    // mesej dari quick-reply chip
        └── scheduledReplies (sub-collection)              // ✅ Overtime Mode - "Schedule Reply"
              └── {replyId}
                    ├── senderId: string       // mesti Teacher
                    ├── text: string
                    ├── createdAt: timestamp
                    ├── scheduledFor: timestamp  // dari OfficeHours.nextOpenDateTime()
                    └── status: "pending" | "sent"
```

### 3.3 Collection: `attendance`

```
attendance (collection)
  └── {studentUid}
        └── records (sub-collection)
              └── {recordId}
                    ├── subject: string          // format "Subjek Tahap", contoh: "Add Maths Form 4"
                    ├── date: timestamp
                    └── status: "present" | "absent"
```

### 3.4 Collection: `performance`

```
performance (collection)
  └── {subjectLevel}                     // contoh: "Add Maths Form 4"
        └── students (sub-collection)
              └── {studentUid}
                    ├── name: string
                    ├── percentage: number
                    ├── trend: "steady" | "dropping" | "critical"
                    └── lastUpdated: timestamp
```

### 3.5 Collection: `warningLetters`

```
warningLetters (collection)
  └── {letterId}
        ├── studentUid: string
        ├── teacherUid: string
        ├── parentUid: string
        ├── reason: string
        ├── sentAt: timestamp
        └── acknowledged: boolean
```

### 3.6 Collection: `subjectCatalog` (✅ Sudah dilaksanakan)

```
subjectCatalog (collection)
  └── {autoId}
        ├── name: string          // format "Subjek Tahap", contoh: "Add Maths Form 4"
        └── createdAt: timestamp
```

Senarai subjek/tahap yang **sah** dalam sistem, diurus oleh Admin (Manage Subjects screen). Wujud supaya Teacher/Student tidak taip nama subjek sendiri secara bebas (elak inconsistency, contoh "Add Maths Form 4" vs "add maths f4"). Field `subjects` dalam `users/{uid}` (Seksyen 3.1) sepatutnya dipadankan dengan entri dari catalog ini pada masa hadapan (belum di-enforce dalam UI Register/Profile semasa).

---

## 4. Ciri-Ciri Utama (Features)

### 4.1 Status: Sudah Dilaksanakan ✅

- **Welcome / Landing Screen** — skrin permulaan app dengan branding TuturEdu (logo), pilihan "Log In" atau "Sign Up" — UI dalam Bahasa Inggeris
- **Register Screen (Self Sign-Up)** — user boleh cipta akaun sendiri: Firebase Authentication (email + password) dan dokumen profile dalam Firestore `users/{uid}` dicipta serentak; auto-login & terus route ke dashboard mengikut role dipilih — UI dalam Bahasa Inggeris
- **Login & Role-based Routing** — Firebase Authentication + semakan role dari Firestore, auto-route ke dashboard mengikut role
- **Real-time Chat** — mesej dikemas kini secara langsung menggunakan `StreamBuilder` + Firestore `snapshots()`
- **Cari Pensyarah** — student boleh cari & pilih teacher untuk mula chat baru
- **Office Hour Lock (Global)** — chat automatik dikunci di luar waktu pejabat (Isnin–Jumaat, 9AM–5PM), guna semakan `DateTime.now()` pada client
- **Overtime Mode (Teacher)** — bila chat locked, teacher diberi pilihan "Reply Now (Overtime Mode)" atau "Schedule Reply" (lihat 4.1 & 5.4)
- **Admin Dashboard** — hub khas untuk role Admin: quick stats (jumlah Student/Teacher/Parent), navigasi ke Manage Users & Manage Subjects
- **Manage Users (Admin)** — Admin boleh search/filter user ikut role, tukar role user (contoh Student → Teacher), padam user (buang dokumen Firestore; akaun Firebase Authentication kekal — nota dipapar dalam UI, rujuk 4.2/limitation), dan "Edit Subjects" (assign entri dari `subjectCatalog` ke Teacher/Student individu)
- **Manage Subjects (Admin) (✅ CRUD penuh)** — Admin boleh Add/Edit/Delete entri `subjectCatalog`. **Add** guna dropdown (bukan free-text) untuk Subject & Level — senarai subjek biasa (Bahasa Malaysia, English, Add Maths, dll.) & level (Year 1-6, Form 1-5, Lower/Upper Six), dengan pilihan "Other (type manually)" yang papar text field custom kalau subjek/level tak ada dalam senarai. Ini + duplicate-name check (case-sensitive exact match sebelum create) elak inconsistency macam "Add Maths" vs "add maths". **Edit** (rename, masih free-text sebab nama gabungan susah nak split balik ke Subject+Level) papar amaran berapa ramai profile (`users.subjects arrayContains`) yang sedang guna nama tu sebelum simpan — sebab `users.subjects` simpan nama sebagai plain string (bukan reference ke dokumen catalog), rename di sini TIDAK auto-update profile yang dah assign. **Delete** papar amaran usage count yang sama sebelum confirm. Ada search field untuk tapis senarai.
- **Firestore Security Rules** — setiap chat & scheduledReplies hanya boleh diakses oleh participant/pemilik yang terlibat; `users` & `subjectCatalog` ada permission khas untuk Admin (fungsi `isAdmin()`)
- **Group Chat** — Teacher cipta group chat ikut subjek (`create_group_chat_screen.dart`): pilih subjek yang diajar, pilih student yang enrolled dalam subjek tu (checkbox + Select All), masukkan nama group. `chat_screen.dart` papar nama group dalam AppBar & nama pengirim di atas setiap mesej masuk (mod group); `chat_list_screen.dart` papar group chat dengan ikon & nama group berasingan daripada chat 1:1. **Nota:** group TIDAK auto-update bila student baru enrol subjek yang sama selepas group dicipta — perlu Teacher cipta group baru.
- **Read Receipts & Unread Badge (WhatsApp-style)** — `chats/{chatId}` ada field `lastRead: {uid: Timestamp}` (dikemaskini bila participant buka/lihat chat) dan `unreadCount: {uid: int}` (increment untuk setiap participant lain bila mesej dihantar, reset ke 0 bila dibuka). Setiap mesej yang dihantar oleh current user papar single tick (dah hantar) atau double tick biru (dah dibaca oleh semua participant lain). `chat_list_screen.dart` papar row bold + badge hijau untuk chat yang belum dibaca, dan tick sent/read pada preview mesej terakhir kalau current user ialah penghantar.
- **Chats sebagai home screen Teacher/Student (✅ redesign)** — `TeacherDashboard`/`StudentDashboard` bukan lagi skrin menu dengan butang "My Chats"/"Chat Saya"; kedua-duanya kini terus papar `ChatListScreen` (dikonfigur dengan warna jenama & Floating Action Button ikut role). AppBar `ChatListScreen` ada tab "All" / "Individual" / "Groups" (filter client-side ikut field `isGroup`) dan indikator jumlah keseluruhan chat belum dibaca (badge hijau "X unread" sebelah tajuk "Chats"). ParentDashboard KEKAL berasingan (tidak digabung dengan chat list) sebab parent chat module belum dibina — rujuk 4.2.
- **Design refresh (✅)** — palet warna & komponen diselaraskan merentasi semua skrin (`main.dart` ThemeData: Material 3, `ColorScheme.fromSeed`, rounded inputs/buttons/cards) mengikut gaya asal `welcome_screen.dart`; senarai (users, subjects, teachers, chats) kini guna `Card`-wrapped tile dengan empty-state ikon + mesej, bukan `Text` kosong sahaja.
- **New Chat (cari user) & Profile (✅)** — `user_search_screen.dart` ialah skrin generik cari user ikut role (dipanggil dengan `targetRole`): Student cari Teacher (FAB "Find a Teacher"), Teacher kini juga boleh cari Student (FAB Teacher dashboard buka bottom sheet: "New Chat" vs "New Group"). Setiap row ada ikon info → `user_profile_screen.dart` (avatar, role, email, subjects, butang "Message"). Dalam `chat_screen.dart`, tajuk AppBar (atau ikon info) boleh ditekan untuk buka profile pihak lain (chat 1:1) atau Group Info (chat group).
- **Group Members: View / Add / Remove (✅)** — `group_info_screen.dart` papar senarai ahli group (nama, avatar, label "Group Admin"). `groupAdmin` (teacher pencipta) boleh buang ahli (`arrayRemove`) atau tambah ahli baru lewat `add_group_members_screen.dart` (senarai student yang enrolled dalam subjek group tapi belum jadi ahli, checkbox multi-select → `arrayUnion`). Ahli biasa (bukan admin) ada butang "Leave Group" untuk buang diri sendiri. **Firestore Rules dikemaskini**: perubahan field `participants` pada chat group hanya dibenarkan untuk `groupAdmin`, ATAU ahli yang buang diri sendiri sahaja (self-leave) — dikuatkuasakan di `firestore.rules` (bukan client-side sahaja).
- **OS-level unread badge (✅, best-effort)** — `lib/utils/unread_badge.dart` (+ `_stub.dart` / `_web.dart`, conditional export ikut `dart.library.js_interop`) panggil Web Badging API (`navigator.setAppBadge` / `clearAppBadge`) setiap kali jumlah keseluruhan chat belum dibaca berubah dalam `ChatListScreen`, dan clear semasa logout. Ini bagi badge kat icon app macam WhatsApp (bulatan hijau + nombor) kat luar tab/skrin app. **Had:** hanya berkesan di browser Chromium (Chrome/Edge) & bila TuturEdu di-"install" sebagai PWA (`web/manifest.json` dah `display: standalone`) — di browser/konteks lain, fungsi ni silently no-op (feature-detected via `dart:js_interop`, tak crash).
- **File Upload / Attachment (✅ dikodkan & berfungsi hujung-ke-hujung, rujuk Seksyen 8)** — Butang 📎 dalam `chat_screen.dart` → `FilePicker.pickFiles(withData: true)` → `FileValidator.validate()` (`lib/utils/file_validator.dart`, 3-lapisan: saiz ≤10MB, extension, magic number — rujuk 8.3/8.4) → upload ke Firebase Storage (`chats/{chatId}/attachments/{messageId}_{namaFail}`) dengan progress bar sebenar + timeout 30 saat (elak upload "hang" selama-lamanya kalau ada masalah rangkaian) → mesej dengan `attachmentUrl`/`attachmentType`/`attachmentName`. Bubble papar thumbnail (image, tap → `FullImageScreen` penuh skrin) atau kad ikon+nama (document, tap → buka luar guna `url_launcher`). Firebase Storage project `tuturedu-app` dah **enabled** (bucket `tuturedu-app.firebasestorage.app`, US-EAST1 no-cost location, plan Blaze) & `storage.rules` dah **dideploy**.
- **Quick Reply Chips (✅ dikodkan)** — row chip boleh scroll horizontal ("OK", "Yes", "No", "Thank you", "Noted", "Please wait") di atas input bar dalam `chat_screen.dart`, hanya papar bila chat tak locked. Tekan chip terus hantar mesej tu (guna fungsi `_sendMessage` yang sama, parameter `quickReplyText`), ditanda `isQuickReply: true` dalam Firestore.
- **Interactive Quiz — Live Session (✅ dikodkan, rujuk Seksyen 9)** — Mod Kahoot-style sahaja buat masa ni (Self-Paced belum dibina, rujuk 4.2). Teacher: `quiz_list_screen.dart` ("My Quizzes") → `create_quiz_screen.dart` (tajuk, subjek, soalan aneka pilihan 4 opsyen + time limit + points) → tekan quiz untuk `host_quiz_session_screen.dart` (generate join code 6-digit, waiting room dengan senarai student join secara live, kawal "Next Question"/"End Quiz", leaderboard akhir). Student: FAB "Join a Quiz" → `join_quiz_screen.dart` (masukkan join code) → `live_quiz_play_screen.dart` (StreamBuilder ikut `quizSessions.status`/`currentQuestionIndex`, countdown timer disegerakkan guna `currentQuestionStartedAt`, submit jawapan, leaderboard). Firestore rules ditambah untuk `quizzes`/`quizSessions` (rujuk firestore.rules) — markah dikira & ditulis client-side (had FYP yang sama macam file validation, tiada Cloud Function). UI/UX guna palet vibrant gaya Wayground/Kahoot (`quiz_theme.dart` — 4 warna+bentuk opsyen, gradient ungu, leaderboard podium dikongsi via `quiz_leaderboard_view.dart`).

### 4.2 Status: Dalam Reka Bentuk (Figma) — Belum Dikodkan 🔲

Berdasarkan prototype Figma, ciri-ciri berikut telah direka tetapi belum dilaksanakan dalam kod:

- **On-Duty / Off-Duty Toggle (Manual)** — teacher boleh tukar status sendiri, bukan hanya bergantung jadual automatik
- **Interactive Quiz — Self-Paced** — mod kedua dari Seksyen 9 (student buat quiz bila-bila masa macam homework, guna koleksi `quizAttempts`) — belum dibina, Live Session je siap setakat ni
- **Class Performance Overview** — dashboard teacher memaparkan:
  - Overall class health score (%)
  - Kategori: Safe / At-Risk / Barred
  - Breakdown performance per-student dengan trend (Steady / Dropping / Critical)
  - Butang "Send Warning Letter" terus dari dashboard
- **Attendance Overview (Student)** — student boleh lihat attendance rate sendiri, jumlah kelas dihadiri, dan status warning jika attendance rendah
- **Parent Module** — parent boleh:
  - Lihat profil & attendance anak
  - Chat terus dengan teacher berkaitan hal akademik anak
  - Terima notifikasi warning letter
- **Working Hours Custom Per-Teacher** — setiap teacher set jadual sendiri (bukan global untuk semua), sebagai penambahbaikan masa depan
- **Notification Settings** — toggle push notification & attendance alert
- **Security & Privacy Settings** — sorok nombor telefon peribadi, tukar password
- **Admin: Full Account Deletion** — "Delete User" dalam Manage Users semasa hanya buang dokumen Firestore; padam akaun **Firebase Authentication** sepenuhnya perlukan Admin SDK/Cloud Function (client-side Flutter tak boleh padam akaun Auth user lain secara terus, atas sebab keselamatan Firebase)
- **Admin: Reports & Monitor System Activities** — placeholder "Coming Soon" dalam Admin Dashboard semasa; bergantung pada data Attendance & Performance yang belum wujud

### 4.3 Status: Belum Dirancang / Cadangan Masa Depan 💡

- Push notification sebenar (Firebase Cloud Messaging)

---

## 5. Aliran Logik (Logic Flow)

### 5.1 Aliran Login

```
User buka app
   → WelcomeScreen (branding TuturEdu, pilihan "Log In" / "Sign Up")
   → Tekan "Log In" → LoginScreen
   → Masukkan email & password
   → FirebaseAuth.signInWithEmailAndPassword()
   → Ambil role dari Firestore (users/{uid})
   → Route mengikut role:
        - "Teacher" → TeacherDashboard (= ChatListScreen terus, tiada skrin menu butang lagi)
        - "Student"  → StudentDashboard (= ChatListScreen terus, tiada skrin menu butang lagi)
        - "Parent"   → ParentDashboard (skrin placeholder, chat module belum dibina)
        - "Admin"    → AdminDashboard   // ✅ ditambah
```

### 5.1a Aliran Register (Sign Up) — ✅ Sudah dilaksanakan

```
Dari WelcomeScreen, tekan "Sign Up"
   → RegisterScreen
   → Isi Nama, Email, Password, Confirm Password, pilih Role (Student/Teacher/Parent)
   → Validation asas (semua field diisi, password >= 6 aksara, password match)
   → FirebaseAuth.createUserWithEmailAndPassword(email, password)
        - Cipta akaun baru dalam Firebase Authentication, dapat UID baru
   → FirebaseFirestore users/{uid}.set({ uid, email, name, role, subjects: [] })
        - Cipta dokumen profile dalam Firestore, guna UID yang sama
   → User automatik logged in (hasil dari createUserWithEmailAndPassword)
   → Terus route ke dashboard mengikut role dipilih (tiada login manual selepas daftar)

Error handling (FirebaseAuthException):
   - "email-already-in-use" → papar mesej, cadang guna Log In
   - "invalid-email" → papar mesej format email tidak sah
   - "weak-password" → papar mesej password terlalu lemah
```

### 5.2 Aliran Mula Chat Baru (Student ↔ Teacher) — ✅ dua-hala

```
Student login → terus masuk ChatListScreen (StudentDashboard)
   → Tekan Floating Action Button "Find a Teacher"
   → UserSearchScreen(targetRole: "Teacher") (senarai dari users collection, role == "Teacher")
   → Student pilih satu teacher (tekan row → mula chat terus,
     ATAU tekan ikon info → UserProfileScreen dulu → tekan "Message")
   → Sistem generate chatId (gabungan uid, disusun abjad)
   → Create/reuse dokumen dalam chats/{chatId}
   → Navigate ke ChatScreen

Teacher login → terus masuk ChatListScreen (TeacherDashboard) → tekan FAB "+"
   → Bottom sheet: pilih "New Chat" atau "New Group"
   → "New Chat" → UserSearchScreen(targetRole: "Student") (aliran sama macam atas, terbalik)
```

### 5.2a Aliran Group Chat (✅ Dikodkan & diintegrasikan)

```
Teacher login → ChatListScreen (TeacherDashboard) → tekan FAB "+" → "New Group"
   → CreateGroupChatScreen
   → Pilih Subject/Level dari senarai subjek yang diajar teacher tu (dropdown)
   → Sistem query users where role == "Student" AND subjects array-contains subjectLevel
        - Senarai student yang match subjek tu dipaparkan dengan checkbox
          (+ butang "Select All" / "Deselect All")
        - Teacher pilih mana student nak dimasukkan dalam group
   → Masukkan nama group (contoh "Add Maths Form 4 - Batch A")
   → Tekan "Create Group"
        - Teacher (pencipta) turut ditambah sebagai participants + groupAdmin
   → Create dokumen baru dalam chats/{autoId}:
        { isGroup: true, chatType: "group", groupName, groupAdmin: teacherUid,
          subject: subjectLevel, participants: [teacherUid, ...studentUids], lastUpdated }
   → Navigate ke ChatScreen (mod group)

Dalam ChatScreen (mod group):
   → AppBar papar groupName (bukan nama individu)
   → Setiap mesej papar nama pengirim (fetch dari users/{senderId}.name) di atas bubble
     (beza dari chat 1:1 yang tak perlu papar nama sebab dah jelas 2 orang je)
   → Semua ahli group nampak & boleh reply dalam satu perbualan yang sama
   → Office Hour Lock tetap terpakai sama macam chat 1:1

Nota: group chat semasa TIDAK auto-update bila student baru daftar/ambil
subjek yang sama selepas group dicipta — Teacher boleh tambah ahli manual
lewat Group Info → "Add" (rujuk 5.2b) atau cipta group baru.
```

### 5.2b Aliran Group Info & Urus Ahli (✅ Dikodkan & diintegrasikan)

```
Dalam ChatScreen (mod group) → tekan tajuk AppBar / ikon info
   → GroupInfoScreen
        - Papar nama group, subjek, jumlah ahli
        - Senarai ahli (nama, avatar, label "Group Admin" untuk pencipta)
        - Tekan mana-mana ahli → UserProfileScreen ahli tu

   Jika current user == groupAdmin:
        - Setiap ahli lain ada ikon "Remove" → confirm dialog →
          chats/{chatId}.participants: arrayRemove([uid])
        - Butang "Add" → AddGroupMembersScreen
             → Query student yang enrolled dalam subjek group tapi BELUM
               jadi ahli (subjects array-contains subject, uid not in
               participants)
             → Checkbox multi-select → "Add N member(s)" →
               chats/{chatId}.participants: arrayUnion([...uids])

   Jika current user BUKAN groupAdmin:
        - Butang "Leave Group" → confirm dialog →
          chats/{chatId}.participants: arrayRemove([currentUid]) →
          kembali ke ChatListScreen

Firestore Rules: field `participants` pada dokumen chat hanya boleh
diubah oleh groupAdmin (bebas ubah), ATAU oleh mana-mana ahli yang
buang DIRI SENDIRI sahaja (self-leave) — bukan ahli lain. Dikuatkuasakan
di firestore.rules, bukan client-side sahaja.
```

### 5.3 Aliran Office Hour Lock

```
ChatScreen dibuka
   → Semak OfficeHours.isOfficeHourNow()
        - Isnin-Jumaat & jam 9AM-5PM → TRUE (chat dibuka)
        - Selain itu → FALSE (chat locked)
   → Jika locked:
        - Input field & send button disabled
        - Papar banner "Chat ditutup di luar waktu pejabat"
        - Jika current user role == "Teacher": papar pilihan
          "Reply Now (Overtime)" / "Schedule Reply" (lihat 5.4)
   → Timer semak status setiap 1 minit (auto-update UI bila jam bertukar)
   → Semasa hantar mesej: double-check office hour untuk elak race condition
```

### 5.4 Aliran Overtime Mode (✅ Sudah dilaksanakan — client-side)

```
ChatScreen dibuka
   → Fetch role user semasa dari users/{uid} (_loadCurrentUserRole)
   → Jika role == "Teacher" DAN chat locked:
        - Papar butang "Reply Now (Overtime Mode)" & "Schedule Reply"

Jika teacher tekan "Reply Now (Overtime Mode)":
   → _overtimeActive = true (state tempatan dalam ChatScreen)
   → Input field & send button unlock semula untuk sesi ini
   → Mesej seterusnya dihantar dengan flag `isOvertimeReply: true`
   → _overtimeActive auto-reset bila office hour betul-betul buka semula

Jika teacher tekan "Schedule Reply":
   → Dialog untuk taip mesej
   → Simpan ke chats/{chatId}/scheduledReplies:
        { senderId, text, scheduledFor: OfficeHours.nextOpenDateTime(), status: "pending" }
   → Dipapar sebagai senarai pending (dengan butang cancel) di atas chat

Auto-hantar scheduled reply (client-side, tanpa Cloud Function):
   → Setiap kali timer 1-minit dalam ChatScreen kesan office hour
     bertukar locked → open, ATAU bila ChatScreen dibuka semasa office hour:
        - Query scheduledReplies milik user semasa, status == "pending",
          scheduledFor <= now
        - Hantar sebagai mesej biasa dengan flag `isScheduledReply: true`
        - Update status jadi "sent"

Nota: sebab belum setup Cloud Functions, auto-hantar hanya berlaku bila
ChatScreen berkaitan dibuka semula selepas office hour bertukar (bukan
background/walaupun app tertutup). Cloud Function untuk auto-hantar
sepenuhnya (walaupun app tertutup) kekal sebagai penambahbaikan masa depan.
```

### 5.5 Aliran Class Performance & Warning Letter (Cadangan — belum dikod)

```
Teacher buka Class Performance Overview
   → Fetch data dari performance/{subjectLevel}/students
   → Papar overall health score & breakdown per-student
   → Jika student trend == "Critical":
        - Teacher tekan "Send Warning Letter"
        - Create dokumen dalam warningLetters collection
        - (Cadangan) Trigger notification ke Parent & Student berkaitan
```

### 5.6 Aliran File Upload / Attachment (✅ Dikodkan & berfungsi hujung-ke-hujung)

```
User tekan butang attachment (📎) dalam ChatScreen
   → Semak dulu OfficeHours.isOfficeHourNow() (kecuali _overtimeActive == true untuk Teacher)
        - Locked & bukan overtime → tolak, papar banner biasa
   → FilePicker.platform.pickFiles(withData: true) — dapatkan bytes fail terus
   → FileValidator.validate(fileName, bytes):
        1. Semak saiz fail (had 10MB)
        2. Semak sambungan fail (extension) — mesti dalam senarai dibenarkan
        3. Semak magic number (byte pertama fail sebenar) — rujuk Seksyen 8.4
   → Jika GAGAL mana-mana semakan:
        - Papar SnackBar ralat (mesej spesifik ikut jenis kegagalan)
        - HENTI, tidak upload
   → Jika LULUS:
        - Upload bytes ke Firebase Storage:
          chats/{chatId}/attachments/{messageId}_{namaFailAsal}
        - Dapatkan download URL
        - Create dokumen dalam chats/{chatId}/messages:
             { senderId, text: '', attachmentUrl, attachmentType, attachmentName, timestamp }
        - Update chats/{chatId}.lastMessage = "📎 {namaFail}"
   → UI papar bubble attachment:
        - attachmentType == "image" → thumbnail (Image.network), tap untuk buka penuh
        - attachmentType == "pdf" / "document" → kad dengan ikon + nama fail, tap untuk buka
          (guna url_launcher, buka dalam browser/app luar)
```

### 5.7 Aliran Admin: Manage Users (✅ Sudah dilaksanakan) & Manage Subjects (🔲 Kod ditulis, belum diintegrasikan/diuji)

```
Admin login → AdminDashboard
   → Fetch quick stats: kira jumlah users ikut role (Student/Teacher/Parent)
   → Pilih "Manage Users":
        - StreamBuilder senarai semua dokumen users
        - Search by nama, filter by role (chip)
        - "Change Role": dialog dropdown, update users/{uid}.role
        - "Delete User": confirmation dialog, delete dokumen users/{uid}
             (NOTA: ini hanya buang dokumen Firestore, BUKAN akaun Firebase
             Authentication — rujuk limitation dalam Seksyen 4.2)
   → Pilih "Manage Subjects":
        - Form input Subject + Level berasingan → digabung jadi "{Subject} {Level}"
        - Simpan ke subjectCatalog collection (rujuk Seksyen 3.6)
        - Senarai dipapar, susun ikut nama (orderBy 'name')
        - Delete dengan confirmation dialog
   → Pilih "Reports": placeholder "Coming Soon" (bergantung Attendance/Performance)

Nota akaun Admin pertama: TIADA pilihan "Admin" dalam RegisterScreen
(sengaja, untuk keselamatan). Cara cipta akaun Admin:
   1. Daftar akaun biasa (contoh role apa-apa) melalui app/RegisterScreen
   2. Manual edit field `role` jadi "Admin" dalam Firestore Console
   3. Login semula — akan route ke AdminDashboard
```

---

## 6. Firestore Security Rules (Ringkasan)

- **Fungsi `isAdmin()`** — helper yang check role user semasa dari `users/{uid}` sama ada `"Admin"`; digunakan dalam rules `users` dan `subjectCatalog`
- `users` — boleh dibaca oleh sesiapa yang login; boleh diedit oleh pemilik akaun sendiri **ATAU** oleh Admin (guna `isAdmin()`)
- `subjectCatalog` — boleh dibaca oleh sesiapa yang login; hanya Admin boleh tulis (tambah/edit/padam)
- `chats` — hanya participant yang terlibat boleh baca/tulis
- `chats/{chatId}/messages` — mesej hanya boleh dicipta (bukan edit/padam), dan `senderId` mesti padan dengan pengguna yang login
- `chats/{chatId}/scheduledReplies` — hanya participant boleh baca; hanya pemilik (`senderId` == uid login) boleh cipta/kemaskini/padam (untuk Overtime Mode "Schedule Reply")
- `attendance`, `performance`, `warningLetters` — (cadangan) hanya teacher berkaitan & Firestore Admin SDK (server-side) boleh tulis; student/parent hanya boleh baca data berkaitan diri sendiri/anak sendiri
- **Firebase Storage** (`chats/{chatId}/attachments/{fileName}`) — hanya participant chat berkaitan boleh baca/tulis; had saiz fail 10MB dikuatkuasakan di peringkat rules — rujuk Seksyen 8.8

---

## 7. Susunan Fail Projek (Struktur `lib/`)

```
lib/
├── main.dart                            // home: WelcomeScreen; ThemeData/design system dikongsi
├── firebase_options.dart
├── models/
│   ├── user_model.dart
│   └── message_model.dart          (cadangan — belum wujud)
├── screens/
│   ├── welcome_screen.dart              // ✅ entry point app, EN
│   ├── register_screen.dart             // ✅ sign up, EN
│   ├── login_screen.dart
│   ├── student_dashboard.dart           // ✅ = ChatListScreen dikonfigur (bukan skrin menu)
│   ├── teacher_dashboard.dart           // ✅ = ChatListScreen dikonfigur (bukan skrin menu)
│   ├── parent_dashboard.dart            // placeholder, chat module belum dibina
│   ├── user_search_screen.dart          // ✅ generik: cari Teacher (Student) atau Student (Teacher), papar profile/mula chat
│   ├── user_profile_screen.dart         // ✅ profile read-only + butang "Message"
│   ├── chat_screen.dart                 // ✅ tajuk AppBar boleh tekan → profile (1:1) / group info (group)
│   ├── chat_list_screen.dart            // ✅ tab All/Individual/Groups + unread badge
│   ├── create_group_chat_screen.dart     // ✅ Teacher: cipta group chat, EN
│   ├── group_info_screen.dart           // ✅ senarai ahli group; groupAdmin boleh add/remove, ahli lain boleh "Leave Group"
│   ├── add_group_members_screen.dart    // ✅ groupAdmin sahaja: tambah ahli baru ke group sedia ada
│   ├── full_image_screen.dart           // ✅ viewer penuh skrin untuk attachment jenis image (pinch-to-zoom)
│   ├── admin_dashboard.dart              // ✅ hub Admin, EN
│   ├── manage_users_screen.dart          // ✅ Admin: CRUD users + Edit Subjects, EN
│   ├── manage_subjects_screen.dart       // ✅ Admin: CRUD subjectCatalog, EN
│   ├── create_quiz_screen.dart          // ✅ Teacher: cipta quiz (soalan 4 opsyen)
│   ├── quiz_list_screen.dart            // ✅ Teacher: "My Quizzes", mula host session
│   ├── host_quiz_session_screen.dart    // ✅ Teacher: join code, waiting room, kawal soalan, leaderboard
│   ├── join_quiz_screen.dart            // ✅ Student: masukkan join code
│   ├── live_quiz_play_screen.dart       // ✅ Student: main quiz real-time, timer, leaderboard
│   ├── quiz_leaderboard_view.dart       // ✅ widget leaderboard/podium dikongsi host + student
│   ├── class_performance_screen.dart   (cadangan — belum wujud)
│   ├── attendance_overview_screen.dart (cadangan — belum wujud)
│   └── settings_screen.dart            (cadangan — belum wujud)
└── utils/
    ├── office_hours.dart
    ├── unread_badge.dart               // ✅ conditional export (web/stub)
    ├── unread_badge_stub.dart          // ✅ no-op untuk platform bukan web
    ├── unread_badge_web.dart           // ✅ Badging API via dart:js_interop
    ├── file_validator.dart             // ✅ rujuk Seksyen 8
    └── quiz_theme.dart                 // ✅ palet warna/bentuk gaya Kahoot/Wayground untuk module Quiz

assets/
└── images/
    └── tuturedu_logo.png               // ✅ didaftar dalam pubspec.yaml
```

> **Nota bahasa UI:** Semua skrin (`lib/screens/`, `lib/utils/`, `lib/models/`) kini menggunakan Bahasa Inggeris sepenuhnya, termasuk code comments. Nama sebenar pusat tuisyen ("Pusat Tuisyen Arena Matrix") dikekalkan dalam Bahasa Melayu di `login_screen.dart` sebab ia proper noun.

---

## 8. File Upload / Attachment Security (✅ Dikodkan & berfungsi hujung-ke-hujung)

### 8.1 Skop

Membenarkan user hantar lampiran dalam chat (contoh: nota kelas, slaid, latihan), **terhad kepada fail berkaitan pendidikan sahaja**. Fail berbahaya (contoh `.exe` yang di-rename jadi `.pdf`) disekat — pengesahan **bukan** berdasarkan nama sambungan fail sahaja.

### 8.2 Jenis Fail Dibenarkan

| Jenis | Sambungan | Kegunaan |
|---|---|---|
| Dokumen | `.pdf` | Nota, latihan |
| Slaid (baru) | `.pptx` | Slaid kuliah |
| Slaid (lama) | `.ppt` | Slaid kuliah (format sebelum Office 2007) |
| Dokumen Word (baru) | `.docx` | Tugasan |
| Dokumen Word (lama) | `.doc` | Tugasan (format sebelum Office 2007) |
| Spreadsheet (baru) | `.xlsx` | Jadual/data |
| Spreadsheet (lama) | `.xls` | Jadual/data (format sebelum Office 2007) |
| Imej | `.jpg`, `.jpeg`, `.png` | Gambar nota tulisan tangan, screenshot soalan |

**Had saiz fail:** 10MB setiap fail.

> **Nota:** Audio **tidak** disokong dalam implementation semasa (walaupun disebut sebagai kemungkinan dalam reka bentuk awal) — tiada magic number standard tunggal untuk semua format audio (MP3/WAV/M4A berbeza signature), jadi digugurkan dari skop MVP untuk kekal konsisten dengan prinsip "setiap jenis fail mesti ada semakan magic number yang jelas".

### 8.3 Prinsip Pengesahan (Validation) — 3 Lapisan

Semakan nama sambungan (extension) **sahaja tidak mencukupi** — sesiapa boleh tukar nama `virus.exe` kepada `nota.pdf`. Sistem sahkan fail pada 3 lapisan (`lib/utils/file_validator.dart`):

1. **Saiz fail** — tolak terus kalau melebihi 10MB
2. **Sambungan fail (extension)** — tolak terus kalau sambungan tak dalam senarai dibenarkan
3. **Magic number / File signature** — semakan **byte pertama fail sebenar**, tak boleh dipalsukan tanpa ubah struktur dalaman fail

### 8.4 Jadual Magic Number (File Signature)

| Jenis Fail | Magic Number (Hex) | Offset |
|---|---|---|
| PDF | `25 50 44 46` (`%PDF`) | 0 |
| PNG | `89 50 4E 47` | 0 |
| JPG/JPEG | `FF D8 FF` | 0 |
| DOCX / PPTX / XLSX | `50 4B 03 04` (`PK..`) | 0 |
| DOC / PPT / XLS (format lama) | `D0 CF 11 E0 A1 B1 1A E1` (OLE Compound File) | 0 |

**Nota penting:** `.docx`, `.pptx`, dan `.xlsx` semuanya berasaskan format ZIP (Office Open XML), jadi magic number `PK..` sama untuk ketiga-tiganya. **Begitu juga** `.doc`, `.ppt`, dan `.xls` (format lama, sebelum Office 2007) — semuanya berasaskan **OLE Compound File**, jadi kongsi magic number `D0 CF 11 E0 A1 B1 1A E1` yang sama. Untuk bezakan dengan tepat jenis fail sebenar dalam kedua-dua kes ni (bukan hanya "ini ZIP" atau "ini OLE"), perlu analisis struktur dalaman fail lebih lanjut. **Untuk fasa MVP semasa**, semakan magic number + padanan sambungan fail dianggap memadai; penambahbaikan (semak struktur dalaman) kekal sebagai peningkatan masa depan.

Fail `.exe` (magic number `4D 5A` / `MZ`) automatik gagal semua semakan di atas → **ditolak**.

### 8.5 Had Penting: Client-Side vs Server-Side

Semakan magic number di **client (dalam app Flutter)** memberi UX yang baik (reject serta-merta, tak buang bandwidth upload), tetapi **bukan jaminan keselamatan mutlak** — client-side code boleh diubah suai oleh pengguna yang cukup mahir.

**Cadangan penambahbaikan masa depan:**
- Guna **Cloud Function** yang trigger bila fail diupload ke Firebase Storage (`onFinalize` trigger)
- Cloud Function baca beberapa byte pertama fail dari Storage, sahkan magic number di **server-side**
- Kalau tak sah, Cloud Function padam fail tu serta-merta dari Storage dan tandakan mesej sebagai invalid

Untuk fasa FYP semasa, semakan client-side sahaja memadai sebagai proof-of-concept, dengan nota jelas dalam laporan bahawa penambahbaikan server-side adalah cadangan masa depan.

### 8.6 Aliran Logik Upload

Rujuk Seksyen 5.6 untuk aliran logik penuh (langkah demi langkah).

### 8.7 Struktur Firebase Storage

```
chats/
  └── {chatId}/
        └── attachments/
              └── {messageId}_{namaFailAsal}
```

### 8.8 Firebase Storage Security Rules (✅ dideploy & disahkan berfungsi)

```
match /chats/{chatId}/attachments/{fileName} {
  allow read: if request.auth != null &&
               request.auth.uid in firestore.get(/databases/(default)/documents/chats/$(chatId)).data.participants;
  allow write: if request.auth != null &&
                request.auth.uid in firestore.get(/databases/(default)/documents/chats/$(chatId)).data.participants;
}
```

> Nota: Storage Rules boleh sekat berdasarkan saiz & content-type asas, tetapi **tidak boleh** baca magic number fail — pengesahan magic number tetap dilakukan di client (`file_validator.dart`), dengan Cloud Function server-side sebagai cadangan masa depan (rujuk 8.5).
>
> **Nota penting (dijumpai semasa testing sebenar):** Rule asal ada juga semakan `request.resource.size < 10 * 1024 * 1024`, tapi ini disahkan **rosakkan semua write request** dari Flutter Web app (kemungkinan besar sebab bagaimana resumable upload protocol Firebase Storage hantar metadata saiz — `request.resource.size` tak reliable pada peringkat Rules dinilai). Diuji secara empirikal: buang semakan saiz tu → upload terus berfungsi. Oleh itu had 10MB **hanya** dikuatkuasakan client-side (`file_validator.dart`), bukan dalam Storage Rules — cukup memadai untuk app sebenar (user tak boleh bypass client), walaupun secara teori seseorang yang panggil Storage API terus (bukan melalui app) boleh upload fail lebih besar. Trade-off yang diterima untuk skop projek ni.

### 8.9 UI Bubble Attachment dalam Chat

- **Image** (`jpg`/`jpeg`/`png`) — papar thumbnail terus dalam bubble (`Image.network`), tap untuk buka penuh
- **PDF / Document** (`pdf`/`docx`/`pptx`/`xlsx`) — papar sebagai kad dengan ikon (ikut jenis) + nama fail asal, tap untuk buka guna `url_launcher` (buka dalam browser/app luar peranti)

---

## 9. Interactive Quiz (✅ Live Session dikodkan — Self-Paced belum dibina)

Ciri quiz gaya Wayground/Kahoot/Quizizz — teacher cipta quiz dengan soalan aneka pilihan, student jawab. Menyokong **dua mod**: **Live Session** ✅ (semua student join serentak dengan join code, real-time, ada leaderboard — rujuk fail di 4.1) dan **Self-Paced** 🔲 (student buat bila-bila masa sendiri, macam homework — belum dibina).

### 9.1 Skop

- Teacher cipta quiz (tajuk, subjek/tahap, senarai soalan aneka pilihan 4 opsyen)
- **Live Session**: teacher "host" sesi, dapat join code (contoh 6-digit), student masuk guna code, semua jawab soalan yang sama serentak dengan timer, leaderboard real-time
- **Self-Paced**: student browse quiz yang available untuk subjek dia, buat sendiri bila-bila, submit, terus dapat markah & boleh review jawapan

### 9.2 Struktur Firestore (Cadangan)

```
quizzes (collection)
  └── {quizId}
        ├── title: string
        ├── subjectLevel: string          // contoh "Add Maths Form 4", rujuk subjectCatalog
        ├── createdBy: string             // teacherUid
        ├── createdAt: timestamp
        ├── mode: "live" | "self_paced" | "both"
        └── questions (sub-collection)
              └── {questionId}
                    ├── text: string
                    ├── options: array<string>      // 4 opsyen
                    ├── correctIndex: number         // index jawapan betul (0-3)
                    ├── timeLimitSeconds: number      // untuk Live mode, contoh 20
                    └── points: number                // markah asas per-soalan

quizSessions (collection)                  // hanya untuk mod LIVE
  └── {sessionId}
        ├── quizId: string
        ├── hostUid: string                // teacher yang start sesi
        ├── joinCode: string               // 6-digit, unik semasa sesi aktif
        ├── status: "waiting" | "active" | "ended"
        ├── currentQuestionIndex: number
        ├── startedAt / endedAt: timestamp
        └── participants (sub-collection)
              └── {studentUid}
                    ├── name: string
                    ├── score: number
                    └── answers: map<questionId, { selectedIndex, correct, timeTakenMs }>

quizAttempts (collection)                  // hanya untuk mod SELF-PACED
  └── {attemptId}
        ├── quizId: string
        ├── studentUid: string
        ├── startedAt / completedAt: timestamp
        ├── status: "in_progress" | "completed"
        ├── score: number
        └── answers: map<questionId, selectedIndex>
```

### 9.3 Aliran Logik (Cadangan)

**Live Session (Teacher host):**
```
Teacher pilih quiz → tekan "Host Live Session"
   → Create dokumen quizSessions, generate joinCode 6-digit unik
   → Status "waiting" — papar joinCode besar untuk student masuk
   → Student masuk join code → tambah diri ke participants sub-collection
   → Teacher tekan "Start" → status "active", currentQuestionIndex = 0
   → Setiap soalan: papar dengan timer countdown
        - Student submit jawapan → update participants/{uid}.answers[questionId]
        - Markah dikira: correct + speed bonus (jawab lebih cepat = markah lebih tinggi, optional)
   → Teacher tekan "Next" → currentQuestionIndex + 1, ulang sampai soalan habis
   → Status "ended" → papar leaderboard akhir (susun ikut score, descending)
```

**Self-Paced (Student):**
```
Student browse senarai quiz (filter ikut subjects dia dalam users/{uid}.subjects)
   → Pilih quiz → "Start Quiz"
   → Create dokumen quizAttempts (status "in_progress")
   → Jawab soalan satu-satu (tiada timer, atau timer longgar optional)
   → Submit → kira score, update status "completed"
   → Papar markah & review jawapan (betul/salah setiap soalan)
```

### 9.4 Firestore Security Rules (Cadangan)

```
match /quizzes/{quizId} {
  allow read: if request.auth != null;
  allow write: if request.auth != null &&
                (request.auth.uid == resource.data.createdBy || isAdmin());
  allow create: if request.auth != null &&
                 request.auth.uid == request.resource.data.createdBy;
}

match /quizSessions/{sessionId} {
  allow read: if request.auth != null;
  allow write: if request.auth != null && request.auth.uid == resource.data.hostUid;

  match /participants/{studentUid} {
    allow read: if request.auth != null;
    allow write: if request.auth != null && request.auth.uid == studentUid;
  }
}

match /quizAttempts/{attemptId} {
  allow read, write: if request.auth != null &&
                       request.auth.uid == resource.data.studentUid;
  allow create: if request.auth != null &&
                 request.auth.uid == request.resource.data.studentUid;
}
```

### 9.5 Nota Pelaksanaan

- **Real-time sync Live Session** guna Firestore `StreamBuilder` (sama pattern macam Chat) — teacher push `currentQuestionIndex`, semua student listen dan auto-update UI bila soalan bertukar
- **Join code collision**: semasa generate 6-digit code, elok check dulu takde sesi lain yang aktif dengan code sama (query `quizSessions` where `joinCode == code AND status == "active"`)
- **Leaderboard** boleh dikira on-the-fly dari `participants` sub-collection (sort by `score` descending) — tak perlu simpan leaderboard berasingan
- Ciri ni **belum masuk timeline semasa** — akan diletak dalam Gantt chart bila kau ready nak mula (cadangan: lepas Quick Reply chips & Class Performance, sebelum Attendance/Parent module, sebab quiz lebih "core" untuk value proposition app berbanding attendance)

---

## 10. Status Keseluruhan Pembangunan

- [x] Welcome / Landing screen (EN)
- [x] Register screen (Sign Up, EN) — auto-create Firebase Auth + Firestore profile
- [x] Login & role-based routing
- [x] Firebase Authentication + Firestore integration
- [x] Real-time chat antara student & teacher
- [x] Office hour lock logic (global)
- [x] Firestore security rules (users & chats)
- [x] Overtime Mode (Reply Now / Schedule Reply) — client-side, auto-send bila ChatScreen dibuka semula
- [x] Admin Dashboard (quick stats + navigasi)
- [x] Manage Users (Admin: search, filter, tukar role, delete)
- [x] Manage Subjects (Admin: CRUD subjectCatalog) — kod ditulis, belum diintegrasikan/diuji
- [x] Group Chat (teacher cipta group ikut subjek, pilih student secara manual)
- [x] File upload dengan validation 3-lapisan (extension + saiz + magic number) — rujuk Seksyen 8. Firebase Storage dah enabled & berfungsi hujung-ke-hujung
- [x] Quick Reply chips
- [x] Interactive Quiz — Live Session (rujuk Seksyen 9); Self-Paced belum dibina
- [ ] On-Duty/Off-Duty manual toggle
- [ ] Class Performance Overview + Warning Letter system
- [ ] Attendance Overview (Student)
- [ ] Modul Parent (chat + monitoring)
- [x] Chat list (senarai perbualan aktif)
- [ ] Push notification (FCM)
- [ ] Full Admin account deletion (padam akaun Firebase Authentication, perlukan Cloud Function/Admin SDK)
---

*Dokumen ini adalah rujukan hidup — kemas kini bila ciri baru siap dilaksanakan atau reka bentuk berubah.*
