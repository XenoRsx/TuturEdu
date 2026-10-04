// lib/l10n/app_strings.dart
//
// English / Bahasa Melayu UI text (BLUEPRINT.md 5.26). Core screens only -
// Admin screens and the Quiz module stay English (user's scope choice).
//
// How it works: every translatable string is written in English at its
// call site as `context.tr('Log In')`; when the app's locale is Malay, the
// English text is looked up in [_ms] below. Missing entries fall back to
// English, and test/app_strings_test.dart scans lib/ for every literal
// passed to tr() and fails if one has no Malay entry - so a new string
// can't silently ship untranslated. Dynamic parts use {placeholders}:
// `context.tr('Seen by {n}', {'n': count})`.
//
// tr() reads the locale via Localizations.localeOf(context), which
// registers a dependency - so even a `const` screen rebuilds the moment
// the language changes, no restart needed.
//
// The language itself is an account setting (users/{uid}.language,
// "en" | "ms"), applied app-wide by main.dart exactly like themeMode.
// Unset / signed out = follow the device language.

import 'package:flutter/widgets.dart';

const kSupportedLocales = [Locale('en'), Locale('ms')];

/// Drives MaterialApp.locale. null = device language.
final ValueNotifier<Locale?> languageNotifier = ValueNotifier(null);

Locale? localeFromLanguage(String? value) {
  switch (value) {
    case 'en':
      return const Locale('en');
    case 'ms':
      return const Locale('ms');
    default:
      return null;
  }
}

extension AppStrings on BuildContext {
  bool get isMalay => Localizations.localeOf(this).languageCode == 'ms';

  String tr(String english, [Map<String, Object?> args = const {}]) {
    var text = isMalay ? (_ms[english] ?? english) : english;
    args.forEach((key, value) => text = text.replaceAll('{$key}', '$value'));
    return text;
  }

  /// Display name for a stored role value ("Teacher" etc. - the Firestore
  /// value itself always stays English).
  String trRole(String? role) {
    switch (role) {
      case 'Teacher':
        return tr('Teacher');
      case 'Student':
        return tr('Student');
      case 'Parent':
        return tr('Parent');
      case 'Admin':
        return tr('Admin');
      default:
        return role ?? '';
    }
  }

  /// For text built outside this file in English (e.g. OfficeHours'
  /// "Monday - Friday, 8:00 AM - 6:00 PM") - swaps day names only.
  String trDays(String english) {
    if (!isMalay) return english;
    var text = english;
    _days.forEach((en, ms) => text = text.replaceAll(en, ms));
    return text;
  }
}

/// Every Malay string keyed by its exact English source text.
@visibleForTesting
Map<String, String> get malayStrings => _ms;

const _days = {
  'Monday': 'Isnin',
  'Tuesday': 'Selasa',
  'Wednesday': 'Rabu',
  'Thursday': 'Khamis',
  'Friday': 'Jumaat',
  'Saturday': 'Sabtu',
  'Sunday': 'Ahad',
  'Today': 'Hari ini',
};

