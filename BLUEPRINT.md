# TuturEdu — Project Blueprint

Final Year Project (FYP) — Politeknik METrO Tasek Gelugor
Stakeholder / Use-case: Pusat Tuisyen
Platform perbualan (chat) antara Student, Teacher, dan Parent dengan sekatan waktu pejabat (office hour lock).

---

## 1. Ringkasan Projek

TuturEdu ialah aplikasi chat berasaskan Flutter + Firebase yang membenarkan tiga jenis pengguna — **Student**, **Teacher**, dan **Parent** — berkomunikasi dalam satu platform, dengan sekatan masa perbualan mengikut waktu pejabat (office hour) teacher. Matlamat utama sistem ini adalah mewujudkan sempadan yang jelas antara waktu mengajar dan waktu peribadi teacher, sambil kekal membenarkan komunikasi akademik yang cekap antara pusat tuisyen, student, dan parent.

Projek ini dibangunkan sebagai Final Year Project (FYP) di Politeknik METrO Tasek Gelugor, dengan pusat tuisyen sebagai stakeholder/use-case sasaran sistem.

**Platform:** Flutter (mobile & web, responsive)
**Backend:** Firebase (Authentication, Cloud Firestore, Hosting)
**Bahasa pengaturcaraan:** Dart

---

## 2. Peranan Pengguna (User Roles)

| Role | Fungsi Utama |
|---|---|
| **Student** | Chat dengan teacher, lihat attendance/performance sendiri, ada info parent dalam profile |
| **Teacher** | Chat dengan student & parent, urus On-Duty/Off-Duty status, lihat class performance overview, hantar warning letter |
| **Parent** | Monitor anak (attendance, performance), chat dengan teacher berkaitan hal anak |

---

## 3. Struktur Firestore

### 3.1 Collection: `users`

```
users (collection)
  └── {uid}
        ├── uid: string
        ├── email: string
        ├── name: string
        ├── role: "Student" | "Teacher" | "Parent"
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
        └── messages (sub-collection)
              └── {messageId}
                    ├── senderId: string
                    ├── text: string
                    ├── timestamp: timestamp
                    ├── attachmentUrl: string (optional)   // untuk future: document/image/audio
                    ├── attachmentType: "document" | "image" | "audio" (optional)
                    └── isQuickReply: boolean (optional)    // mesej dari quick-reply chip
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

---

## 4. Ciri-Ciri Utama (Features)

### 4.1 Status: Sudah Dilaksanakan ✅

- **Login & Role-based Routing** — Firebase Authentication + semakan role dari Firestore, auto-route ke dashboard mengikut role
- **Real-time Chat** — mesej dikemas kini secara langsung menggunakan `StreamBuilder` + Firestore `snapshots()`
- **Cari Pensyarah** — student boleh cari & pilih teacher untuk mula chat baru
- **Office Hour Lock (Global)** — chat automatik dikunci di luar waktu pejabat (Isnin–Jumaat, 9AM–5PM), guna semakan `DateTime.now()` pada client
- **Firestore Security Rules** — setiap chat hanya boleh diakses oleh participant yang terlibat

### 4.2 Status: Dalam Reka Bentuk (Figma) — Belum Dikodkan 🔲

Berdasarkan prototype Figma, ciri-ciri berikut telah direka tetapi belum dilaksanakan dalam kod:

- **On-Duty / Off-Duty Toggle (Manual)** — teacher boleh tukar status sendiri, bukan hanya bergantung jadual automatik
- **Overtime Mode** — bila chat locked (outside office hour), teacher diberi pilihan:
  - **"Reply Now (Overtime Mode)"** — override lock, reply terus
  - **"Schedule Reply for 8:00 AM"** — jadualkan reply automatik bila office hour buka semula
- **Quick Reply Chips** — butang pantas dalam chat (contoh: "OK", "Thank you", "Wait") untuk balasan pantas
- **Attachment Support** — hantar document, image, atau audio dalam chat
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

### 4.3 Status: Belum Dirancang / Cadangan Masa Depan 💡

- Register / self sign-up screen
- Chat list (senarai semua perbualan aktif dalam satu skrin)
- Push notification sebenar (Firebase Cloud Messaging)

---

## 5. Aliran Logik (Logic Flow)

### 5.1 Aliran Login

```
User buka app
   → LoginScreen
   → Masukkan email & password
   → FirebaseAuth.signInWithEmailAndPassword()
   → Ambil role dari Firestore (users/{uid})
   → Route mengikut role:
        - "Teacher" → TeacherDashboard
        - "Student"  → StudentDashboard
        - "Parent"   → ParentDashboard
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
        - (Cadangan Figma) Papar pilihan "Reply Now (Overtime)" / "Schedule Reply"
   → Timer semak status setiap 1 minit (auto-update UI bila jam bertukar)
   → Semasa hantar mesej: double-check office hour untuk elak race condition
