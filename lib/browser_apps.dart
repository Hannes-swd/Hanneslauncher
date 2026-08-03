import 'package:flutter/services.dart';

/// One browser installed on the device, as offered when picking which one a
/// web app should open in.
class BrowserApp {
  const BrowserApp({required this.package, required this.name});

  final String package;
  final String name;
}

/// The browsers on the device, and opening a link in one of them in
/// particular - see the "hanneslouncher/browsers" channel in `MainActivity.kt`.
///
/// `url_launcher` can only ask Android for "a browser" and gets whatever is
/// set as the default, which is exactly what this exists to override.
class BrowserApps {
  BrowserApps._();

  static const _channel = MethodChannel('hanneslouncher/browsers');

  static Future<List<BrowserApp>> installed() async {
    try {
      final raw = await _channel.invokeListMethod<Map<Object?, Object?>>(
        'list',
      );
      if (raw == null) return const [];
      return [
        for (final entry in raw)
          BrowserApp(
            package: entry['package'] as String,
            name: entry['name'] as String,
          ),
      ];
    } catch (_) {
      // No channel (tests, another platform) - the picker then only offers
      // the system default, which is what happens without a choice anyway.
      return const [];
    }
  }

  /// Opens [url] in [package]. False if that browser is gone or refused the
  /// link, so the caller can fall back to the system default.
  static Future<bool> open(String url, String package) async {
    try {
      final opened = await _channel.invokeMethod<bool>('open', {
        'url': url,
        'package': package,
      });
      return opened ?? false;
    } catch (_) {
      return false;
    }
  }
}
