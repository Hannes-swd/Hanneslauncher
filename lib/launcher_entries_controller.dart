import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';

import 'app_overrides_controller.dart';
import 'app_pairs_controller.dart';
import 'builtin_entries.dart';
import 'folders_controller.dart';
import 'launcher_entry.dart';
import 'locale_controller.dart';
import 'saved_shortcuts_controller.dart';
import 'secret_apps_controller.dart';
import 'web_apps_controller.dart';

/// The single list of everything the launcher can show: installed apps,
/// saved web apps, saved app shortcuts, folders and the launcher's own
/// built-in screens, sorted by displayed name.
///
/// Kept in one place because folders reference their contents by key, so
/// resolving a folder needs the same lookup the app list and the pinned apps
/// use. Notifies whenever apps are (re)loaded or a rename, web app or folder
/// changes what should be on screen.
///
/// Apps in the secret folder are not in [entries] and not in [byKey] - they
/// are left out here rather than filtered where they would be drawn, so
/// anything reading this list is covered without knowing the secret folder
/// exists. The one way to see them is [secretEntries], which needs the token
/// only a correct password produces.
class LauncherEntriesController extends ChangeNotifier {
  LauncherEntriesController._() {
    AppOverridesController.instance.addListener(_rebuild);
    WebAppsController.instance.addListener(_rebuild);
    AppPairsController.instance.addListener(_rebuild);
    SavedShortcutsController.instance.addListener(_rebuild);
    FoldersController.instance.addListener(_rebuild);
    // Hiding an app has to take effect everywhere at once, the same way a
    // rename does.
    SecretAppsController.instance.addListener(_rebuild);
    // The built-in entries are named in the app's own language, so a
    // language change moves them to a different spot in the sorted list.
    LocaleController.instance.addListener(_rebuild);
  }

  static final LauncherEntriesController instance =
      LauncherEntriesController._();

  List<AppInfo> _apps = [];

  /// Everything, secret entries included - private, and the only list built
  /// from the raw apps. [_entries] and [_byKey] are derived from it.
  List<LauncherEntry> _all = [];
  List<LauncherEntry> _entries = [];
  Map<String, LauncherEntry> _byKey = {};
  bool _loaded = false;

  /// False until the installed apps have been read for the first time.
  bool get isLoaded => _loaded;

  List<LauncherEntry> get entries => _entries;

  LauncherEntry? byKey(String key) => _byKey[key];

  /// The apps hidden behind the secret folder's password. Empty unless
  /// [token] is the current unlock, so this cannot be used to peek.
  ///
  /// Not quite the complement of [entries]: a shortcut saved out of a hidden
  /// app is left out of both. It was never hidden by name - it goes when its
  /// app goes - so the row here would carry a "remove from secret folder"
  /// button with no key to remove. Un-hiding the app brings it back.
  List<LauncherEntry> secretEntries(SecretUnlock token) {
    if (!SecretAppsController.instance.isUnlockedWith(token)) return const [];
    final secret = SecretAppsController.instance.value;
    return [
      for (final entry in _all)
        if (secret.contains(entry.key)) entry,
    ];
  }

  /// Turns stored keys (folder contents, pinned entries) into entries,
  /// skipping anything that no longer exists - an uninstalled app, a deleted
  /// web app or folder - and anything in the secret folder, which is what
  /// takes a hidden app out of folders and off the home screen.
  List<LauncherEntry> resolve(Iterable<String> keys) => [
    for (final key in keys)
      if (_byKey[key] != null) _byKey[key]!,
  ];

  /// Swapped in by tests, which have no platform channel to answer
  /// [InstalledApps.getInstalledApps] with - see
  /// [DataSourcesController.debugClientOverride] for the same idea applied
  /// to network calls.
  @visibleForTesting
  void debugSetInstalledApps(List<AppInfo> apps) {
    _apps = apps;
    _loaded = true;
    _rebuild();
    // Saved shortcuts follow the apps that published them: a contact renamed
    // in the messenger renames the shortcut here too. Not awaited - it is a
    // handful of platform calls, and the list above is already right without
    // them; the rebuild it triggers when something did change is enough.
    unawaited(SavedShortcutsController.instance.refresh());
  }

  /// Reads the installed apps. Safe to call again to pick up newly
  /// installed ones; the stored settings are loaded alongside on first use.
  Future<void> load() async {
    await Future.wait([
      AppOverridesController.instance.load(),
      WebAppsController.instance.load(),
      AppPairsController.instance.load(),
      SavedShortcutsController.instance.load(),
      FoldersController.instance.load(),
      // Before the apps are turned into entries, otherwise the first build
      // after a cold start would show the hidden ones.
      SecretAppsController.instance.load(),
    ]);
    _apps = await InstalledApps.getInstalledApps(
      excludeSystemApps: false,
      excludeNonLaunchableApps: true,
      withIcon: true,
    );
    _loaded = true;
    _rebuild();
  }

  void _rebuild() {
    _all = [
      for (final app in _apps) LauncherEntry.app(app),
      for (final webApp in WebAppsController.instance.value)
        LauncherEntry.web(webApp),
      for (final pair in AppPairsController.instance.value)
        LauncherEntry.pair(pair),
      for (final shortcut in SavedShortcutsController.instance.value)
        LauncherEntry.shortcut(shortcut),
      for (final folder in FoldersController.instance.value)
        LauncherEntry.folder(folder),
      for (final builtIn in BuiltInEntry.values) LauncherEntry.builtIn(builtIn),
    ];
    _all.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final secret = SecretAppsController.instance.value;
    _entries = [
      for (final entry in _all)
        if (!entry.hidingKeys.any(secret.contains)) entry,
    ];
    _byKey = {for (final entry in _entries) entry.key: entry};
    notifyListeners();
  }
}
