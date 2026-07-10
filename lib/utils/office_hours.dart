// lib/utils/office_hours.dart
//
// Helper untuk check sama ada masa sekarang dalam office hour atau tidak.
// Setting global: Isnin - Jumaat, 9:00 AM - 5:00 PM (boleh ubah kat bawah).

class OfficeHours {
  // ----- SETTING BOLEH UBAH DI SINI -----
  static const int startHour = 9; // 9 AM
  static const int endHour = 17; // 5 PM (24-hour format)
  static const List<int> workingDays = [
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
  ];
  // ----------------------------------------

  /// Return true kalau masa sekarang dalam office hour.
  static bool isOfficeHourNow() {
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
    final now = DateTime.now();
    DateTime checkDay = now;

    // Kalau sekarang dalam working day tapi lepas office hour, check esok
    // Kalau weekend, cari working day seterusnya
    for (int i = 0; i < 8; i++) {
      final candidate = DateTime(checkDay.year, checkDay.month, checkDay.day)
          .add(Duration(days: i));
      if (workingDays.contains(candidate.weekday)) {
        // Kalau candidate hari ni dan office hour belum tamat, return hari ni
        if (i == 0 && now.hour < startHour) {
          return 'Hari ini, ${_formatHour(startHour)}';
        }
        if (i == 0 && now.hour < endHour) {
          // sebenarnya sekarang office hour, tak patut sampai sini
          continue;
        }
        final dayNames = {
          DateTime.monday: 'Isnin',
          DateTime.tuesday: 'Selasa',
          DateTime.wednesday: 'Rabu',
          DateTime.thursday: 'Khamis',
          DateTime.friday: 'Jumaat',
        };
        return '${dayNames[candidate.weekday]}, ${_formatHour(startHour)}';
      }
    }
    return _formatHour(startHour);
  }
}
