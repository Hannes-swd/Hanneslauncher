import 'package:flutter/material.dart';

import 'app_customize_screen.dart';
import 'app_list_settings_screen.dart';
import 'app_strings.dart';
import 'clock_settings_screen.dart';
import 'data_sources_settings_screen.dart';
import 'default_launcher_controller.dart';
import 'default_launcher_screen.dart';
import 'device_data_screen.dart';
import 'folders_settings_screen.dart';
import 'icon_theme_controller.dart';
import 'icon_theme_settings_screen.dart';
import 'locale_controller.dart';
import 'pinned_apps_settings_screen.dart';
import 'settings_backup_screen.dart';
import 'update_controller.dart';
import 'update_screen.dart';
import 'wallpaper_controller.dart';
import 'web_apps_settings_screen.dart';

/// The headings the settings list is grouped under, in display order.
enum SettingsSection { appearance, apps, panelData, app }

extension SettingsSectionLabel on SettingsSection {
  String label(AppStrings s) => switch (this) {
    SettingsSection.appearance => s.sectionAppearance,
    SettingsSection.apps => s.sectionApps,
    SettingsSection.panelData => s.sectionPanelData,
    SettingsSection.app => s.sectionApp,
  };

  IconData get icon => switch (this) {
    SettingsSection.appearance => Icons.brush_outlined,
    SettingsSection.apps => Icons.apps,
    SettingsSection.panelData => Icons.dashboard_outlined,
    SettingsSection.app => Icons.settings_outlined,
  };
}

/// What a section holds, as the row's subtitle - read off the entries
/// themselves rather than written out separately, so it can't drift out of
/// date when something is added or moved.
String settingsSectionSummary(
  SettingsSection section,
  List<SettingsEntry> entries,
) {
  return [
    for (final entry in entries)
      if (entry.section == section) entry.title,
  ].join(', ');
}

/// One row in the settings list.
class SettingsEntry {
  const SettingsEntry({
    required this.icon,
    required this.title,
    required this.section,
    required this.onTap,
    this.subtitle = '',
    this.keywords = const [],
    this.trailing,
  });

  final IconData icon;
  final String title;
  final SettingsSection section;
  final void Function(BuildContext context) onTap;
  final String subtitle;

  /// What this entry should also be findable by: the settings that live
  /// inside the screen it opens, plus the words people actually type for
  /// them. Kept in both languages regardless of the app's current one - the
  /// cost is a few strings, and searching in the "wrong" language finding
  /// nothing is exactly the kind of dead end this is meant to remove.
  /// Must be lowercase; [matches] does not fold them.
  final List<String> keywords;

  final Widget? trailing;

  /// [query] is expected already trimmed and lowercased.
  bool matches(String query) {
    if (query.isEmpty) return true;
    if (title.toLowerCase().contains(query)) return true;
    if (subtitle.toLowerCase().contains(query)) return true;
    for (final keyword in keywords) {
      if (keyword.contains(query)) return true;
    }
    return false;
  }
}

