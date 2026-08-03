import 'package:flutter_test/flutter_test.dart';
import 'package:hanneslouncher/app_strings.dart';
import 'package:hanneslouncher/default_launcher_controller.dart';
import 'package:hanneslouncher/icon_theme_controller.dart';
import 'package:hanneslouncher/locale_controller.dart';
import 'package:hanneslouncher/settings_catalog.dart';
import 'package:hanneslouncher/update_controller.dart';

/// The catalog as it looks with nothing configured yet - enough for the
/// search, which only ever reads titles, subtitles and keywords.
List<SettingsEntry> catalog({
  AppLanguage language = AppLanguage.de,
  bool deviceDataEnabled = false,
  UpdateState update = const UpdateState(),
}) {
  return buildSettingsCatalog(
    s: AppStrings(language),
    wallpaper: null,
    iconTheme: const IconThemeSettings(),
    folderCount: 0,
    webAppCount: 0,
    pinnedCount: 0,
    pinnedMax: 6,
    dataSourceCount: 0,
    deviceDataEnabled: deviceDataEnabled,
    language: language,
    update: update,
    defaultLauncher: const DefaultLauncherState(),
  );
}

/// What the settings screen does: lowercase, trimmed, then matched.
List<String> search(String query, {AppLanguage language = AppLanguage.de}) => [
  for (final entry in catalog(language: language))
    if (entry.matches(query.trim().toLowerCase())) entry.title,
];

void main() {
  test('an empty query keeps every entry', () {
    expect(search('').length, catalog().length);
  });

  group('a setting nested inside another screen is still findable', () {
    // The whole point: these live one screen deeper, so without keywords
    // they would be invisible to the search - which is what made things feel
    // missing in the first place.
    final cases = {
      'schriftgröße': 'App-Liste',
      'sortieren': 'App-Liste',
      'zeilenabstand': 'App-Liste',
      'römisch': 'Uhr',
      'klapptafel': 'Uhr',
      'umbenennen': 'Apps anpassen',
      'pwa': 'Web-Apps',
      'lesezeichen': 'Web-Apps',
      'exportieren': 'Sicherung',
      'wiederherstellen': 'Sicherung',
      'api': 'Datenquellen',
      'wetter': 'Datenquellen',
    };
    for (final entry in cases.entries) {
      test('"${entry.key}" finds ${entry.value}', () {
        expect(search(entry.key), contains(entry.value));
      });
    }
  });

  test('searching in English works while the app is in German', () {
    // Keywords carry both languages, so the search never depends on which
    // one the app happens to be set to.
    expect(search('wallpaper'), contains('Hintergrundbild'));
    expect(search('font'), contains('App-Liste'));
    expect(search('backup'), contains('Sicherung'));
  });

  test('the update row is findable by what people call it', () {
    for (final query in ['update', 'version', 'apk', 'aktualisieren']) {
      expect(search(query), contains('Update'), reason: query);
    }
  });

  test('the update row only carries the mark when there is one', () {
    SettingsEntry updateEntry(UpdateState state) => catalog(
      update: state,
    ).firstWhere((entry) => entry.title == 'Update');

    expect(
      updateEntry(const UpdateState(installedVersion: '1.0.0')).trailing,
      isNull,
    );
    expect(
      updateEntry(
        const UpdateState(
          installedVersion: '1.0.0',
          latest: UpdateRelease(
            version: '1.1.0',
            apkUrl: '',
            pageUrl: '',
            notes: '',
            publishedAt: null,
          ),
        ),
      ).trailing,
      isNotNull,
    );
  });

  test('umlaut spelled out finds the same entry', () {
    expect(search('schriftgroesse'), contains('App-Liste'));
    expect(search('geraetedaten', language: AppLanguage.de), isEmpty);
    final withPackage = [
      for (final entry in catalog(deviceDataEnabled: true))
        if (entry.matches('geraetedaten')) entry.title,
    ];
    expect(withPackage, contains('Gerätedaten'));
  });

  test('device data only appears once the package has been added', () {
    expect(
      catalog().map((e) => e.title),
      isNot(contains('Gerätedaten')),
    );
    expect(
      catalog(deviceDataEnabled: true).map((e) => e.title),
      contains('Gerätedaten'),
    );
  });

  test('a query matching nothing returns nothing', () {
    expect(search('zzzznotasetting'), isEmpty);
  });

  test('every entry has a section and a non-empty title', () {
    for (final entry in catalog(deviceDataEnabled: true)) {
      expect(entry.title, isNotEmpty);
      expect(SettingsSection.values, contains(entry.section));
    }
  });

  test('no section is empty, so no row leads to a blank page', () {
    // The overview lists every section unconditionally; one with nothing in
    // it would be a dead end.
    for (final section in SettingsSection.values) {
      expect(
        settingsSectionSummary(section, catalog()),
        isNotEmpty,
        reason: '$section has no entries',
      );
    }
  });

  test('a section summary names what is inside it', () {
    final summary = settingsSectionSummary(
      SettingsSection.appearance,
      catalog(),
    );
    expect(summary, contains('Uhr'));
    expect(summary, contains('App-Liste'));
    // Generated from the entries, so a conditional row shows up only when it
    // actually exists.
    expect(
      settingsSectionSummary(SettingsSection.panelData, catalog()),
      isNot(contains('Gerätedaten')),
    );
    expect(
      settingsSectionSummary(
        SettingsSection.panelData,
        catalog(deviceDataEnabled: true),
      ),
      contains('Gerätedaten'),
    );
  });
}
