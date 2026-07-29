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
  └── {chatId}                          // format: "{uid1}_{uid2}" (uid disusun abjad)
        ├── participants: array<string>  // [uid1, uid2]
        ├── chatType: "student_teacher" | "parent_teacher"
        ├── lastMessage: string
        ├── lastUpdated: timestamp
        ├── messages (sub-collection)
        │     └── {messageId}
        │           ├── senderId: string
        │           ├── text: string
        │           ├── timestamp: timestamp
        │           ├── isOvertimeReply: boolean (optional)   // ✅ true jika dihantar via "Reply Now (Overtime Mode)"
        │           ├── isScheduledReply: boolean (optional)  // ✅ true jika dihantar via auto-send "Schedule Reply"
        │           ├── attachmentUrl: string (optional)      // ✅ rujuk Seksyen 8
        │           ├── attachmentType: "pdf" | "image" | "document" (optional)  // ✅ rujuk Seksyen 8
        │           ├── attachmentName: string (optional)     // ✅ nama fail asal
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
- **File Upload / Attachment (PDF, Image, Document)** — sokongan hantar lampiran dalam chat, disahkan guna validation 3-lapisan (extension + MIME + magic number) — rujuk Seksyen 8
- **Admin Dashboard** — hub khas untuk role Admin: quick stats (jumlah Student/Teacher/Parent), navigasi ke Manage Users & Manage Subjects
- **Manage Users (Admin)** — Admin boleh search/filter user ikut role, tukar role user (contoh Student → Teacher), padam user (buang dokumen Firestore; akaun Firebase Authentication kekal — nota dipapar dalam UI, rujuk 4.2/limitation)
- **Manage Subjects (Admin)** — Admin boleh tambah/padam entri dalam `subjectCatalog` (Subjek + Tahap, contoh "Add Maths Form 4") — rujuk Seksyen 3.6
- **Firestore Security Rules** — setiap chat & scheduledReplies hanya boleh diakses oleh participant/pemilik yang terlibat; `users` & `subjectCatalog` ada permission khas untuk Admin (fungsi `isAdmin()`)

### 4.2 Status: Dalam Reka Bentuk (Figma) — Belum Dikodkan 🔲

Berdasarkan prototype Figma, ciri-ciri berikut telah direka tetapi belum dilaksanakan dalam kod:

- **On-Duty / Off-Duty Toggle (Manual)** — teacher boleh tukar status sendiri, bukan hanya bergantung jadual automatik
- **Quick Reply Chips** — butang pantas dalam chat (contoh: "OK", "Thank you", "Wait") untuk balasan pantas
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

- Chat list (senarai semua perbualan aktif dalam satu skrin)
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
        - "Teacher" → TeacherDashboard
        - "Student"  → StudentDashboard
        - "Parent"   → ParentDashboard
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

### 5.2 Aliran Mula Chat (Student → Teacher)

```
Student di StudentDashboard
   → Tekan "Cari Pensyarah"
   → TeacherListScreen (senarai teacher dari users collection, role == "Teacher")
   → Student pilih satu teacher
   → Sistem generate chatId (gabungan uid, disusun abjad)
   → Create/reuse dokumen dalam chats/{chatId}
   → Navigate ke ChatScreen
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

### 5.6 Aliran File Upload / Attachment (✅ Sudah dilaksanakan — client-side)

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

### 5.7 Aliran Admin: Manage Users & Manage Subjects (✅ Sudah dilaksanakan)

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
├── main.dart                            // home: WelcomeScreen
├── firebase_options.dart
├── models/
│   ├── user_model.dart
│   └── message_model.dart          (cadangan — belum wujud)
├── screens/
│   ├── welcome_screen.dart              // ✅ entry point app, EN
│   ├── register_screen.dart             // ✅ sign up, EN
│   ├── login_screen.dart
│   ├── student_dashboard.dart
│   ├── teacher_dashboard.dart
│   ├── parent_dashboard.dart
│   ├── teacher_list_screen.dart
│   ├── chat_screen.dart
│   ├── admin_dashboard.dart              // ✅ hub Admin, EN
│   ├── manage_users_screen.dart          // ✅ Admin: CRUD users, EN
│   ├── manage_subjects_screen.dart       // ✅ Admin: CRUD subjectCatalog, EN
│   ├── class_performance_screen.dart   (cadangan — belum wujud)
│   ├── attendance_overview_screen.dart (cadangan — belum wujud)
│   └── settings_screen.dart            (cadangan — belum wujud)
└── utils/
    ├── office_hours.dart
    └── file_validator.dart             // ✅ rujuk Seksyen 8

assets/
└── images/
    └── tuturedu_logo.png               // ✅ didaftar dalam pubspec.yaml
```

