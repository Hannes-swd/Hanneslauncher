import 'package:flutter/material.dart';

import 'app_icon.dart';
import 'app_list_settings_controller.dart' show appListColorPalette;
import 'app_strings.dart';
import 'icon_theme_controller.dart';
import 'launcher_entries_controller.dart';
import 'locale_controller.dart';

class IconThemeSettingsScreen extends StatelessWidget {
  const IconThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LocaleController.instance,
      builder: (context, language, child) {
        final s = AppStrings(language);
        return ValueListenableBuilder<IconThemeSettings>(
          valueListenable: IconThemeController.instance,
          builder: (context, iconTheme, child) {
            return Scaffold(
              appBar: AppBar(title: Text(s.iconTheme)),
              body: ListView(
                children: [
                  SwitchListTile(
                    title: Text(s.iconThemeEnabled),
                    subtitle: Text(s.iconThemeHint),
                    value: iconTheme.enabled,
                    onChanged: (enabled) => IconThemeController.instance
                        .update(iconTheme.copyWith(enabled: enabled)),
                  ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text(
                      s.textColor,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (var i = 0; i < appListColorPalette.length; i++)
                          GestureDetector(
                            onTap: () {
                              // Picking a color also switches the theme on -
                              // choosing one and seeing nothing happen would
                              // just be confusing.
                              IconThemeController.instance.update(
                                iconTheme.copyWith(
                                  colorIndex: i,
                                  enabled: true,
                                ),
                              );
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: appListColorPalette[i],
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: i == iconTheme.colorIndex
                                      ? Colors.black
                                      : Colors.black26,
                                  width: i == iconTheme.colorIndex ? 3 : 1,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Real icons rather than a mock-up, so the effect can be
                  // judged on the apps that are actually installed.
                  _Preview(),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _Preview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LauncherEntriesController.instance,
      builder: (context, child) {
        final entries = [
          for (final entry in LauncherEntriesController.instance.entries)
            if (!entry.isFolder) entry,
        ].take(8).toList();
        if (entries.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (final entry in entries) AppIcon(entry: entry, size: 48),
            ],
          ),
        );
      },
    );
  }
}