const _ms = <String, String>{
  // ----- welcome_screen.dart -----
  'Log In': 'Log Masuk',
  'Sign Up': 'Daftar',
  'Could not open the link.': 'Tidak dapat membuka pautan.',
  'The chat platform built for\nPusat Tuisyen Arena Matriks':
      'Platform sembang khas untuk\nPusat Tuisyen Arena Matriks',
  'One organised space to connect students, teachers, and parents — inside clear working hours, with nothing lost in a group chat.':
      'Satu ruang tersusun untuk menghubungkan pelajar, guru dan ibu bapa — dalam waktu operasi yang jelas, tanpa mesej tenggelam dalam group chat.',
  'ABOUT THE CENTRE': 'TENTANG PUSAT',
  'Built around one idea: learning works best when students, tutors, and parents are genuinely connected. Every class runs with that in mind — structured lessons, tutors who follow up on progress, and a clear line of communication home.\n\nTuturEdu is the centre\'s official chat platform, carrying that connection online: one safe space for students, parents, and tutors to talk, in line with the centre\'s working hours.':
      'Dibina atas satu idea: pembelajaran paling berkesan apabila pelajar, tutor dan ibu bapa benar-benar terhubung. Setiap kelas dijalankan dengan prinsip itu — pelajaran berstruktur, tutor yang memantau kemajuan, dan saluran komunikasi yang jelas dengan keluarga.\n\nTuturEdu ialah platform sembang rasmi pusat ini, membawa hubungan itu ke dalam talian: satu ruang selamat untuk pelajar, ibu bapa dan tutor berbincang, selaras dengan waktu operasi pusat.',
  'OPERATING HOURS': 'WAKTU OPERASI',
  'WHAT WE OFFER': 'APA YANG KAMI TAWARKAN',
  'Small, focused classes': 'Kelas kecil dan fokus',
  'Class sizes kept manageable so every student gets real attention, not just a seat in a crowd.':
      'Saiz kelas dikawal supaya setiap pelajar mendapat perhatian sebenar, bukan sekadar tempat duduk dalam kelas yang sesak.',
  'Subjects across levels': 'Subjek pelbagai peringkat',
  'Core and elective subjects covering primary through secondary levels, taught by tutors who know the syllabus inside out.':
      'Subjek teras dan elektif dari peringkat rendah hingga menengah, diajar oleh tutor yang benar-benar menguasai sukatan pelajaran.',
  'Progress that\'s tracked, not guessed': 'Kemajuan dipantau, bukan diteka',
  'Attendance, grades, and performance trends are recorded every term, so both the centre and parents can see how a student is actually doing.':
      'Kehadiran, gred dan trend prestasi direkodkan setiap penggal, supaya pusat dan ibu bapa dapat melihat perkembangan sebenar pelajar.',
  'One conversation space': 'Satu ruang perbualan',
  'TuturEdu keeps students, parents, and tutors talking in one place, inside clear working hours - not scattered across personal phone numbers.':
      'TuturEdu menyatukan perbualan pelajar, ibu bapa dan tutor di satu tempat, dalam waktu operasi yang jelas - bukan bertaburan di nombor telefon peribadi.',

  // ----- Shared / common -----
  'OK': 'OK',
  'Cancel': 'Batal',
  'Save': 'Simpan',
  'Delete': 'Padam',
  'Edit': 'Edit',
  'Add': 'Tambah',
  'Remove': 'Buang',
  'Set': 'Tetapkan',
  'Clear': 'Kosongkan',
  'Change': 'Tukar',
  'New': 'Baharu',
  'Loading...': 'Memuatkan...',
  'Sending...': 'Menghantar...',
  'Please log in again.': 'Sila log masuk semula.',
  'Error: {e}': 'Ralat: {e}',
  'Settings': 'Tetapan',
  'Email': 'E-mel',
  'Password': 'Kata Laluan',
  'Full Name': 'Nama Penuh',
  'Subject': 'Subjek',
  'Subjects': 'Subjek',
  'Subject / Class': 'Subjek / Kelas',
  'Message': 'Mesej',
  'Title': 'Tajuk',
  'Teacher': 'Guru',
  'Student': 'Pelajar',
  'Parent': 'Ibu Bapa',
  'Admin': 'Admin',
  'View profile': 'Lihat profil',
  'No subjects assigned yet': 'Belum ada subjek ditetapkan',
  'Subject catalog is empty. Ask an Admin to add subjects first.':
      'Katalog subjek kosong. Minta Admin tambah subjek dahulu.',

  // ----- auth_error_dialog.dart -----
  'Incorrect email or password. Please try again.':
      'E-mel atau kata laluan salah. Sila cuba lagi.',
  "That doesn't look like a valid email address.":
      'Alamat e-mel itu nampaknya tidak sah.',
  'This account has been disabled. Contact an Admin for help.':
      'Akaun ini telah dinyahaktifkan. Hubungi Admin untuk bantuan.',
  'Too many attempts. Please wait a moment and try again.':
      'Terlalu banyak cubaan. Sila tunggu sebentar dan cuba lagi.',
  'This email is already registered. Please log in instead.':
      'E-mel ini sudah didaftarkan. Sila log masuk.',
  'Password is too weak. Use at least 6 characters.':
      'Kata laluan terlalu lemah. Gunakan sekurang-kurangnya 6 aksara.',
  'Network error. Check your connection and try again.':
      'Ralat rangkaian. Semak sambungan anda dan cuba lagi.',
  'Something went wrong. Please try again.':
      'Sesuatu tidak kena. Sila cuba lagi.',

  // ----- login_screen.dart -----
  'Please enter your email and password!':
      'Sila masukkan e-mel dan kata laluan anda!',
  'Unrecognized role in the system.': 'Peranan tidak dikenali dalam sistem.',
  'User data not found in the database. Make sure the account is registered in Firestore.':
      'Data pengguna tiada dalam pangkalan data. Pastikan akaun telah didaftarkan.',
  'Login Failed': 'Log Masuk Gagal',
  'Reset Password': 'Set Semula Kata Laluan',
  "Enter your account's email and we'll send you a link to set a new password.":
      'Masukkan e-mel akaun anda dan kami akan hantar pautan untuk menetapkan kata laluan baharu.',
  'Send Link': 'Hantar Pautan',
  'Reset Failed': 'Set Semula Gagal',
  'Check Your Email': 'Semak E-mel Anda',
  'If an account exists for {email}, a password reset link has been sent. Check your inbox (and spam folder).':
      'Jika akaun wujud untuk {email}, pautan set semula kata laluan telah dihantar. Semak peti masuk (dan folder spam) anda.',
  'Welcome back': 'Selamat kembali',
  'Log in to continue to your chats':
      'Log masuk untuk teruskan ke sembang anda',
  'Forgot password?': 'Lupa kata laluan?',
  "TuturEdu is the official chat platform for Pusat Tuisyen Arena Matriks, connecting students, parents & tutors in one safe conversation space, in line with the tuition centre's operating hours.":
      'TuturEdu ialah platform sembang rasmi Pusat Tuisyen Arena Matriks, menghubungkan pelajar, ibu bapa & tutor dalam satu ruang perbualan yang selamat, selaras dengan waktu operasi pusat tuisyen.',

  // ----- register_screen.dart -----
  'Please fill in all fields.': 'Sila isi semua ruangan.',
  'Password must be at least 6 characters.':
      'Kata laluan mesti sekurang-kurangnya 6 aksara.',
  'Password and Confirm Password do not match.':
      'Kata Laluan dan Sahkan Kata Laluan tidak sepadan.',
  'Sign Up Failed': 'Pendaftaran Gagal',
  'Create a New Account': 'Cipta Akaun Baharu',
  'Join TuturEdu in a few seconds': 'Sertai TuturEdu dalam beberapa saat',
  'Password (min. 6 characters)': 'Kata Laluan (min. 6 aksara)',
  'Confirm Password': 'Sahkan Kata Laluan',
  'Register As': 'Daftar Sebagai',
  'Already have an account? Log In': 'Sudah ada akaun? Log Masuk',
  "Teacher accounts are set up by the centre's Admin. Teachers: sign up as a Student, then ask the Admin to change your role.":
      'Akaun guru disediakan oleh Admin pusat. Guru: daftar sebagai Pelajar, kemudian minta Admin menukar peranan anda.',

  // ----- mfa_verification_screen.dart -----
  'Could not send the code.': 'Tidak dapat menghantar kod.',
  'Enter the 6-digit code.': 'Masukkan kod 6 digit.',
  'Incorrect code.': 'Kod salah.',
  'your email': 'e-mel anda',
  'Check your email': 'Semak e-mel anda',
  'Sending a 6-digit code to {email}…': 'Menghantar kod 6 digit ke {email}…',
  'We sent a 6-digit code to {email}':
      'Kami telah menghantar kod 6 digit ke {email}',
  'Verify': 'Sahkan',
  'Resend code in {s}s': 'Hantar semula kod dalam {s}s',
  'Resend code': 'Hantar semula kod',
  'Cancel and sign out': 'Batal dan log keluar',

  // ----- Dashboards -----
  'Unread': 'Belum Dibaca',
  'Total Chats': 'Jumlah Sembang',
  'Groups': 'Kumpulan',
  'Attendance': 'Kehadiran',
  'Performance': 'Prestasi',
  'Quizzes': 'Kuiz',
  "You're now Off-Duty. Your chats are locked until you go back on-duty.":
      'Anda kini Luar Tugas. Sembang anda dikunci sehingga anda kembali bertugas.',
  "You're now On-Duty. Your chats follow the normal office-hour schedule again.":
      'Anda kini Bertugas. Sembang anda kembali mengikut jadual waktu pejabat biasa.',
  'You are on leave (set in Settings) — chats are locked':
      'Anda sedang bercuti (ditetapkan dalam Tetapan) — sembang dikunci',
  'You are Off-Duty — tap to go On-Duty':
      'Anda Luar Tugas — ketik untuk Bertugas',
  'You are On-Duty — tap to go Off-Duty':
      'Anda Bertugas — ketik untuk Luar Tugas',
  'New Chat': 'Sembang Baharu',
  'Search a student and start a 1:1 chat':
      'Cari pelajar dan mulakan sembang 1:1',
  'Find a Student': 'Cari Pelajar',
  'New Group': 'Kumpulan Baharu',
  'Create a group chat for a subject/class':
      'Cipta sembang kumpulan untuk subjek/kelas',
  'Find a Teacher': 'Cari Guru',
  'Search a teacher and start a 1:1 chat': 'Cari guru dan mulakan sembang 1:1',
  'Join a Quiz': 'Sertai Kuiz',
  'Enter a 6-digit code from your teacher':
      'Masukkan kod 6 digit daripada guru anda',
  'My Attendance': 'Kehadiran Saya',
  'View your attendance rate and history':
      'Lihat kadar dan sejarah kehadiran anda',
  'Self-Paced Quizzes': 'Kuiz Kendiri',
  'Attempt a quiz on your own time': 'Jawab kuiz pada masa anda sendiri',
  'Message a Teacher': 'Mesej Guru',
  "Search your child's teacher and start a 1:1 chat":
      'Cari guru anak anda dan mulakan sembang 1:1',
  'My Child': 'Anak Saya',
  'Warning Letters': 'Surat Amaran',

  // ----- chat_list_screen.dart -----
  'Chats': 'Sembang',
  'All': 'Semua',
  'Individual': 'Individu',
  'No conversations yet.': 'Belum ada perbualan.',
  'No individual chats yet.': 'Belum ada sembang individu.',
  'No group chats yet.': 'Belum ada sembang kumpulan.',
  'Delete for Me': 'Padam untuk Saya',
  'Removes this chat from your list only':
      'Buang sembang ini daripada senarai anda sahaja',
  'Delete for Everyone': 'Padam untuk Semua',
  'Permanently deletes this chat for everyone':
      'Padam sembang ini secara kekal untuk semua',
  'Delete Chat': 'Padam Sembang',
  'This removes the chat from your list only. It will come back if the other side sends a new message.':
      'Ini membuang sembang daripada senarai anda sahaja. Ia akan muncul semula jika pihak lain menghantar mesej baharu.',
  'This permanently deletes the entire chat and every message in it, for everyone. This cannot be undone.':
      'Ini memadam keseluruhan sembang dan semua mesej di dalamnya secara kekal, untuk semua orang. Tindakan ini tidak boleh dibatalkan.',
  'Failed to delete chat: {e}': 'Gagal memadam sembang: {e}',

  // ----- chat_screen.dart -----
  'typing...': 'sedang menaip...',
  '{name} is typing...': '{name} sedang menaip...',
  '{n} people are typing...': '{n} orang sedang menaip...',
  'Someone': 'Seseorang',
  'Online': 'Dalam talian',
  'Last seen': 'Kali terakhir dilihat',
  'Close search': 'Tutup carian',
  'Search messages': 'Cari mesej',
  'Search messages...': 'Cari mesej...',
  'Group info': 'Info kumpulan',
  'No messages yet': 'Belum ada mesej',
  'Start the conversation!': 'Mulakan perbualan!',
  'No matching messages': 'Tiada mesej sepadan',
  'Nothing in this chat matches "{q}".':
      'Tiada apa-apa dalam sembang ini yang sepadan dengan "{q}".',
  'This message was deleted': 'Mesej ini telah dipadam',
  'Overtime': 'Lebih Masa',
  'Scheduled': 'Dijadualkan',
  'Could not read the selected file.': 'Tidak dapat membaca fail yang dipilih.',
  'Upload timed out. Firebase Storage may not be enabled for this project yet - check the Firebase Console.':
      'Muat naik tamat masa. Firebase Storage mungkin belum diaktifkan untuk projek ini - semak Firebase Console.',
  'Upload timed out.': 'Muat naik tamat masa.',
  'Upload failed: {e}': 'Muat naik gagal: {e}',
  'Attachment Error': 'Ralat Lampiran',
  'Could not open the attachment.': 'Tidak dapat membuka lampiran.',
  'Suspicious link': 'Pautan mencurigakan',
  'This link looks like it could be a phishing attempt:\n\n{url}\n\nOnly open it if you trust where it came from.':
      'Pautan ini mungkin cubaan pancingan data (phishing):\n\n{url}\n\nBuka hanya jika anda mempercayai sumbernya.',
  'Open Anyway': 'Buka Juga',
  'Delete Message': 'Padam Mesej',
  'Delete this message for everyone in the chat? This cannot be undone.':
      'Padam mesej ini untuk semua dalam sembang? Tindakan ini tidak boleh dibatalkan.',
  'Report Message': 'Laporkan Mesej',
  'Send this message to an Admin to review':
      'Hantar mesej ini kepada Admin untuk disemak',
  'Bullying or harassment': 'Buli atau gangguan',
  'Inappropriate content': 'Kandungan tidak sesuai',
  'Spam or scam': 'Spam atau penipuan',
  'Other': 'Lain-lain',
  'Why are you reporting this message?': 'Mengapa anda melaporkan mesej ini?',
  'More details (optional)': 'Butiran lanjut (pilihan)',
  'Report': 'Laporkan',
  'Thanks - an Admin will review this message.':
      'Terima kasih - Admin akan menyemak mesej ini.',
  "You've already reported this message.":
      'Anda sudah pun melaporkan mesej ini.',
  'Could not send report: {e}': 'Tidak dapat menghantar laporan: {e}',
  'Schedule Reply': 'Jadualkan Balasan',
  'Schedule Message': 'Jadualkan Mesej',
  'This message will be sent automatically once office hours reopen ({when}).':
      'Mesej ini akan dihantar secara automatik apabila waktu pejabat dibuka semula ({when}).',
  'Type the message to schedule...': 'Taip mesej untuk dijadualkan...',
  'Schedule': 'Jadualkan',
  'Reply scheduled for {when}.': 'Balasan dijadualkan pada {when}.',
  'Overtime Mode active — your message will be marked as an after-hours reply.':
      'Mod Lebih Masa aktif — mesej anda akan ditandakan sebagai balasan luar waktu.',
  'This teacher is on leave until {date}. Chat will reopen after that.':
      'Guru ini bercuti sehingga {date}. Sembang akan dibuka semula selepas itu.',
  'This teacher is currently Off-Duty. Chat will reopen once they go back On-Duty.':
      'Guru ini sedang Luar Tugas. Sembang akan dibuka semula apabila guru kembali Bertugas.',
  'Chat is closed outside office hours ({hours}). Reopens: {when}.':
      'Sembang ditutup di luar waktu pejabat ({hours}). Dibuka semula: {when}.',
  'Reply Now (Overtime)': 'Balas Sekarang (Lebih Masa)',
  'Scheduled {time}: "{text}"': 'Dijadualkan {time}: "{text}"',
  'Yes': 'Ya',
  'No': 'Tidak',
  'Thank you': 'Terima kasih',
  'Noted': 'Baik, dimaklumkan',
  'Please wait': 'Sila tunggu',
  'Send a file (PDF, Word, PowerPoint, Excel, image)':
      'Hantar fail (PDF, Word, PowerPoint, Excel, gambar)',
  'Type a message (Overtime Mode)...': 'Taip mesej (Mod Lebih Masa)...',
  'Type a message...': 'Taip mesej...',
  'Chat is currently locked': 'Sembang sedang dikunci',

  // ----- settings_screen.dart -----
  'Edit Profile': 'Edit Profil',
  'Profile updated.': 'Profil dikemas kini.',
  'Change Password': 'Tukar Kata Laluan',
  'Current Password': 'Kata Laluan Semasa',
  'New Password': 'Kata Laluan Baharu',
  'Confirm New Password': 'Sahkan Kata Laluan Baharu',
  'New password must be at least 6 characters.':
      'Kata laluan baharu mesti sekurang-kurangnya 6 aksara.',
  'New passwords do not match.': 'Kata laluan baharu tidak sepadan.',
  'Current password is incorrect.': 'Kata laluan semasa salah.',
  'Password changed successfully.': 'Kata laluan berjaya ditukar.',
  'Leave dates set. Chats will lock automatically during this period.':
      'Tarikh cuti ditetapkan. Sembang akan dikunci secara automatik dalam tempoh ini.',
  'Leave dates cleared.': 'Tarikh cuti dikosongkan.',
  'My Subjects': 'Subjek Saya',
  'Delete Account': 'Padam Akaun',
  'This permanently deletes your account and profile. This cannot be undone. Enter your password to confirm.':
      'Ini memadam akaun dan profil anda secara kekal. Tindakan ini tidak boleh dibatalkan. Masukkan kata laluan anda untuk mengesahkan.',
  'Password is incorrect.': 'Kata laluan salah.',
  'Appearance': 'Paparan',
  'System': 'Sistem',
  'Light': 'Cerah',
  'Dark': 'Gelap',
  'Language': 'Bahasa',
  'Leave / Holiday': 'Cuti',
  'On leave: {from} - {to}': 'Bercuti: {from} - {to}',
  'No leave dates set': 'Tiada tarikh cuti ditetapkan',
  'Chats lock automatically for this date range, same as manual Off-Duty.':
      'Sembang dikunci secara automatik dalam julat tarikh ini, sama seperti Luar Tugas manual.',
  'Clear leave dates': 'Kosongkan tarikh cuti',
  'No subjects selected yet': 'Belum ada subjek dipilih',
  'Subjects you teach - controls which chats/classes you can manage attendance, performance, and quizzes for.':
      'Subjek yang anda ajar - menentukan kelas yang boleh anda urus kehadiran, prestasi dan kuiznya.',
  'Announcements': 'Pengumuman',
  'My Announcements': 'Pengumuman Saya',
  'Send a notice to every student in one of your subjects':
      'Hantar notis kepada semua pelajar dalam salah satu subjek anda',
  'Notices from your teachers': 'Notis daripada guru anda',
  'Notifications': 'Pemberitahuan',
  'Push Notifications': 'Pemberitahuan Tolak',
  'New messages and warning letters': 'Mesej baharu dan surat amaran',
  'Notification Sound': 'Bunyi Pemberitahuan',
  'Pop': 'Pop',
  'Marimba': 'Marimba',
  'Double Tap': 'Ketuk Dua Kali',
  'Preview': 'Dengar',
  'Account': 'Akaun',
  'Log Out': 'Log Keluar',
  'Delete account': 'Padam akaun',
  'Permanently delete your account and profile':
      'Padam akaun dan profil anda secara kekal',

  // ----- user_profile / user_search / group_info -----
  'Edit Subjects': 'Edit Subjek',
  'Profile': 'Profil',
  'User not found.': 'Pengguna tidak dijumpai.',
  'Search teacher name...': 'Cari nama guru...',
  'Search student name...': 'Cari nama pelajar...',
  'No teachers found.': 'Tiada guru dijumpai.',
  'No students found.': 'Tiada pelajar dijumpai.',
  'Remove Member': 'Buang Ahli',
  'Remove "{name}" from this group?': 'Buang "{name}" daripada kumpulan ini?',
  'Leave Group': 'Keluar Kumpulan',
  'You will no longer receive messages from this group.':
      'Anda tidak akan menerima mesej daripada kumpulan ini lagi.',
  'Leave': 'Keluar',
  'Group Info': 'Info Kumpulan',
  '{n} member(s)': '{n} ahli',
  'Group Admin': 'Admin Kumpulan',
  'Remove member': 'Buang ahli',

  // ----- Announcements -----
  'No subjects yet': 'Belum ada subjek',
  "Announcements from your teachers will show up here once you're enrolled in a subject.":
      'Pengumuman daripada guru anda akan dipaparkan di sini sebaik sahaja anda didaftarkan dalam subjek.',
  'No announcements yet': 'Belum ada pengumuman',
  'Delete Announcement': 'Padam Pengumuman',
  'Students will no longer see this announcement. This cannot be undone.':
      'Pelajar tidak akan dapat melihat pengumuman ini lagi. Tindakan ini tidak boleh dibatalkan.',
  'Tap "New" to send one to a whole class.':
      'Ketik "Baharu" untuk menghantar kepada seluruh kelas.',
  'Seen by {n}': 'Dilihat oleh {n}',
  'Please choose a subject.': 'Sila pilih subjek.',
  'Please fill in both the title and the message.': 'Sila isi tajuk dan mesej.',
  'Announcement sent to {subject} students.':
      'Pengumuman dihantar kepada pelajar {subject}.',
  'Failed to send announcement: {e}': 'Gagal menghantar pengumuman: {e}',
  'New Announcement': 'Pengumuman Baharu',
  'Pick your subjects in Settings first, then you can send announcements to those classes.':
      'Pilih subjek anda dalam Tetapan dahulu, kemudian anda boleh menghantar pengumuman kepada kelas tersebut.',
  'Send to': 'Hantar kepada',
  'Announcement': 'Pengumuman',
  'e.g. Extra class this Saturday': 'cth. Kelas tambahan Sabtu ini',
  'Send Announcement': 'Hantar Pengumuman',

  // ----- Attendance / child overview / warning letters -----
  'No attendance records yet.': 'Belum ada rekod kehadiran.',
  'All Subjects': 'Semua Subjek',
  'No data': 'Tiada data',
  'Attendance Rate': 'Kadar Kehadiran',
  '{a} / {t} classes attended': '{a} / {t} kelas dihadiri',
  'Low attendance warning (below {n}%)': 'Amaran kehadiran rendah (bawah {n}%)',
  'Present': 'Hadir',
  'Absent': 'Tidak Hadir',
  'Safe': 'Selamat',
  'At-Risk': 'Berisiko',
  'Barred': 'Dihalang',
  'Critical': 'Kritikal',
  'Dropping': 'Menurun',
  'Steady': 'Stabil',
  "Your account isn't linked to a student yet. Please contact an Admin to link your child.":
      'Akaun anda belum dipautkan kepada pelajar. Sila hubungi Admin untuk memautkan anak anda.',
  'No subjects enrolled yet.': 'Belum didaftarkan dalam mana-mana subjek.',
  'Not graded yet': 'Belum dinilai',
  'No warning letters.': 'Tiada surat amaran.',
  'Mark Read': 'Tanda Dibaca',
};
