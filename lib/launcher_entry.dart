import 'dart:io';
import 'dart:typed_data';

import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';

import 'app_overrides_controller.dart';
import 'folders_controller.dart';
import 'web_apps_controller.dart';

/// One entry in the app list: an installed app, a saved web app, or a
/// folder. Everything the launcher draws goes through this, so all three
/// behave identically in the list, the alphabet index and the pinned apps.
class LauncherEntry {
  const LauncherEntry.app(this.app) : webApp = null, folder = null;
  const LauncherEntry.web(this.webApp) : app = null, folder = null;
  const LauncherEntry.folder(this.folder) : app = null, webApp = null;

  final AppInfo? app;
  final WebApp? webApp;
  final LauncherFolder? folder;

  bool get isWebApp => webApp != null;

  /// Folders can't be launched - opening one shows its contents instead, so
  /// callers check this before calling [launch].
  bool get isFolder => folder != null;

  /// Identifies the entry when it's pinned or put into a folder. Installed
  /// apps use their package name (unchanged from before web apps and folders
  /// existed, so existing pins keep working); the others use a prefixed id
  /// that can't collide with one.
  String get key {
    if (app != null) return app!.packageName;
    if (webApp != null) return WebAppsController.pinKeyFor(webApp!.id);
    return FoldersController.keyFor(folder!.id);
  }

  /// When this was installed (an app) or added to the launcher (a web app or
  /// folder) - milliseconds since epoch, so it lines up with
  /// [AppInfo.installedTimestamp]. Used to sort "newest first".
  int get addedAt {
    if (app != null) return app!.installedTimestamp;
    // Web app/folder ids are DateTime.microsecondsSinceEpoch - divided down
    // to milliseconds, otherwise they'd always sort as newer than every
    // installed app just from being a bigger raw number.
    if (webApp != null) return (int.tryParse(webApp!.id) ?? 0) ~/ 1000;
    return (int.tryParse(folder!.id) ?? 0) ~/ 1000;
  }

  /// Displayed name: for installed apps this honours a rename made in the
  /// app customization screen.
  String get name {
    if (app != null) {
      return AppOverridesController.instance.nameFor(
        app!.packageName,
        app!.name,
      );
    }
    return webApp?.name ?? folder!.name;
  }

  /// The user's own picture for this entry, if one was picked. Folders are
  /// drawn from their color instead and never have one.
  File? get customIcon {
    if (app != null) {
      return AppOverridesController.instance
          .forPackage(app!.packageName)
          ?.iconFile;
    }
    return webApp?.iconFile;
  }

  /// The icon Android reports for an installed app. Null for the others,
  /// which only ever have a custom picture (or the fallback glyph).
  Uint8List? get systemIcon => app?.icon;

  Future<void> launch() async {
    if (app != null) {
      await InstalledApps.startApp(app!.packageName);
    } else if (webApp != null) {
      await WebAppsController.launch(webApp!);
    }
    // Folders are handled by the caller (see [isFolder]).
  }
}
