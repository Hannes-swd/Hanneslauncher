import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'locale_controller.dart';

/// The device's current position, for data sources whose URL follows where
/// the phone is. Only ever coarse accuracy - a weather forecast needs the
/// town, not the street.
///
/// The last position is kept, so a source still works while the phone has no
/// fix yet, or indoors where getting one takes a while.
class LocationController extends ValueNotifier<({double lat, double lon})?> {
  LocationController._() : super(null);

  static final LocationController instance = LocationController._();

  static const _latKey = 'location_lat';
  static const _lonKey = 'location_lon';
  static const _cityKey = 'location_city';
  static const _cityLocaleKey = 'location_city_locale';

  bool _loaded = false;
  DateTime? _updatedAt;

  /// The town the coordinates belong to, for `{{ort}}`. Kept alongside the
  /// position so a card can say which place its numbers are for.
  String? city;

  /// Which language [city] was looked up in. Without it, switching the app's
  /// language would leave the stored name in the old one forever.
  String? _cityLocale;

  /// Place names follow the app's own language rather than the country you
  /// happen to be in - otherwise a trip to Italy renames every town on the
  /// home screen.
  static String get _locale =>
      LocaleController.instance.value == AppLanguage.de ? 'de' : 'en';

  /// Set when the last attempt failed, so the source editor can say why
  /// instead of just showing a broken URL.
  String? error;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_latKey);
    final lon = prefs.getDouble(_lonKey);
    city = prefs.getString(_cityKey);
    _cityLocale = prefs.getString(_cityLocaleKey);
    if (lat != null && lon != null) value = (lat: lat, lon: lon);
  }

  /// Fetches a position if the stored one has aged past [maxAge]. Asks for
  /// the permission the first time; a refusal is remembered by Android, so
  /// this does not nag on every call.
  Future<void> ensureFresh({
    Duration maxAge = const Duration(minutes: 15),
  }) async {
    await load();
    final at = _updatedAt;
    if (at != null && DateTime.now().difference(at) < maxAge) {
      // The position is still good, but its name may have been missing when
      // it was fetched, or be left over from another language.
      final here = value;
      if ((city == null || _cityLocale != _locale) && here != null) {
        await _lookUpCity(
          here.lat,
          here.lon,
          await SharedPreferences.getInstance(),
        );
      }
      return;
    }

    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        error = 'location permission denied';
        debugPrint('hanneslouncher: $error');
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        error = 'location is switched off';
        debugPrint('hanneslouncher: $error');
        return;
      }

      // Indoors a fresh fix can take longer than anyone waits for a launcher
      // to draw, so the position the system already has counts too.
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 15),
          ),
        );
      } catch (e) {
        debugPrint('hanneslouncher: no fresh fix ($e), trying last known');
        position = await Geolocator.getLastKnownPosition();
      }
      if (position == null) {
        error = 'no position available';
        debugPrint('hanneslouncher: $error');
        return;
      }
      _updatedAt = DateTime.now();
      error = null;
      value = (lat: position.latitude, lon: position.longitude);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_latKey, position.latitude);
      await prefs.setDouble(_lonKey, position.longitude);

      await _lookUpCity(position.latitude, position.longitude, prefs);
    } catch (e) {
      // Never throws upwards: a missing position must degrade to "the
      // widget can't show this", not to a crashing launcher.
      error = e.toString();
    }
  }

  /// Asks the platform which place these coordinates are in. Failing here
  /// only costs the name - the coordinates, and with them the forecast,
  /// keep working.
  Future<void> _lookUpCity(
    double lat,
    double lon,
    SharedPreferences prefs,
  ) async {
    try {
      // Without this the platform answers in the language of wherever the
      // phone currently is - an Italian name while travelling in Italy.
      await setLocaleIdentifier(_locale);
      final places = await placemarkFromCoordinates(lat, lon);
      if (places.isEmpty) {
        debugPrint('hanneslouncher: no place for $lat,$lon');
        return;
      }
      final place = places.first;
      // Hamlets often have no locality of their own, so the surrounding
      // area is the next best answer.
      final candidates = <String?>[
        place.locality,
        place.subAdministrativeArea,
        place.administrativeArea,
      ];
      final name = candidates.firstWhere(
        (candidate) => candidate != null && candidate.isNotEmpty,
        orElse: () => null,
      );
      if (name == null) return;
      city = name;
      _cityLocale = _locale;
      await prefs.setString(_cityKey, name);
      await prefs.setString(_cityLocaleKey, _locale);
      // The name arrives after the position, so anything already drawn from
      // it has to be told - otherwise a card keeps showing the dash until it
      // happens to rebuild for some other reason.
      notifyListeners();
    } catch (e) {
      // No geocoder on this device, or it couldn't answer. Logged rather
      // than swallowed: a missing place name is otherwise indistinguishable
      // from one that simply hasn't arrived yet.
      debugPrint('hanneslouncher: city lookup failed: $e');
    }
  }

  /// Rounded to four decimals - about ten metres, which is far more than a
  /// weather forecast resolves, and keeps the URL short.
  String? get latText => value?.lat.toStringAsFixed(4);
  String? get lonText => value?.lon.toStringAsFixed(4);
}
