/// Where the moon is in its cycle right now, computed from a known new
/// moon and the length of a synodic month - no location, no network.
const double _synodicMonthDays = 29.53058867;
final DateTime _knownNewMoon = DateTime.utc(2000, 1, 6, 18, 14);

/// 0 = new moon, 0.25 = first quarter, 0.5 = full moon, 0.75 = last quarter,
/// wrapping back to 1 (= 0) at the next new moon.
double moonPhaseFraction(DateTime date) {
  final days = date.toUtc().difference(_knownNewMoon).inMinutes / (60 * 24);
  final phase = (days % _synodicMonthDays) / _synodicMonthDays;
  return phase < 0 ? phase + 1 : phase;
}

/// The single emoji matching [moonPhaseFraction] - meant to be dropped
/// straight into a text element, no icon-rule setup needed.
String moonPhaseEmoji(DateTime date) {
  final phase = moonPhaseFraction(date);
  const symbols = [
    '🌑', // new moon
    '🌒', // waxing crescent
    '🌓', // first quarter
    '🌔', // waxing gibbous
    '🌕', // full moon
    '🌖', // waning gibbous
    '🌗', // last quarter
    '🌘', // waning crescent
  ];
  final index = (phase * symbols.length).floor() % symbols.length;
  return symbols[index];
}
