import 'package:flutter/foundation.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';

import 'app_overrides_controller.dart';
import 'folders_controller.dart';
import 'launcher_entry.dart';
import 'web_apps_controller.dart';

/// The single list of everything the launcher can show: installed apps,
/// saved web apps and folders, sorted by displayed name.
///
/// Kept in one place because folders reference their contents by key, so
/// resolving a folder needs the same lookup the app list and the pinned apps
/// use. Notifies whenever apps are (re)loaded or a rename, web app or folder
/// changes what should be on screen.
class LauncherEntriesController extends ChangeNotifier {
  LauncherEntriesController._() {
    AppOverridesController.instance.addListener(_rebuild);
    WebAppsController.instance.addListener(_rebuild);
    FoldersController.instance.addListener(_rebuild);
  }

  static final LauncherEntriesController instance =
      LauncherEntriesController._();

  List<AppInfo> _apps = [];
  List<LauncherEntry> _entries = [];
  Map<String, LauncherEntry> _byKey = {};
  bool _loaded = false;

  /// False until the installed apps have been read for the first time.
  bool get isLoaded => _loaded;

  List<LauncherEntry> get entries => _entries;

  /// The installed apps on their own, for screens that only deal with those.
  List<AppInfo> get installedApps => _apps;

  LauncherEntry? byKey(String key) => _byKey[key];

  /// Turns stored keys (folder contents, pinned entries) into entries,
  /// skipping anything that no longer exists - an uninstalled app, a deleted
  /// web app or folder.
  List<LauncherEntry> resolve(Iterable<String> keys) => [
    for (final key in keys)
      if (_byKey[key] != null) _byKey[key]!,
  ];

  /// Reads the installed apps. Safe to call again to pick up newly
  /// installed ones; the stored settings are loaded alongside on first use.
  Future<void> load() async {
    await Future.wait([
      AppOverridesController.instance.load(),
      WebAppsController.instance.load(),
      FoldersController.instance.load(),
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
    _entries = [
      for (final app in _apps) LauncherEntry.app(app),
      for (final webApp in WebAppsController.instance.value)
        LauncherEntry.web(webApp),
      for (final folder in FoldersController.instance.value)
        LauncherEntry.folder(folder),
    ];
    _entries.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    _byKey = {for (final entry in _entries) entry.key: entry};
    notifyListeners();
  }
}
