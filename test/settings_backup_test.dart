import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:hanneslouncher/app_list_settings_controller.dart';
import 'package:hanneslouncher/app_overrides_controller.dart';
import 'package:hanneslouncher/clock_settings_controller.dart';
import 'package:hanneslouncher/custom_colors_controller.dart';
import 'package:hanneslouncher/data_sources_controller.dart';
import 'package:hanneslouncher/folders_controller.dart';
import 'package:hanneslouncher/icon_theme_controller.dart';
import 'package:hanneslouncher/locale_controller.dart';
import 'package:hanneslouncher/panel_blocks_controller.dart';
import 'package:hanneslouncher/pinned_apps_controller.dart';
import 'package:hanneslouncher/settings_backup_service.dart';
import 'package:hanneslouncher/web_apps_controller.dart';
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
      const AppListSettings(colorIndex: 5, fontSize: 20, rowHeight: 80),
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
      const WebApp(id: 'w1', name: 'Example', url: 'https://example.com'),
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