> **Nota bahasa UI:** `welcome_screen.dart` dan `register_screen.dart` menggunakan Bahasa Inggeris sepenuhnya. `login_screen.dart` dan skrin lain masih campuran/Bahasa Melayu setakat penulisan blueprint ini — perlu diselaraskan (English sepenuhnya, atau dwibahasa secara konsisten) sebagai future cleanup sebelum submission akhir.

---

## 8. File Upload / Attachment Security (✅ Sudah dilaksanakan — client-side)

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

### 8.8 Firebase Storage Security Rules

```
match /chats/{chatId}/attachments/{fileName} {
  allow read: if request.auth != null &&
               request.auth.uid in firestore.get(/databases/(default)/documents/chats/$(chatId)).data.participants;
  allow write: if request.auth != null &&
                request.auth.uid in firestore.get(/databases/(default)/documents/chats/$(chatId)).data.participants &&
                request.resource.size < 10 * 1024 * 1024;
}
```

> Nota: Storage Rules boleh sekat berdasarkan saiz & content-type asas, tetapi **tidak boleh** baca magic number fail — pengesahan magic number tetap dilakukan di client (`file_validator.dart`), dengan Cloud Function server-side sebagai cadangan masa depan (rujuk 8.5).

### 8.9 UI Bubble Attachment dalam Chat

- **Image** (`jpg`/`jpeg`/`png`) — papar thumbnail terus dalam bubble (`Image.network`), tap untuk buka penuh
- **PDF / Document** (`pdf`/`docx`/`pptx`/`xlsx`) — papar sebagai kad dengan ikon (ikut jenis) + nama fail asal, tap untuk buka guna `url_launcher` (buka dalam browser/app luar peranti)

---

## 9. Status Keseluruhan Pembangunan

- [x] Welcome / Landing screen (EN)
- [x] Register screen (Sign Up, EN) — auto-create Firebase Auth + Firestore profile
- [x] Login & role-based routing
- [x] Firebase Authentication + Firestore integration
- [x] Real-time chat antara student & teacher
- [x] Office hour lock logic (global)
- [x] Firestore security rules (users & chats)
- [x] Overtime Mode (Reply Now / Schedule Reply) — client-side, auto-send bila ChatScreen dibuka semula
- [x] File upload dengan validation 3-lapisan (extension + saiz + magic number) — rujuk Seksyen 8
- [x] Admin Dashboard (quick stats + navigasi)
- [x] Manage Users (Admin: search, filter, tukar role, delete)
- [x] Manage Subjects (Admin: CRUD subjectCatalog)
- [ ] Quick Reply chips
- [ ] On-Duty/Off-Duty manual toggle
- [ ] Class Performance Overview + Warning Letter system
- [ ] Attendance Overview (Student)
- [ ] Modul Parent (chat + monitoring)
- [ ] Chat list (senarai perbualan aktif)
- [ ] Push notification (FCM)
- [ ] Full Admin account deletion (padam akaun Firebase Authentication, perlukan Cloud Function/Admin SDK)
- [ ] Selaraskan bahasa UI merentasi semua skrin (sesetengah masih Bahasa Melayu, welcome/register/admin dah English)

---

*Dokumen ini adalah rujukan hidup — kemas kini bila ciri baru siap dilaksanakan atau reka bentuk berubah.*
