import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'launcher_entries_controller.dart';
import 'secret_apps_controller.dart';

/// Battery, storage, connection type, steps and today's most-used app -
/// read from Android through `MainActivity.kt`'s "hanneslauncher/device_stats"
/// channel and cached here as plain synchronous fields, the same way
/// [LocationController] caches the last known position. Nothing here pushes
/// updates on its own; [ensureFresh] is called whenever the panel using
/// these values is opened.
class DeviceStatsController extends ChangeNotifier {
  DeviceStatsController._();

  static final DeviceStatsController instance = DeviceStatsController._();

  static const _channel = MethodChannel('hanneslauncher/device_stats');

  // A fresh read every time the panel opens is plenty - nothing here needs
  // to track changes second by second.
  static const _minInterval = Duration(minutes: 2);
  DateTime? _lastRefresh;

  // And what that last read actually fetched. The two extras are optional,
  // so "it was read two minutes ago" is only an answer to a caller asking
  // for no more than the last one did: the device-data screen always wants
  // the steps, and after any panel refresh with the device-data switch off
  // it used to show a dash for two minutes with no way to force the issue.
  bool _lastIncludedSteps = false;
  bool _lastIncludedMostUsedApp = false;

  int? batteryPercent;
  bool batteryCharging = false;
  double? storageFreeGb;
  double? storageTotalGb;

  /// 'wifi', 'mobile', 'ethernet', 'other' or 'none'.
  String connectionType = 'none';

  int? stepsToday;

  // Package and label of today's most-used app, kept raw and private so the
  // only way out is the filtered [mostUsedApp] below.
  String? _mostUsedAppPackage;
  String? _mostUsedAppLabel;

  /// Today's most-used app, or null when there is none, the permission is
  /// missing - or it is in the secret folder.
  ///
  /// Android's usage statistics are a second way to learn an app's name, next
  /// to the app list, so the filter sits here rather than at the `{{...}}`
  /// placeholder that shows this: anything reading it later is covered too.
  /// The launcher's own rename wins over the system label, the same way the
  /// app list shows it.
  String? get mostUsedApp {
    final package = _mostUsedAppPackage;
    if (package == null) return null;
    if (SecretAppsController.instance.contains(package)) return null;
    return LauncherEntriesController.instance.byKey(package)?.name ??
        _mostUsedAppLabel;
  }

  bool stepsPermissionGranted = false;
  bool usageAccessGranted = false;

  static const _stepsBaselineKey = 'steps_baseline_count';
  static const _stepsBaselineDateKey = 'steps_baseline_date';
  static const _stepsLastRawKey = 'steps_last_raw';
  static const _stepsLastRawDateKey = 'steps_last_raw_date';

  Future<void> ensureFresh({
    bool wantsSteps = false,
    bool wantsMostUsedApp = false,
  }) async {
    final now = DateTime.now();
    final alreadyCovered =
        (!wantsSteps || _lastIncludedSteps) &&
        (!wantsMostUsedApp || _lastIncludedMostUsedApp);
    if (alreadyCovered &&
        _lastRefresh != null &&
        now.difference(_lastRefresh!) < _minInterval) {
      return;
    }
    await refresh(wantsSteps: wantsSteps, wantsMostUsedApp: wantsMostUsedApp);
  }

  Future<void> refresh({
    bool wantsSteps = false,
    bool wantsMostUsedApp = false,
  }) async {
    _lastRefresh = DateTime.now();
    _lastIncludedSteps = wantsSteps;
    _lastIncludedMostUsedApp = wantsMostUsedApp;
    await Future.wait([
      _refreshBattery(),
      _refreshStorage(),
      _refreshConnection(),
      if (wantsSteps) _refreshSteps(),
      if (wantsMostUsedApp) _refreshMostUsedApp(),
    ]);
    notifyListeners();
  }

  Future<void> _refreshBattery() async {
    try {
      final raw = await _channel.invokeMapMethod<String, Object?>('battery');
      final percent = raw?['percent'] as int?;
      batteryPercent = (percent == null || percent < 0) ? null : percent;
      batteryCharging = raw?['charging'] as bool? ?? false;
    } catch (_) {
      batteryPercent = null;
    }
  }

  Future<void> _refreshStorage() async {
    try {
      final raw = await _channel.invokeMapMethod<String, Object?>('storage');
      final free = raw?['freeBytes'] as num?;
      final total = raw?['totalBytes'] as num?;
      storageFreeGb = free == null ? null : free / 1e9;
      storageTotalGb = total == null ? null : total / 1e9;
    } catch (_) {
      storageFreeGb = null;
      storageTotalGb = null;
    }
  }

  Future<void> _refreshConnection() async {
    try {
      connectionType =
          await _channel.invokeMethod<String>('connectionType') ?? 'none';
    } catch (_) {
      connectionType = 'none';
    }
  }

  Future<bool> hasStepsPermission() async {
    try {
      stepsPermissionGranted =
          await _channel.invokeMethod<bool>('hasStepsPermission') ?? false;
    } catch (_) {
      stepsPermissionGranted = false;
    }
    return stepsPermissionGranted;
  }

