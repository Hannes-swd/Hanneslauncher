import 'package:flutter_test/flutter_test.dart';
import 'package:hanneslauncher/moon_phase.dart';
import 'package:hanneslauncher/sun_times.dart';

void main() {
  group('sunTimesFor', () {
    test('sunrise happens before sunset on an ordinary day', () {
      // Berlin, summer solstice.
      final times = sunTimesFor(DateTime.utc(2026, 6, 21, 12), 52.52, 13.405);
      expect(times.sunrise, isNotNull);
      expect(times.sunset, isNotNull);
      expect(times.sunset!.isAfter(times.sunrise!), isTrue);
    });

    test('neither one happens during a polar night', () {
      // Svalbard, deep in the arctic winter.
      final times = sunTimesFor(DateTime.utc(2026, 12, 21, 12), 78.0, 15.0);
      expect(times.sunrise, isNull);
      expect(times.sunset, isNull);
    });

    test('the sun never sets during a polar day', () {
      // Same place, height of summer.
      final times = sunTimesFor(DateTime.utc(2026, 6, 21, 12), 78.0, 15.0);
      expect(times.sunrise, isNull);
      expect(times.sunset, isNull);
    });
  });

  group('moonPhaseFraction', () {
    test('the reference new moon sits at phase ~0', () {
      final phase = moonPhaseFraction(DateTime.utc(2000, 1, 6, 18, 14));
      expect(phase, closeTo(0, 0.01));
    });

    test('half a synodic month later is a full moon', () {
      final fullMoon = DateTime.utc(
        2000,
        1,
        6,
        18,
        14,
      ).add(const Duration(days: 14, hours: 18));
      expect(moonPhaseFraction(fullMoon), closeTo(0.5, 0.02));
    });

    test('wraps back around after a full cycle', () {
      final nextNewMoon = DateTime.utc(
        2000,
        1,
        6,
        18,
        14,
      ).add(const Duration(days: 30));
      final phase = moonPhaseFraction(nextNewMoon);
      expect(phase < 0.05 || phase > 0.95, isTrue);
    });

    test('each symbol is centred on its own moment, not started by it', () {
      // The reference new moon, and the three quarter points after it.
      final newMoon = DateTime.utc(2000, 1, 6, 18, 14);
      const synodic = 29.53058867;
      DateTime at(double phase) => newMoon.add(
        Duration(milliseconds: (phase * synodic * 24 * 60 * 60 * 1000).round()),
      );

      // The moment itself.
      expect(moonPhaseEmoji(at(0.0)), '🌑');
      expect(moonPhaseEmoji(at(0.25)), '🌓');
      expect(moonPhaseEmoji(at(0.5)), '🌕');
      expect(moonPhaseEmoji(at(0.75)), '🌗');

      // And the nights either side of it: a symbol that started at its
      // moment instead of straddling it showed the one before for the whole
      // run-up, so the full-moon night itself read as waxing gibbous.
      expect(moonPhaseEmoji(at(0.46)), '🌕');
      expect(moonPhaseEmoji(at(0.54)), '🌕');
      // A full eighth past it is the next symbol, not still this one.
      expect(moonPhaseEmoji(at(0.625 + 0.01)), '🌖');
      // Just short of the next new moon wraps back to it rather than
      // running off the end of the list.
      expect(moonPhaseEmoji(at(0.99)), '🌑');
    });

    test('moonPhaseEmoji always returns one of the eight phase symbols', () {
      const symbols = [
        '🌑',
        '🌒',
        '🌓',
        '🌔',
        '🌕',
        '🌖',
        '🌗',
        '🌘',
      ];
      for (var days = 0; days < 30; days++) {
        final date = DateTime.utc(2026, 1, 1).add(Duration(days: days));
        expect(symbols, contains(moonPhaseEmoji(date)));
      }
    });
  });
}
