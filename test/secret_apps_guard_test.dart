import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the secret folder against the one way it can quietly break: a new
/// feature that learns an app's name through a path of its own instead of
/// [LauncherEntriesController], and so shows a hidden app again.
///
/// These tests read the source as text rather than running anything. They are
/// meant to fail when something legitimate is added - the failure is the
/// reminder to check whether the new code can expose a secret app, not an
/// accusation that it does. Widen the lists below once that is answered.
void main() {
  final dartFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList();

  String named(File file) => file.uri.pathSegments.last;

  test('only the entries controller may enumerate installed apps', () {
    // Every list of apps in the launcher starts here. Anything else calling
    // the plugin directly would get the secret ones back too.
    final offenders = [
      for (final file in dartFiles)
        if (file.readAsStringSync().contains('getInstalledApps') &&
            named(file) != 'launcher_entries_controller.dart')
          named(file),
    ];

    expect(
      offenders,
      isEmpty,
      reason:
          'These files read the installed apps themselves: $offenders. Go '
          'through LauncherEntriesController.entries instead, which leaves the '
          'secret folder out.',
    );
  });

  test('the unlock token stays where it can be reasoned about', () {
    // The two places that may show hidden apps, and both ask for the password
    // first: the unlocked folder screen, and the app list's search (typing the
    // password there lists them for the length of that search).
    const allowed = {
      'secret_apps_controller.dart',
      'launcher_entries_controller.dart',
      'secret_folder_screen.dart',
      'app_list_view.dart',
    };

    final offenders = [
      for (final file in dartFiles)
        if (!allowed.contains(named(file)))
          if (file.readAsStringSync().contains('SecretUnlock') ||
              file.readAsStringSync().contains('secretEntries'))
            named(file),
    ];

    expect(
      offenders,
      isEmpty,
      reason:
          'These files reach for the secret entries: $offenders. Only the '
          'unlocked folder screen should - if another screen needs them, that '
          'screen needs a password prompt first.',
    );
  });

  test('the secret list is never filtered against before it is read', () {
    // The list starts as an empty set and is filled from disk. Everything
    // that filters against it outside the entries controller runs off the
    // panel being pulled down or off a timer, either of which can happen
    // first - and a filter against an empty set is not a filter. Awaiting
    // loadedKeys() is the same question with the load in front of it, so
    // that is the only door; the two below are already inside one.
    const allowed = {
      // Owns it.
      'secret_apps_controller.dart',
      // Reads it from inside its own load(), which awaits the secret one
      // before touching it.
      'launcher_entries_controller.dart',
      // mostUsedApp is a synchronous getter on purpose: it re-filters every
      // time it is read, so an app hidden after the value was fetched is
      // hidden too. It can only answer non-null once _refreshMostUsedApp
      // has awaited loadedKeys(), so the load is always in front of it.
      'device_stats_controller.dart',
      // build() is synchronous and reads the list to write it into the
      // file. Both ways a backup is actually written go through
      // buildWithFiles(), which awaits loadedKeys() first - an empty list
      // in the file would not read as a fault but as an empty secret
      // folder, and restoring it would un-hide everything in there.
      'settings_backup_service.dart',
    };

    final pattern = RegExp(r'SecretAppsController\.instance\.(value|contains)');
    final offenders = [
      for (final file in dartFiles)
        if (!allowed.contains(named(file)))
          if (pattern.hasMatch(file.readAsStringSync())) named(file),
    ];

    expect(
      offenders,
      isEmpty,
      reason:
          'These files read the secret list without waiting for it to be '
          'loaded: $offenders. Await '
          'SecretAppsController.instance.loadedKeys() instead - read too '
          'early, the set is empty and every hidden app shows.',
    );
  });

  test('no new platform channel slipped in unnoticed', () {
    // A native channel is the second way an app name can reach the launcher
    // (it is how both leaks found when the secret folder was built got in:
    // the browser list and the usage statistics). A new one here is the moment
    // to ask whether it can name an app - and if it can, to filter it the way
    // DeviceStatsController.mostUsedApp does.
    const known = {
      'hanneslauncher/app_info',
      // Answers only about a package Dart named first, and those names come
      // from LauncherEntriesController.entries, which the secret ones are
      // already out of - so a hidden app's shortcuts can never be asked for.
      // The kept shortcuts themselves are covered by LauncherEntry.hidingKeys:
      // a shortcut goes when the app that published it goes.
      'hanneslauncher/app_shortcuts',
      'hanneslauncher/backup',
      'hanneslauncher/browsers',
      'hanneslauncher/calendar',
      'hanneslauncher/contacts',
      'hanneslauncher/device_stats',
      'hanneslauncher/media',
      // Names a package per waiting notification, so NotificationCounts
      // drops the secret ones as they arrive - a hidden app must not
      // announce itself with a badge either.
      'hanneslauncher/notifications',
      // Names no app on its own: Dart hands it the packages to render an
      // icon for, and that list comes from LauncherEntriesController.entries,
      // which the secret ones are already out of. Nothing comes back but
      // paths for packages that were sent in.
      'hanneslauncher/icon_packs',
      // Takes a package name in and starts it; hands none back. The only
      // packages that reach it come from an entry the user tapped, and the
      // secret ones are not in that list.
      'hanneslauncher/launch',
      // Says *that* the installed apps changed and deliberately not which -
      // see MainActivity.packageReceiver. A package name here would be a
      // second route by which one reaches Dart outside the entries
      // controller, and the folder depends on there being only one.
      'hanneslauncher/packages',
      'hanneslauncher/offline_mode',
      'hanneslauncher/system_apps',
      'hanneslauncher/system_gestures',
      // Hands Android a picture for the lock screen and asks whether it is
      // allowed to. Nothing about apps goes either way over it.
      'hanneslauncher/wallpaper',
    };

    final pattern = RegExp(r"MethodChannel\(\s*'([^']+)'");
    final found = <String>{};
    for (final file in dartFiles) {
      for (final match in pattern.allMatches(file.readAsStringSync())) {
        found.add(match.group(1)!);
      }
    }

    expect(
      found.difference(known),
      isEmpty,
      reason:
          'New platform channel(s). Can they name an installed app? If so, '
          'filter SecretAppsController.instance.contains(package) at the '
          'controller that holds the value, not at the widget showing it. '
          'Then add the channel here.',
    );
  });

  test('no new native app lookup slipped in unnoticed', () {
    // The same check on the Android side, where the app names actually come
    // from. Every Kotlin file, not just MainActivity: a lookup moved into a
    // helper of its own would otherwise walk straight past this. Comment
    // lines are dropped first, so a mention in prose does not count.
    final code =
        Directory('android/app/src/main/kotlin/com/example/hanneslauncher')
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.kt'))
            .expand((file) => file.readAsLinesSync())
            .where((line) => !line.trimLeft().startsWith('//'))
            .join('\n');

    // What each lookup is used for today:
    //   queryIntentActivities -> installedBrowsers(), IconPacks.installed()
    //   queryUsageStats -> mostUsedAppToday()
    //   getApplicationLabel/getApplicationInfo -> mostUsedAppToday(), and an
    //     installed icon pack's own name
    //   resolveActivity -> the default-launcher and clock/calendar intents
    //   getPackageInfo -> this app's own version, and a pack's, which keys
    //     the pack's rendered icons so an update isn't served from the old
    //     cache
    //   getApplicationIcon/getResourcesForApplication -> IconPacks, both
    //     only ever asked about a package Dart named first
    //   getLaunchIntentForPackage -> IconPacks, plus launchIntentFor() for
    //     the animated start and the split-screen pair. Both of those are
    //     handed a package by Dart and answer with an intent or nothing;
    //     neither can be asked "which apps are there".
    //   getShortcuts/getShortcutIconDrawable/startShortcut/pinShortcuts ->
    //     AppShortcuts, likewise only ever about a package Dart named first.
    //     getShortcuts is the one to watch: dropped from the query, it
    //     enumerates every app on the phone, hidden ones included.
    const expected = {
      'queryIntentActivities': 2,
      'queryUsageStats': 1,
      'getApplicationLabel': 2,
      'getApplicationInfo': 2,
      'getApplicationIcon': 1,
      'getLaunchIntentForPackage': 2,
      'getResourcesForApplication': 1,
      'getPackageInfo': 2,
      'resolveActivity': 2,
      'getInstalledPackages': 0,
      'getInstalledApplications': 0,
      'getShortcuts': 1,
      'getShortcutIconDrawable': 1,
      'startShortcut': 1,
      'pinShortcuts': 1,
    };

    final counts = {
      for (final api in expected.keys)
        api: RegExp(RegExp.escape(api)).allMatches(code).length,
    };

    expect(
      counts,
      expected,
      reason:
          'The native side looks up apps in a new place. Does it hand a name '
          'or package to Dart? Then it has to be filtered against '
          'SecretAppsController before anything shows it. Update the counts '
          'here afterwards.',
    );
  });
}
