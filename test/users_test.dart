import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanneslauncher/app_strings.dart';
import 'package:hanneslauncher/clock_settings_controller.dart';
import 'package:hanneslauncher/code_widget_store.dart';
import 'package:hanneslauncher/custom_colors_controller.dart';
import 'package:hanneslauncher/design_controller.dart';
import 'package:hanneslauncher/design_tokens.dart';
import 'package:hanneslauncher/folders_controller.dart';
import 'package:hanneslauncher/launcher_entries_controller.dart';
import 'package:hanneslauncher/locale_controller.dart';
import 'package:hanneslauncher/panel_blocks_controller.dart';
import 'package:hanneslauncher/pinned_apps_controller.dart';
import 'package:hanneslauncher/secret_apps_controller.dart';
import 'package:hanneslauncher/settings_backup_service.dart';
import 'package:hanneslauncher/settings_keys.dart';
import 'package:hanneslauncher/users_controller.dart';
import 'package:hanneslauncher/users_settings_screen.dart';
import 'package:hanneslauncher/wallpaper_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A second home screen is only worth having if switching to it can never
/// cost the first one anything - a picture deleted, a setting left behind,
/// a hidden app shown. These hold that shut.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final users = UsersController.instance;
  late Directory root;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('hl_users_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => root.path,
        );
    // Nothing installed - the pins below are folders, which resolve without
    // a platform channel to ask.
    LauncherEntriesController.instance.debugSetInstalledApps(const []);
    await users.debugRestartForTest();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Future<File> writePicture(String name, List<int> bytes) async {
    final file = File('${root.path}/$name');
    await file.writeAsBytes(bytes);
    return file;
  }

  /// A home screen that looks nothing like a fresh one.
  Future<void> setUpFirstUser() async {
    await CustomColorsController.instance.restore([const Color(0xFF123456)]);
    await ClockSettingsController.instance.update(
      const ClockSettings(style: ClockStyle.bars, topPadding: 40),
    );
    await DesignController.instance.update(
      DesignSettings(
        preset: DesignThemePreset.blue,
        overrides: {DesignColorRole.accent: const Color(0xFF00FF88)},
        radius: 10,
      ),
    );
    await FoldersController.instance.replaceAll([
      const LauncherFolder(id: 'f1', name: 'Spiele'),
    ]);
    await PinnedAppsController.instance.restore(['folder:f1']);
    await PanelBlocksController.instance.replaceAll([
      const PanelBlock(id: 'b1', type: PanelBlockType.calendar),
    ]);
  }

  test('a new user starts out as a fresh install would', () async {
    await setUpFirstUser();

    final second = await users.create('Arbeit');
    await users.switchTo(second.id);

    expect(users.value.activeId, second.id);
    expect(CustomColorsController.instance.value, isEmpty);
    expect(ClockSettingsController.instance.value.style, ClockStyle.digital);
    expect(ClockSettingsController.instance.value.topPadding, 0);
    expect(DesignController.instance.value.preset, DesignThemePreset.grey);
    expect(DesignController.instance.value.overrides, isEmpty);
    expect(FoldersController.instance.value, isEmpty);
    expect(PinnedAppsController.instance.value, isEmpty);
    expect(PanelBlocksController.instance.value, isEmpty);
  });

  test('switching back brings every setting back, both ways', () async {
    await setUpFirstUser();
    final second = await users.create('Arbeit');
    await users.switchTo(second.id);

    await ClockSettingsController.instance.update(
      const ClockSettings(style: ClockStyle.orbit),
    );
    await FoldersController.instance.replaceAll([
      const LauncherFolder(id: 'f2', name: 'Büro'),
    ]);

    await users.switchTo(mainUserId);
    expect(CustomColorsController.instance.value, [const Color(0xFF123456)]);
    expect(ClockSettingsController.instance.value.style, ClockStyle.bars);
    expect(ClockSettingsController.instance.value.topPadding, 40);
    expect(DesignController.instance.value.preset, DesignThemePreset.blue);
    expect(
      DesignController.instance.value.overrides[DesignColorRole.accent],
      const Color(0xFF00FF88),
    );
    expect(DesignController.instance.value.radius, 10);
    expect(FoldersController.instance.value.single.name, 'Spiele');
    expect(PinnedAppsController.instance.value, ['folder:f1']);
    expect(PanelBlocksController.instance.value.single.id, 'b1');

    await users.switchTo(second.id);
    expect(ClockSettingsController.instance.value.style, ClockStyle.orbit);
    expect(FoldersController.instance.value.single.name, 'Büro');
    expect(PinnedAppsController.instance.value, isEmpty);
  });

  test('the language and the secret folder are the same for every user',
      () async {
    await LocaleController.instance.update(AppLanguage.de);
    await SecretAppsController.instance.restore(
      keys: ['com.example.hidden'],
      hash: 'h',
      salt: 's',
    );

    final second = await users.create('Arbeit');
    await users.switchTo(second.id);

    expect(LocaleController.instance.value, AppLanguage.de);
    final prefs = await SharedPreferences.getInstance();
    // Read off disk rather than the controller, which a switch never asks
    // to read again - what matters is that nothing moved underneath it.
    expect(prefs.getStringList('secret_app_keys'), ['com.example.hidden']);
    expect(prefs.getString('secret_password_hash'), 'h');
  });

  test("a new wallpaper in one user never deletes another's", () async {
    final first = await writePicture('first.png', [1, 2, 3]);
    await WallpaperController.instance.restoreFile(first);

    final second = await users.create('Arbeit');
    await users.switchTo(second.id);
    expect(WallpaperController.instance.value, isNull);

    final other = await writePicture('second.png', [4, 5, 6]);
    await WallpaperController.instance.restoreFile(other);
    expect(first.existsSync(), isTrue);

    await users.switchTo(mainUserId);
    expect(WallpaperController.instance.value?.file.path, first.path);
    expect(other.existsSync(), isTrue);
  });

  test('deleting a user throws away its files and nothing else', () async {
    final first = await writePicture('first.png', [1, 2, 3]);
    await WallpaperController.instance.restoreFile(first);

    final second = await users.create('Arbeit');
    await users.switchTo(second.id);
    final other = await writePicture('second.png', [4, 5, 6]);
    await WallpaperController.instance.restoreFile(other);
    await PanelBlocksController.instance.replaceAll([
      const PanelBlock(id: 'code1', type: PanelBlockType.code),
    ]);
    await CodeWidgetStore.instance.write('code1', html: '<p>hi</p>');
    final widgetFolder = await CodeWidgetStore.instance.folderFor('code1');

    // Deleting the active user goes back to the main one first.
    await users.remove(second.id);

    expect(users.value.activeId, mainUserId);
    expect(users.value.users.map((user) => user.id), [mainUserId]);
    expect(WallpaperController.instance.value?.file.path, first.path);
    expect(first.existsSync(), isTrue);
    expect(other.existsSync(), isFalse);
    expect(widgetFolder.existsSync(), isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys().where((key) => key.startsWith('users_stash_')),
        isEmpty);
  });

  test('the main user cannot be deleted', () async {
    await users.remove(mainUserId);
    expect(users.value.users.single.id, mainUserId);
  });

  test('name and icon survive a restart, and editing one keeps the other',
      () async {
    final second = await users.create('Arbeit', icon: 'work');
    await users.edit(second.id, icon: 'night');
    await users.edit(mainUserId, name: 'Privat');

    await users.debugRestartForTest();

    expect(users.value.users.first.name, 'Privat');
    expect(users.value.users.last.name, 'Arbeit');
    expect(users.value.users.last.icon, 'night');
  });

  group('the quick switch in the panel', () {
    const s = AppStrings(AppLanguage.de);

    Future<void> showSwitch(WidgetTester tester) => tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(DesignSettings()),
        home: const Scaffold(body: UserQuickSwitch(s: s)),
      ),
    );

    // The controller's queue lives outside the widget test's fake clock, so
    // anything that goes through it runs on the real one.
    Future<void> makeUsers(WidgetTester tester, int count) async {
      await tester.runAsync(() async {
        for (var i = 2; i <= count; i++) {
          await users.create('Benutzer $i');
        }
      });
      await tester.pump();
    }

    /// A switch started by a tap runs partly on each clock; both are turned
    /// until it has landed.
    Future<void> waitFor(WidgetTester tester, bool Function() done) async {
      for (var i = 0; i < 100 && !done(); i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
    }

    testWidgets('is not there with only one user', (tester) async {
      await showSwitch(tester);
      expect(find.byType(UserAvatar), findsNothing);
    });

    testWidgets('shows every user while three fit', (tester) async {
      await makeUsers(tester, 3);
      await showSwitch(tester);
      expect(find.byType(UserAvatar), findsNWidgets(3));
      expect(find.textContaining('+'), findsNothing);
    });

    testWidgets('shows two and "+2" at four users', (tester) async {
      await makeUsers(tester, 4);
      await showSwitch(tester);
      expect(find.byType(UserAvatar), findsNWidgets(2));
      expect(find.text('+2'), findsOneWidget);
    });

    testWidgets('keeps the active user among the two, and the dropdown '
        'switches to the rest', (tester) async {
      await makeUsers(tester, 5);
      final last = users.value.users.last;
      await tester.runAsync(() => users.switchTo(last.id));
      await showSwitch(tester);

      final shown = tester
          .widgetList<UserAvatar>(find.byType(UserAvatar))
          .toList();
      expect(shown.map((avatar) => avatar.user.id), [mainUserId, last.id]);
      expect(shown.last.active, isTrue);
      expect(find.text('+3'), findsOneWidget);

      await tester.tap(find.text('+3'));
      await tester.pumpAndSettle();
      final hidden = users.value.users[1];
      expect(find.text(hidden.name), findsOneWidget);

      await tester.tap(find.text(hidden.name));
      await waitFor(tester, () => users.value.activeId == hidden.id);
      expect(users.value.activeId, hidden.id);
    });
  });

  test('a switch cut off half way is finished on the next start', () async {
    final second = await users.create('Arbeit');
    await users.switchTo(second.id);
    await ClockSettingsController.instance.update(
      const ClockSettings(style: ClockStyle.orbit),
    );
    await users.switchTo(mainUserId);

    // What a switch back to "Arbeit" leaves behind when the phone dies
    // right after marking it active: its parked copy still there, and the
    // keys only half replaced.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('users_active', second.id);
    await prefs.setInt('clock_style', ClockStyle.roman.index);

    await users.debugRestartForTest();

    expect(users.value.activeId, second.id);
    expect(ClockSettingsController.instance.value.style, ClockStyle.orbit);
    expect(prefs.containsKey('users_stash_${second.id}'), isFalse);
  });

  test('a backup carries every user, pictures and code widgets included',
      () async {
    await setUpFirstUser();
    final second = await users.create('Arbeit', icon: 'work');
    await users.switchTo(second.id);
    final picture = await writePicture('second.png', [7, 7, 7]);
    await WallpaperController.instance.restoreFile(picture);
    await PanelBlocksController.instance.replaceAll([
      const PanelBlock(id: 'code1', type: PanelBlockType.code),
    ]);
    await CodeWidgetStore.instance.write('code1', html: '<p>Arbeit</p>');
    await users.switchTo(mainUserId);

    final json = await SettingsBackupService.exportJsonWithFiles();
    final document = jsonDecode(json) as Map<String, dynamic>;
    expect(document['users']['active'], mainUserId);

    // A fresh install: nothing stored, no files, no users.
    SharedPreferences.setMockInitialValues({});
    for (final entity in root.listSync()) {
      entity.deleteSync(recursive: true);
    }
    await users.debugRestartForTest();
    expect(users.value.users, hasLength(1));

    await SettingsBackupService.apply(json);

    expect(users.value.users.map((user) => user.name), ['', 'Arbeit']);
    expect(users.value.users.last.icon, 'work');
    expect(users.value.activeId, mainUserId);
    expect(FoldersController.instance.value.single.name, 'Spiele');

    await users.switchTo(users.value.users.last.id);
    final wallpaper = WallpaperController.instance.value;
    expect(wallpaper, isNotNull);
    expect(await wallpaper!.file.readAsBytes(), [7, 7, 7]);
    expect(PanelBlocksController.instance.value.single.id, 'code1');
    // Off disk: the store's cache still remembers the page from before the
    // files were wiped, and would pass this whatever the restore did.
    final page = File(
      '${root.path}/${CodeWidgetStore.folderName}/code1/'
      '${CodeWidgetStore.htmlFile}',
    );
    expect(await page.readAsString(), '<p>Arbeit</p>');
  });

  group('which keys move', () {
    test('every shared key is one the registry backs up', () {
      final wrong = [
        for (final key in sharedUserKeys.keys)
          if (settingsKeyRegistry[key] != KeyFate.backedUp) key,
      ];
      expect(
        wrong,
        isEmpty,
        reason: 'A shared key that is not backed up (or not registered at '
            'all) is a note about nothing: $wrong',
      );
    });

    test('every shared prefix is a registered one', () {
      final wrong = [
        for (final prefix in sharedUserPrefixes.keys)
          if (!settingsKeyPrefixes.containsKey(prefix)) prefix,
      ];
      expect(wrong, isEmpty);
    });

    test('the device-local keys that move are device-local ones', () {
      final wrong = [
        for (final key in deviceLocalUserKeys)
          if (settingsKeyRegistry[key] != KeyFate.deviceLocal) key,
      ];
      expect(wrong, isEmpty);
    });

    test('every file owning a user key is read again on a switch', () {
      // The keys move by themselves - settings_keys.dart decides which -
      // but a controller nobody asks to read again would go on showing the
      // other user. Same check as the backup's in settings_keys_test.dart:
      // the file has to at least be imported where the switch happens.
      final source = File('lib/users_controller.dart').readAsStringSync();
      final missing = <String>{};
      for (final file in Directory('lib').listSync().whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        final name = file.uri.pathSegments.last;
        for (final match in _keyDeclaration.allMatches(
          file.readAsStringSync(),
        )) {
          if (isUserKey(match.group(1)!) &&
              !source.contains("import '$name';")) {
            missing.add(name);
          }
        }
      }
      expect(
        missing,
        isEmpty,
        reason: 'These files hold settings that belong to a user, but '
            'users_controller.dart does not import them - so nothing there '
            'can be having them read again after a switch. Add the '
            "controller's reload to _reloaders: ${missing.join(', ')}",
      );
    });
  });
}

/// Same pattern as test/settings_keys_test.dart.
final _keyDeclaration = RegExp(
  r"""const\s+_?[A-Za-z0-9_]*[Kk]ey\s*=\s*'([^']+)'""",
);
