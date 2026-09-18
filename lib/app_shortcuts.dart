import 'dart:io';

import 'package:flutter/services.dart';

/// One shortcut an app publishes about itself: a chat in a messenger, "new
/// tab" in a browser, a playlist. Read live from Android every time the
/// long-press menu opens - these change while the app runs, and a list kept
/// in here would go stale within the day.
class AppShortcut {
  const AppShortcut({
    required this.package,
    required this.id,
    required this.label,
    this.iconPath,
  });

  /// The app that published it.
  final String package;

  /// The app's own id for it, stable across restarts - which is what makes
  /// saving one to the launcher possible at all.
  final String id;

  final String label;

  /// Android's rendered icon, written out as a PNG. Null when the shortcut
  /// carries none, which is rare but allowed.
  final String? iconPath;

  File? get iconFile {
    final path = iconPath;
    if (path == null) return null;
    final file = File(path);
    return file.existsSync() ? file : null;
  }

  static AppShortcut? fromPlatform(Object? raw) {
    if (raw is! Map) return null;
    final package = raw['package'];
    final id = raw['id'];
    final label = raw['label'];
    if (package is! String || id is! String || label is! String) return null;
    final iconPath = raw['iconPath'];
    return AppShortcut(
      package: package,
      id: id,
      label: label,
      iconPath: iconPath is String && iconPath.isNotEmpty ? iconPath : null,
    );
  }
}

/// Reaches Android's [LauncherApps] through the one channel `AppShortcuts.kt`
/// serves.
///
/// Every method answers "nothing" rather than throwing, because the normal
/// case for all of them is a launcher that isn't the home app yet: Android
/// hands shortcuts out to whichever app the home button opens and to nobody
/// else. [available] is the one place that difference is worth showing, so
/// the menu can say why it is empty instead of just being empty.
class AppShortcuts {
  const AppShortcuts._();

  static const _channel = MethodChannel('hanneslauncher/app_shortcuts');

  /// Whether Android will hand this launcher any shortcuts at all - false on
  /// Android 7.0 and older, and while another app is the home app.
  static Future<bool> available() async {
    try {
      return await _channel.invokeMethod<bool>('available') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// What [package] offers right now, in the order Android ranks it.
  static Future<List<AppShortcut>> list(String package) async {
    try {
      final raw = await _channel.invokeListMethod<Object?>('list', {
        'package': package,
      });
      if (raw == null) return const [];
      return [for (final entry in raw) ?AppShortcut.fromPlatform(entry)];
    } catch (_) {
      return const [];
    }
  }

  /// Starts one. False when it is gone, disabled, or the launcher is no
  /// longer the home app - all three of which a saved shortcut can hit
  /// long after it was saved, so the caller is expected to say so.
  static Future<bool> launch(String package, String id) async {
    try {
      return await _channel.invokeMethod<bool>('launch', {
            'package': package,
            'id': id,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Asks Android to keep exactly [ids] of [package] alive for this
  /// launcher. The list replaces the previous one, so it is always the full
  /// set that should survive - see `AppShortcuts.pin` on the Kotlin side.
  static Future<bool> pin(String package, List<String> ids) async {
    try {
      return await _channel.invokeMethod<bool>('pin', {
            'package': package,
            'ids': ids,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Re-renders a saved shortcut's icon. Null when it no longer exists.
  static Future<String?> icon(String package, String id) async {
    try {
      return await _channel.invokeMethod<String>('icon', {
        'package': package,
        'id': id,
      });
    } catch (_) {
      return null;
    }
  }

  /// The label the shortcut carries now - apps do rename them, a contact
  /// changes their name - or null when it is gone.
  static Future<String?> label(String package, String id) async {
    try {
      return await _channel.invokeMethod<String>('label', {
        'package': package,
        'id': id,
      });
    } catch (_) {
      return null;
    }
  }
}
