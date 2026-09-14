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

  test('no new platform channel slipped in unnoticed', () {
    // A native channel is the second way an app name can reach the launcher
    // (it is how both leaks found when the secret folder was built got in:
    // the browser list and the usage statistics). A new one here is the moment
    // to ask whether it can name an app - and if it can, to filter it the way
    // DeviceStatsController.mostUsedApp does.
    const known = {
      'hanneslauncher/app_info',
      'hanneslauncher/backup',
      'hanneslauncher/browsers',
      'hanneslauncher/calendar',
      'hanneslauncher/contacts',
      'hanneslauncher/device_stats',
      'hanneslauncher/media',
      'hanneslauncher/offline_mode',
      'hanneslauncher/system_apps',
      'hanneslauncher/system_gestures',
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
    // from. Comment lines are dropped first, so a mention in prose does not
    // count.
    final kotlin = File(
      'android/app/src/main/kotlin/com/example/hanneslauncher/MainActivity.kt',
    ).readAsLinesSync().where((line) => !line.trimLeft().startsWith('//'));
    final code = kotlin.join('\n');

    // What each lookup is used for today:
    //   queryIntentActivities -> installedBrowsers()
    //   queryUsageStats / getApplicationLabel -> mostUsedAppToday()
    //   resolveActivity -> the default-launcher and clock/calendar intents
    const expected = {
      'queryIntentActivities': 1,
      'queryUsageStats': 1,
      'getApplicationLabel': 1,
      'resolveActivity': 2,
      'getInstalledPackages': 0,
      'getInstalledApplications': 0,
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
