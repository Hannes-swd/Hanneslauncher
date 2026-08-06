import 'package:flutter/material.dart';

import 'app_list_settings_controller.dart';
import 'app_strings.dart';
import 'color_swatch_picker.dart';
import 'locale_controller.dart';

class AppListSettingsScreen extends StatelessWidget {
  const AppListSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LocaleController.instance,
      builder: (context, language, child) {
        final s = AppStrings(language);
        return Scaffold(
          appBar: AppBar(title: Text(s.appList)),
          body: ValueListenableBuilder<AppListSettings>(
            valueListenable: AppListSettingsController.instance,
            builder: (context, settings, child) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _PreviewRow(settings: settings, s: s),
                  const SizedBox(height: 24),
                  _SectionLabel(s.appListLayout),
                  _LayoutModePicker(settings: settings, s: s),
                  const SizedBox(height: 6),
                  Text(
                    s.appListLayoutHint,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _SectionLabel(s.appListHand),
                  _HandPicker(settings: settings, s: s),
                  const SizedBox(height: 6),
                  Text(
                    s.appListHandHint,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _SectionLabel(s.textColor),
                  ColorSwatchPicker(
                    s: s,
                    selectedIndex: settings.colorIndex,
                    onSelected: (i) {
                      AppListSettingsController.instance.update(
                        settings.copyWith(colorIndex: i),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  _SectionLabel(s.font),
                  _FontFamilyPicker(settings: settings, s: s),
                  const SizedBox(height: 24),
                  _SectionLabel(s.textSize(settings.fontSize.round())),
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
                  _SectionLabel(s.lineSpacing(settings.rowHeight.round())),
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
      },
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
  const _PreviewRow({required this.settings, required this.s});

  final AppListSettings settings;
  final AppStrings s;

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
            s.exampleApp,
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

class _LayoutModePicker extends StatelessWidget {
  const _LayoutModePicker({required this.settings, required this.s});

  final AppListSettings settings;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    final options = {
      AppListLayoutMode.singleColumn: s.layoutSingleColumn,
      AppListLayoutMode.columns: s.layoutColumns,
    };
    return Wrap(
      spacing: 8,
      children: [
        for (final entry in options.entries)
          ChoiceChip(
            label: Text(entry.value),
            selected: settings.layoutMode == entry.key,
            onSelected: (_) {
              AppListSettingsController.instance.update(
                settings.copyWith(layoutMode: entry.key),
              );
            },
          ),
      ],
    );
  }
}

class _HandPicker extends StatelessWidget {
  const _HandPicker({required this.settings, required this.s});

  final AppListSettings settings;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    final options = {
      AppListHand.right: s.handRight,
      AppListHand.left: s.handLeft,
    };
    return Wrap(
      spacing: 8,
      children: [
        for (final entry in options.entries)
          ChoiceChip(
            label: Text(entry.value),
            selected: settings.hand == entry.key,
            onSelected: (_) {
              AppListSettingsController.instance.update(
                settings.copyWith(hand: entry.key),
              );
            },
          ),
      ],
    );
  }
}

class _FontFamilyPicker extends StatelessWidget {
  const _FontFamilyPicker({required this.settings, required this.s});

  final AppListSettings settings;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    final options = {
      s.fontStandard: '',
      s.fontSerif: 'serif',
      s.fontMonospace: 'monospace',
    };
    return Wrap(
      spacing: 8,
      children: [
        for (final entry in options.entries)
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
