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
        ├── parentUid: string                     // ✅ untuk Student, rujuk ke uid Parent - diisi oleh Admin (link_parent_child_screen.dart), rujuk 5.9
        ├── childUid: string                      // ✅ untuk Parent, rujuk ke uid Student - diisi oleh Admin, kedua-dua field ditulis serentak dalam SATU batch
        ├── dutyStatus: "on_duty" | "off_duty"    // ✅ untuk Teacher, toggle manual dari AppBar TeacherDashboard - field tiada (belum pernah toggle) = layan sebagai "on_duty", rujuk 5.10
        ├── fcmTokens: array<string>              // ✅ push notification tokens peranti (boleh > 1 - login banyak device/tab), rujuk 5.12
        ├── pushEnabled: boolean                  // ✅ keutamaan Settings - tiada field = layan sebagai true, rujuk 5.14
        ├── leaveStart / leaveEnd: timestamp       // ✅ untuk Teacher, julat tarikh cuti (Settings) - auto Off-Duty, rujuk 5.14
        ├── notificationSound: string              // ✅ salah satu "option1_pop"/"option2_marimba"/"option3_double_tap" - tiada field = "option2_marimba" (default), rujuk 5.15
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

### 3.3 Collection: `attendance` (✅ Sudah dilaksanakan)

```
attendance (collection)
  └── {studentUid}
        └── records (sub-collection)
              └── {recordId}                // ✅ deterministik: "{subjectLevel}_{yyyy-MM-dd}"
                                              //    (tandakan semula subjek+tarikh sama = overwrite, bukan duplicate)
                    ├── subject: string          // format "Subjek Tahap", contoh: "Add Maths Form 4"
                    ├── date: timestamp
                    ├── status: "present" | "absent"
                    ├── markedBy: string          // ✅ uid teacher yang tandakan
                    └── markedAt: timestamp        // ✅ serverTimestamp()
```

### 3.4 Collection: `performance` (✅ Sudah dilaksanakan)

```
performance (collection)
  └── {subjectLevel}                     // contoh: "Add Maths Form 4" - guna sebagai document ID terus
        └── students (sub-collection)
              └── {studentUid}
                    ├── name: string
                    ├── percentage: number             // 0-100, diisi manual oleh teacher
                    ├── trend: "steady" | "dropping" | "critical"   // ✅ dikira automatik, rujuk 5.5
                    └── lastUpdated: timestamp
```

### 3.5 Collection: `warningLetters` (✅ Sudah dilaksanakan)

