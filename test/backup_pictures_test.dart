import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanneslauncher/app_overrides_controller.dart';
import 'package:hanneslauncher/app_pairs_controller.dart';
import 'package:hanneslauncher/settings_backup_service.dart';
import 'package:hanneslauncher/wallpaper_controller.dart';
import 'package:hanneslauncher/web_apps_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The pictures were the one thing a backup genuinely did not carry: the
/// settings all came back and the launcher looked wrong, because a wallpaper
/// and a replaced icon travelled as paths into an install that no longer
/// existed. These hold that shut.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('hl_backup_test');

    // path_provider has no implementation in a test, so the documents
    // directory every picture is written into has to be answered here.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => root.path,
        );

    await WallpaperController.instance.clear();
    await AppOverridesController.instance.load();
    await WebAppsController.instance.load();
    await AppPairsController.instance.replaceAll(const []);
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  /// A file with recognisable contents, so "the same picture came back" can
  /// be checked by reading it rather than by trusting a path.
  Future<File> writePicture(String name, List<int> bytes) async {
    final file = File('${root.path}/$name');
    await file.writeAsBytes(bytes);
    return file;
  }

  test('the wallpaper travels as the picture, not as a path', () async {
    const bytes = [1, 2, 3, 4, 5, 6, 7, 8];
    final original = await writePicture('wall.png', bytes);
    await WallpaperController.instance.restoreFile(original);

    final json = await SettingsBackupService.exportJsonWithFiles();

    // The old install is gone: its file is deleted and the setting cleared,
    // which is exactly the state a restore lands in.
    await WallpaperController.instance.clear();
    if (original.existsSync()) original.deleteSync();
    expect(WallpaperController.instance.value, isNull);

    await SettingsBackupService.apply(json);

    final restored = WallpaperController.instance.value;
    expect(restored, isNotNull);
    expect(restored!.file.existsSync(), isTrue);
    expect(await restored.file.readAsBytes(), bytes);
    // A new file of this install's own, not the path out of the document.
    expect(restored.file.path, isNot(original.path));
  });

  test('the wallpaper keeps its extension, which is what decides how it is '
      'drawn', () async {
    final original = await writePicture('clip.mp4', [9, 9, 9]);
    await WallpaperController.instance.restoreFile(original);
    expect(WallpaperController.instance.value!.isVideo, isTrue);

    final json = await SettingsBackupService.exportJsonWithFiles();
    await WallpaperController.instance.clear();
    await SettingsBackupService.apply(json);

    expect(WallpaperController.instance.value!.isVideo, isTrue);
  });

  test('a replaced app icon comes back on the same app', () async {
    const bytes = [42, 43, 44];
    final icon = await writePicture('icon.png', bytes);
    await AppOverridesController.instance.setName('com.example.app', 'Renamed');
    await AppOverridesController.instance.debugSetIconPath(
      'com.example.app',
      icon.path,
    );

    final json = await SettingsBackupService.exportJsonWithFiles();
    await AppOverridesController.instance.clearIcon('com.example.app');

    await SettingsBackupService.apply(json);

    final override = AppOverridesController.instance.forPackage(
      'com.example.app',
    );
    expect(override, isNotNull);
    // The name survived the icon being put back on top of it - the restore
    // order is what this is really checking.
    expect(override!.name, 'Renamed');
    expect(override.iconPath, isNotNull);
    expect(await File(override.iconPath!).readAsBytes(), bytes);
  });

  test('a picture too large to carry is named, not silently dropped', () async {
    // One byte over the limit.
    final huge = await writePicture(
      'huge.png',
      List.filled(SettingsBackupService.maxPictureBytes + 1, 7),
    );
    await WallpaperController.instance.restoreFile(huge);

    final json = await SettingsBackupService.exportJsonWithFiles();

    expect(SettingsBackupService.oversizedPicturesIn(json), ['wallpaper']);
    // And the document stayed a sane size rather than growing by 8 MB.
    expect(json.length, lessThan(SettingsBackupService.maxPictureBytes));

    await WallpaperController.instance.clear();
    await SettingsBackupService.apply(json);
    // Nothing to put back, and nothing broken by trying.
    expect(WallpaperController.instance.value, isNull);
  });

  test('a document from before the pictures existed still restores', () async {
    // Version 1 is what every backup written until now says.
    await SettingsBackupService.apply('{"formatVersion": 1}');
    expect(WallpaperController.instance.value, isNull);
    expect(SettingsBackupService.oversizedPicturesIn('{"formatVersion": 1}'),
        isEmpty);
  });

  test('app pairs survive a round trip', () async {
    await AppPairsController.instance.add(
      'Chat + Notes',
      'com.example.chat',
      'com.example.notes',
    );

    final json = SettingsBackupService.exportJson();
    await AppPairsController.instance.replaceAll(const []);
    expect(AppPairsController.instance.value, isEmpty);

    await SettingsBackupService.apply(json);

    final pairs = AppPairsController.instance.value;
    expect(pairs, hasLength(1));
    expect(pairs.single.name, 'Chat + Notes');
    expect(pairs.single.first, 'com.example.chat');
    expect(pairs.single.second, 'com.example.notes');
  });

  test('a pair naming nothing is skipped rather than restored empty', () async {
    await SettingsBackupService.apply(
      jsonEncode({
        'formatVersion': 2,
        'appPairs': [
          {'id': '1', 'name': 'Good', 'first': 'a', 'second': 'b'},
          {'id': '2', 'name': 'Broken', 'first': '', 'second': 'b'},
          {'id': '3'},
        ],
      }),
    );
    expect(AppPairsController.instance.value, hasLength(1));
    expect(AppPairsController.instance.value.single.name, 'Good');
  });

  test('the search settings come back with everything else', () async {
    // The three fields added with the magnifier's extra piles. They are here
    // rather than in a settings test because the thing that goes wrong with
    // a new field is that nobody carries it into the backup.
    final json = SettingsBackupService.exportJson();
    final document = jsonDecode(json) as Map<String, dynamic>;
    final appList = document['appList'] as Map<String, dynamic>;
    expect(appList.keys, contains('searchExtras'));
    expect(appList.keys, contains('searchContacts'));
    expect(appList.keys, contains('searchWebUrl'));
  });
}
