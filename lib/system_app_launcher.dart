import 'package:flutter/services.dart';

/// Opens the device's own clock or calendar app - whatever is installed as
/// the default for it, resolved natively (see `MainActivity.kt`) rather than
/// guessing a package name that differs by OEM.
class SystemAppLauncher {
  SystemAppLauncher._();

  static const _channel = MethodChannel('hanneslouncher/system_apps');

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
}