```
warningLetters (collection)
  └── {letterId}
        ├── studentUid: string
        ├── teacherUid: string
        ├── parentUid: string
        ├── subjectLevel: string    // ✅ ditambah semasa implementasi - subjek yang trigger warning
        ├── reason: string          // teacher edit sebelum hantar, prefilled dengan cadangan mesej
        ├── sentAt: timestamp
        └── acknowledged: boolean   // sentiasa false semasa dicipta - tiada UI utk ack lagi (student/parent belum dibina)
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
- **Overtime Mode & Schedule Message** — bila chat locked, Teacher diberi pilihan "Reply Now (Overtime Mode)" atau "Schedule Reply"; Student/Parent diberi "Schedule Message" (mekanisme sama, cuma tiada bypass "Reply Now" — rujuk 5.4)
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
- **Class Performance Overview + Warning Letter (✅ dikodkan, rujuk Seksyen 5.5)** — `class_performance_screen.dart`: Teacher pilih subjek dia ajar (dropdown), papar "Class Health Score" (purata `percentage` semua student yang dah digred dalam subjek tu) + breakdown Safe/At-Risk/Barred (>=70% / 50-69% / <50%). Senarai student enrolled dalam subjek tu (query `users` sama macam Group Chat) digabung dengan data `performance/{subjectLevel}/students` (kalau belum ada rekod, papar "Not graded yet"). Tekan "%" pada row student untuk buka dialog masukkan markah baru (0-100) — `trend` (Steady/Dropping/Critical) dikira **automatik** berdasarkan beza markah baru vs lama (drop >=15 mata = Critical, drop < 15 = Dropping, selain itu Steady), bukan dipilih manual oleh teacher. Student dengan trend "Critical" papar butang "Send Warning Letter" (dialog reason boleh edit, prefilled cadangan mesej) — cipta dokumen `warningLetters` guna `parentUid` dari profile student (`users/{uid}.parentUid`); kalau student tiada parent linked, papar mesej ralat dan tidak hantar. Setiap student ada butang "History" (bottom sheet senarai warning letter yang pernah dihantar untuk dia, `orderBy sentAt desc`).
- **Attendance (✅ dikodkan, rujuk Seksyen 5.8)** — `take_attendance_screen.dart` (Teacher): pilih subjek + tarikh, senarai student enrolled dipapar dengan togol Present/Absent (default Present, ada "Mark All Present"/"Mark All Absent"), simpan sebagai satu dokumen per student dalam `attendance/{studentUid}/records` guna document ID deterministik (`{subjectLevel}_{yyyy-MM-dd}`) supaya tandakan semula subjek+tarikh yang sama overwrite rekod asal. `attendance_overview_screen.dart` (Student): papar Attendance Rate (%), jumlah kelas dihadiri, dan amaran "Low attendance warning" kalau rate < 75%, dengan dropdown filter ikut subjek dan senarai rekod penuh.
- **Parent Module (✅ dikodkan, rujuk Seksyen 5.9)** — Admin pautkan akaun Parent ke akaun Student lewat `link_parent_child_screen.dart` (accessible dari `manage_users_screen.dart` → "Link Child" pada row Parent), tulis `parentUid`/`childUid` serentak dalam satu batch supaya kedua-dua field sentiasa segerak. `parent_dashboard.dart` kini `ChatListScreen` sebenar (bukan placeholder lagi) — sama corak dengan Teacher/Student: FAB "Message a Teacher" (guna `UserSearchScreen` generik yang sama), nav bar ada "My Child" (→ `child_overview_screen.dart`, tab Attendance + Performance untuk anak yang dipautkan, read-only, papar mesej "belum dipautkan, hubungi Admin" kalau `childUid` masih null) dan ikon "Warning Letters" (→ `parent_warning_letters_screen.dart`, senarai warning letter berkaitan anak, boleh tekan "Mark Read" untuk kemaskini `acknowledged`). Tiada perubahan Firestore rules diperlukan — rules untuk `attendance`/`warningLetters` yang parent-aware sudah sedia dari modul Attendance & Class Performance sebelum ni, cuma baru betul-betul "dipakai" sekarang.
- **On-Duty / Off-Duty Toggle (✅ dikodkan, rujuk Seksyen 5.10)** — ikon `work_outline`/`work_off_outlined` dalam AppBar `teacher_dashboard.dart` (`ChatListScreen.extraActions`, param baru), StreamBuilder live pada `users/{uid}.dutyStatus` supaya ikon+warna sentiasa terkini. Tekan untuk tukar status terus (tiada dialog confirm - reversible, rendah risiko), papar SnackBar mengesahkan. Kesan sebenar: `chat_screen.dart` kini kira "chat terbuka" = jadual office hour automatik **DAN** teacher berkaitan chat tu tak "off_duty" (`_computeIsOfficeHour()`) — kalau teacher tukar ke Off-Duty, SEMUA chat dia terus locked serta-merta (guna banner+Overtime Mode UI yang sama macam luar waktu pejabat), walaupun masih dalam waktu berjadual. `_relevantTeacherUid` (diri sendiri untuk Teacher, `otherUserUid`/`groupAdmin` untuk Student/Parent) di-watch live supaya lock terus update kalau teacher toggle semasa chat screen terbuka.
- **Interactive Quiz — Live Session (✅ dikodkan, rujuk Seksyen 9)** — Teacher: `quiz_list_screen.dart` ("My Quizzes") → `create_quiz_screen.dart` (tajuk, subjek, mod, soalan aneka pilihan 4 opsyen + time limit + points) → tekan quiz untuk `host_quiz_session_screen.dart` (generate join code 6-digit, waiting room dengan senarai student join secara live, kawal "Next Question"/"End Quiz", leaderboard akhir). Student: FAB "Join a Quiz" → `join_quiz_screen.dart` (masukkan join code) → `live_quiz_play_screen.dart` (StreamBuilder ikut `quizSessions.status`/`currentQuestionIndex`, countdown timer disegerakkan guna `currentQuestionStartedAt`, submit jawapan, leaderboard). Firestore rules ditambah untuk `quizzes`/`quizSessions` (rujuk firestore.rules) — markah dikira & ditulis client-side (had FYP yang sama macam file validation, tiada Cloud Function). UI/UX guna palet vibrant gaya Wayground/Kahoot (`quiz_theme.dart` — 4 warna+bentuk opsyen, gradient ungu, leaderboard podium dikongsi via `quiz_leaderboard_view.dart`).
- **Interactive Quiz — Self-Paced (✅ dikodkan, rujuk Seksyen 9.6)** — Teacher pilih mod "Self-Paced"/"Both" semasa cipta quiz. Student: FAB/nav bar "Self-Paced Quizzes" → `self_paced_quiz_list_screen.dart` (senarai quiz untuk subjek dia, badge markah kalau dah submit) → `attempt_quiz_screen.dart` (jawab semua soalan sekali gus, tiada timer, submit sekali sahaja - dwi-mod Attempt/Review dalam satu skrin). `quizAttempts/{quizId}_{studentUid}` (ID deterministik, elak retake & elak keperluan index).
- **Admin Reports (✅ dikodkan, rujuk Seksyen 5.11)** — `admin_reports_screen.dart` gantikan placeholder "Coming Soon" — statistik sebenar (users ikut role, chats, quizzes, quiz sessions, quiz attempts, warning letters, subjek) guna Firestore `count()` aggregation query, tiada dokumen sebenar dibaca, tiada index baru diperlukan.
- **Push Notifications (✅ dikodkan & AKTIF sepenuhnya di Web, rujuk Seksyen 5.12)** — Cloud Functions (`functions/index.js`, projek Node.js BARU, infra berasingan dari Flutter/Firestore rules) hantar push notification sebenar bila mesej chat baru dihantar (`onNewChatMessage`) atau warning letter baru dicipta (`onNewWarningLetter`) — Firestore sendiri TAK BOLEH panggil FCM API terus, perlukan konteks server. `lib/utils/push_notifications.dart` daftar/buang token peranti (`users/{uid}.fcmTokens`) pada login/logout. VAPID key Web dah diisi & dideploy.
- **Settings Screen (✅ dikodkan, rujuk Seksyen 5.14)** — `settings_screen.dart`, boleh diakses semua role (ikon gear dalam nav bar Teacher/Student/Parent, kad menu untuk Admin): Edit Profile (nama), Change Password (perlukan re-auth), Push Notifications on/off (`users/{uid}.pushEnabled`), Notification Sound (3 pilihan, rujuk 5.15), Log Out, Delete Account (self-service, re-auth + padam dokumen Firestore + akaun Firebase Auth sendiri — BEZA dengan had "Admin Delete User" sebab user padam akaun DIA SENDIRI tak perlukan Admin SDK). Teacher sahaja dapat seksyen tambahan "Leave / Holiday" (julat tarikh cuti, auto Off-Duty untuk tempoh tu — rujuk 5.14).
- **Notification Sound (✅ dikodkan, rujuk Seksyen 5.15)** — 3 fail bunyi (`assets/sounds/`) boleh dipilih dari Settings, "Marimba" (option2) default. Aktif untuk push foreground (semua platform, `audioplayers`) DAN push background/system di Android (fail sama disalin ke `android/app/src/main/res/raw/`, Cloud Function set `android.notification.sound` ikut keutamaan penerima). Web Push tiada sokongan bunyi custom rentas-browser, jadi background push di Web guna bunyi default OS/browser sahaja.
- **Android App Icon (✅ ditukar)** — ikon launcher (5 densiti mipmap) ditukar dari default Flutter kepada mark "T" TuturEdu (crop sama yang dipakai untuk favicon Web), latar putih. APK release pertama dibina & disahkan (`flutter build apk --release`) — rujuk BLUEPRINT.md nota Android SDK setup lebih awal dalam sesi ni. Nota: `applicationId` masih placeholder `com.example.tuturedu` dan release build guna debug signing key — cukup untuk sideload/demo, TAPI perlu ditukar sebelum publish Play Store sebenar (bukan skop semasa).

### 4.2 Status: Dalam Reka Bentuk (Figma) — Belum Dikodkan 🔲

Berdasarkan prototype Figma, ciri-ciri berikut telah direka tetapi belum dilaksanakan dalam kod:

- **Working Hours Custom Per-Teacher** — setiap teacher set jadual JAM harian sendiri (contoh 10AM-6PM, bukan 9AM-5PM global untuk semua), sebagai penambahbaikan masa depan. **Beza dengan Leave/Holiday (✅ dah dibina, rujuk 5.14)**: Leave/Holiday ialah julat TARIKH auto Off-Duty, bukan jadual jam harian custom.
- **Admin: Full Account Deletion** — "Delete User" dalam Manage Users semasa hanya buang dokumen Firestore; padam akaun **Firebase Authentication** sepenuhnya perlukan Admin SDK/Cloud Function (client-side Flutter tak boleh padam akaun Auth user lain secara terus, atas sebab keselamatan Firebase). **Belum dibina** — perlukan infra Cloud Functions berasingan (Node.js project, deploy pipeline lain), keputusan sengaja ditangguh buat masa ni (rujuk perbualan sesi ni - dianggap infra risk/effort berasingan dari kerja Flutter/Firestore rules yang lain).

### 4.3 Status: Belum Dirancang / Cadangan Masa Depan 💡

Tiada item buat masa ni — Push Notification (dulu satu-satunya item di sini) dah dikodkan, rujuk 5.12.

---

## 5. Aliran Logik (Logic Flow)

### 5.1 Aliran Login

```
User buka app
   → AuthGate (root widget, lib/screens/auth_gate.dart)   // ✅ ditambah
        - StreamBuilder atas FirebaseAuth.authStateChanges()
        - Ada session sah (currentUser != null)?
             YA  → ambil role dari Firestore (users/{uid}), route terus ke
                   dashboard yang sepadan (tiada perlu login semula)
             TIDAK → WelcomeScreen (branding TuturEdu, pilihan "Log In" / "Sign Up")
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

> **Nota:** Firebase Auth sendiri dah auto-persist session merentasi app restart —
> bug asal adalah `main.dart`'s `home:` di-hardcode ke `WelcomeScreen`, jadi
> app minta login semula setiap kali dibuka walaupun session masih sah.
> `AuthGate` fix ni dengan check `currentUser` dulu sebelum papar
> WelcomeScreen. Kalau Firestore user doc dah takde/corrupt (akaun
> dipadam), AuthGate sign-out session yang "mati" tu dan jatuh balik ke
> WelcomeScreen, bukan skrin kosong.

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

### 5.4 Aliran Overtime Mode & Schedule Message (✅ Sudah dilaksanakan — client-side)

