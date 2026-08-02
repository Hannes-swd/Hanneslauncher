import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'data_packages_controller.dart';
import 'data_sources_controller.dart';
import 'folders_controller.dart';
import 'icon_theme_controller.dart';
import 'locale_controller.dart';
import 'pinned_apps_controller.dart';
import 'settings_catalog.dart';
import 'wallpaper_controller.dart';
import 'web_apps_controller.dart';

/// Builds the full catalog from whatever the controllers currently hold.
/// Shared by the overview and the section pages so both always show the same
/// entries, counts and conditional rows.
List<SettingsEntry> _catalog(AppStrings s) {
  return buildSettingsCatalog(
    s: s,
    wallpaper: WallpaperController.instance.value,
    iconTheme: IconThemeController.instance.value,
    folderCount: FoldersController.instance.value.length,
    webAppCount: WebAppsController.instance.value.length,
    pinnedCount: PinnedAppsController.instance.value.length,
    pinnedMax: PinnedAppsController.maxPinned,
    dataSourceCount: DataSourcesController.instance.value.length,
    deviceDataEnabled: DeviceDataController.instance.value,
    language: LocaleController.instance.value,
  );
}

/// Everything a settings page has to follow: each of these shows up in a
/// subtitle, a trailing thumbnail, or decides whether a row exists at all.
Listenable _settingsSources() => Listenable.merge([
  LocaleController.instance,
  WallpaperController.instance,
  IconThemeController.instance,
  FoldersController.instance,
  WebAppsController.instance,
  PinnedAppsController.instance,
  DataSourcesController.instance,
  DeviceDataController.instance,
]);

/// The settings overview: the four groups as sub-pages, with a search field
/// above them that reaches past them. Searching deliberately ignores the
/// grouping and lists the matching settings directly - having to already
/// know which group something was filed under before you can look for it is
/// what makes settings feel missing.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _settingsSources(),
      builder: (context, child) {
        final s = AppStrings(LocaleController.instance.value);
        final entries = _catalog(s);
        final query = _search.text.trim().toLowerCase();

        return Scaffold(
          appBar: AppBar(title: Text(s.settings)),
          body: Column(
            children: [
              _searchField(s),
              Expanded(
                child: query.isEmpty
                    ? _sectionList(s, entries)
                    : _searchResults(s, entries, query),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _searchField(AppStrings s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: _search,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          isDense: true,
          hintText: s.searchSettings,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _search.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(_search.clear),
                ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
    );
  }

  Widget _sectionList(AppStrings s, List<SettingsEntry> entries) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        for (final section in SettingsSection.values)
          ListTile(
            leading: Icon(section.icon),
            title: Text(section.label(s)),
            subtitle: Text(
              settingsSectionSummary(section, entries),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => SettingsSectionScreen(section: section),
              ),
            ),
          ),
      ],
    );
  }

  Widget _searchResults(
    AppStrings s,
    List<SettingsEntry> entries,
    String query,
  ) {
    final matches = [
      for (final entry in entries)
        if (entry.matches(query)) entry,
    ];
    if (matches.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            s.noSettingsFound,
            style: const TextStyle(color: Colors.black54),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        for (final entry in matches)
          settingsTile(context, entry, groupLabel: entry.section.label(s)),
      ],
    );
  }
}

/// One group's settings. Reached from the overview, and the only place a
/// setting is listed under its own group.
class SettingsSectionScreen extends StatelessWidget {
  const SettingsSectionScreen({super.key, required this.section});

  final SettingsSection section;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _settingsSources(),
      builder: (context, child) {
        final s = AppStrings(LocaleController.instance.value);
        final entries = [
          for (final entry in _catalog(s))
            if (entry.section == section) entry,
        ];
        return Scaffold(
          appBar: AppBar(title: Text(section.label(s))),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              for (final entry in entries) settingsTile(context, entry),
            ],
          ),
        );
      },
    );
  }
}

/// A single settings row. [groupLabel] is set only in search results: a hit
/// on a keyword can look arbitrary on its own ("Schriftgröße" finding
/// "App-Liste"), so the result says which group it came from.
Widget settingsTile(
  BuildContext context,
  SettingsEntry entry, {
  String? groupLabel,
}) {
  final subtitle = groupLabel == null
      ? entry.subtitle
      : (entry.subtitle.isEmpty
            ? groupLabel
            : '$groupLabel · ${entry.subtitle}');
  return ListTile(
    leading: Icon(entry.icon),
    title: Text(entry.title),
    subtitle: subtitle.isEmpty
        ? null
        : Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
    trailing: entry.trailing,
    onTap: () => entry.onTap(context),
  );
}
