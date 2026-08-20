import 'dart:convert';

import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:hanneslauncher/app_list_settings_controller.dart';
import 'package:hanneslauncher/app_overrides_controller.dart';
import 'package:hanneslauncher/clock_settings_controller.dart';
import 'package:hanneslauncher/custom_colors_controller.dart';
import 'package:hanneslauncher/data_sources_controller.dart';
import 'package:hanneslauncher/folders_controller.dart';
import 'package:hanneslauncher/icon_theme_controller.dart';
import 'package:hanneslauncher/launcher_entries_controller.dart';
import 'package:hanneslauncher/locale_controller.dart';
import 'package:hanneslauncher/panel_blocks_controller.dart';
import 'package:hanneslauncher/pinned_apps_controller.dart';
import 'package:hanneslauncher/settings_backup_service.dart';
import 'package:hanneslauncher/web_apps_controller.dart';
import 'package:installed_apps/app_category.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/platform_type.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('export then apply restores everything it covers', () async {
    // Set up a distinctive value on every controller the backup touches.
    await LocaleController.instance.update(AppLanguage.en);
    await ClockSettingsController.instance.update(
      const ClockSettings(
        enabled: false,
        style: ClockStyle.bars,
        alignment: ClockAlignment.right,
        topPadding: 40,
        sidePadding: 12,
        barsFilledColorIndex: 4,
      ),
    );
    await AppListSettingsController.instance.update(
      const AppListSettings(
        colorIndex: 5,
        fontSize: 20,
        rowHeight: 80,
        layoutMode: AppListLayoutMode.columns,
        hand: AppListHand.left,
        hideAlphabet: true,
      ),
    );
    await IconThemeController.instance.update(
      const IconThemeSettings(enabled: true, colorIndex: 2),
    );
    await PanelBlocksController.instance.replaceAll([
      const PanelBlock(
        id: 'b1',
        type: PanelBlockType.appRow,
        itemKeys: ['com.example.mail'],
        columns: 5,
      ),
    ]);
    await FoldersController.instance.replaceAll([
      const LauncherFolder(id: 'f1', name: 'Spiele', colorIndex: 2),
    ]);
    await WebAppsController.instance.replaceAll([
      const WebApp(
        id: 'w1',
        name: 'Example',
        url: 'https://example.com',
        browserPackage: 'org.mozilla.firefox',
      ),
    ]);
    await AppOverridesController.instance.restoreNames({
      'com.example.mail': 'Post',
    });
    await DataSourcesController.instance.replaceAll([
      const DataSource(
        id: 'd1',
        key: 'wetter',
        name: 'Wetter',
        url: 'https://example.com/weather',
        refreshMinutes: 15,
      ),
    ]);
    await PinnedAppsController.instance.restore(['com.example.mail']);
    await PinnedAppsLayoutController.instance.setLeftMargin(42);
    await CustomColorsController.instance.restore([
      const Color(0xFF123456),
    ]);
    // Restoring pinned apps only keeps ones that resolve on this device (an
    // uninstalled app's pin is dropped rather than occupying a slot
    // forever) - there is no platform channel in a test to answer with the
    // real installed apps, so this fakes "com.example.mail" being one of
    // them.
    LauncherEntriesController.instance.debugSetInstalledApps([
      const AppInfo(
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
      ),
    ]);

    final exported = SettingsBackupService.exportJson();

    // Now blow everything away, as if this were a fresh install.
    await LocaleController.instance.update(AppLanguage.de);
    await ClockSettingsController.instance.update(const ClockSettings());
    await AppListSettingsController.instance.update(const AppListSettings());
    await IconThemeController.instance.update(const IconThemeSettings());
    await PanelBlocksController.instance.replaceAll([]);
    await FoldersController.instance.replaceAll([]);
    await WebAppsController.instance.replaceAll([]);
    await AppOverridesController.instance.restoreNames({});
    await DataSourcesController.instance.replaceAll([]);
    await PinnedAppsController.instance.restore([]);
    await PinnedAppsLayoutController.instance.setLeftMargin(16);
    await CustomColorsController.instance.restore([]);

    await SettingsBackupService.apply(exported);

    expect(LocaleController.instance.value, AppLanguage.en);

    final clock = ClockSettingsController.instance.value;
    expect(clock.enabled, false);
    expect(clock.style, ClockStyle.bars);
    expect(clock.alignment, ClockAlignment.right);
    expect(clock.topPadding, 40);
    expect(clock.sidePadding, 12);
    expect(clock.barsFilledColorIndex, 4);

    final appList = AppListSettingsController.instance.value;
    expect(appList.colorIndex, 5);
    expect(appList.fontSize, 20);
    expect(appList.rowHeight, 80);
    expect(appList.layoutMode, AppListLayoutMode.columns);
    expect(appList.hand, AppListHand.left);
    expect(appList.hideAlphabet, isTrue);

    final iconTheme = IconThemeController.instance.value;
    expect(iconTheme.enabled, true);
    expect(iconTheme.colorIndex, 2);

    expect(PanelBlocksController.instance.value.single.id, 'b1');
    expect(
      PanelBlocksController.instance.value.single.itemKeys,
      ['com.example.mail'],
    );

    expect(FoldersController.instance.value.single.name, 'Spiele');
    expect(WebAppsController.instance.value.single.url, 'https://example.com');
    expect(
      WebAppsController.instance.value.single.browserPackage,
      'org.mozilla.firefox',
    );
    expect(
      AppOverridesController.instance.value['com.example.mail']?.name,
      'Post',
    );
    expect(DataSourcesController.instance.value.single.key, 'wetter');
    expect(PinnedAppsController.instance.value, ['com.example.mail']);
    expect(PinnedAppsLayoutController.instance.value, 42);
    expect(
      CustomColorsController.instance.value,
      [const Color(0xFF123456)],
    );
  });

  test(
    'apply drops pinned apps that do not exist on this device',
    () async {
      // Only "com.example.mail" is "installed" here - a backup made on
      // another phone naming a second app this one never had.
      LauncherEntriesController.instance.debugSetInstalledApps([
        const AppInfo(
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
        ),
      ]);
      await PinnedAppsController.instance.restore([]);

      await SettingsBackupService.apply(
        jsonEncode({
          'formatVersion': 1,
          'pinnedApps': ['com.example.mail', 'com.other.app'],
        }),
      );

      expect(PinnedAppsController.instance.value, ['com.example.mail']);
    },
  );

  test('apply rejects anything that is not a backup file', () async {
    expect(
      () => SettingsBackupService.apply('{"not":"a backup"}'),
      throwsFormatException,
    );
    expect(
      () => SettingsBackupService.apply('not even json'),
      throwsFormatException,
    );
  });
}