```
ChatScreen dibuka
   → Fetch role user semasa dari users/{uid} (_loadCurrentUserRole)
   → Jika chat locked (rujuk _computeIsOfficeHour(), 5.10):
        - Role == "Teacher" → papar DUA butang: "Reply Now (Overtime Mode)"
          & "Schedule Reply"
        - Role == "Student"/"Parent" → papar SATU butang sahaja: "Schedule
          Message" (label je beza, mekanisme di bawah 100% sama)

Jika teacher tekan "Reply Now (Overtime Mode)":
   → _overtimeActive = true (state tempatan dalam ChatScreen) - TEACHER SAHAJA,
     sebab ni pilihan teacher secara sukarela pecah waktu sendiri; kalau
     Student/Parent boleh buat ni juga, seluruh tujuan office hour lock hilang
   → Input field & send button unlock semula untuk sesi ini
   → Mesej seterusnya dihantar dengan flag `isOvertimeReply: true`
   → _overtimeActive auto-reset bila office hour betul-betul buka semula

Jika mana-mana role tekan "Schedule Reply"/"Schedule Message" (✅ dulu
Teacher sahaja, kini semua role, sebab seluruh pipeline di bawah sentiasa
key ikut senderId, tiada semakan role langsung):
   → Dialog untuk taip mesej (tajuk dialog ikut role: "Schedule Reply" untuk
     Teacher, "Schedule Message" untuk Student/Parent)
   → Simpan ke chats/{chatId}/scheduledReplies:
        { senderId, text, scheduledFor: OfficeHours.nextOpenDateTime(), status: "pending" }
   → Dipapar sebagai senarai pending (dengan butang cancel) di atas chat
     untuk SESIAPA yang ada scheduledReplies dia sendiri dalam chat tu

Auto-hantar scheduled reply (client-side, tanpa Cloud Function):
   → Setiap kali timer 1-minit dalam ChatScreen kesan office hour
     bertukar locked → open, ATAU bila ChatScreen dibuka semasa office hour:
        - Query scheduledReplies milik user semasa, status == "pending",
          scheduledFor <= now
        - Hantar sebagai mesej biasa dengan flag `isScheduledReply: true`
        - Update status jadi "sent"

Nota: auto-hantar hanya berlaku bila ChatScreen berkaitan dibuka semula
selepas office hour bertukar (bukan background/walaupun app tertutup) -
sengaja kekal client-side macam ni walaupun Cloud Functions (`functions/`)
dah wujud sekarang (dibina untuk push notification, rujuk 5.12), sebab
memindah logik "hantar mesej" ke server perlukan reka bentuk berasingan
(contoh: Cloud Scheduler pol berkala) di luar skop kerja terkini.
```

### 5.5 Aliran Class Performance & Warning Letter (✅ Sudah dilaksanakan)

```
Teacher buka Class Performance (`class_performance_screen.dart`, dari nav bar TeacherDashboard)
   → Pilih subjek dari dropdown (senarai subjek yang teacher ajar, users/{uid}.subjects)
   → Query student yang enrolled dalam subjek tu (users where role=="Student" AND
     subjects array-contains subjectLevel) - sama query macam Group Chat (5.2a)
   → StreamBuilder kedua ambil performance/{subjectLevel}/students - gabung secara
     client-side ikut uid (student yang belum ada rekod papar "Not graded yet")
   → Papar "Class Health Score" (purata percentage student yang DAH digred sahaja)
     + breakdown count Safe (>=70%) / At-Risk (50-69%) / Barred (<50%)

Teacher tekan "%" pada row student → dialog masukkan markah baru (0-100)
   → Sistem kira trend automatik: diff = markah_baru - markah_lama
        - diff <= -15  → "critical"
        - diff < 0     → "dropping"
        - selain itu   → "steady"
        - (tiada rekod lama / student baru digred kali pertama → "steady")
   → Simpan ke performance/{subjectLevel}/students/{studentUid}:
        { name, percentage, trend, lastUpdated: serverTimestamp() }

Jika trend student == "critical":
   → Row student papar butang "Send Warning Letter"
   → Fetch users/{studentUid}.parentUid
        - Jika tiada parentUid → papar ralat "tiada parent linked", HENTI
   → Dialog reason (boleh edit, prefilled cadangan mesej ada nama student/subjek/markah)
   → Teacher confirm "Send" → create dokumen warningLetters:
        { studentUid, teacherUid, parentUid, subjectLevel, reason,
          sentAt: serverTimestamp(), acknowledged: false }

Setiap row student ada butang "History" → bottom sheet senarai warningLetters
   milik student tu (query studentUid == uid, orderBy sentAt desc)

Nota: `acknowledged` sentiasa `false` semasa dicipta - tiada UI untuk Parent/Student
tandakan "dah baca" lagi sebab Parent Module & Student-side warning view belum
dibina (rujuk 4.2). Firestore rule untuk field ni dah sedia (allow update terhad
ke field `acknowledged` sahaja, oleh studentUid/parentUid) untuk bila UI tu dibina.
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

### 5.8 Aliran Attendance (✅ Sudah dilaksanakan)

```
Teacher buka "Take Attendance" (`take_attendance_screen.dart`, ikon dari nav bar TeacherDashboard)
   → Pilih subjek (dropdown, dari users/{uid}.subjects) + tarikh (date picker,
     default hari ini, tak boleh pilih tarikh masa depan)
   → Query student enrolled dalam subjek tu (sama query macam Group Chat/Class
     Performance) → untuk setiap student, get() sekali sahaja rekod attendance
     sedia ada untuk subjek+tarikh tu (kalau ada) - default "Present" kalau
     tiada rekod lagi
   → Senarai student papar SwitchListTile (hijau = Present, ditog individu),
     ada butang pantas "Mark All Present" / "Mark All Absent"
   → Tekan "Save Attendance" → satu WriteBatch, satu dokumen per student:
        attendance/{studentUid}/records/{subject}_{yyyy-MM-dd}
        { subject, date, status: "present"|"absent", markedBy: teacherUid,
          markedAt: serverTimestamp() }
     Document ID deterministik (subjek + tarikh) → tandakan attendance kali
     kedua untuk subjek+tarikh yang sama akan OVERWRITE rekod asal (bukan
     duplicate), supaya teacher boleh betulkan kesilapan.

Student buka "My Attendance" (`attendance_overview_screen.dart`, dari nav bar
   atau FAB StudentDashboard)
   → StreamBuilder attendance/{myUid}/records, orderBy date descending
   → Dropdown filter subjek ("All Subjects" atau salah satu subjek yang ada
     rekod) - filter & kira peratus dibuat client-side (rekod seorang
     student sentiasa kecil, tak perlukan composite index)
   → Papar "Attendance Rate" (% dikira dari rekod yang ditapis), "X / Y
     classes attended", dan amaran merah "Low attendance warning" kalau
     rate < 75%
   → Senarai rekod (tarikh, subjek, status Present/Absent bertanda ikon+warna)
```

### 5.9 Aliran Parent Module (✅ Sudah dilaksanakan)

```
Prasyarat - Admin pautkan Parent ↔ Student (sebelum ni TIADA cara buat ni
langsung dalam app - `parentUid`/`childUid` wujud dalam skema sejak awal
tapi tak pernah ditulis oleh mana-mana skrin, rujuk nota dalam 3.1):
   Admin buka Manage Users → row dengan role "Parent" → menu "..." →
   "Link Child" → LinkParentChildScreen(parentUid, parentName)
      → Senarai semua Student (boleh search by nama)
      → Admin tekan satu Student → dialog confirm →
        SATU WriteBatch:
           users/{parentUid}.childUid = studentUid
           users/{studentUid}.parentUid = parentUid
      → Kembali ke Manage Users, row Parent papar "Linked to: {nama student}"
   (Boleh "Unlink Child" bila-bila - batch yang sama tapi FieldValue.delete()
   pada kedua-dua field.)

