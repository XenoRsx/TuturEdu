import 'package:flutter_test/flutter_test.dart';
import 'package:tuturedu/utils/office_hours.dart';

void main() {
  // 2024-01-01 is a Monday - every date below is relative to that week.
  DateTime at(int day, int hour, [int minute = 0]) =>
      DateTime(2024, 1, day, hour, minute);

  group('OfficeHours.isWithinOfficeHour', () {
    test('test dates fall on the weekdays they claim to', () {
      expect(at(1, 12).weekday, DateTime.monday);
      expect(at(5, 12).weekday, DateTime.friday);
      expect(at(6, 12).weekday, DateTime.saturday);
      expect(at(7, 12).weekday, DateTime.sunday);
    });

    test('open on a weekday right at the start hour', () {
      expect(
        OfficeHours.isWithinOfficeHour(at(1, OfficeHours.startHour)),
        isTrue,
      );
    });

    test('open on a weekday in the last minute before closing', () {
      expect(
        OfficeHours.isWithinOfficeHour(at(5, OfficeHours.endHour - 1, 59)),
        isTrue,
      );
    });

    test('closed before the start hour', () {
      expect(
        OfficeHours.isWithinOfficeHour(at(1, OfficeHours.startHour - 1, 59)),
        isFalse,
      );
    });

    test('closed exactly at the end hour (end is exclusive)', () {
      expect(
        OfficeHours.isWithinOfficeHour(at(1, OfficeHours.endHour)),
        isFalse,
      );
    });

    test('closed all day on weekends', () {
      expect(OfficeHours.isWithinOfficeHour(at(6, 12)), isFalse);
      expect(OfficeHours.isWithinOfficeHour(at(7, 12)), isFalse);
    });
  });

  test('officeHourText describes the working days', () {
    expect(OfficeHours.officeHourText(), startsWith('Monday - Friday'));
  });
}