  Future<bool> requestStepsPermission() async {
    try {
      stepsPermissionGranted =
          await _channel.invokeMethod<bool>('requestStepsPermission') ??
          false;
    } catch (_) {
      stepsPermissionGranted = false;
    }
    notifyListeners();
    if (stepsPermissionGranted) await _refreshSteps();
    return stepsPermissionGranted;
  }

  /// Steps since midnight, as closely as the sensor allows.
  ///
  /// Android's step counter only ever reports a running total since the
  /// device last booted, so "today" is that total minus what it stood at
  /// midnight - a number nobody was awake to write down. Which reading
  /// stands in for it is the whole of this method, and it used to be "the
  /// first reading of the day", i.e. whenever the panel happened to be
  /// pulled down: opening it at two in the afternoon answered 0 and threw
  /// the morning away.
  ///
  /// So every reading is now kept, and the one from *before* midnight is
  /// what the new day subtracts. The error left is whatever was walked
  /// between the last time the panel was open and midnight, which is
  /// normally a night's sleep and nothing.
  ///
  /// A reboot is the case that cannot be recovered: the sensor starts again
  /// from zero and no longer knows what it counted before. Counting from
  /// the reboot is then the most that can honestly be claimed, and it is
  /// also the closest - a phone restarted overnight or in the morning has
  /// its own count running from roughly the start of the day anyway.
  Future<void> _refreshSteps() async {
    if (!await hasStepsPermission()) {
      stepsToday = null;
      return;
    }
    int? raw;
    try {
      raw = await _channel.invokeMethod<int>('stepCounterRaw');
    } catch (_) {
      raw = null;
    }
    if (raw == null) {
      stepsToday = null;
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';

    if (prefs.getString(_stepsBaselineDateKey) != todayKey) {
      await prefs.setInt(
        _stepsBaselineKey,
        _baselineForNewDay(prefs, raw, todayKey),
      );
      await prefs.setString(_stepsBaselineDateKey, todayKey);
    }

    var baseline = prefs.getInt(_stepsBaselineKey) ?? raw;
    if (raw < baseline) {
      // The sensor restarted under us - only a reboot does that. Written
      // back rather than just used: without it every later reading today
      // keeps comparing against a number the counter will not reach again,
      // and the count sits at zero for the rest of the day.
      baseline = 0;
      await prefs.setInt(_stepsBaselineKey, 0);
    }
    stepsToday = raw - baseline;

    // Kept for tomorrow's first reading, which is the whole point: it is
    // the last number from before midnight.
    await prefs.setInt(_stepsLastRawKey, raw);
    await prefs.setString(_stepsLastRawDateKey, todayKey);
  }

  /// What the counter is taken to have stood at last midnight.
  ///
  /// The last reading from an earlier day, when there is one the sensor
  /// could still be counting up from. A reading higher than the current one
  /// means the device rebooted in between, and then the counter's own zero
  /// is the only honest floor.
  static int _baselineForNewDay(
    SharedPreferences prefs,
    int raw,
    String todayKey,
  ) {
    final lastRaw = prefs.getInt(_stepsLastRawKey);
    final lastDate = prefs.getString(_stepsLastRawDateKey);
    if (lastRaw == null || lastDate == null || lastDate == todayKey) {
      // Nothing from before today - the first day after an install, or
      // after an update that introduced these. Today starts here.
      return raw;
    }
    return lastRaw <= raw ? lastRaw : 0;
  }

  Future<bool> hasUsageAccess() async {
    try {
      usageAccessGranted =
          await _channel.invokeMethod<bool>('hasUsageAccess') ?? false;
    } catch (_) {
      usageAccessGranted = false;
    }
    return usageAccessGranted;
  }

  /// Opens the system's "Usage access" settings screen - the only way this
  /// permission can be turned on, there's no runtime prompt for it.
  Future<void> requestUsageAccess() async {
    try {
      await _channel.invokeMethod('requestUsageAccess');
    } catch (_) {
      // Nothing to fall back to.
    }
  }

  Future<void> _refreshMostUsedApp() async {
    // Before the value exists at all: pulling the panel down during a cold
    // start would otherwise read a value while the secret list is still being
    // loaded, and [mostUsedApp] would have nothing to filter against.
    await SecretAppsController.instance.loadedKeys();
    if (!await hasUsageAccess()) {
      _mostUsedAppPackage = null;
      _mostUsedAppLabel = null;
      return;
    }
    try {
      // Package and label, not just the label: the package is what the secret
      // folder is keyed by, and the label alone could not be matched against
      // it.
      final raw = await _channel.invokeMapMethod<String, Object?>(
        'mostUsedApp',
      );
      _mostUsedAppPackage = raw?['package'] as String?;
      _mostUsedAppLabel = raw?['name'] as String?;
    } catch (_) {
      _mostUsedAppPackage = null;
      _mostUsedAppLabel = null;
    }
  }
}
