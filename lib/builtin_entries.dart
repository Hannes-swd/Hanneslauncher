import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'offline_mode_screen.dart';

/// The launcher's own screens that behave exactly like an installed app:
/// they sit in the app list under their own letter, can be pinned to the
/// home screen, dropped into a folder or put on a widget, and are opened
/// with the same tap. Only the offline mode so far.
///
/// This is why there is no separate button anywhere for them - anything
/// that already knows how to show an app knows how to show these too.
enum BuiltInEntry { offlineMode }

/// Prefixed like the web app and folder keys so a stored pin can't collide
/// with a package name.
const String builtInKeyPrefix = 'builtin:';

extension BuiltInEntryDetails on BuiltInEntry {
  String get key => '$builtInKeyPrefix$name';

  /// Drawn when no picture has been picked for it - which is the normal
  /// case, since these have no icon of their own to fall back on.
  IconData get icon => switch (this) {
    BuiltInEntry.offlineMode => Icons.bedtime_outlined,
  };

  String label(AppStrings s) => switch (this) {
    BuiltInEntry.offlineMode => s.offlineMode,
  };
}

/// The built-in a stored key names, or null if it names something else (a
/// package, a web app, a folder) or one that no longer exists.
BuiltInEntry? builtInFromKey(String key) {
  if (!key.startsWith(builtInKeyPrefix)) return null;
  final name = key.substring(builtInKeyPrefix.length);
  for (final entry in BuiltInEntry.values) {
    if (entry.name == name) return entry;
  }
  return null;
}

/// Opens one. Kept apart from `LauncherEntry.launch()` for the same reason
/// folders are: it needs a [BuildContext] to put a screen on top, which an
/// entry doesn't have.
Future<void> openBuiltIn(BuildContext context, BuiltInEntry entry) {
  return switch (entry) {
    BuiltInEntry.offlineMode => openOfflineMode(context),
  };
}