Parent login → ParentDashboard = ChatListScreen terus (✅ REDESIGN - dulu
   placeholder statik "coming soon", sekarang corak sama macam Teacher/
   Student: chat list ITU SENDIRI, bukan skrin menu depan dia)
   → FAB "+" → bottom sheet "Message a Teacher" → UserSearchScreen
     (targetRole: "Teacher") - sama skrin generik yang Student guna untuk
     cari Teacher, parent boleh cari & chat dengan mana-mana teacher
   → Nav bar (sebelah tab All/Individual/Groups):
        - Ikon "Warning Letters" → ParentWarningLettersScreen
        - Butang teks "My Child" → ChildOverviewScreen

ChildOverviewScreen (read-only, tiada butang edit/hantar):
   → Fetch users/{myUid}.childUid
        - Null → papar "Your account isn't linked to a student yet.
          Please contact an Admin to link your child." (HENTI di sini)
   → Fetch users/{childUid} untuk nama & senarai subjek
   → Tab "Attendance": StreamBuilder attendance/{childUid}/records - sama
     pengiraan macam attendance_overview_screen.dart (rate, warning < 75%)
   → Tab "Performance": untuk setiap subjek anak, get()
     performance/{subjectLevel}/students/{childUid} - papar percentage +
     trend (sama visual macam class_performance_screen.dart tapi tiada
     butang "%"/"Send Warning Letter" - viewing sahaja)

ParentWarningLettersScreen:
   → Query warningLetters where parentUid == myUid, orderBy sentAt desc
   → Setiap letter belum "acknowledged" papar butang "Mark Read" → update
     acknowledged: true (firestore.rules dah benarkan parentUid buat ni
     sejak modul Class Performance dibina - rujuk 5.5 - skrin ni first
     consumer sebenar untuk field tu)

Nota: TIADA perubahan firestore.rules diperlukan untuk seluruh modul ni -
rules untuk `attendance`, `performance`, dan `warningLetters` yang
parent-aware (guna childUid/parentUid) semuanya sudah sedia dari modul
Attendance & Class Performance sebelum ni. Hanya SATU index Firestore baru
diperlukan: warningLetters (parentUid ASC, sentAt DESC) - untuk query
ParentWarningLettersScreen (index studentUid+sentAt yang sedia ada tak
boleh dipakai sebab field equality yang berbeza).
```

### 5.10 Aliran On-Duty / Off-Duty Toggle (✅ Sudah dilaksanakan)

```
Teacher login → TeacherDashboard → AppBar ada ikon On-Duty/Off-Duty
   (StreamBuilder live pada users/{teacherUid}.dutyStatus - ikon
   work_outline (putih) = On-Duty, work_off_outlined (merah muda) = Off-Duty;
   field tiada dalam dokumen = layan sebagai On-Duty)
   → Tekan ikon → terus tukar (tiada dialog confirm, reversible & rendah
     risiko): update users/{teacherUid}.dutyStatus ke "on_duty"/"off_duty"
   → SnackBar mengesahkan status baru

Kesan pada SEMUA chat teacher tu (chat_screen.dart, kedua-dua pihak):
   → "Chat terbuka" kini dikira oleh _computeIsOfficeHour():
        OfficeHours.isOfficeHourNow() DAN teacher berkaitan chat ni bukan
        "off_duty"
   → `_relevantTeacherUid` untuk chat tu ditentukan:
        - Teacher tengok chat sendiri → uid dia sendiri
        - Student/Parent tengok chat 1:1 → otherUserUid (teacher pihak lawan)
        - Sesiapa tengok group chat → groupAdmin (teacher pencipta group)
   → Live listen pada users/{relevantTeacherUid} - lock terus update kalau
     teacher toggle status semasa chat screen sedang terbuka (tak perlu
     tunggu refresh/timer 1-minit)
   → Bila Off-Duty: banner locked papar mesej khusus "This teacher is
     currently Off-Duty. Chat will reopen once they go back On-Duty."
     (beza dari mesej "outside office hours" biasa) - guna UI/logic Overtime
     Mode yang SAMA (teacher boleh "Reply Now"/"Schedule Reply" macam biasa
     kalau nak reply walaupun set diri Off-Duty)
   → Bila teacher toggle balik ke On-Duty semasa dalam waktu pejabat, chat
     terus reopen (sama macam bila jadual automatik masuk waktu pejabat) -
     _overtimeActive direset, scheduled reply yang tertunggak auto-hantar

Nota: TIADA perubahan firestore.rules diperlukan - rule sedia ada untuk
`users/{userId}` (`request.auth.uid == userId`) dah cukup untuk teacher
tulis field `dutyStatus` pada dokumen dia sendiri.
```

### 5.11 Aliran Admin Reports (✅ Sudah dilaksanakan)

```
Admin buka Admin Dashboard → "Reports" (dulu placeholder "Coming Soon")
   → AdminReportsScreen: 11 query Firestore `count()` aggregation
     dijalankan serentak (Future.wait) pada collection top-level sahaja
     (users x4 role, chats, chats where isGroup, subjectCatalog, quizzes,
     quizSessions, quizAttempts, warningLetters) - TIADA dokumen sebenar
     dibaca (lebih murah & pantas dari fetch+tally), TIADA composite index
     diperlukan (setiap query paling banyak SATU filter equality)
   → Papar dalam kad kumpulan: Users (Student/Teacher/Parent/Admin),
     Communication (Total Chats/Group Chats), Interactive Quiz (Quizzes
     Created/Live Sessions/Self-Paced Attempts), Academic (Subjects in
     Catalog/Warning Letters Sent)
   → Butang refresh (ikon) + pull-to-refresh untuk re-fetch semua count

Nota skop: statistik attendance (contoh jumlah rekod attendance) sengaja
TIDAK dimasukkan - itu perlukan collectionGroup query pada sub-collection
`records`, yang boleh perlukan setup index collection-group berasingan;
digugurkan untuk kekal konsisten dengan prinsip "semua query dalam skrin
ni tak perlukan sebarang index baru".

Nota bug (dijumpai lepas cuba skrin ni sebenar): `chats`, `quizAttempts`,
dan `warningLetters` punya rules asal HANYA benarkan participant/pemilik
sendiri baca (tiada bypass Admin macam `users`/`subjectCatalog` sedia ada) -
count() aggregation Admin kena permission-denied pada tiga collection tu.
Fix: tambah `|| isAdmin()` pada rule `allow read` ketiga-tiga collection tu
(rujuk firestore.rules & Seksyen 6) - dideploy.
```

### 5.12 Aliran Push Notifications (✅ Sudah dilaksanakan — ⚠️ satu langkah manual belum siap untuk Web)

```
Prasyarat infra - Cloud Functions (BUKAN Flutter/Firestore rules, projek
Node.js berasingan di `functions/`, pertama kali dipakai dalam projek ni):
   → functions/package.json + functions/index.js (firebase-admin,
     firebase-functions v2)
   → firebase.json ditambah blok "functions" (source: "functions")
   → npm install dalam functions/, firebase deploy --only functions
   → Nota deploy: kali PERTAMA guna Cloud Functions 2nd Gen, deploy mula-mula
     gagal dengan ralat "Permission denied while using the Eventarc Service
     Agent" (IAM permission belum propagate) - retry deploy lepas beberapa
     minit selesaikan ni, seperti yang dicadang oleh mesej ralat sendiri.
   → firebase functions:artifacts:setpolicy (atau deploy --force) untuk
     setup cleanup policy Artifact Registry (imej container Cloud Build lama
     auto-padam lepas 1 hari - elak kos storan terkumpul)

