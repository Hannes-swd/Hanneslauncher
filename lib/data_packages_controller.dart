import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the device-data placeholders ({{akku}}, {{speicher_frei}},
/// {{verbindung}}, {{sonnenauf}}/{{sonnenunter}}, {{mondphase}},
/// {{schritte}}, {{meistgenutzt}}) are switched on - one flag for all of
/// them, added and removed as a single package exactly like a data source
/// is, rather than a row of individual switches.
class DeviceDataController extends ValueNotifier<bool> {
  DeviceDataController._() : super(false);

  static final DeviceDataController instance = DeviceDataController._();

  static const _key = 'device_data_enabled';

  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    value = prefs.getBool(_key) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    value = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, enabled);
  }
}
