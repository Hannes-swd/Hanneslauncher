import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'builtin_entries.dart';
import 'folder_sheet.dart';
import 'launcher_entries_controller.dart';
import 'locale_controller.dart';
import 'system_app_launcher.dart';
import 'widget_action.dart';

/// What drawing a shape does.
///
/// Kept as a kind plus one or two plain fields rather than a class per kind:
/// every one of these is "a name for a thing the launcher can already do",
/// and the storing, the restoring and the picker all stay one switch each
/// that the compiler checks is complete when a new kind is added.
enum GestureActionKind {
  /// Anything that sits in the app list: an installed app, a saved web app,
  /// a folder, or one of the launcher's own screens. One kind for all four
  /// because [LauncherEntry.key] already names all four the same way, which
  /// is also what the pinned apps are stored as.
  entry,

  /// Any address the phone can open - https, but also `tel:`, `geo:`,
  /// `spotify:` and anything else something on the phone has registered
  /// for.
  address,

  /// Starts a countdown in the phone's own clock app, so it rings and keeps
  /// running even when the launcher is long gone from the screen.
  timer,

  /// Pulls the launcher's own settings panel down.
  settings,
}

/// The thing a shape is wired up to.
class GestureAction {
  const GestureAction({
    required this.kind,
    this.target = '',
    this.seconds = 0,
  });

  final GestureActionKind kind;

  /// The launcher key for [GestureActionKind.entry], the address for
  /// [GestureActionKind.address], unused otherwise.
  final String target;

  /// [GestureActionKind.timer] only: how long the countdown runs.
  final int seconds;

  /// Whether this is filled in enough to do anything. A half-finished action
  /// can only be produced by editing a backup by hand, but a shortcut that
  /// silently does nothing is worth catching before it is saved.
  bool get isComplete => switch (kind) {
    GestureActionKind.entry => target.isNotEmpty,
    GestureActionKind.address => target.trim().isNotEmpty,
    GestureActionKind.timer => seconds > 0,
    GestureActionKind.settings => true,
  };

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    if (target.isNotEmpty) 'target': target,
    if (seconds > 0) 'seconds': seconds,
  };

  static GestureAction? fromJson(Object? json) {
    if (json is! Map) return null;
    final name = json['kind'];
    for (final kind in GestureActionKind.values) {
      if (kind.name != name) continue;
      return GestureAction(
        kind: kind,
        target: json['target'] as String? ?? '',
        seconds: (json['seconds'] as num?)?.round() ?? 0,
      );
    }
    return null;
  }

  /// One line saying what this does, for the list of saved shapes. An entry
  /// is named by whatever it is called right now rather than by its stored
  /// key, so renaming an app renames it here too - and an app that has been
  /// uninstalled says so instead of showing a package name nobody recognises.
  String describe(AppStrings s) => switch (kind) {
    GestureActionKind.entry =>
      LauncherEntriesController.instance.byKey(target)?.name ??
          s.gestureActionEntryMissing,
    GestureActionKind.address => target,
    GestureActionKind.timer => s.gestureActionTimerFor(
      formatGestureDuration(seconds, s),
    ),
    GestureActionKind.settings => s.settings,
  };
}

/// "5 Min", "1:30 Min", "45 Sek" - short enough for a list subtitle.
String formatGestureDuration(int seconds, AppStrings s) {
  if (seconds < 60) return '$seconds ${s.secondsShort}';
  final minutes = seconds ~/ 60;
  final rest = seconds % 60;
  if (rest == 0) return '$minutes ${s.minutesShort}';
  return '$minutes:${rest.toString().padLeft(2, '0')} ${s.minutesShort}';
}

/// How a run went, as the one line the home screen flashes afterwards.
class GestureActionResult {
  const GestureActionResult({required this.ok, this.message});

  final bool ok;

  /// Only set when something went wrong and it is worth saying - a plain
  /// success says nothing, because the app opening is the confirmation.
  final String? message;
}

/// Carries out a shortcut's action.
///
/// Needs a [BuildContext] because half of these are not "launch something"
/// at all: a folder opens a window on top of the home screen, a built-in is
/// a screen of the launcher's own. [onOpenSettings] is how the panel is
/// pulled down - it lives in the launcher's root state, which is the one
/// thing this cannot reach from here.
Future<GestureActionResult> runGestureAction(
  BuildContext context,
  GestureAction action, {
  required VoidCallback onOpenSettings,
}) async {
  final s = AppStrings(LocaleController.instance.value);
  switch (action.kind) {
    case GestureActionKind.entry:
      final entry = LauncherEntriesController.instance.byKey(action.target);
      if (entry == null) {
        return GestureActionResult(ok: false, message: s.gestureActionGone);
      }
      if (entry.isFolder) {
        showFolderSheet(context, entry.folder!);
      } else if (entry.isBuiltIn) {
        await openBuiltIn(context, entry.builtIn!);
      } else if (!await entry.launch()) {
        // Only a kept app shortcut gets here: the app that published it is
        // free to drop it, and a shape that draws itself and then does
        // nothing is the worst way to find that out.
        return GestureActionResult(ok: false, message: s.appShortcutFailed);
      }
      return const GestureActionResult(ok: true);

    case GestureActionKind.address:
      // The same opener the widget cards' buttons use, so which schemes work
      // and which need a `<queries>` entry in the manifest is one answer for
      // the whole app rather than two that can drift apart.
      final result = await openExternalUrl(action.target);
      return GestureActionResult(ok: result.success, message: result.detail);

    case GestureActionKind.timer:
      final started = await SystemAppLauncher.startTimer(action.seconds);
      return started
          ? GestureActionResult(
              ok: true,
              message: s.gestureTimerStarted(
                formatGestureDuration(action.seconds, s),
              ),
            )
          : GestureActionResult(ok: false, message: s.gestureTimerNoClockApp);

    case GestureActionKind.settings:
      onOpenSettings();
      return const GestureActionResult(ok: true);
  }
}

/// The icon a kind is drawn with, in the picker and in the list of saved
/// shapes.
IconData gestureActionIcon(GestureActionKind kind) => switch (kind) {
  GestureActionKind.entry => Icons.apps_outlined,
  GestureActionKind.address => Icons.link,
  GestureActionKind.timer => Icons.timer_outlined,
  GestureActionKind.settings => Icons.settings_outlined,
};

/// What the kind is called where it is picked.
String gestureActionKindLabel(GestureActionKind kind, AppStrings s) =>
    switch (kind) {
      GestureActionKind.entry => s.gestureActionKindEntry,
      GestureActionKind.address => s.gestureActionKindAddress,
      GestureActionKind.timer => s.gestureActionKindTimer,
      GestureActionKind.settings => s.gestureActionKindSettings,
    };

/// A line under that label saying what it is good for - these are the four
/// answers to "was soll passieren?", and the difference between them is not
/// obvious from four words alone.
String gestureActionKindHint(GestureActionKind kind, AppStrings s) =>
    switch (kind) {
      GestureActionKind.entry => s.gestureActionKindEntryHint,
      GestureActionKind.address => s.gestureActionKindAddressHint,
      GestureActionKind.timer => s.gestureActionKindTimerHint,
      GestureActionKind.settings => s.gestureActionKindSettingsHint,
    };