Client (lib/utils/push_notifications.dart):
   → registerPushToken() dipanggil lepas login (login_screen.dart) &
     register (register_screen.dart) berjaya - minta permission notifikasi
     (FirebaseMessaging.requestPermission()), ambil token peranti
     (getToken()), simpan ke users/{uid}.fcmTokens guna arrayUnion (BUKAN
     overwrite - satu akaun boleh log masuk banyak peranti/tab serentak)
   → unregisterPushToken() dipanggil SEBELUM signOut() (chat_list_screen.dart
     _logout, admin_dashboard.dart) - buang token peranti tu sahaja
     (arrayRemove) supaya peranti kongsi/awam tak terus dapat notifikasi
     untuk akaun yang dah log keluar
   → Semua panggilan best-effort (try/catch senyap) - browser tak
     sokong/permission ditolak/VAPID key tiada TAK PERNAH sekat proses
     login/logout, sama falsafah macam unread_badge.dart
   → main.dart: FirebaseMessaging.onMessage (mesej masuk semasa app dibuka
     & fokus) papar SnackBar guna rootScaffoldMessengerKey global - FCM
     hanya auto-papar notifikasi sistem bila app di background/tertutup,
     jadi ini SATU-SATUNYA cara push nampak semasa app aktif

Server (functions/index.js, dua trigger):
   → onNewChatMessage: Firestore trigger pada
     chats/{chatId}/messages/{messageId} onCreate - fetch dokumen chat induk
     untuk senarai participants, keluarkan sender, untuk setiap penerima
     fetch fcmTokens dia, hantar via messaging.sendEachForMulticast()
     (tajuk = nama group/pengirim, badan = teks mesej atau "📎 nama fail").
     Liputi SEMUA jenis mesej (biasa, quick reply, overtime, scheduled
     reply auto-hantar) sebab semua akhirnya jadi satu dokumen biasa dalam
     sub-collection yang sama.
   → onNewWarningLetter: Firestore trigger pada warningLetters/{letterId}
     onCreate - hantar ke parentUid punya fcmTokens. Ini penuhi baris
     "Terima notifikasi warning letter" dari skop asal Parent Module
     (Seksyen 4.1) yang sebelum ni menunggu prasyarat push notification ni.
   → Kedua-dua trigger auto-bersihkan token yang FCM lapor sebagai
     invalid/not-registered (arrayRemove) supaya fcmTokens tak membesar
     tanpa had dengan peranti mati/uninstall

✅ LANGKAH MANUAL SIAP: VAPID key Web dijana oleh user dari Firebase Console
(Project Settings > Cloud Messaging > Web configuration > "Generate key
pair" - langkah ni MEMANG hanya boleh dibuat oleh manusia, Firebase
CLI/automasi tiada cara jana ni) dan diisi dalam `_webVapidKey`
(lib/utils/push_notifications.dart). Web rebuilt (`flutter build web`) &
redeployed ke Hosting supaya key tu masuk dalam JS bundle sebenar - push
notification kini AKTIF sepenuhnya di Web.
Android/iOS TAK pernah terjejas oleh had VAPID ni (guna google-services.json
/ GoogleService-Info.plist sendiri) - tapi app ni belum pernah dibina/diuji
untuk Android/iOS dalam sesi ni (semua build & deploy `flutter build web`
sahaja setakat ni).
```

### 5.13 Nota Pembetulan Bug: Quiz (Live Session) Auto "Sign In Balik" Lepas Finish

```
Symptom: student tekan "Done" pada leaderboard akhir lepas quiz Live Session
tamat → app papar semula WelcomeScreen/LoginScreen macam kena log out,
walaupun sesi Firebase Auth sebenarnya MASIH sah (bukan signOut() sebenar).

Punca: login_screen.dart guna Navigator.pushReplacement() (bukan
pushAndRemoveUntil()) untuk route ke dashboard lepas login berjaya - ni
GANTIKAN LoginScreen sahaja di puncak stack, tapi WelcomeScreen (route
PERTAMA, dari MaterialApp.home) kekal terkubur di dasar navigator stack
untuk SELAMA-LAMANYA. live_quiz_play_screen.dart punya leaderboard "Done"
guna Navigator.popUntil(context, (route) => route.isFirst) - ni pop
SEMUA route sehingga sampai balik ke WelcomeScreen tu (route pertama),
bukan StudentDashboard macam yang dijangka.

Fix (✅ dua bahagian):
   1. live_quiz_play_screen.dart: tukar popUntil(isFirst) → Navigator.pop()
      sahaja (satu tahap) - betul sebab join_quiz_screen.dart → sini pun
      pushReplacement (bukan push biasa), jadi satu pop sahaja dah cukup
      pulang terus ke StudentDashboard. Sama macam
      host_quiz_session_screen.dart punya "Done" (Teacher side) yang
      memang dah betul dari awal (Navigator.pop() sahaja).
   2. login_screen.dart: tukar pushReplacement() → pushAndRemoveUntil()
      (sama pattern macam register_screen.dart yang MEMANG dah betul dari
      awal) - ni bersihkan WelcomeScreen/LoginScreen terus dari stack lepas
      login berjaya, punca masalah dihapuskan terus (bukan sekadar patch
      simptom di satu tempat) - mana-mana popUntil(isFirst) lain (kalau ada
      di masa depan) takkan boleh terjebak isu yang sama lagi.
```

### 5.14 Aliran Settings (✅ Sudah dilaksanakan)

```
Sesiapa yang login → ikon gear "Settings" (nav bar Teacher/Student/Parent,
   kad menu Admin) → SettingsScreen (StreamBuilder pada users/{uid} sendiri)

Edit Profile:
   → Ikon pensil pada kad profil → dialog nama → update users/{uid}.name
     (rule sedia ada `request.auth.uid == userId` dah cukup)

Change Password:
   → Dialog: Current Password, New Password, Confirm New Password
   → Validasi tempatan: New Password >= 6 aksara, Confirm mesti sepadan
   → _reauthenticate(currentPassword): EmailAuthProvider.credential(email,
     currentPassword) → user.reauthenticateWithCredential() - WAJIB sebab
     Firebase tolak operasi sensitif (updatePassword) kalau sesi login dah
     "lapuk" (ralat requires-recent-login)
   → Kalau re-auth gagal (password salah) → papar ralat, HENTI
   → user.updatePassword(newPassword)

Leave / Holiday (Teacher sahaja, rujuk juga nota di 4.2 pasal beza dengan
"Working Hours Custom Per-Teacher"):
   → showDateRangePicker() (widget terbina-dalam Flutter) → pilih tarikh
     mula & akhir
   → Simpan users/{uid}.leaveStart (00:00:00 tarikh mula) & .leaveEnd
     (23:59:59 tarikh akhir) sebagai Timestamp
   → Kesan: chat_screen.dart punya _computeIsOfficeHour() kini check TIGA
     syarat (office hour automatik DAN bukan Off-Duty manual DAN bukan
     dalam tempoh cuti) - rujuk 5.10 untuk dua syarat pertama. Listener
     _watchTeacherDutyStatus() yang sama (live pada dokumen teacher) kini
     tangkap leaveStart/leaveEnd sekali dengan dutyStatus - tiada listener
     berasingan diperlukan.
   → Banner locked papar mesej khusus "This teacher is on leave until
     {tarikh}." (beza dari mesej Off-Duty manual atau luar waktu pejabat)
   → Butang "Clear leave dates" (FieldValue.delete() kedua-dua field) papar
     bila leave dates sedang aktif
   → teacher_dashboard.dart punya ikon duty toggle turut kesan status cuti
     (ikon beach_access berasingan) walaupun dutyStatus manual still
     "on_duty" - dua field ni tak saling bergantung, jadi UI perlu papar
     status EFEKTIF (mana-mana satu true = locked), bukan sekadar dutyStatus
     mentah

