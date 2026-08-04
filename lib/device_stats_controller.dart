import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  int? batteryPercent;
  bool batteryCharging = false;
  double? storageFreeGb;
  double? storageTotalGb;

  /// 'wifi', 'mobile', 'ethernet', 'other' or 'none'.
  String connectionType = 'none';

  int? stepsToday;
  String? mostUsedApp;

  bool stepsPermissionGranted = false;
  bool usageAccessGranted = false;

  static const _stepsBaselineKey = 'steps_baseline_count';
  static const _stepsBaselineDateKey = 'steps_baseline_date';

  Future<void> ensureFresh({
    bool wantsSteps = false,
    bool wantsMostUsedApp = false,
  }) async {
    final now = DateTime.now();
    if (_lastRefresh != null && now.difference(_lastRefresh!) < _minInterval) {
      return;
    }
    await refresh(wantsSteps: wantsSteps, wantsMostUsedApp: wantsMostUsedApp);
  }

  Future<void> refresh({
    bool wantsSteps = false,
    bool wantsMostUsedApp = false,
  }) async {
    _lastRefresh = DateTime.now();
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

  /// The sensor only ever reports a cumulative count since the device last
  /// booted, so "steps today" is that count minus whatever it read at the
  /// first check today - reset automatically once the date moves on.
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
    final storedDate = prefs.getString(_stepsBaselineDateKey);
    if (storedDate != todayKey) {
      await prefs.setString(_stepsBaselineDateKey, todayKey);
      await prefs.setInt(_stepsBaselineKey, raw);
      stepsToday = 0;
      return;
    }
    final baseline = prefs.getInt(_stepsBaselineKey) ?? raw;
    // A reboot resets the sensor's own counter below the stored baseline -
    // treated as a fresh start for today rather than a negative count.
    stepsToday = raw >= baseline ? raw - baseline : 0;
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
    if (!await hasUsageAccess()) {
      mostUsedApp = null;
      return;
    }
    try {
      mostUsedApp = await _channel.invokeMethod<String>('mostUsedApp');
    } catch (_) {
      mostUsedApp = null;
    }
  }
}
