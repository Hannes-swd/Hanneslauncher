import 'package:flutter/material.dart';

import 'app_list_settings_controller.dart';

class AppListSettingsScreen extends StatelessWidget {
  const AppListSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('App-Liste')),
      body: ValueListenableBuilder<AppListSettings>(
        valueListenable: AppListSettingsController.instance,
        builder: (context, settings, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _PreviewRow(settings: settings),
              const SizedBox(height: 24),
              const _SectionLabel('Textfarbe'),
              _ColorPicker(settings: settings),
              const SizedBox(height: 24),
              const _SectionLabel('Schriftart'),
              _FontFamilyPicker(settings: settings),
              const SizedBox(height: 24),
              _SectionLabel('Textgröße (${settings.fontSize.round()})'),
              Slider(
                value: settings.fontSize,
                min: 12,
                max: 28,
                divisions: 16,
                onChanged: (value) {
                  AppListSettingsController.instance.update(
                    settings.copyWith(fontSize: value),
                  );
                },
              ),
              const SizedBox(height: 8),
              _SectionLabel('Zeilenabstand (${settings.rowHeight.round()})'),
              Slider(
                value: settings.rowHeight,
                min: 56,
                max: 104,
                divisions: 12,
                onChanged: (value) {
                  AppListSettingsController.instance.update(
                    settings.copyWith(rowHeight: value),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Colors.black54,
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.settings});

  final AppListSettings settings;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: settings.rowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.apps, color: Colors.black45),
          const SizedBox(width: 16),
          Text(
            'Beispiel App',
            style: TextStyle(
              color: settings.color,
              fontSize: settings.fontSize,
              fontFamily: settings.fontFamily.isEmpty
                  ? null
                  : settings.fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorPicker extends StatelessWidget {
  const _ColorPicker({required this.settings});

  final AppListSettings settings;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      children: [
        for (var i = 0; i < appListColorPalette.length; i++)
          GestureDetector(
            onTap: () {
              AppListSettingsController.instance.update(
                settings.copyWith(colorIndex: i),
              );
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: appListColorPalette[i],
                shape: BoxShape.circle,
                border: Border.all(
                  color: i == settings.colorIndex
                      ? Colors.black
                      : Colors.black26,
                  width: i == settings.colorIndex ? 3 : 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FontFamilyPicker extends StatelessWidget {
  const _FontFamilyPicker({required this.settings});

  final AppListSettings settings;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        for (final entry in appListFontFamilies.entries)
          ChoiceChip(
            label: Text(entry.key),
            selected: settings.fontFamily == entry.value,
            onSelected: (_) {
              AppListSettingsController.instance.update(
                settings.copyWith(fontFamily: entry.value),
              );
            },
          ),
      ],
    );
  }
}
