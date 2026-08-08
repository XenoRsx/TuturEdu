// lib/utils/office_hours.dart
//
// Helper to check whether the current time falls within office hours.
// Global setting: Monday - Friday, 8:00 - 18:00 (adjustable below).

import 'package:flutter/foundation.dart' show kDebugMode;

class OfficeHours {
  // ----- ADJUSTABLE SETTINGS -----
  static const int startHour = 8;
  static const int endHour = 18; // (24-hour format)
  static const List<int> workingDays = [
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
  ];
  // ----------------------------------------

  // ----- DEBUG BYPASS (testing only) -----
  // Set to true to force chat to ALWAYS be open during testing.
  // SAFE: since it's wrapped in kDebugMode, this flag automatically becomes
  // `false` in a production build (flutter build web / apk --release), even
  // if you forget to flip it back before deploying.
  static bool debugForceOpen = false;
  // -------------------------------------------------

  /// Returns true if the current time is within office hours.
  static bool isOfficeHourNow() {
    if (kDebugMode && debugForceOpen) return true;
    final now = DateTime.now();
    return isWithinOfficeHour(now);
  }

  /// Test against a specific DateTime (handy for testing/debug).
  static bool isWithinOfficeHour(DateTime dateTime) {
    final isWorkingDay = workingDays.contains(dateTime.weekday);
    final isWithinHour = dateTime.hour >= startHour && dateTime.hour < endHour;
    return isWorkingDay && isWithinHour;
  }

  /// Text to display in the UI (e.g. in the "Chat locked" banner).
  static String officeHourText() {
    return 'Monday - Friday, ${_formatHour(startHour)} - ${_formatHour(endHour)}';
  }

  static String _formatHour(int hour) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : hour;
    return '$displayHour:00 $period';
  }

  /// When office hours will next open (for UI text, e.g. "Reopens on...").
  static String nextOpenText() {
    final target = nextOpenDateTime();
    final now = DateTime.now();
    final isToday =
        target.year == now.year &&
        target.month == now.month &&
        target.day == now.day;
    if (isToday) {
      return 'Today, ${_formatHour(startHour)}';
    }

    final dayNames = {
      DateTime.monday: 'Monday',
      DateTime.tuesday: 'Tuesday',
      DateTime.wednesday: 'Wednesday',
      DateTime.thursday: 'Thursday',
      DateTime.friday: 'Friday',
    };
    return '${dayNames[target.weekday]}, ${_formatHour(startHour)}';
  }

  /// Calculates the actual DateTime when office hours will next open.
  /// Used for Overtime Mode - "Schedule Reply for 8:00 AM" (or whatever the
  /// current office-hour start time is), so the reply auto-sends once the
  /// time arrives.
  static DateTime nextOpenDateTime() {
    final now = DateTime.now();

    // If today is still a working day and start hour hasn't passed yet,
    // office hours will open again today.
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

      // Today, and office hours haven't started yet -> this is the next open time.
      if (i == 0 && now.hour < startHour) return openTime;

      // Today, and we're actually still within office hours -> shouldn't
      // reach here (this function is for the locked state), but skip ahead
      // to tomorrow just in case.
      if (i == 0 && now.hour < endHour) continue;

      // Any day after today (i >= 1) is necessarily a candidate for next open.
      if (i >= 1) return openTime;
    }

    // Fallback (should never be reached)
    return DateTime(now.year, now.month, now.day + 1, startHour);
  }
}
