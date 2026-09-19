import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' show Color;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_list_settings_controller.dart';
import 'app_overrides_controller.dart';
import 'app_pairs_controller.dart';
import 'clock_settings_controller.dart';
import 'code_widget_store.dart';
import 'color_swatch_picker.dart' show autoColorIndex;
import 'custom_colors_controller.dart';
import 'data_packages_controller.dart';
import 'data_sources_controller.dart';
import 'design_controller.dart';
import 'design_tokens.dart';
import 'folders_controller.dart';
import 'gesture_shortcuts_controller.dart';
import 'icon_theme_controller.dart';
import 'launcher_entries_controller.dart';
import 'locale_controller.dart';
import 'lock_wallpaper_controller.dart';
import 'notification_badges_controller.dart';
import 'offline_mode_controller.dart';
import 'panel_blocks_controller.dart';
import 'pinned_apps_controller.dart';
import 'secret_apps_controller.dart';
import 'saved_shortcuts_controller.dart';
import 'wallpaper_controller.dart';
import 'web_apps_controller.dart';

/// Everything the user has configured, as one JSON document: colors,
/// positions, the panel's widgets and calendar/app blocks, pinned apps,
/// folders, web apps, saved app shortcuts, data sources, app renames, the
/// secret folder, clock and offline mode style, the design, and language.
///
/// The code widgets are the one part that isn't held by a block: their
/// files are written alongside the document by [buildWithFiles].
///
/// Custom pictures - the home screen wallpaper, the lock screen one,
/// replaced app icons, web app icons - travel as the pictures themselves,
/// base64 in the 'pictures' section, not as paths. A path would point into this install's private storage and
/// therefore at nothing after a reinstall, which is how a restored launcher
/// used to come back correct in every respect except that it looked wrong.
///
/// They are also the only part with a size limit. A wallpaper can be a
/// video, and a backup nobody can send anywhere because it is 300 MB is one
/// that stops being made; anything over [maxPictureBytes] is named in the
/// document without its contents, so a restore can at least say what is
/// missing rather than silently dropping it.
class SettingsBackupService {
  // 2 adds the 'pictures' section. Nothing else changed shape, so a
  // version-1 document still restores completely - it simply has no
  // pictures in it, which is what those installs had.
  static const _formatVersion = 2;

  /// Per picture, not for the document as a whole: 8 MB covers any still
  /// wallpaper at any screen size this runs on, and every icon many times
  /// over, while leaving a video out - which is the one case where the file
  /// is large enough to matter and easy enough to set again.
  static const maxPictureBytes = 8 * 1024 * 1024;

