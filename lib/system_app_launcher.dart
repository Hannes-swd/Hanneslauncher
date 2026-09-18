import 'package:flutter/services.dart';

/// Opens the device's own clock or calendar app - whatever is installed as
/// the default for it, resolved natively (see `MainActivity.kt`) rather than
/// guessing a package name that differs by OEM.
class SystemAppLauncher {
  SystemAppLauncher._();

  static const _channel = MethodChannel('hanneslauncher/system_apps');

  static Future<void> openClock() async {
    try {
      await _channel.invokeMethod('openClock');
    } catch (_) {
      // No clock app registered to handle it - nothing to open.
    }
  }

  static Future<void> openCalendar() async {
    try {
      await _channel.invokeMethod('openCalendar');
    } catch (_) {
      // No calendar app registered to handle it - nothing to open.
    }
  }

  /// Starts a countdown of [seconds] in the phone's clock app, without
  /// opening it. False when no installed app answers for timers, which is
  /// the one case worth telling the user about - a shortcut that looks like
  /// it fired but never rings is worse than one that says it can't.
  static Future<bool> startTimer(int seconds, {String label = ''}) async {
    try {
      final started = await _channel.invokeMethod<bool>('startTimer', {
        'seconds': seconds,
        'label': label,
      });
      return started ?? false;
    } catch (_) {
      return false;
    }
  }
}
