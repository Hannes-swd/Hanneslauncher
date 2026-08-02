import 'dart:convert';

import 'package:flutter/material.dart' show Color;

import 'app_list_settings_controller.dart';
import 'app_overrides_controller.dart';
import 'clock_settings_controller.dart';
import 'custom_colors_controller.dart';
import 'data_packages_controller.dart';
import 'data_sources_controller.dart';
import 'folders_controller.dart';
import 'icon_theme_controller.dart';
import 'launcher_entries_controller.dart';
import 'locale_controller.dart';
import 'panel_blocks_controller.dart';
import 'pinned_apps_controller.dart';
import 'web_apps_controller.dart';

/// Everything the user has configured, as one JSON document: colors,
/// positions, the panel's widgets and calendar/app blocks, pinned apps,
/// folders, web apps, data sources, app renames, clock style and language.
///
/// Custom pictures (the wallpaper, replaced app icons, web app icons) are
/// left out on purpose - their files live in this install's own private
/// storage, so a path to one would point nowhere once carried into a
/// different install, and everything that reads them already falls back
/// cleanly when the file is missing.
class SettingsBackupService {
  static const _formatVersion = 1;

  static Map<String, dynamic> build() {
    final clock = ClockSettingsController.instance.value;
    final appList = AppListSettingsController.instance.value;
    final iconTheme = IconThemeController.instance.value;

    return {
      'formatVersion': _formatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'locale': LocaleController.instance.value.name,
      'clock': {
        'enabled': clock.enabled,
        'style': clock.style.name,
        'wordBgColorIndex': clock.wordBgColorIndex,
        'wordBgOpacity': clock.wordBgOpacity,
        'wordActiveColorIndex': clock.wordActiveColorIndex,
        'wordInactiveColorIndex': clock.wordInactiveColorIndex,
        'digitalColorIndex': clock.digitalColorIndex,
        'romanColorIndex': clock.romanColorIndex,
        'dotColorIndex': clock.dotColorIndex,
        'splitFlapBgColorIndex': clock.splitFlapBgColorIndex,
        'splitFlapBgOpacity': clock.splitFlapBgOpacity,
        'splitFlapTextColorIndex': clock.splitFlapTextColorIndex,
        'orbitColorIndex': clock.orbitColorIndex,
        'verticalColorIndex': clock.verticalColorIndex,
        'barsFilledColorIndex': clock.barsFilledColorIndex,
        'barsUnfilledColorIndex': clock.barsUnfilledColorIndex,
        'barsUnfilledOpacity': clock.barsUnfilledOpacity,
        'barsTextColorIndex': clock.barsTextColorIndex,
        'alignment': clock.alignment.name,
        'topPadding': clock.topPadding,
        'sidePadding': clock.sidePadding,
      },
      'appList': {
        'colorIndex': appList.colorIndex,
        'fontFamily': appList.fontFamily,
        'fontSize': appList.fontSize,
        'rowHeight': appList.rowHeight,
        'sortMode': appList.sortMode.name,
      },
      'iconTheme': {
        'enabled': iconTheme.enabled,
        'colorIndex': iconTheme.colorIndex,
      },
      'pinnedApps': PinnedAppsController.instance.value,
      'pinnedAppsLeftMargin': PinnedAppsLayoutController.instance.value,
      'panelBlocks': [
        for (final block in PanelBlocksController.instance.value)
          block.toJson(),
      ],
      'folders': [
        for (final folder in FoldersController.instance.value)
          folder.toJson(),
      ],
      'webApps': [
        for (final app in WebAppsController.instance.value)
          {'id': app.id, 'name': app.name, 'url': app.url},
      ],
      'appOverrides': {
        for (final entry in AppOverridesController.instance.value.entries)
          if (entry.value.name != null) entry.key: entry.value.name,
      },
      'dataSources': [
        for (final source in DataSourcesController.instance.value)
          source.toJson(),
      ],
      // Colors are stored everywhere as an index into the base palette plus
      // these - restoring them first is what keeps a `colorIndex` above 6
      // pointing at the right color instead of throwing or landing on
      // whatever now happens to sit at that index.
      'customColors': [
        for (final color in CustomColorsController.instance.value)
          color.toARGB32(),
      ],
      'deviceDataEnabled': DeviceDataController.instance.value,
    };
  }