```

### 5.4 Aliran Overtime Mode (Cadangan — belum dikod)

```
Chat locked (outside office hour)
   → Teacher nampak butang "Reply Now (Overtime Mode)"
   → Jika ditekan:
        - Override lock sementara untuk mesej ini sahaja
        - Mesej dihantar dengan flag `isOvertimeReply: true`
        - (Pilihan) Log dalam analytics untuk track kekerapan overtime
   → ATAU teacher tekan "Schedule Reply for 8:00 AM"
        - Simpan draft reply dalam Firestore dengan `scheduledFor` timestamp
        - Cloud Function (perlu setup) akan hantar mesej automatik bila masa tiba
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

---

## 6. Firestore Security Rules (Ringkasan)

- `users` — boleh dibaca oleh sesiapa yang login; hanya boleh diedit oleh pemilik akaun sendiri
- `chats` — hanya participant yang terlibat boleh baca/tulis
- `chats/{chatId}/messages` — mesej hanya boleh dicipta (bukan edit/padam), dan `senderId` mesti padan dengan pengguna yang login
- `attendance`, `performance`, `warningLetters` — (cadangan) hanya teacher berkaitan & Firestore Admin SDK (server-side) boleh tulis; student/parent hanya boleh baca data berkaitan diri sendiri/anak sendiri

---

## 7. Susunan Fail Projek (Struktur `lib/`)

```
lib/
├── main.dart
├── firebase_options.dart
├── models/
│   ├── user_model.dart
│   └── message_model.dart          (cadangan — belum wujud)
├── screens/
│   ├── login_screen.dart
│   ├── student_dashboard.dart
│   ├── teacher_dashboard.dart
│   ├── parent_dashboard.dart
│   ├── teacher_list_screen.dart
│   ├── chat_screen.dart
│   ├── class_performance_screen.dart   (cadangan — belum wujud)
│   ├── attendance_overview_screen.dart (cadangan — belum wujud)
│   └── settings_screen.dart            (cadangan — belum wujud)
└── utils/
    └── office_hours.dart
```

---

## 8. Status Keseluruhan Pembangunan

- [x] Login & role-based routing
- [x] Firebase Authentication + Firestore integration
- [x] Real-time chat antara student & teacher
- [x] Office hour lock logic (global)
- [x] Firestore security rules (users & chats)
- [ ] Overtime Mode (Reply Now / Schedule Reply)
- [ ] Quick Reply chips
- [ ] Attachment support (document/image/audio)
- [ ] On-Duty/Off-Duty manual toggle
- [ ] Class Performance Overview + Warning Letter system
- [ ] Attendance Overview (Student)
- [ ] Modul Parent (chat + monitoring)
- [ ] Register screen
- [ ] Chat list (senarai perbualan aktif)
- [ ] Push notification (FCM)

---

*Dokumen ini adalah rujukan hidup — kemas kini bila ciri baru siap dilaksanakan atau reka bentuk berubah.*
