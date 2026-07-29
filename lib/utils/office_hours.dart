// lib/utils/office_hours.dart
//
// Helper untuk check sama ada masa sekarang dalam office hour atau tidak.
// Setting global: Isnin - Jumaat, 9:00 - 17:00 (boleh ubah kat bawah).

import 'package:flutter/foundation.dart' show kDebugMode;

class OfficeHours {
  // ----- SETTING BOLEH UBAH DI SINI -----
  static const int startHour = 11;
  static const int endHour = 17; // (24-hour format)
  static const List<int> workingDays = [
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
  ];
  // ----------------------------------------

  // ----- DEBUG BYPASS (untuk testing sahaja) -----
  // Set true untuk force chat SENTIASA terbuka semasa testing.
  // SELAMAT: sebab dibalut dengan kDebugMode, flag ni automatik jadi `false`
  // dalam production build (flutter build web / apk --release), walaupun
  // kau lupa tukar balik ke `false` sebelum deploy.
  static bool debugForceOpen = false;
  // -------------------------------------------------

  /// Return true kalau masa sekarang dalam office hour.
  static bool isOfficeHourNow() {
    if (kDebugMode && debugForceOpen) return true;
    final now = DateTime.now();
    return isWithinOfficeHour(now);
  }

  /// Boleh test dengan DateTime tertentu (senang untuk testing/debug).
  static bool isWithinOfficeHour(DateTime dateTime) {
    final isWorkingDay = workingDays.contains(dateTime.weekday);
    final isWithinHour = dateTime.hour >= startHour && dateTime.hour < endHour;
    return isWorkingDay && isWithinHour;
  }

  /// Text untuk tunjuk kat UI (contoh dalam banner "Chat locked")
  static String officeHourText() {
    return 'Isnin - Jumaat, ${_formatHour(startHour)} - ${_formatHour(endHour)}';
  }

  static String _formatHour(int hour) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : hour;
    return '$displayHour:00 $period';
  }

  /// Bila office hour seterusnya akan buka (untuk UI, contoh "Buka semula pada...")
  static String nextOpenText() {
    final target = nextOpenDateTime();
    final now = DateTime.now();
    final isToday =
        target.year == now.year &&
        target.month == now.month &&
        target.day == now.day;
    if (isToday) {
      return 'Hari ini, ${_formatHour(startHour)}';
    }

    final dayNames = {
      DateTime.monday: 'Isnin',
      DateTime.tuesday: 'Selasa',
      DateTime.wednesday: 'Rabu',
      DateTime.thursday: 'Khamis',
      DateTime.friday: 'Jumaat',
    };
    return '${dayNames[target.weekday]}, ${_formatHour(startHour)}';
  }

  /// Kira DateTime sebenar bila office hour seterusnya akan buka.
  /// Digunakan untuk Overtime Mode - "Schedule Reply for 8:00 AM" (atau
  /// jam mula office hour semasa) supaya reply auto-hantar bila masa tiba.
  static DateTime nextOpenDateTime() {
    final now = DateTime.now();

    // Kalau sekarang masih dalam working day & belum lepas start hour,
    // office hour akan buka hari ini juga.
    for (int i = 0; i < 8; i++) {
      final candidate = DateTime(
        now.year,
        now.month,
        now.day,
      ).add(Duration(days: i));
      if (!workingDays.contains(candidate.weekday)) continue;

      final openTime = DateTime(
        candidate.year,
        candidate.month,
        candidate.day,
        startHour,
      );

      // Hari ni & office hour belum start -> ni lah next open time.
      if (i == 0 && now.hour < startHour) return openTime;

      // Hari ni & sekarang sebenarnya dalam office hour -> tak patut sampai
      // sini (fungsi ni untuk locked state), tapi jaga-jaga skip ke esok.
      if (i == 0 && now.hour < endHour) continue;

      // Hari-hari selepas ni (i >= 1) semestinya candidate untuk next open.
      if (i >= 1) return openTime;
    }

    // Fallback (tak sepatutnya sampai sini)
    return DateTime(now.year, now.month, now.day + 1, startHour);
  }
}
