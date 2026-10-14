import 'package:flutter/services.dart';

import 'secret_apps_controller.dart';

/// One widget an installed app offers, as the picker lists it.
class AppWidgetProvider {
  const AppWidgetProvider({
    required this.provider,
    required this.packageName,
    required this.label,
    required this.appLabel,
    required this.height,
  });

  /// Android's flattened component name - what [AppWidgets.create] takes
  /// and what a block keeps to set the same widget up again.
  final String provider;
  final String packageName;
  final String label;
  final String appLabel;

  /// How tall a new card for it starts out, in logical pixels.
  final double height;
}

/// Real Android app widgets, hosted by the launcher. The Android half is
/// `AppWidgets.kt`; every call here answers something harmless rather than
/// throwing where that half is missing (tests, desktop).
class AppWidgets {
  AppWidgets._();

  static const _channel = MethodChannel('hanneslauncher/app_widgets');

  /// The platform view type the panel card draws through.
  static const viewType = 'hanneslauncher/app_widget';

  /// Every widget on offer, minus those of the apps in the secret folder:
  /// Android lists them all, and a picker naming a hidden app would give it
  /// away as surely as the app list would.
  static Future<List<AppWidgetProvider>> providers() async {
    try {
      final raw =
          await _channel.invokeListMethod<Map<dynamic, dynamic>>('providers') ??
          const [];
      final secret = await SecretAppsController.instance.loadedKeys();
      return [
        for (final entry in raw)
          if (!secret.contains(entry['package']))
            AppWidgetProvider(
              provider: entry['provider'] as String,
              packageName: entry['package'] as String,
              label: entry['label'] as String,
              appLabel: entry['appLabel'] as String,
              height: (entry['height'] as num).toDouble(),
            ),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// The widget's preview picture (or its app icon) as PNG.
  static Future<Uint8List?> preview(String provider) async {
    try {
      return await _channel.invokeMethod<Uint8List>('preview', {
        'provider': provider,
      });
    } catch (_) {
      return null;
    }
  }

  /// Binds [provider] to a new id and runs its setup screen. Android may
  /// ask the user first; null means they said no somewhere along the way.
  static Future<int?> create(String provider) async {
    try {
      return await _channel.invokeMethod<int>('create', {
        'provider': provider,
      });
    } catch (_) {
      return null;
    }
  }

  static Future<void> delete(int id) async {
    if (id < 0) return;
    try {
      await _channel.invokeMethod<void>('delete', {'id': id});
    } catch (_) {
      // Nothing registered to hand back.
    }
  }

  /// Which provider [id] is bound to now, or null when it is bound to
  /// nothing.
  static Future<String?> providerOf(int id) async {
    if (id < 0) return null;
    try {
      return await _channel.invokeMethod<String>('providerOf', {'id': id});
    } catch (_) {
      return null;
    }
  }
}
