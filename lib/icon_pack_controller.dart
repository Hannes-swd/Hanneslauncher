import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'icon_theme_controller.dart';
import 'launcher_entries_controller.dart';

/// One icon pack installed on the phone.
class IconPack {
  const IconPack({required this.package, required this.label});

  final String package;
  final String label;
}

/// The icons the chosen pack has for the installed apps, as files on disk.
///
/// The platform side does the work (see `IconPacks.kt`): it finds the packs,
/// reads their `appfilter.xml` and renders each drawing into this app's cache
/// directory. All that arrives here is a package name to file path map, which
/// is why an icon can be drawn straight with `Image.file` and costs nothing to
/// keep around.
///
/// Rebuilds itself whenever the chosen style or pack changes and whenever the
/// installed apps change, so a newly installed app is themed as soon as it
/// shows up in the list. Apps in the secret folder are not part of that: they
/// are not in [LauncherEntriesController.entries], so nothing here ever names
/// one - not in a channel call and not as a file in the cache.
class IconPacksController extends ChangeNotifier {
  IconPacksController._();

  static final IconPacksController instance = IconPacksController._();

  static const _channel = MethodChannel('hanneslauncher/icon_packs');

  Map<String, String> _icons = const {};

  /// What [_icons] was built from, so the same request isn't run twice - the
  /// app list rebuilds on every rename, and re-resolving a few hundred icons
  /// each time would be felt.
  String? _resolvedPack;
  Set<String> _resolvedPackages = const {};

  bool _running = false;

  /// Set while a run is in flight and something changed under it; the run
  /// starts over rather than leaving the newer choice unanswered.
  bool _again = false;

  bool _listening = false;

  /// True while the icons are being rendered. The settings screen says so,
  /// because a first run over a few hundred apps takes a moment.
  bool get isWorking => _running;

  /// How many apps the chosen pack actually answered for. Shown in the
  /// settings, since a pack covering 40 of 200 apps is worth knowing about
  /// before wondering why most icons look unchanged.
  int get coveredCount => _icons.length;

  /// Starts following the style and the app list. Called once at startup;
  /// calling it again does nothing.
  void start() {
    if (_listening) return;
    _listening = true;
    IconThemeController.instance.addListener(_sync);
    LauncherEntriesController.instance.addListener(_sync);
    _sync();
  }

  /// The pack's icon for an app, or null when the pack has nothing for it -
  /// in which case the app keeps its own icon.
  ///
  /// Whether the file is still there is not checked here: this is asked once
  /// per icon per frame while the app list scrolls, and a hit on the disk
  /// each time would be paid on every frame to catch something that happens
  /// almost never. [AppIcon] falls back to the app's own icon when the file
  /// turns out to be gone.
  File? iconFor(String packageName) {
    final path = _icons[packageName];
    return path == null ? null : File(path);
  }

  /// Every pack installed on the phone, newest answer each time - a pack can
  /// be installed while the settings screen is open.
  static Future<List<IconPack>> installed() async {
    try {
      final raw = await _channel.invokeListMethod<Map<Object?, Object?>>('list');
      return [
        for (final entry in raw ?? const <Map<Object?, Object?>>[])
          if (entry['package'] case final String package)
            IconPack(
              package: package,
              label: entry['label'] as String? ?? package,
            ),
      ];
    } catch (_) {
      // Not Android, or the channel isn't there (tests): no packs.
      return const [];
    }
  }

  /// The declarations a pack is recognised by, straight from the platform
  /// side that looks for them. Listed in the settings screen so a pack that
  /// isn't picked up can be checked against the list rather than guessed at.
  static Future<List<String>> supportedFormats() async {
    try {
      return await _channel.invokeListMethod<String>('formats') ?? const [];
    } catch (_) {
      return const [];
    }
  }

  /// Renders the chosen pack again from scratch, even if nothing changed.
  /// The way out when a pack was updated while it was already selected.
  Future<void> refresh() async {
    _resolvedPack = null;
    _resolvedPackages = const {};
    await _sync();
  }

  Future<void> _sync() async {
    final settings = IconThemeController.instance.value;
    final pack = settings.style == IconStyle.pack ? settings.packPackage : null;

    if (pack == null) {
      _resolvedPack = null;
      _resolvedPackages = const {};
      if (_icons.isNotEmpty) {
        _icons = const {};
        notifyListeners();
      }
      return;
    }

    final packages = <String>{
      for (final entry in LauncherEntriesController.instance.entries)
        if (entry.app != null) entry.app!.packageName,
    };
    if (packages.isEmpty) return;
    if (pack == _resolvedPack && setEquals(packages, _resolvedPackages)) return;

    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    notifyListeners();

    Map<String, String>? icons;
    try {
      icons = await _channel.invokeMapMethod<String, String>('resolve', {
        'pack': pack,
        'packages': packages.toList(),
      });
    } catch (_) {
      icons = null;
    }

    _running = false;
    // A failed run must not be remembered as done, or the pack would stay
    // unrendered until something else changed.
    if (icons == null) {
      _resolvedPack = null;
      _resolvedPackages = const {};
    } else {
      _resolvedPack = pack;
      _resolvedPackages = packages;
      _icons = icons;
    }
    notifyListeners();

    if (_again) {
      _again = false;
      await _sync();
    }
  }

  /// Stands in for the platform side in tests, which have no channel to
  /// answer with - the same idea as
  /// [LauncherEntriesController.debugSetInstalledApps].
  @visibleForTesting
  void debugSetIcons(Map<String, String> icons) {
    _icons = Map.of(icons);
    notifyListeners();
  }
}
