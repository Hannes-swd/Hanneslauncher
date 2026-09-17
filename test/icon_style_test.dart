import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanneslauncher/app_icon.dart';
import 'package:hanneslauncher/app_overrides_controller.dart';
import 'package:hanneslauncher/icon_pack_controller.dart';
import 'package:hanneslauncher/icon_theme_controller.dart';
import 'package:hanneslauncher/launcher_entry.dart';
import 'package:installed_apps/app_category.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/platform_type.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The rule the whole icon setting hangs on: a picture picked for one app by
/// hand is that app's answer and nothing global overrules it, while every app
/// without one follows the chosen style - and goes back to following it the
/// moment the picked picture is removed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  late File picked;
  late File fromPack;

  const mail = AppInfo(
    name: 'Mail',
    icon: null,
    packageName: 'com.example.mail',
    versionName: '1.0.0',
    versionCode: 1,
    platformType: PlatformType.nativeOrOthers,
    installedTimestamp: 0,
    isSystemApp: false,
    isLaunchableApp: true,
    category: AppCategory.undefined,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    temp = await Directory.systemTemp.createTemp('icon_style_test');
    // Both readers check the file is really there before using it, so these
    // have to exist on disk - the bytes are never decoded in a test.
    picked = File('${temp.path}/picked.png')..writeAsBytesSync(const [1]);
    fromPack = File('${temp.path}/pack.png')..writeAsBytesSync(const [2]);
    IconPacksController.instance.debugSetIcons({mail.packageName: fromPack.path});
    await AppOverridesController.instance.restoreNames({});
  });

  tearDown(() async {
    await AppOverridesController.instance.clearAllIcons();
    IconPacksController.instance.debugSetIcons({});
    temp.deleteSync(recursive: true);
  });

  /// The file path [AppIcon] ended up drawing, or null when it drew the app's
  /// own icon instead of a picture.
  String? drawnPath(WidgetTester tester) {
    final images = tester.widgetList<Image>(find.byType(Image));
    for (final image in images) {
      final provider = image.image;
      if (provider is FileImage) return provider.file.path;
    }
    return null;
  }

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppIcon(entry: const LauncherEntry.app(mail), size: 48),
      ),
    );
  }

  testWidgets('an icon pack leaves a picture picked by hand alone', (
    tester,
  ) async {
    await AppOverridesController.instance.debugSetIconPath(
      mail.packageName,
      picked.path,
    );
    await IconThemeController.instance.update(
      const IconThemeSettings(
        style: IconStyle.pack,
        packPackage: 'com.example.pack',
      ),
    );

    await pump(tester);
    expect(drawnPath(tester), picked.path);
  });

  testWidgets('removing the picked picture hands the app to the pack', (
    tester,
  ) async {
    await AppOverridesController.instance.debugSetIconPath(
      mail.packageName,
      picked.path,
    );
    await IconThemeController.instance.update(
      const IconThemeSettings(
        style: IconStyle.pack,
        packPackage: 'com.example.pack',
      ),
    );
    // Deleting the picked file is real disk work, which never finishes inside
    // the fake clock a widget test runs on - runAsync is what lets it.
    await tester.runAsync(
      () => AppOverridesController.instance.clearIcon(mail.packageName),
    );

    await pump(tester);
    expect(drawnPath(tester), fromPack.path);
  });

  testWidgets('an app the pack has nothing for keeps its own icon', (
    tester,
  ) async {
    IconPacksController.instance.debugSetIcons({});
    await IconThemeController.instance.update(
      const IconThemeSettings(
        style: IconStyle.pack,
        packPackage: 'com.example.pack',
      ),
    );

    await pump(tester);
    expect(drawnPath(tester), isNull);
  });

  testWidgets('the color leaves a picture picked by hand alone too', (
    tester,
  ) async {
    await AppOverridesController.instance.debugSetIconPath(
      mail.packageName,
      picked.path,
    );
    await IconThemeController.instance.update(
      const IconThemeSettings(style: IconStyle.color, colorIndex: 2),
    );

    await pump(tester);
    expect(drawnPath(tester), picked.path);
    // Tinting is what the color style does to everything else; a picked
    // picture must reach the screen untouched.
    expect(find.byType(ColorFiltered), findsNothing);
  });

  test('a launcher updated from the on/off switch keeps its color', () async {
    SharedPreferences.setMockInitialValues({
      'icon_theme_enabled': true,
      'icon_theme_color': 5,
    });

    await IconThemeController.instance.load();

    expect(IconThemeController.instance.value.style, IconStyle.color);
    expect(IconThemeController.instance.value.colorIndex, 5);
  });

  test('the switch having been off means the icons are left alone', () async {
    SharedPreferences.setMockInitialValues({'icon_theme_enabled': false});

    await IconThemeController.instance.load();

    expect(IconThemeController.instance.value.style, IconStyle.system);
  });

  test('clearing all pictures keeps the renames', () async {
    await AppOverridesController.instance.setName(mail.packageName, 'Post');
    await AppOverridesController.instance.debugSetIconPath(
      mail.packageName,
      picked.path,
    );

    await AppOverridesController.instance.clearAllIcons();

    expect(AppOverridesController.instance.pickedIconCount, 0);
    expect(
      AppOverridesController.instance.nameFor(mail.packageName, 'Mail'),
      'Post',
    );
  });
}
