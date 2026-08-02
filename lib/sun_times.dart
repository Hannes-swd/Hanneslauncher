import 'dart:math' as math;

/// Sunrise and sunset for [date] at [latitude]/[longitude], both in local
/// time. Null for either one on days that never see one (polar day/night).
///
/// The public-domain "sunrise equation" (the same one behind the SunCalc.js
/// library) - no location lookup, no network, accurate to within a minute
/// or so, which is all a home screen placeholder needs.
class SunTimes {
  const SunTimes({this.sunrise, this.sunset});

  final DateTime? sunrise;
  final DateTime? sunset;
}

const double _rad = math.pi / 180;
const double _dayMs = 1000 * 60 * 60 * 24;
const double _j1970 = 2440588;
const double _j2000 = 2451545;
const double _obliquity = 23.4397 * _rad;

double _toJulian(DateTime date) =>
    date.toUtc().millisecondsSinceEpoch / _dayMs - 0.5 + _j1970;

DateTime _fromJulian(double j) => DateTime.fromMillisecondsSinceEpoch(
  ((j + 0.5 - _j1970) * _dayMs).round(),
  isUtc: true,
).toLocal();

double _toDays(DateTime date) => _toJulian(date) - _j2000;

double _solarMeanAnomaly(double d) => _rad * (357.5291 + 0.98560028 * d);

double _eclipticLongitude(double m) {
  final c =
      _rad *
      (1.9148 * math.sin(m) + 0.02 * math.sin(2 * m) + 0.0003 * math.sin(3 * m));
  const perihelion = 102.9372 * _rad;
  return m + c + perihelion + math.pi;
}

// The sun's own ecliptic latitude is always ~0, which drops the general
// declination formula down to just this.
double _declination(double l) => math.asin(math.sin(_obliquity) * math.sin(l));

double _julianCycle(double d, double lw) => (d - 0.0009 - lw / (2 * math.pi)).roundToDouble();

double _approxTransit(double ht, double lw, double n) =>
    0.0009 + (ht + lw) / (2 * math.pi) + n;

double _solarTransitJ(double ds, double m, double l) =>
    _j2000 + ds + 0.0053 * math.sin(m) - 0.0069 * math.sin(2 * l);

double _hourAngle(double h, double phi, double d) {
  final cosH =
      (math.sin(h) - math.sin(phi) * math.sin(d)) / (math.cos(phi) * math.cos(d));
  return math.acos(cosH.clamp(-1.0, 1.0));
}

/// Computes today's sunrise/sunset for the given position. Both fields are
/// null if the numbers never resolve (e.g. deep into a polar night, where
/// the sun neither rises nor sets).
SunTimes sunTimesFor(DateTime date, double latitude, double longitude) {
  final lw = _rad * -longitude;
  final phi = _rad * latitude;
  final d = _toDays(date);
  final n = _julianCycle(d, lw);
  final ds = _approxTransit(0, lw, n);
  final m = _solarMeanAnomaly(ds);
  final l = _eclipticLongitude(m);
  final dec = _declination(l);
  final jNoon = _solarTransitJ(ds, m, l);

  const h0 = -0.833 * _rad;
  final cosH =
      (math.sin(h0) - math.sin(phi) * math.sin(dec)) /
      (math.cos(phi) * math.cos(dec));
  if (cosH < -1 || cosH > 1) {
    // The sun stays above (cosH < -1) or below (cosH > 1) the horizon all
    // day at this latitude/date.
    return const SunTimes();
  }

  final w = _hourAngle(h0, phi, dec);
  final a = _approxTransit(w, lw, n);
  final jSet = _solarTransitJ(a, m, l);
  final jRise = jNoon - (jSet - jNoon);

  return SunTimes(sunrise: _fromJulian(jRise), sunset: _fromJulian(jSet));
}
