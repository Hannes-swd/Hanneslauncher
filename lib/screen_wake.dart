import 'package:flutter/services.dart';

/// Keeps the screen from turning itself off. Used by the offline mode: a
/// clock nobody can see because the display went dark two minutes ago is no
/// clock at all.
///
/// Backed by a window flag on the Android side rather than a wakelock, so it
/// belongs to this app's window and disappears with it - it cannot be left
/// on by accident and drain the battery in the background.
class ScreenWake {
  static const _channel = MethodChannel('hanneslauncher/offline_mode');

  static Future<void> setKeepOn(bool on) async {
    try {
      await _channel.invokeMethod('keepScreenOn', {'on': on});
    } catch (_) {
      // Best-effort: without it the screen just times out as usual.
    }
  }
}
