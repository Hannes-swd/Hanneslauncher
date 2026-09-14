import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanneslauncher/app_list_settings_controller.dart';
import 'package:hanneslauncher/app_list_view.dart';
import 'package:hanneslauncher/device_stats_controller.dart';
import 'package:hanneslauncher/folders_controller.dart';
import 'package:hanneslauncher/launcher_entries_controller.dart';
import 'package:hanneslauncher/pinned_apps_controller.dart';
import 'package:hanneslauncher/secret_apps_controller.dart';
import 'package:hanneslauncher/settings_backup_service.dart';
import 'package:installed_apps/app_category.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/platform_type.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppInfo _app(String name, String package) => AppInfo(
  name: name,
  icon: null,
  packageName: package,
  versionName: '1.0.0',
  versionCode: 1,
  platformType: PlatformType.nativeOrOthers,
  installedTimestamp: 0,
  isSystemApp: false,
  isLaunchableApp: true,
  category: AppCategory.undefined,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// A fresh unlock for every test: the controller is a singleton, so a
  /// leftover one from the test before would let the next test pass without
  /// ever going through a password.
  Future<SecretUnlock> reset() async {
    SharedPreferences.setMockInitialValues({});
    SecretAppsController.instance.lock();
    await SecretAppsController.instance.restore(keys: const []);
    await PinnedAppsController.instance.restore(const []);
    LauncherEntriesController.instance.debugSetInstalledApps([
      _app('Mail', 'com.example.mail'),
      _app('Diary', 'com.example.diary'),
    ]);
    // A password can only be set while none exists, which restore() above
    // has just made true again.
    final unlock = await SecretAppsController.instance.setPassword('1234');
    return unlock!;
  }

  test('a secret app is gone from entries, byKey and resolve', () async {
    final unlock = await reset();
    final entries = LauncherEntriesController.instance;
    expect(entries.byKey('com.example.diary'), isNotNull);

    await SecretAppsController.instance.add(unlock, 'com.example.diary');

    // The app list, the search and every picker read this one list.
    expect(
      entries.entries.map((entry) => entry.key),
      isNot(contains('com.example.diary')),
    );
    expect(
      entries.entries.map((entry) => entry.key),
      contains('com.example.mail'),
    );
    // Pinned apps, folders and the code widgets' `open` go through these two.
    expect(entries.byKey('com.example.diary'), isNull);
    expect(
      entries.resolve(['com.example.diary', 'com.example.mail']),
      hasLength(1),
    );
  });

  test('only the current unlock can see the secret entries', () async {
    final unlock = await reset();
    await SecretAppsController.instance.add(unlock, 'com.example.diary');
    final entries = LauncherEntriesController.instance;

    expect(entries.secretEntries(unlock), hasLength(1));

    // Locking makes the token that was handed out worthless, so a screen
    // holding on to one cannot keep reading after the launcher was
    // backgrounded.
    SecretAppsController.instance.lock();
    expect(entries.secretEntries(unlock), isEmpty);

    // And a wrong password produces no token at all.
    expect(SecretAppsController.instance.unlock('wrong'), isNull);
    final again = SecretAppsController.instance.unlock('1234');
    expect(again, isNotNull);
    expect(entries.secretEntries(again!), hasLength(1));
    // The stale one stays worthless even though a later unlock succeeded.
    expect(entries.secretEntries(unlock), isEmpty);
  });

  test('a locked folder refuses to add or remove', () async {
    final unlock = await reset();
    SecretAppsController.instance.lock();

    await SecretAppsController.instance.add(unlock, 'com.example.diary');
    expect(
      SecretAppsController.instance.contains('com.example.diary'),
      isFalse,
    );

    final fresh = SecretAppsController.instance.unlock('1234')!;
    await SecretAppsController.instance.add(fresh, 'com.example.diary');
    expect(SecretAppsController.instance.contains('com.example.diary'), isTrue);

    SecretAppsController.instance.lock();
    await SecretAppsController.instance.remove(fresh, 'com.example.diary');
    expect(SecretAppsController.instance.contains('com.example.diary'), isTrue);
  });

  test('hiding a pinned app unpins it', () async {
    final unlock = await reset();
    await PinnedAppsController.instance.toggle('com.example.diary');
    expect(PinnedAppsController.instance.isPinned('com.example.diary'), isTrue);

    final wasPinned = await SecretAppsController.instance.add(
      unlock,
      'com.example.diary',
    );

    // Otherwise one of the six slots would stay occupied by something that
    // can never be drawn.
    expect(wasPinned, isTrue);
    expect(
      PinnedAppsController.instance.isPinned('com.example.diary'),
      isFalse,
    );
  });

  test('a secret app is skipped inside a folder', () async {
    final unlock = await reset();
    await FoldersController.instance.replaceAll(const []);
    final folder = await FoldersController.instance.add('Stuff');
    await FoldersController.instance.addItem(folder.id, 'com.example.mail');
    await FoldersController.instance.addItem(folder.id, 'com.example.diary');

    await SecretAppsController.instance.add(unlock, 'com.example.diary');

    final contents = LauncherEntriesController.instance.resolve(
      FoldersController.instance.value.first.itemKeys,
    );
    expect(contents.map((entry) => entry.key), ['com.example.mail']);
  });

  test('the password survives a restore, a wrong one still fails', () async {
    final unlock = await reset();
    await SecretAppsController.instance.add(unlock, 'com.example.diary');
    final hash = SecretAppsController.instance.passwordHash;
    final salt = SecretAppsController.instance.passwordSalt;

    await SecretAppsController.instance.restore(
      keys: ['com.example.diary'],
      hash: hash,
      salt: salt,
    );

    // A restore locks the folder, and the restored password is the one that
    // opens it again.
    expect(SecretAppsController.instance.isUnlocked, isFalse);
    expect(SecretAppsController.instance.unlock('wrong'), isNull);
    expect(SecretAppsController.instance.unlock('1234'), isNotNull);
  });

  test('half a restored password leaves the folder without one', () async {
    final unlock = await reset();
    await SecretAppsController.instance.add(unlock, 'com.example.diary');

    // A hand-edited backup with the salt missing: keeping the hash would lock
    // the list away for good.
    await SecretAppsController.instance.restore(
      keys: ['com.example.diary'],
      hash: SecretAppsController.instance.passwordHash,
    );

    expect(SecretAppsController.instance.hasPassword, isFalse);
    expect(SecretAppsController.instance.contains('com.example.diary'), isTrue);
    expect(await SecretAppsController.instance.setPassword('new'), isNotNull);
  });

  test('a backup carries the folder and its password through', () async {
    final unlock = await reset();
    await SecretAppsController.instance.add(unlock, 'com.example.diary');
    final code = (await SecretAppsController.instance.newRecoveryCode(unlock))!;

    final exported = SettingsBackupService.exportJson();

    // As if this were a different install: no folder, no password.
    await SecretAppsController.instance.restore(keys: const []);
    expect(SecretAppsController.instance.hasPassword, isFalse);

    await SettingsBackupService.apply(exported);

    // Exported but not imported is the failure this catches - the folder would
    // silently come back empty and un-hide every app in it.
    expect(SecretAppsController.instance.contains('com.example.diary'), isTrue);
    expect(SecretAppsController.instance.unlock('1234'), isNotNull);
    // And the recovery code has to come along too, or a restore would leave
    // the folder with no way back in.
    SecretAppsController.instance.lock();
    expect(
      SecretAppsController.instance.unlockWithRecoveryCode(code),
      isNotNull,
    );
  });

  test('the recovery code opens the folder, a wrong one does not', () async {
    final unlock = await reset();
    final code = await SecretAppsController.instance.newRecoveryCode(unlock);
    expect(code, isNotNull);
    SecretAppsController.instance.lock();

    expect(
      SecretAppsController.instance.unlockWithRecoveryCode('NOPE'),
      isNull,
    );

    // Written down by hand: lowercase, spaces instead of the dashes, a stray
    // line break. All of that has to be accepted, or a code on paper is
    // worthless.
    final sloppy = code!.toLowerCase().replaceAll('-', ' ');
    final recovered = SecretAppsController.instance.unlockWithRecoveryCode(
      ' $sloppy\n',
    );
    expect(recovered, isNotNull);

    // And it is a way in, not a way to read the password: a new one has to be
    // set, which needs no knowledge of the old.
    expect(
      await SecretAppsController.instance.changePassword(recovered!, 'neu'),
      isTrue,
    );
    SecretAppsController.instance.lock();
    expect(SecretAppsController.instance.unlock('1234'), isNull);
    expect(SecretAppsController.instance.unlock('neu'), isNotNull);
  });

  test('a new recovery code retires the one before it', () async {
    final unlock = await reset();
    final first = await SecretAppsController.instance.newRecoveryCode(unlock);
    final second = await SecretAppsController.instance.newRecoveryCode(unlock);
    expect(second, isNot(first));

    SecretAppsController.instance.lock();
    expect(
      SecretAppsController.instance.unlockWithRecoveryCode(first!),
      isNull,
    );
    expect(
      SecretAppsController.instance.unlockWithRecoveryCode(second!),
      isNotNull,
    );
  });

  test('a locked folder cannot mint itself a recovery code', () async {
    final unlock = await reset();
    SecretAppsController.instance.lock();

    // Otherwise the way in would be: ask for a code, read it, use it.
    expect(await SecretAppsController.instance.newRecoveryCode(unlock), isNull);
    expect(SecretAppsController.instance.hasRecoveryCode, isFalse);
  });

  test('the search lists the secret apps once the password is in', () async {
    final unlock = await reset();
    await SecretAppsController.instance.add(unlock, 'com.example.diary');
    final visible = LauncherEntriesController.instance.entries;
    final secret = LauncherEntriesController.instance.secretEntries(unlock);

    // Without the password the search is the search: no hidden app, whatever
    // is typed - including its exact name.
    expect(
      searchResults(
        query: 'Diary',
        visible: visible,
        secret: const [],
        sortMode: AppListSortMode.alphabetical,
      ),
      isEmpty,
    );

    // With it, and the field cleared right after: just the hidden apps, not
    // every installed one.
    expect(
      searchResults(
        query: '',
        visible: visible,
        secret: secret,
        sortMode: AppListSortMode.alphabetical,
      ).map((entry) => entry.key),
      ['com.example.diary'],
    );

    // Typing on from there searches across both, in one alphabetical run
    // rather than visible-then-secret.
    final both = searchResults(
      query: 'a',
      visible: visible,
      secret: secret,
      sortMode: AppListSortMode.alphabetical,
    ).map((entry) => entry.name).toList();
    expect(both, contains('Diary'));
    expect(both, contains('Mail'));
    expect(both, orderedEquals([...both]..sort()));
  });

  test('the most-used app is not reported while it is secret', () async {
    final unlock = await reset();
    const channel = MethodChannel('hanneslauncher/device_stats');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'hasUsageAccess':
              return true;
            case 'mostUsedApp':
              return {'package': 'com.example.diary', 'name': 'Diary'};
            case 'battery':
            case 'storage':
              return <String, Object?>{};
            case 'connectionType':
              return 'wifi';
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    await DeviceStatsController.instance.refresh(wantsMostUsedApp: true);
    expect(DeviceStatsController.instance.mostUsedApp, 'Diary');

    // Android's usage statistics are a second way to learn an app's name -
    // the placeholder that shows this must not name a hidden app.
    await SecretAppsController.instance.add(unlock, 'com.example.diary');
    expect(DeviceStatsController.instance.mostUsedApp, isNull);
  });
}
