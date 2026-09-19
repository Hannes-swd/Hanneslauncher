import 'package:flutter_test/flutter_test.dart';
import 'package:hanneslauncher/calendar_controller.dart';

/// What the calendar block is allowed to still be showing.
///
/// The query behind it has to start at midnight, not at *now*: Android
/// hands back the event instances overlapping the window it is given, and
/// an event that began yesterday evening and runs into this afternoon is
/// still happening. The same window also hands back everything earlier
/// today that is long finished, which is what these pin down - the block
/// used to lead with the morning's meeting until midnight.
void main() {
  final now = DateTime(2026, 9, 19, 14, 30);

  CalendarEvent timed(DateTime start, DateTime? end) => CalendarEvent(
    title: 'Termin',
    start: start,
    end: end,
    allDay: false,
    calendarColor: null,
    eventId: null,
    calendarId: '1',
  );

  /// An all-day event as Android stores one: UTC midnight, and an end that
  /// is midnight of the day *after* the last one it covers.
  CalendarEvent allDay(DateTime firstDay, {int days = 1}) => CalendarEvent(
    title: 'Ganztägig',
    start: DateTime.utc(firstDay.year, firstDay.month, firstDay.day),
    end: DateTime.utc(
      firstDay.year,
      firstDay.month,
      firstDay.day,
    ).add(Duration(days: days)),
    allDay: true,
    calendarColor: null,
    eventId: null,
    calendarId: '1',
  );

  group('a timed event', () {
    test('that finished earlier today is gone', () {
      expect(
        CalendarController.isStillToCome(
          timed(DateTime(2026, 9, 19, 8), DateTime(2026, 9, 19, 9)),
          now,
        ),
        isFalse,
      );
    });

    test('that is running right now stays', () {
      expect(
        CalendarController.isStillToCome(
          timed(DateTime(2026, 9, 19, 14), DateTime(2026, 9, 19, 15)),
          now,
        ),
        isTrue,
      );
    });

    test('that began yesterday and runs into today stays', () {
      // The reason the window cannot simply start at now.
      expect(
        CalendarController.isStillToCome(
          timed(DateTime(2026, 9, 18, 20), DateTime(2026, 9, 19, 18)),
          now,
        ),
        isTrue,
      );
    });

    test('still to come stays', () {
      expect(
        CalendarController.isStillToCome(
          timed(DateTime(2026, 9, 19, 18), DateTime(2026, 9, 19, 19)),
          now,
        ),
        isTrue,
      );
    });

    test('without an end is a moment, and passes with it', () {
      expect(
        CalendarController.isStillToCome(timed(DateTime(2026, 9, 19, 9), null), now),
        isFalse,
      );
      expect(
        CalendarController.isStillToCome(timed(DateTime(2026, 9, 19, 20), null), now),
        isTrue,
      );
    });
  });

  group('an all-day event', () {
    test("today's stays all day, however late it is", () {
      // It carries UTC midnight, so its end timestamp is already in the
      // past for anyone east of Greenwich - the comparison has to be
      // between dates, not moments.
      expect(
        CalendarController.isStillToCome(allDay(DateTime(2026, 9, 19)), now),
        isTrue,
      );
      expect(
        CalendarController.isStillToCome(
          allDay(DateTime(2026, 9, 19)),
          DateTime(2026, 9, 19, 23, 59),
        ),
        isTrue,
      );
    });

    test("yesterday's is gone", () {
      expect(
        CalendarController.isStillToCome(allDay(DateTime(2026, 9, 18)), now),
        isFalse,
      );
    });

    test('a multi-day one stays until its last day is over', () {
      final holiday = allDay(DateTime(2026, 9, 17), days: 4); // 17th-20th
      expect(CalendarController.isStillToCome(holiday, now), isTrue);
      expect(
        CalendarController.isStillToCome(holiday, DateTime(2026, 9, 20, 22)),
        isTrue,
      );
      expect(
        CalendarController.isStillToCome(holiday, DateTime(2026, 9, 21, 1)),
        isFalse,
      );
    });

    test("tomorrow's stays", () {
      expect(
        CalendarController.isStillToCome(allDay(DateTime(2026, 9, 20)), now),
        isTrue,
      );
    });
  });
}