/// Every setting there is, in one list. Built fresh on each rebuild so the
/// subtitles can carry live counts, and so entries that only make sense
/// sometimes (removing a wallpaper that isn't set, the device-data package
/// before it's added) simply aren't there.
List<SettingsEntry> buildSettingsCatalog({
  required AppStrings s,
  required Wallpaper? wallpaper,
  required IconThemeSettings iconTheme,
  required int folderCount,
  required int webAppCount,
  required int pinnedCount,
  required int pinnedMax,
  required int dataSourceCount,
  required bool deviceDataEnabled,
  required AppLanguage language,
  required UpdateState update,
  required DefaultLauncherState defaultLauncher,
}) {
  return [
    SettingsEntry(
      icon: Icons.image_outlined,
      title: s.wallpaper,
      section: SettingsSection.appearance,
      subtitle: switch (wallpaper?.kind) {
        null => s.noImageSelected,
        WallpaperKind.image => s.imageSelected,
        WallpaperKind.video => s.videoSelected,
      },
      keywords: const [
        'wallpaper', 'hintergrund', 'hintergrundbild', 'bild', 'foto',
        'background', 'image', 'picture', 'video', 'gif', 'mp4', 'film',
        'bewegt', 'animiert', 'animated', 'live',
      ],
      trailing: wallpaper == null
          ? null
          : SizedBox(
              width: 40,
              height: 40,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                // No thumbnail for a video - pulling a frame out of it costs
                // a decoder run per settings rebuild, for a 40 pixel square.
                child: wallpaper.isVideo
                    ? const ColoredBox(
                        color: Color(0xFFE0E0E0),
                        child: Icon(Icons.movie_outlined, size: 22),
                      )
                    : Image.file(wallpaper.file, fit: BoxFit.cover),
              ),
            ),
      onTap: (context) => WallpaperController.instance.pickAndSet(),
    ),
    if (wallpaper != null)
      SettingsEntry(
        icon: Icons.delete_outline,
        title: s.removeWallpaper,
        section: SettingsSection.appearance,
        keywords: const [
          'wallpaper', 'hintergrund', 'hintergrundbild', 'entfernen',
          'löschen', 'loeschen', 'remove', 'delete', 'background',
        ],
        onTap: (context) => WallpaperController.instance.clear(),
      ),
    SettingsEntry(
      icon: Icons.access_time_outlined,
      title: s.clock,
      section: SettingsSection.appearance,
      subtitle: s.clockSubtitle,
      keywords: const [
        'uhr', 'uhrzeit', 'zeit', 'clock', 'time', 'stil', 'style',
        'digital', 'römisch', 'roemisch', 'roman', 'balken', 'bars',
        'punktraster', 'dot matrix', 'klapptafel', 'split-flap', 'splitflap',
        'orbit', 'vertikal', 'vertical', 'wortuhr', 'word', 'position',
        'ausrichtung', 'alignment', 'abstand', 'farbe', 'color',
      ],
      onTap: (context) => _push(context, const ClockSettingsScreen()),
    ),
    SettingsEntry(
      icon: Icons.list_alt_outlined,
      title: s.appList,
      section: SettingsSection.appearance,
      subtitle: s.appListSubtitle,
      keywords: const [
        'app-liste', 'appliste', 'liste', 'app list', 'schrift', 'schriftart',
        'schriftgröße', 'schriftgroesse', 'textgröße', 'textgroesse', 'font',
        'size', 'größe', 'groesse', 'zeilenabstand', 'abstand', 'spacing',
        'textfarbe', 'farbe', 'color', 'sortierung', 'sortieren', 'sort',
        'alphabetisch', 'alphabetical', 'neueste', 'newest',
      ],
      onTap: (context) => _push(context, const AppListSettingsScreen()),
    ),
    SettingsEntry(
      icon: Icons.palette_outlined,
      title: s.iconTheme,
      section: SettingsSection.appearance,
      subtitle: s.iconThemeSubtitle,
      keywords: const [
        'icon', 'icons', 'symbol', 'design', 'theme', 'farbe', 'color',
        'einfärben', 'einfaerben', 'tint', 'einheitlich',
      ],
      trailing: iconTheme.enabled
          ? CircleAvatar(radius: 12, backgroundColor: iconTheme.color)
          : null,
      onTap: (context) => _push(context, const IconThemeSettingsScreen()),
    ),
    SettingsEntry(
      icon: Icons.push_pin_outlined,
      title: s.pinnedApps,
      section: SettingsSection.apps,
      subtitle: s.pinnedAppsSubtitle(pinnedCount, pinnedMax),
      keywords: const [
        'angepinnt', 'anpinnen', 'pin', 'pinned', 'homescreen', 'startseite',
        'favoriten', 'favourites', 'abstand', 'rand', 'margin',
      ],
      onTap: (context) => _push(context, const PinnedAppsSettingsScreen()),
    ),
    SettingsEntry(
      icon: Icons.folder_outlined,
      title: s.folders,
      section: SettingsSection.apps,
      subtitle: s.foldersSubtitle(folderCount),
      keywords: const [
        'ordner', 'folder', 'folders', 'gruppe', 'gruppen', 'group',
        'sammlung', 'farbe', 'color',
      ],
      onTap: (context) => _push(context, const FoldersSettingsScreen()),
    ),
    SettingsEntry(
      icon: Icons.public,
      title: s.webApps,
      section: SettingsSection.apps,
      subtitle: s.webAppsSubtitle(webAppCount),
      keywords: const [
        'web', 'webapp', 'web-app', 'pwa', 'webseite', 'website', 'seite',
        'link', 'links', 'lesezeichen', 'bookmark', 'url', 'adresse',
        'browser', 'chrome', 'firefox',
      ],
      onTap: (context) => _push(context, const WebAppsSettingsScreen()),
    ),
    SettingsEntry(
      icon: Icons.apps_outlined,
      title: s.customizeApps,
      section: SettingsSection.apps,
      subtitle: s.customizeAppsSubtitle,
      keywords: const [
        'anpassen', 'customize', 'umbenennen', 'rename', 'name', 'namen',
        'icon', 'symbol', 'ändern', 'aendern', 'change', 'deinstallieren',
        'uninstall', 'entfernen',
      ],
      onTap: (context) => _push(context, const AppCustomizeScreen()),
    ),
    SettingsEntry(
      icon: Icons.cloud_outlined,
      title: s.dataSources,
      section: SettingsSection.panelData,
      subtitle: s.dataSourcesSubtitle(dataSourceCount),
      keywords: const [
        'datenquelle', 'datenquellen', 'quelle', 'quellen', 'data source',
        'source', 'api', 'json', 'url', 'wetter', 'weather', 'open-meteo',
        'platzhalter', 'placeholder', 'header', 'aktualisieren', 'refresh',
        'intervall', 'widget', 'widgets',
      ],
      onTap: (context) => _push(context, const DataSourcesSettingsScreen()),
    ),
    // Only once the package has actually been added - before that it lives
    // behind the "+" on the data sources screen, and a row leading to an
    // empty screen would be a dead end.
    if (deviceDataEnabled)
      SettingsEntry(
        icon: Icons.smartphone_outlined,
        title: s.devicePackages,
        section: SettingsSection.panelData,
        subtitle: s.devicePackagesHint,
        keywords: const [
          'gerätedaten', 'geraetedaten', 'gerät', 'geraet', 'device data',
          'akku', 'battery', 'speicher', 'storage', 'verbindung',
          'connection', 'wlan', 'wifi', 'sonnenaufgang', 'sonnenuntergang',
          'sunrise', 'sunset', 'mondphase', 'moon', 'schritte', 'steps',
          'meistgenutzt', 'most used',
        ],
        onTap: (context) => _push(context, const DeviceDataScreen()),
      ),
    SettingsEntry(
      icon: Icons.home_outlined,
      title: s.defaultLauncher,
      section: SettingsSection.app,
      subtitle: defaultLauncher.isDefault
          ? s.defaultLauncherIsDefault
          : (defaultLauncher.otherName == null
                ? s.defaultLauncherNone
                : s.defaultLauncherCurrently(defaultLauncher.otherName!)),
      keywords: const [
        'standard', 'default', 'launcher', 'start-app', 'startapp', 'home',
        'home-taste', 'homescreen', 'startbildschirm', 'home screen',
        'festlegen', 'set', 'einrichten', 'setup',
      ],
      onTap: (context) => _push(context, const DefaultLauncherScreen()),
    ),
    SettingsEntry(
      icon: Icons.language,
      title: s.languageLabel,
      section: SettingsSection.app,
      subtitle: LocaleController.instance.followsSystem
          ? s.languageSystemSubtitle(
              language == AppLanguage.de ? s.german : s.english,
            )
          : (language == AppLanguage.de ? s.german : s.english),
      keywords: const [
        'sprache', 'language', 'deutsch', 'german', 'englisch', 'english',
        'übersetzung', 'uebersetzung', 'system', 'systemsprache',
      ],
      onTap: (context) => _pickLanguage(context, s),
    ),
    SettingsEntry(
      icon: Icons.save_outlined,
      title: s.backup,
      section: SettingsSection.app,
      subtitle: s.backupSubtitle,
      keywords: const [
        'backup', 'sicherung', 'sichern', 'export', 'exportieren', 'import',
        'importieren', 'wiederherstellen', 'restore', 'datei', 'file',
        'kopie', 'json',
      ],
      onTap: (context) => _push(context, const SettingsBackupScreen()),
    ),
    SettingsEntry(
      icon: Icons.system_update_outlined,
      title: s.update,
      section: SettingsSection.app,
      subtitle: update.available
          ? s.updateSubtitleAvailable(update.latest!.version)
          : (update.installedVersion.isEmpty
                ? s.updateSubtitleUnknown
                : s.updateSubtitleInstalled(update.installedVersion)),
      keywords: const [
        'update', 'aktualisierung', 'aktualisieren', 'version', 'neue version',
        'new version', 'github', 'apk', 'release', 'download',
        'herunterladen', 'installieren', 'install', 'upgrade',
      ],
      trailing: update.available ? const UpdateDot() : null,
      onTap: (context) => _push(context, const UpdateScreen()),
    ),
  ];
}

void _push(BuildContext context, Widget screen) {
  Navigator.of(context).push(MaterialPageRoute(builder: (context) => screen));
}

/// Three options aren't worth a screen of their own, so the language is
/// picked straight from the list row. `null` in the map is "follow the
/// phone", which is what a fresh install does.
Future<void> _pickLanguage(BuildContext context, AppStrings s) async {
  final controller = LocaleController.instance;
  final current = controller.followsSystem ? null : controller.value;
  final options = <AppLanguage?, String>{
    null: s.languageSystem,
    AppLanguage.de: s.german,
    AppLanguage.en: s.english,
  };
  // Wrapped so "cancelled" can be told apart from "picked the system
  // entry", which pops a null of its own.
  final choice = await showDialog<List<AppLanguage?>>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(s.languageLabel),
      children: [
        for (final entry in options.entries)
          ListTile(
            leading: Icon(
              entry.key == current
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
            ),
            title: Text(entry.value),
            onTap: () => Navigator.of(context).pop([entry.key]),
          ),
      ],
    ),
  );
  if (choice == null) return;
  final picked = choice.single;
  if (picked == null) {
    await controller.useSystem();
  } else {
    await controller.update(picked);
  }
}