  static Map<String, dynamic> build() {
    final clock = ClockSettingsController.instance.value;
    final offline = OfflineModeController.instance.value;
    final appList = AppListSettingsController.instance.value;
    final iconTheme = IconThemeController.instance.value;
    final design = DesignController.instance.value;

    return {
      'formatVersion': _formatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      // 'system' rather than the language it currently resolves to, so a
      // backup carried to a phone in another language keeps following it.
      'locale': LocaleController.instance.followsSystem
          ? 'system'
          : LocaleController.instance.value.name,
      'clock': {
        'enabled': clock.enabled,
        'style': clock.style.name,
        'wordBgColorIndex': clock.wordBgColorIndex,
        'wordBgOpacity': clock.wordBgOpacity,
        'wordActiveColorIndex': clock.wordActiveColorIndex,
        'wordInactiveColorIndex': clock.wordInactiveColorIndex,
        'digitalColorIndex': clock.digitalColorIndex,
        'digitalFontFamily': clock.digitalFontFamily,
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
      'offlineMode': {
        'style': offline.style.name,
        'colorIndex': offline.colorIndex,
        'showMedia': offline.showMedia,
        'digitalFontFamily': offline.digitalFontFamily,
        'burnInProtection': offline.burnInProtection,
      },
      'appList': {
        'colorIndex': appList.colorIndex,
        'fontFamily': appList.fontFamily,
        'fontSize': appList.fontSize,
        'rowHeight': appList.rowHeight,
        'sortMode': appList.sortMode.name,
        'layoutMode': appList.layoutMode.name,
        'hand': appList.hand.name,
        'hideAlphabet': appList.hideAlphabet,
        'backgroundBlur': appList.backgroundBlur,
        'searchExtras': appList.searchExtras,
        'searchContacts': appList.searchContacts,
        'searchWebUrl': appList.searchWebUrl,
      },
      'iconTheme': {
        'style': iconTheme.style.name,
        'colorIndex': iconTheme.colorIndex,
        // The pack's package name, not the pack itself: a backup restored on
        // a phone without it falls back to the app's own icons, and installing
        // the pack there brings the setting straight back to life.
        'packPackage': iconTheme.packPackage,
      },
      // Raw ARGB rather than an index into the shared palette: these six are
      // the theme's own colors, and putting them in the palette would add six
      // near-greys to every color picker in the app.
      'design': {
        'preset': design.preset.name,
        'fieldStyle': design.fieldStyle.name,
        'colors': {
          for (final entry in design.overrides.entries)
            entry.key.name: entry.value.toARGB32(),
        },
        'radius': design.radius,
        'shadow': design.shadow,
        'spacing': design.spacing,
        'cardSize': design.cardSize,
        'font': design.font,
        'opacity': design.opacity,
        'motion': design.motion,
        'haptics': design.haptics,
      },
      'pinnedApps': PinnedAppsController.instance.value,
      'pinnedAppsLeftMargin': PinnedAppsLayoutController.instance.value,
      'pinnedBadgeStyle': PinnedBadgeController.instance.value.style.name,
      'pinnedBadgeColorIndex': PinnedBadgeController.instance.value.colorIndex,
      // The drawn shortcuts travel as-is: the shape is 64 pairs of numbers
      // and the action names a package, an address or a number of seconds -
      // nothing in there points at a file on this install.
      'gestureShortcuts': [
        for (final shortcut in GestureShortcutsController.instance.value)
          shortcut.toJson(),
      ],
      'gestureDrawing': {
        'enabled': GestureDrawingController.instance.value.enabled,
        'showTrail': GestureDrawingController.instance.value.showTrail,
        'colorIndex': GestureDrawingController.instance.value.colorIndex,
      },
      'panelBlocks': [
        for (final block in PanelBlocksController.instance.value)
          block.toJson(),
      ],
      'folders': [
        for (final folder in FoldersController.instance.value) folder.toJson(),
      ],
      'webApps': [
        for (final app in WebAppsController.instance.value)
          {
            'id': app.id,
            'name': app.name,
            'url': app.url,
            if (app.browserPackage != null)
              'browserPackage': app.browserPackage,
          },
      ],
      // Without the picture: Android renders a shortcut's icon into this
      // install's own cache, so the path would point nowhere after a
      // restore. The refresh on the next load fetches it again from the app
      // that published the shortcut, which is where it came from anyway.
      // Two package names and a name of your own - nothing in there points
      // at a file or at this install.
      'appPairs': [
        for (final pair in AppPairsController.instance.value) pair.toJson(),
      ],
      'savedShortcuts': [
        for (final shortcut in SavedShortcutsController.instance.value)
          {
            'id': shortcut.id,
            'package': shortcut.package,
            'shortcutId': shortcut.shortcutId,
            'name': shortcut.name,
          },
      ],
      'appOverrides': {
        for (final entry in AppOverridesController.instance.value.entries)
          if (entry.value.name != null) entry.key: entry.value.name,
      },
      // The secret folder, password and recovery code included - without
      // those hashes a restored list could never be opened again. A backup
      // file is plain text, so it does show which apps are in there; the
      // alternative (leaving them out) would silently un-hide them on the next
      // restore, which is worse. The hashes themselves give nothing away.
      'secretApps': SecretAppsController.instance.value.toList(),
      if (SecretAppsController.instance.passwordHash != null)
        'secretPasswordHash': SecretAppsController.instance.passwordHash,
      if (SecretAppsController.instance.passwordSalt != null)
        'secretPasswordSalt': SecretAppsController.instance.passwordSalt,
      if (SecretAppsController.instance.recoveryHash != null)
        'secretRecoveryHash': SecretAppsController.instance.recoveryHash,
      if (SecretAppsController.instance.recoverySalt != null)
        'secretRecoverySalt': SecretAppsController.instance.recoverySalt,
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

  /// [build] plus the code widgets' own files, which is what the export
  /// actually writes.
  ///
  /// They need their own pass because they are the one thing a block does
  /// not carry: a code widget's HTML, CSS and JavaScript live in a folder on
  /// the device, so a backup built from the blocks alone would restore a row
  /// of empty cards. Uploaded pictures come along too, up to
  /// [CodeWidgetStore.maxBackedUpFileBytes] each - past that the file would
  /// do more harm to the backup's size than good.
  static Future<Map<String, dynamic>> buildWithFiles() async {
    // Before anything is read out of it: [build] takes the secret folder's
    // list straight off the controller, and an automatic backup is written
    // when the panel is first pulled down - which can be before that list
    // has been read off disk. An empty list written into the file would not
    // look like a fault, it would look like an empty secret folder, and
    // restoring it would un-hide every app in there.
    await SecretAppsController.instance.loadedKeys();
    final document = build();
    final widgets = <String, dynamic>{};
    for (final block in PanelBlocksController.instance.value) {
      if (block.type != PanelBlockType.code) continue;
      widgets[block.id] = await CodeWidgetStore.instance.exportBlock(block.id);
    }
    if (widgets.isNotEmpty) document['codeWidgets'] = widgets;
    final pictures = await _buildPictures();
    if (pictures.isNotEmpty) document['pictures'] = pictures;
    return document;
  }

  /// Every picture the user chose, as bytes.
  ///
  /// Four kinds, each keyed by what it belongs to so a restore can put it
  /// back without the old path meaning anything: the home screen wallpaper,
  /// the lock screen one, one icon per app package, one icon per web app id.
  ///
  /// A picture that came out of the app's own library carries the asset it
  /// came from next to its bytes. Only so the picker can tick the right tile
  /// again after a restore - the bytes are what is put back either way, so a
  /// backup from a build whose library has since changed still restores the
  /// picture the user was actually looking at.
  static Future<Map<String, dynamic>> _buildPictures() async {
    final pictures = <String, dynamic>{};

    final wallpaper = WallpaperController.instance.value;
    if (wallpaper != null) {
      final entry = await _encodePicture(wallpaper.file);
      if (entry != null) {
        if (wallpaper.assetKey != null) entry['asset'] = wallpaper.assetKey;
        pictures['wallpaper'] = entry;
      }
    }

    final lock = LockWallpaperController.instance.value;
    if (lock != null) {
      final entry = await _encodePicture(lock);
      if (entry != null) {
        final asset = LockWallpaperController.instance.assetKey;
        if (asset != null) entry['asset'] = asset;
        pictures['lockWallpaper'] = entry;
      }
    }

    final appIcons = <String, dynamic>{};
    for (final entry in AppOverridesController.instance.value.entries) {
      final path = entry.value.iconPath;
      if (path == null) continue;
      final encoded = await _encodePicture(File(path));
      if (encoded != null) appIcons[entry.key] = encoded;
    }
    if (appIcons.isNotEmpty) pictures['appIcons'] = appIcons;

    final webIcons = <String, dynamic>{};
    for (final app in WebAppsController.instance.value) {
      final path = app.iconPath;
      if (path == null) continue;
      final encoded = await _encodePicture(File(path));
      if (encoded != null) webIcons[app.id] = encoded;
    }
    if (webIcons.isNotEmpty) pictures['webAppIcons'] = webIcons;

    return pictures;
  }

  /// One picture as `{extension, bytes}`, or `{extension, tooLarge}` when it
  /// is past [maxPictureBytes].
  ///
  /// The extension travels because it is what decides how the picture is
  /// drawn again - `wallpaper_controller.dart` reads the kind (still, GIF,
  /// video) off it and nothing else.
  static Future<Map<String, dynamic>?> _encodePicture(File file) async {
    try {
      if (!file.existsSync()) return null;
      final extension = p.extension(file.path);
      final length = await file.length();
      if (length > maxPictureBytes) {
        return {'extension': extension, 'tooLarge': length};
      }
      return {
        'extension': extension,
        'bytes': base64Encode(await file.readAsBytes()),
      };
    } catch (_) {
      // One unreadable picture shouldn't cost the rest of the backup.
      return null;
    }
  }

  /// What a restore could not bring back because it was too big to carry.
  /// Named so the screen can say which, instead of the user finding out by
  /// looking at their home screen.
  static List<String> oversizedPicturesIn(String jsonText) {
    try {
      final decoded = jsonDecode(jsonText);
      if (decoded is! Map<String, dynamic>) return const [];
      final pictures = decoded['pictures'];
      if (pictures is! Map<String, dynamic>) return const [];
      final names = <String>[];
      for (final single in const ['wallpaper', 'lockWallpaper']) {
        final picture = pictures[single];
        if (picture is Map && picture.containsKey('tooLarge')) {
          names.add(single);
        }
      }
      for (final group in const ['appIcons', 'webAppIcons']) {
        final entries = pictures[group];
        if (entries is! Map<String, dynamic>) continue;
        for (final entry in entries.entries) {
          final value = entry.value;
          if (value is Map && value.containsKey('tooLarge')) {
            names.add(entry.key);
          }
        }
      }
      return names;
    } catch (_) {
      return const [];
    }
  }

  static Future<String> exportJsonWithFiles() async =>
      const JsonEncoder.withIndent('  ').convert(await buildWithFiles());

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
      throw const FormatException('Not a hanneslauncher backup file');
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
    if (localeName == 'de' || localeName == 'en') {
      await LocaleController.instance.update(
        localeName == 'en' ? AppLanguage.en : AppLanguage.de,
      );
    } else if (localeName != null) {
      await LocaleController.instance.useSystem();
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
          wordActiveColorIndex: clockJson['wordActiveColorIndex'] as int? ?? 1,
          wordInactiveColorIndex:
              clockJson['wordInactiveColorIndex'] as int? ?? 0,
          digitalColorIndex: clockJson['digitalColorIndex'] as int? ?? 0,
          digitalFontFamily: clockJson['digitalFontFamily'] as String? ?? '',
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
          barsFilledColorIndex: clockJson['barsFilledColorIndex'] as int? ?? 0,
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

    final offlineJson = decoded['offlineMode'] as Map<String, dynamic>?;
    if (offlineJson != null) {
      await OfflineModeController.instance.update(
        OfflineModeSettings(
          style: _enumOr(
            ClockStyle.values,
            offlineJson['style'],
            ClockStyle.digital,
          ),
          colorIndex: offlineJson['colorIndex'] as int? ?? 1,
          showMedia: offlineJson['showMedia'] as bool? ?? false,
          digitalFontFamily: offlineJson['digitalFontFamily'] as String? ?? '',
          burnInProtection: offlineJson['burnInProtection'] as bool? ?? true,
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
          layoutMode: _enumOr(
            AppListLayoutMode.values,
            appListJson['layoutMode'],
            AppListLayoutMode.singleColumn,
          ),
          hand: _enumOr(
            AppListHand.values,
            appListJson['hand'],
            AppListHand.right,
          ),
          hideAlphabet: appListJson['hideAlphabet'] as bool? ?? false,
          backgroundBlur:
              (appListJson['backgroundBlur'] as num?)?.toDouble() ?? 14,
          searchExtras: appListJson['searchExtras'] as bool? ?? true,
          searchContacts: appListJson['searchContacts'] as bool? ?? false,
          searchWebUrl: appListJson['searchWebUrl'] as String? ?? '',
        ),
      );
    }

    final designJson = decoded['design'] as Map<String, dynamic>?;
    if (designJson != null) {
      final colorsJson = designJson['colors'] as Map<String, dynamic>?;
      // Every number below is clamped by DesignSettings itself, so a file
      // naming a radius of 400 restores as the largest one the sliders can
      // reach rather than as a screen full of circles.
      await DesignController.instance.update(
        DesignSettings(
          preset: _enumOr(
            DesignThemePreset.values,
            designJson['preset'],
            DesignThemePreset.grey,
          ),
          fieldStyle: _enumOr(
            InputFieldStyle.values,
            designJson['fieldStyle'],
            InputFieldStyle.line,
          ),
          overrides: {
            for (final role in DesignColorRole.values)
              if (colorsJson?[role.name] is int)
                role: Color(colorsJson![role.name] as int),
          },
          radius: (designJson['radius'] as num?)?.toDouble(),
          shadow: (designJson['shadow'] as num?)?.toDouble(),
          spacing: (designJson['spacing'] as num?)?.toDouble(),
          cardSize: (designJson['cardSize'] as num?)?.toDouble(),
          font: (designJson['font'] as num?)?.toDouble(),
          opacity: (designJson['opacity'] as num?)?.toDouble(),
          motion: (designJson['motion'] as num?)?.toDouble(),
          haptics: (designJson['haptics'] as num?)?.toDouble(),
        ),
      );
    }

    final iconThemeJson = decoded['iconTheme'] as Map<String, dynamic>?;
    if (iconThemeJson != null) {
      await IconThemeController.instance.update(
        IconThemeSettings(
          // 'enabled' is what a backup written before there were three
          // styles carries, and it only ever meant the color.
          style: iconThemeJson.containsKey('style')
              ? IconThemeController.styleFromName(iconThemeJson['style'])
              : ((iconThemeJson['enabled'] as bool? ?? false)
                    ? IconStyle.color
                    : IconStyle.system),
          colorIndex: iconThemeJson['colorIndex'] as int? ?? 3,
          packPackage: iconThemeJson['packPackage'] as String?,
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

    // After the blocks: these write into the folders the restored code
    // blocks name, so the blocks have to exist first.
    final codeWidgetsJson = decoded['codeWidgets'] as Map<String, dynamic>?;
    if (codeWidgetsJson != null) {
      for (final entry in codeWidgetsJson.entries) {
        final files = entry.value;
        if (files is! Map<String, dynamic>) continue;
        try {
          await CodeWidgetStore.instance.importBlock(entry.key, files);
        } catch (_) {
          // One widget that won't write shouldn't cost the rest of the
          // restore - the block is there either way, just empty.
        }
      }
    }

    final gestureShortcutsJson =
        decoded['gestureShortcuts'] as List<dynamic>?;
    if (gestureShortcutsJson != null) {
      final shortcuts = <GestureShortcut>[];
      for (final entry in gestureShortcutsJson) {
        final shortcut = GestureShortcut.fromJson(entry);
        // Skip just the unreadable one - a shape that won't parse costs that
        // shortcut, not the rest of them.
        if (shortcut != null) shortcuts.add(shortcut);
      }
      await GestureShortcutsController.instance.replaceAll(shortcuts);
    }

    final gestureDrawingJson = decoded['gestureDrawing'] as Map<String, dynamic>?;
    if (gestureDrawingJson != null) {
      await GestureDrawingController.instance.update(
        GestureDrawingSettings(
          enabled: gestureDrawingJson['enabled'] as bool? ?? true,
          showTrail: gestureDrawingJson['showTrail'] as bool? ?? true,
          // Restored after the custom colours above, like every other
          // colorIndex in this file, so an index into the hand-picked part
          // of the palette lands on the colour it was exported as.
          colorIndex:
              (gestureDrawingJson['colorIndex'] as num?)?.round() ??
              autoColorIndex,
        ),
      );
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
              // Kept even though the browser may not be installed on the
              // phone this is restored onto: launching falls back to the
              // default there, and carrying it back is then still correct.
              browserPackage: map['browserPackage'] as String?,
            ),
          );
        } catch (_) {
          // Skip just the unreadable one.
        }
      }
      await WebAppsController.instance.replaceAll(apps);
    }

    // Same reason as the web apps above: a pin naming a pair is only kept
    // if the pair it names is back by the time the pins are pruned.
    final appPairsJson = decoded['appPairs'] as List<dynamic>?;
    if (appPairsJson != null) {
      await AppPairsController.instance.replaceAll([
        for (final entry in appPairsJson) ?AppPair.fromJson(entry),
      ]);
    }

    // Before the pinned apps below, like the web apps and folders above: a
    // pin pointing at a shortcut is only kept if the shortcut it names
    // already exists again by then.
    final shortcutsJson = decoded['savedShortcuts'] as List<dynamic>?;
    if (shortcutsJson != null) {
      final shortcuts = <SavedShortcut>[];
      for (final entry in shortcutsJson) {
        try {
          final map = entry as Map<String, dynamic>;
          shortcuts.add(
            SavedShortcut(
              id: map['id'] as String,
              package: map['package'] as String,
              shortcutId: map['shortcutId'] as String,
              name: map['name'] as String,
            ),
          );
        } catch (_) {
          // Skip just the unreadable one.
        }
      }
      await SavedShortcutsController.instance.replaceAll(shortcuts);
    }

    final appOverridesJson = decoded['appOverrides'] as Map<String, dynamic>?;
    if (appOverridesJson != null) {
      await AppOverridesController.instance.restoreNames({
        for (final entry in appOverridesJson.entries)
          entry.key: entry.value as String,
      });
    }

    // After the names, the web apps and the folders, because each picture is
    // put back onto something those restored - and before the pinned apps,
    // which are pruned against entries that by then have to be complete.
    await _applyPictures(decoded['pictures']);

    // Before the pinned apps below: those are pruned against the entry list,
    // which a restored secret app is not part of - so a key that is in both
    // lists loses its pin, exactly as it would when hiding the app by hand.
    final secretAppsJson = decoded['secretApps'] as List<dynamic>?;
    if (secretAppsJson != null) {
      await SecretAppsController.instance.restore(
        keys: [for (final key in secretAppsJson) key as String],
        hash: decoded['secretPasswordHash'] as String?,
        salt: decoded['secretPasswordSalt'] as String?,
        recoveryHash: decoded['secretRecoveryHash'] as String?,
        recoverySalt: decoded['secretRecoverySalt'] as String?,
      );
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
      // place. The installed apps only get read once on demand, so a restore
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

    final badgeStyle = decoded['pinnedBadgeStyle'];
    final badgeColor = decoded['pinnedBadgeColorIndex'] as int?;
    if (badgeStyle != null || badgeColor != null) {
      // The notification permission itself doesn't travel with a backup -
      // restoring "show a number" on a phone that hasn't granted it leaves
      // the setting standing and the badges simply empty until it is.
      await PinnedBadgeController.instance.update(
        PinnedBadgeSettings(
          style: PinnedBadgeController.styleFromName(badgeStyle),
          colorIndex: badgeColor ?? PinnedBadgeSettings.defaultColorIndex,
        ),
      );
    }
  }

  /// Writes the pictures out of a backup back into this install's own
  /// storage and points the settings at them.
  ///
  /// Anything missing is simply skipped: a version-1 document has no
  /// pictures at all, a picture too large to carry has no bytes, and an app
  /// or web app that no longer exists here has nothing to put one on. None
  /// of those is a failed restore - everything else in the document is still
  /// correct, and a picture is the one part the user can put back in a tap.
  static Future<void> _applyPictures(Object? pictures) async {
    if (pictures is! Map<String, dynamic>) return;

    final wallpaper = await _decodePicture(pictures['wallpaper'], 'wallpaper');
    if (wallpaper != null) {
      await WallpaperController.instance.restoreFile(
        wallpaper,
        assetKey: _assetOf(pictures['wallpaper']),
      );
    }

    // The one picture here that leaves the app: this hands it to Android as
    // the lock screen. A restore is meant to give back the phone that was
    // backed up, and the lock screen is part of what was set up on it.
    final lock = await _decodePicture(pictures['lockWallpaper'], 'lock');
    if (lock != null) {
      await LockWallpaperController.instance.restoreFile(
        lock,
        assetKey: _assetOf(pictures['lockWallpaper']),
      );
    }

    final appIcons = pictures['appIcons'];
    if (appIcons is Map<String, dynamic>) {
      for (final entry in appIcons.entries) {
        final file = await _decodePicture(entry.value, 'icon_${entry.key}');
        if (file != null) {
          await AppOverridesController.instance.restoreIcon(entry.key, file);
        }
      }
    }

    final webIcons = pictures['webAppIcons'];
    if (webIcons is Map<String, dynamic>) {
      for (final entry in webIcons.entries) {
        final file = await _decodePicture(entry.value, 'web_${entry.key}');
        if (file != null) {
          await WebAppsController.instance.restoreIcon(entry.key, file);
        }
      }
    }
  }

  /// Which library entry a stored picture came from, if any.
  static String? _assetOf(Object? entry) {
    if (entry is! Map) return null;
    final asset = entry['asset'];
    return asset is String ? asset : null;
  }

  /// One picture back onto disk, under a name of this install's choosing.
  ///
  /// The timestamp is not decoration: `Image.file` caches decoded bitmaps by
  /// path, so restoring twice onto the same path would keep showing the
  /// first picture - the same trap `pickImageInto` documents.
  static Future<File?> _decodePicture(Object? entry, String baseName) async {
    if (entry is! Map) return null;
    final encoded = entry['bytes'];
    if (encoded is! String) return null;
    try {
      final extension = entry['extension'] as String? ?? '';
      final dir = Directory(
        p.join((await getApplicationDocumentsDirectory()).path, 'restored'),
      );
      if (!dir.existsSync()) await dir.create(recursive: true);
      final safeName = baseName.replaceAll(RegExp(r'[^\w.]'), '_');
      final stamp = DateTime.now().microsecondsSinceEpoch;
      final file = File(p.join(dir.path, '$safeName.$stamp$extension'));
      await file.writeAsBytes(base64Decode(encoded));
      return file;
    } catch (_) {
      return null;
    }
  }

  static T _enumOr<T extends Enum>(List<T> values, Object? name, T fallback) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }
}