Push Notifications on/off:
   → SwitchListTile → update users/{uid}.pushEnabled (true/false)
   → true → panggil registerPushToken() (lib/utils/push_notifications.dart)
   → false → panggil unregisterPushToken()
   → registerPushToken() kini SEMAK dulu pushEnabled sebelum minta izin/
     daftar token - kalau user dah matikan dari Settings, login semula pada
     peranti yang sama TAK akan diam-diam aktifkan balik

Log Out:
   → unregisterPushToken() → FirebaseAuth.instance.signOut() →
     pushAndRemoveUntil ke LoginScreen (bersihkan stack, rujuk 5.13)

Delete Account (self-service - BEZA dengan had "Admin Delete User" di 4.2,
rujuk juga 5.7):
   → Dialog amaran + medan Password
   → _reauthenticate(password) - WAJIB sebelum operasi sensitif
     (currentUser.delete() perlukan sesi "baru")
   → unregisterPushToken() → users/{uid}.delete() (dokumen Firestore) →
     currentUser.delete() (akaun Firebase Authentication SENDIRI)
   → pushAndRemoveUntil ke WelcomeScreen
   → Nota skop: Firebase BENARKAN user padam akaun Auth DIA SENDIRI
     client-side (tiada Admin SDK diperlukan) - ni BEZA sepenuhnya dengan
     Admin cuba padam akaun ORANG LAIN (perlukan Cloud Function, rujuk 4.2).
     TIADA cleanup rentas-akaun (contoh: kosongkan childUid pada dokumen
     Parent kalau Student yang dipadam ada parentUid) - trade-off diterima,
     sama macam had sedia ada "Admin Delete User tak sentuh Firebase Auth".
```

### 5.15 Aliran Notification Sound (✅ Sudah dilaksanakan)

```
Sumber: 3 fail .mp3 dalam assets/sounds/ (option1_pop, option2_marimba,
option3_double_tap) - didaftar dalam pubspec.yaml, dimainkan guna pakej
`audioplayers`. Semua definisi (id, label, path asset) berpusat dalam
lib/utils/notification_sounds.dart - satu sumber kebenaran dipakai oleh
Settings (pilih/preview) DAN main.dart (main automatik bila push masuk).

Settings screen:
   → Kad "Notification Sound" - RadioGroup<String> (3 RadioListTile, satu
     per opsyen), setiap row ada ikon "play" untuk preview (main terus,
     TANPA simpan pilihan)
   → Tekan salah satu row (radio) → simpan users/{uid}.notificationSound
     → terus main bunyi tu sekali sebagai maklum balas
   → Tiada field (akaun lama sebelum ciri ni) = layan sebagai
     "option2_marimba" (defaultNotificationSoundId) - ni jugalah pilihan
     lalai eksplisit yang diminta semasa ciri ni dibina

Push foreground (semua platform - Web/Android/iOS sama):
   → main.dart punya FirebaseMessaging.onMessage listener (yang dah ada
     untuk papar SnackBar, rujuk 5.12) kini turut panggil
     playNotificationSoundForCurrentUser() - fetch keutamaan user semasa
     dari Firestore, mainkan guna audioplayers

Push background/system (Android SAHAJA - rujuk had di bawah):
   → 3 fail .mp3 yang SAMA turut disalin ke
     android/app/src/main/res/raw/{id}.mp3 (nama fail = id opsyen, valid
     sebagai nama raw resource Android - huruf kecil + underscore)
   → functions/index.js: kedua-dua trigger (onNewChatMessage,
     onNewWarningLetter) kini fetch users/{uid}.notificationSound untuk
     SETIAP penerima, letak dalam FCM payload sebagai
     android.notification.sound (rujuk nama resource raw yang sama, FCM
     akan cari & mainkan fail tu secara native semasa notifikasi sistem
     dipaparkan)
   → Redeploy functions diperlukan lepas ubah index.js (firebase deploy
     --only functions)

Had skop (Web Push):
   → Web Push (Notification API pelayar) TIADA cara standard rentas-browser
     untuk set bunyi custom pada notifikasi sistem/background - jadi push
     background yang sampai di Web hanya guna bunyi lalai OS/pelayar,
     walaupun user dah pilih bunyi custom dalam Settings. Bunyi custom
     TETAP berfungsi penuh untuk push FOREGROUND di Web (main.dart punya
     onMessage), cuma bukan untuk push background/system di platform tu.
   → iOS tidak disentuh (app belum pernah dibina untuk iOS dalam sesi ni) -
     kalau dibina masa depan, perlukan fail bunyi format .caf/.aiff/.wav
     dibundle dalam projek iOS berasingan, bukan .mp3 yang dipakai untuk
     Android/foreground.