  static String exportJson() =>
      const JsonEncoder.withIndent('  ').convert(build());

  /// Applies a previously exported document. Throws a [FormatException]
  /// (safe to show the user directly) if [jsonText] isn't one of ours -
  /// nothing is changed in that case.
  static Future<void> apply(String jsonText) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(jsonText);
    } catch (_) {
      throw const FormatException('Not readable JSON');
    }
    if (decoded is! Map<String, dynamic> || decoded['formatVersion'] == null) {
      throw const FormatException('Not a hanneslouncher backup file');
    }

    // First: every `colorIndex` below references this list (appended after
    // the fixed base palette), so it has to be in place before anything
    // that reads one is restored.
    final customColorsJson = decoded['customColors'] as List<dynamic>?;
    if (customColorsJson != null) {
      await CustomColorsController.instance.restore([
        for (final value in customColorsJson) Color(value as int),
      ]);
    }

    final localeName = decoded['locale'] as String?;
    if (localeName != null) {
      await LocaleController.instance.update(
        localeName == 'en' ? AppLanguage.en : AppLanguage.de,
      );
    }

    final clockJson = decoded['clock'] as Map<String, dynamic>?;
    if (clockJson != null) {
      await ClockSettingsController.instance.update(
        ClockSettings(
          enabled: clockJson['enabled'] as bool? ?? true,
          style: _enumOr(
            ClockStyle.values,
            clockJson['style'],
            ClockStyle.digital,
          ),
          wordBgColorIndex: clockJson['wordBgColorIndex'] as int? ?? 0,
          wordBgOpacity:
              (clockJson['wordBgOpacity'] as num?)?.toDouble() ?? 0.6,
          wordActiveColorIndex:
              clockJson['wordActiveColorIndex'] as int? ?? 1,
          wordInactiveColorIndex:
              clockJson['wordInactiveColorIndex'] as int? ?? 0,
          digitalColorIndex: clockJson['digitalColorIndex'] as int? ?? 0,
          romanColorIndex: clockJson['romanColorIndex'] as int? ?? 0,
          dotColorIndex: clockJson['dotColorIndex'] as int? ?? 0,
          splitFlapBgColorIndex:
              clockJson['splitFlapBgColorIndex'] as int? ?? 0,
          splitFlapBgOpacity:
              (clockJson['splitFlapBgOpacity'] as num?)?.toDouble() ?? 0.85,
          splitFlapTextColorIndex:
              clockJson['splitFlapTextColorIndex'] as int? ?? 1,
          orbitColorIndex: clockJson['orbitColorIndex'] as int? ?? 0,
          verticalColorIndex: clockJson['verticalColorIndex'] as int? ?? 0,
          barsFilledColorIndex:
              clockJson['barsFilledColorIndex'] as int? ?? 0,
          barsUnfilledColorIndex:
              clockJson['barsUnfilledColorIndex'] as int? ?? 0,
          barsUnfilledOpacity:
              (clockJson['barsUnfilledOpacity'] as num?)?.toDouble() ?? 0.12,
          barsTextColorIndex: clockJson['barsTextColorIndex'] as int? ?? 0,
          alignment: _enumOr(
            ClockAlignment.values,
            clockJson['alignment'],
            ClockAlignment.center,
          ),
          topPadding: (clockJson['topPadding'] as num?)?.toDouble() ?? 0,
          sidePadding: (clockJson['sidePadding'] as num?)?.toDouble() ?? 16,
        ),
      );
    }

    final appListJson = decoded['appList'] as Map<String, dynamic>?;
    if (appListJson != null) {
      await AppListSettingsController.instance.update(
        AppListSettings(
          colorIndex: appListJson['colorIndex'] as int? ?? 0,
          fontFamily: appListJson['fontFamily'] as String? ?? '',
          fontSize: (appListJson['fontSize'] as num?)?.toDouble() ?? 16,
          rowHeight: (appListJson['rowHeight'] as num?)?.toDouble() ?? 72,
          sortMode: _enumOr(
            AppListSortMode.values,
            appListJson['sortMode'],
            AppListSortMode.alphabetical,
          ),
        ),
      );
    }

    final iconThemeJson = decoded['iconTheme'] as Map<String, dynamic>?;
    if (iconThemeJson != null) {
      await IconThemeController.instance.update(
        IconThemeSettings(
          enabled: iconThemeJson['enabled'] as bool? ?? false,
          colorIndex: iconThemeJson['colorIndex'] as int? ?? 3,
        ),
      );
    }

    final panelBlocksJson = decoded['panelBlocks'] as List<dynamic>?;
    if (panelBlocksJson != null) {
      final blocks = <PanelBlock>[];
      for (final entry in panelBlocksJson) {
        try {
          blocks.add(PanelBlock.fromJson(entry as Map<String, dynamic>));
        } catch (_) {
          // Skip just the unreadable one rather than losing the rest.
        }
      }
      await PanelBlocksController.instance.replaceAll(blocks);
    }

    final foldersJson = decoded['folders'] as List<dynamic>?;
    if (foldersJson != null) {
      final folders = <LauncherFolder>[];
      for (final entry in foldersJson) {
        try {
          folders.add(LauncherFolder.fromJson(entry as Map<String, dynamic>));
        } catch (_) {
          // Skip just the unreadable one.
        }
      }
      await FoldersController.instance.replaceAll(folders);
    }

    final webAppsJson = decoded['webApps'] as List<dynamic>?;
    if (webAppsJson != null) {
      final apps = <WebApp>[];
      for (final entry in webAppsJson) {
        try {
          final map = entry as Map<String, dynamic>;
          apps.add(
            WebApp(
              id: map['id'] as String,
              name: map['name'] as String,
              url: map['url'] as String,
            ),
          );
        } catch (_) {
          // Skip just the unreadable one.
        }
      }
      await WebAppsController.instance.replaceAll(apps);
    }

    final appOverridesJson = decoded['appOverrides'] as Map<String, dynamic>?;
    if (appOverridesJson != null) {
      await AppOverridesController.instance.restoreNames({
        for (final entry in appOverridesJson.entries)
          entry.key: entry.value as String,
      });
    }

    final dataSourcesJson = decoded['dataSources'] as List<dynamic>?;
    if (dataSourcesJson != null) {
      final sources = <DataSource>[];
      for (final entry in dataSourcesJson) {
        try {
          sources.add(DataSource.fromJson(entry as Map<String, dynamic>));
        } catch (_) {
          // Skip just the unreadable one.
        }
      }
      await DataSourcesController.instance.replaceAll(sources);
    }

    final deviceDataEnabled = decoded['deviceDataEnabled'] as bool?;
    if (deviceDataEnabled != null) {
      await DeviceDataController.instance.setEnabled(deviceDataEnabled);
    }

    // Pinned apps last: web apps/folders it points at must already exist
    // again by the time this resolves them.
    final pinnedAppsJson = decoded['pinnedApps'] as List<dynamic>?;
    if (pinnedAppsJson != null) {
      // A backup made on another phone can name apps this one never had -
      // keeping those would occupy pinned slots forever with something that
      // can never be shown, blocking real apps from being pinned in their
      // place. installedApps only gets read once on demand, so a restore
      // straight after a fresh install (before the app drawer was ever
      // opened) would otherwise see none of them and drop everything.
      if (!LauncherEntriesController.instance.isLoaded) {
        await LauncherEntriesController.instance.load();
      }
      await PinnedAppsController.instance.restore([
        for (final key in pinnedAppsJson)
          if (LauncherEntriesController.instance.byKey(key as String) != null)
            key,
      ]);
    }

    final leftMargin = decoded['pinnedAppsLeftMargin'] as num?;
    if (leftMargin != null) {
      await PinnedAppsLayoutController.instance.setLeftMargin(
        leftMargin.toDouble(),
      );
    }
  }

  static T _enumOr<T extends Enum>(List<T> values, Object? name, T fallback) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }
}