```

---

## 6. Firestore Security Rules (Ringkasan)

- **Fungsi `isAdmin()`** — helper yang check role user semasa dari `users/{uid}` sama ada `"Admin"`; digunakan dalam rules `users` dan `subjectCatalog`
- `users` — boleh dibaca oleh sesiapa yang login; boleh diedit oleh pemilik akaun sendiri **ATAU** oleh Admin (guna `isAdmin()`) — `write` dalam Firestore rules meliputi create/update/DELETE, jadi rule sedia ada ni juga yang benarkan self-delete akaun dari Settings (rujuk 5.14), tiada rule berasingan diperlukan. Rule sedia ada ni cukup untuk Admin tulis `parentUid`/`childUid` pada DUA dokumen user berlainan dalam satu batch (link_parent_child_screen.dart, rujuk 5.9) — tiada perubahan rule diperlukan sebab `isAdmin()` benarkan Admin tulis mana-mana dokumen `users`. Sama juga untuk `fcmTokens`/`pushEnabled`/`leaveStart`/`leaveEnd` (rujuk 5.12/5.14) — user tulis field-field tu pada dokumen sendiri sahaja, rule sedia ada dah cukup, tiada perubahan diperlukan untuk seluruh Settings screen
- `subjectCatalog` — boleh dibaca oleh sesiapa yang login; hanya Admin boleh tulis (tambah/edit/padam)
- `chats` — hanya participant yang terlibat boleh baca/tulis, ATAU Admin boleh baca (ditambah untuk `admin_reports_screen.dart`'s `count()` aggregation, rujuk 5.11 - awalnya terlepas, punca bug permission-denied bila Reports mula-mula dibina)
- `chats/{chatId}/messages` — mesej hanya boleh dicipta (bukan edit/padam), dan `senderId` mesti padan dengan pengguna yang login
- `chats/{chatId}/scheduledReplies` — hanya participant boleh baca; hanya pemilik (`senderId` == uid login) boleh cipta/kemaskini/padam (untuk Overtime Mode "Schedule Reply")
- **Fungsi `teachesSubject(subject)`** — helper yang check `subject` tu ada dalam `users/{uid}.subjects` user semasa; digunakan dalam rules `performance` dan `attendance`
- `performance/{subjectLevel}/students` — boleh dibaca oleh sesiapa yang login; hanya teacher yang mengajar subjectLevel tu (`teachesSubject()`) boleh tulis
- `warningLetters` — boleh dibaca oleh teacher yang hantar, student berkaitan, parent student tu, ATAU Admin (rujuk 5.11); hanya boleh dicipta oleh teacher (`teacherUid` mesti padan uid login); `update` terhad ke field `acknowledged` sahaja, oleh studentUid/parentUid (rujuk 5.5)
- `attendance/{studentUid}/records` — boleh dibaca oleh student berkaitan, teacher yang mengajar subjek rekod tu, atau parent student tu; hanya boleh dicipta/dikemaskini oleh teacher yang mengajar subjek dalam rekod tu (rujuk 5.8). Rule guna short-circuit `resource == null ||` supaya teacher boleh `get()` rekod yang mungkin belum wujud (semak dah tandakan ke belum) tanpa kena nafi
- `quizAttempts/{attemptId}` — hanya student pemilik (`studentUid`) boleh baca/cipta/kemaskini attempt dia sendiri, ATAU Admin boleh baca (rujuk 9.4/9.6/5.11); ID dokumen deterministik jadi tiada isu batch-timing macam `performance`/`attendance`
- **Firebase Storage** (`chats/{chatId}/attachments/{fileName}`) — hanya participant chat berkaitan boleh baca/tulis; had saiz fail 10MB dikuatkuasakan di peringkat rules — rujuk Seksyen 8.8

---

## 7. Susunan Fail Projek (Struktur `lib/`)

```
lib/
├── main.dart                            // home: AuthGate; ThemeData/design system dikongsi
├── firebase_options.dart
├── models/
│   ├── user_model.dart
│   └── message_model.dart          (cadangan — belum wujud)
├── screens/
│   ├── auth_gate.dart                   // ✅ root widget - check session sedia ada (rujuk 5.1) sebelum papar welcome_screen.dart
│   ├── welcome_screen.dart              // ✅ entry point tanpa session, EN
│   ├── register_screen.dart             // ✅ sign up, EN
│   ├── login_screen.dart
│   ├── student_dashboard.dart           // ✅ = ChatListScreen dikonfigur (bukan skrin menu)
│   ├── teacher_dashboard.dart           // ✅ = ChatListScreen dikonfigur (bukan skrin menu)
│   ├── parent_dashboard.dart            // ✅ = ChatListScreen dikonfigur (bukan placeholder lagi, rujuk 5.9)
│   ├── user_search_screen.dart          // ✅ generik: cari Teacher (Student/Parent) atau Student (Teacher), papar profile/mula chat
│   ├── user_profile_screen.dart         // ✅ profile read-only + butang "Message"
│   ├── chat_screen.dart                 // ✅ tajuk AppBar boleh tekan → profile (1:1) / group info (group)
│   ├── chat_list_screen.dart            // ✅ tab All/Individual/Groups + unread badge
│   ├── create_group_chat_screen.dart     // ✅ Teacher: cipta group chat, EN
│   ├── group_info_screen.dart           // ✅ senarai ahli group; groupAdmin boleh add/remove, ahli lain boleh "Leave Group"
│   ├── add_group_members_screen.dart    // ✅ groupAdmin sahaja: tambah ahli baru ke group sedia ada
│   ├── full_image_screen.dart           // ✅ viewer penuh skrin untuk attachment jenis image (pinch-to-zoom)
│   ├── admin_dashboard.dart              // ✅ hub Admin, EN
│   ├── manage_users_screen.dart          // ✅ Admin: CRUD users + Edit Subjects + Link/Unlink Child, EN
│   ├── link_parent_child_screen.dart     // ✅ Admin: pautkan akaun Parent ↔ Student
│   ├── manage_subjects_screen.dart       // ✅ Admin: CRUD subjectCatalog, EN
│   ├── create_quiz_screen.dart          // ✅ Teacher: cipta quiz (soalan 4 opsyen, pilih mod)
│   ├── quiz_list_screen.dart            // ✅ Teacher: "My Quizzes", mula host session (Live/Both sahaja)
│   ├── host_quiz_session_screen.dart    // ✅ Teacher: join code, waiting room, kawal soalan, leaderboard
│   ├── join_quiz_screen.dart            // ✅ Student: masukkan join code
│   ├── live_quiz_play_screen.dart       // ✅ Student: main quiz real-time, timer, leaderboard
│   ├── quiz_leaderboard_view.dart       // ✅ widget leaderboard/podium dikongsi host + student
│   ├── self_paced_quiz_list_screen.dart // ✅ Student: senarai quiz Self-Paced untuk subjek dia
│   ├── attempt_quiz_screen.dart         // ✅ Student: jawab/review quiz Self-Paced (dwi-mod)
│   ├── class_performance_screen.dart    // ✅ Teacher: health score, trend/kategori per-student, Warning Letter
│   ├── take_attendance_screen.dart      // ✅ Teacher: tandakan Present/Absent ikut subjek+tarikh
│   ├── attendance_overview_screen.dart  // ✅ Student: attendance rate, filter subjek, senarai rekod
│   ├── child_overview_screen.dart       // ✅ Parent: tab Attendance + Performance anak (read-only)
│   ├── parent_warning_letters_screen.dart // ✅ Parent: senarai warning letter anak, Mark Read
│   ├── admin_reports_screen.dart        // ✅ Admin: statistik sistem (count aggregation)
│   └── settings_screen.dart             // ✅ Semua role: profile, password, push toggle, leave dates (Teacher), logout, delete account
└── utils/
    ├── office_hours.dart
    ├── unread_badge.dart               // ✅ conditional export (web/stub)
    ├── unread_badge_stub.dart          // ✅ no-op untuk platform bukan web
    ├── unread_badge_web.dart           // ✅ Badging API via dart:js_interop
    ├── file_validator.dart             // ✅ rujuk Seksyen 8
    ├── quiz_theme.dart                 // ✅ palet warna/bentuk gaya Kahoot/Wayground untuk module Quiz
    ├── push_notifications.dart         // ✅ daftar/buang token FCM, rujuk Seksyen 5.12
    └── notification_sounds.dart        // ✅ 3 pilihan bunyi + main audio, rujuk Seksyen 5.15

assets/
├── images/
│   ├── arena_matrix_logo.png
│   └── tuturedu_logo.png               // ✅ didaftar dalam pubspec.yaml
└── sounds/                             // ✅ 3 fail bunyi notification, rujuk Seksyen 5.15
    ├── option1_pop.mp3
    ├── option2_marimba.mp3             // = default (5.15)
    └── option3_double_tap.mp3

web/
└── firebase-messaging-sw.js            // ✅ service worker Web Push, rujuk Seksyen 5.12

functions/                              // ✅ projek Node.js BERASINGAN (bukan lib/, bukan Dart/Flutter)
├── package.json                        // firebase-admin, firebase-functions v2
└── index.js                            // ✅ onNewChatMessage + onNewWarningLetter, hantar android.notification.sound ikut keutamaan, rujuk 5.12/5.15

android/app/src/main/res/               // ✅ ikon launcher ditukar (rujuk 4.1), + raw/ untuk bunyi Android
├── mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png  // ✅ mark TuturEdu, latar putih
└── raw/                                // ✅ salinan assets/sounds/*.mp3 (nama = Android resource name)
    ├── option1_pop.mp3
    ├── option2_marimba.mp3
    └── option3_double_tap.mp3
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

## 9. Interactive Quiz (✅ Live Session + Self-Paced kedua-duanya dikodkan)

Ciri quiz gaya Wayground/Kahoot/Quizizz — teacher cipta quiz dengan soalan aneka pilihan, student jawab. Menyokong **dua mod**: **Live Session** ✅ (semua student join serentak dengan join code, real-time, ada leaderboard — rujuk fail di 4.1) dan **Self-Paced** ✅ (student buat bila-bila masa sendiri, macam homework — rujuk 9.6). Teacher pilih mod semasa cipta quiz (`create_quiz_screen.dart` — chip "Live Session" / "Self-Paced" / "Both") — field `mode` sama untuk kedua-dua, soalan (`questions` sub-collection) dikongsi.

### 9.1 Skop

- Teacher cipta quiz (tajuk, subjek/tahap, mod, senarai soalan aneka pilihan 4 opsyen)
- **Live Session**: teacher "host" sesi, dapat join code (contoh 6-digit), student masuk guna code, semua jawab soalan yang sama serentak dengan timer, leaderboard real-time
- **Self-Paced**: student browse quiz yang available untuk subjek dia, buat sendiri bila-bila (tiada timer), submit, terus dapat markah & boleh review jawapan — **tiada retake** (satu attempt sahaja per student per quiz)

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

quizAttempts (collection)                  // ✅ hanya untuk mod SELF-PACED
  └── {attemptId}                          // ✅ deterministik: "{quizId}_{studentUid}" (elak retake, tiada query/index diperlukan utk check attempt sedia ada)
        ├── quizId: string
        ├── studentUid: string
        ├── startedAt / completedAt: timestamp
        ├── status: "completed"            // ✅ hanya ditulis sekali submit (tiada draf "in_progress" disimpan - jawapan dikumpul client-side dulu)
        ├── score: number
        ├── totalPoints: number            // ✅ ditambah semasa implementasi - jumlah points semua soalan, untuk papar "X/Y"
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

**Self-Paced (Student) — ✅ rujuk 9.6 untuk butiran pelaksanaan sebenar:**
```
Student browse senarai quiz (filter ikut subjects dia dalam users/{uid}.subjects)
   → Pilih quiz → buka AttemptQuizScreen
   → Jawab semua soalan (tiada timer, satu skrin scroll, semua soalan sekali gus)
   → Submit → kira score client-side, terus tulis quizAttempts (status "completed")
   → Skrin bertukar terus jadi mod REVIEW (tiada navigasi lain) — papar markah &
     setiap soalan dengan jawapan betul/salah ditanda
```

### 9.4 Firestore Security Rules (✅ Dideploy — rujuk firestore.rules untuk versi sebenar `quizzes`/`quizSessions`, sama macam draf asal)

```
match /quizAttempts/{attemptId} {
  allow read: if request.auth != null &&
               request.auth.uid == resource.data.studentUid;
  allow create: if request.auth != null &&
                 request.auth.uid == request.resource.data.studentUid;
  allow update: if request.auth != null &&
                 request.auth.uid == resource.data.studentUid;
  allow delete: if false;
}
```

### 9.5 Nota Pelaksanaan (Live Session)

- **Real-time sync Live Session** guna Firestore `StreamBuilder` (sama pattern macam Chat) — teacher push `currentQuestionIndex`, semua student listen dan auto-update UI bila soalan bertukar
- **Join code collision**: semasa generate 6-digit code, elok check dulu takde sesi lain yang aktif dengan code sama (query `quizSessions` where `joinCode == code AND status == "active"`)
- **Leaderboard** boleh dikira on-the-fly dari `participants` sub-collection (sort by `score` descending) — tak perlu simpan leaderboard berasingan

### 9.6 Nota Pelaksanaan (✅ Self-Paced)

- `create_quiz_screen.dart` — teacher pilih mod via `ChoiceChip` (Live Session/Self-Paced/Both), simpan ke `quizzes.mode`. Field `timeLimitSeconds` per-soalan kekal dalam borang walaupun tak dipakai untuk Self-Paced (tiada timer) - tak berbaloi buang secara bersyarat untuk 1 field yang harmless bila diabaikan.
- `self_paced_quiz_list_screen.dart` (Student) — query `quizzes where mode whereIn ['self_paced','both']` (**hanya SATU** klausa `whereIn`/`in` dibenarkan Firestore setiap query - tak boleh gabung dengan `subjectLevel whereIn [...]` sekali). Jadi subjek pelajar ditapis **client-side** lepas fetch, bukan dalam query. Elak keperluan composite index sepenuhnya.
- Setiap row list guna `FutureBuilder` `get()` sekali ke `quizAttempts/{quizId}_{studentUid}` (ID deterministik) untuk papar badge markah kalau dah submit, atau chevron kalau belum - tiada query, tiada index.
- `attempt_quiz_screen.dart` (Student) — skrin **dwi-mod** dalam satu widget tree:
  - **Mod Attempt**: semua soalan dipapar sekali (bukan satu-satu), pilih jawapan (grid opsyen berwarna sama macam Live Session), butang "Submit Quiz" aktif hanya lepas semua soalan dijawab, dialog confirm sebelum hantar (tak boleh ubah lepas submit).
  - **Mod Review**: auto-aktif kalau `quizAttempts/{quizId}_{studentUid}` dah wujud dengan `status: "completed"` (check sekali dalam `_load()`, atau terus lepas submit tanpa re-fetch) - papar header markah (gradient ungu) + setiap opsyen ditanda betul/salah (border putih + check untuk jawapan betul, silang untuk pilihan salah student), tiada input lagi.
- **Tiada retake**: sebab ID attempt deterministik, submit kali kedua akan overwrite (bukan create baru) - tapi UI tak pernah benarkan submit kali kedua sebab mod Review tak papar butang Submit langsung.
- Firestore rules (`quizAttempts`) tak perlukan `get()` ke dokumen lain (unlike `attendance`) sebab create/update rule check terus `request.resource.data.studentUid`/`resource.data.studentUid` - tiada isu "belum wujud lagi" macam yang dijumpai untuk Class Performance/Attendance.

---

## 10. Status Keseluruhan Pembangunan

- [x] Welcome / Landing screen (EN)
- [x] Register screen (Sign Up, EN) — auto-create Firebase Auth + Firestore profile
- [x] Login & role-based routing
- [x] Session persistence (AuthGate, rujuk Seksyen 5.1) — app tak minta login semula bila dibuka semula dengan session sah
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
- [x] Interactive Quiz — Live Session (rujuk Seksyen 9)
- [x] Interactive Quiz — Self-Paced (rujuk Seksyen 9.6)
- [x] Class Performance Overview + Warning Letter system (rujuk Seksyen 5.5)
- [x] Attendance (Take Attendance + Attendance Overview, rujuk Seksyen 5.8)
- [x] Modul Parent (Admin Link/Unlink Child, ParentDashboard chat, Child Overview, Warning Letters, rujuk Seksyen 5.9)
- [x] On-Duty/Off-Duty manual toggle (rujuk Seksyen 5.10)
- [x] Admin Reports (statistik sistem, rujuk Seksyen 5.11)
- [x] Chat list (senarai perbualan aktif)
- [x] Push notification (FCM, rujuk Seksyen 5.12) — Web VAPID key dah diisi & dideploy, aktif sepenuhnya; Android dapat bunyi custom untuk background push (rujuk 5.15) - iOS tak terjejas tapi belum dibina/diuji
- [x] Settings Screen — Edit Profile, Change Password, Push toggle, Notification Sound (3 pilihan), Log Out, Delete Account (self-service), Leave/Holiday dates untuk Teacher (rujuk Seksyen 5.14/5.15)
- [x] Android APK — `flutter build apk --release` disahkan berfungsi, ikon launcher ditukar dari default Flutter (rujuk 4.1). Package name `com.example.tuturedu` & debug signing masih placeholder - cukup untuk sideload/demo, belum sedia untuk publish Play Store
- [ ] Full Admin account deletion (padam akaun Firebase Authentication, perlukan Cloud Function/Admin SDK — infra Cloud Functions dah wujud sekarang dari kerja push notification, jadi ni jadi lebih senang nak tambah bila-bila; BEZA dengan self-delete akaun sendiri yang dah dibina dalam Settings)
---

*Dokumen ini adalah rujukan hidup — kemas kini bila ciri baru siap dilaksanakan atau reka bentuk berubah.*
