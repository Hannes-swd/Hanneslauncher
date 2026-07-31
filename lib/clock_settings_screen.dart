import 'package:flutter/material.dart';

import 'app_list_settings_controller.dart' show appListColorPalette;
import 'app_strings.dart';
import 'clock_settings_controller.dart';
import 'clock_widget.dart';
import 'locale_controller.dart';

class ClockSettingsScreen extends StatelessWidget {
  const ClockSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LocaleController.instance,
      builder: (context, language, child) {
        final s = AppStrings(language);
        return Scaffold(
          appBar: AppBar(title: Text(s.clock)),
          body: ValueListenableBuilder<ClockSettings>(
            valueListenable: ClockSettingsController.instance,
            builder: (context, settings, child) {
              return ListView(
                children: [
                  SwitchListTile(
                    title: Text(s.showClock),
                    value: settings.enabled,
                    onChanged: (value) {
                      ClockSettingsController.instance.update(
                        settings.copyWith(enabled: value),
                      );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      s.style,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  Opacity(
                    opacity: settings.enabled ? 1 : 0.4,
                    child: IgnorePointer(
                      ignoring: !settings.enabled,
                      child: Column(
                        children: [
                          _StyleOption(
                            title: s.digital,
                            selected: settings.style == ClockStyle.digital,
                            preview: const _DigitalPreview(),
                            onTap: () {
                              ClockSettingsController.instance.update(
                                settings.copyWith(style: ClockStyle.digital),
                              );
                            },
                          ),
                          _StyleOption(
                            title: s.custom,
                            selected: settings.style == ClockStyle.word,
                            preview: const _WordPreview(),
                            onTap: () {
                              ClockSettingsController.instance.update(
                                settings.copyWith(style: ClockStyle.word),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      s.appearanceCustom,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  Opacity(
                    opacity:
                        settings.enabled && settings.style == ClockStyle.word
                        ? 1
                        : 0.4,
                    child: IgnorePointer(
                      ignoring:
                          !settings.enabled ||
                          settings.style != ClockStyle.word,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Label(s.backgroundColor),
                            _ColorSwatchRow(
                              selectedIndex: settings.wordBgColorIndex,
                              onSelected: (i) {
                                ClockSettingsController.instance.update(
                                  settings.copyWith(wordBgColorIndex: i),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            _Label(
                              s.backgroundStrength(
                                (settings.wordBgOpacity * 100).round(),
                              ),
                            ),
                            Slider(
                              value: settings.wordBgOpacity,
                              min: 0,
                              max: 1,
                              divisions: 20,
                              onChanged: (value) {
                                ClockSettingsController.instance.update(
                                  settings.copyWith(wordBgOpacity: value),
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            _Label(s.activeLetters),
                            _ColorSwatchRow(
                              selectedIndex: settings.wordActiveColorIndex,
                              onSelected: (i) {
                                ClockSettingsController.instance.update(
                                  settings.copyWith(wordActiveColorIndex: i),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            _Label(s.inactiveLetters),
                            _ColorSwatchRow(
                              selectedIndex: settings.wordInactiveColorIndex,
                              onSelected: (i) {
                                ClockSettingsController.instance.update(
                                  settings.copyWith(
                                    wordInactiveColorIndex: i,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
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

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }
}

class _ColorSwatchRow extends StatelessWidget {
  const _ColorSwatchRow({required this.selectedIndex, required this.onSelected});

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      children: [
        for (var i = 0; i < appListColorPalette.length; i++)
          GestureDetector(
            onTap: () => onSelected(i),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: appListColorPalette[i],
                shape: BoxShape.circle,
                border: Border.all(
                  color: i == selectedIndex ? Colors.black : Colors.black26,
                  width: i == selectedIndex ? 3 : 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _StyleOption extends StatelessWidget {
  const _StyleOption({
    required this.title,
    required this.selected,
    required this.preview,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final Widget preview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Colors.black : Colors.black26,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? Colors.black : Colors.black45,
            ),
            const SizedBox(width: 12),
            Expanded(child: preview),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
      ),
    );
  }
}

class _DigitalPreview extends StatelessWidget {
  const _DigitalPreview();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 60,
      child: Center(child: DigitalClock(fontSize: 28)),
    );
  }
}

class _WordPreview extends StatelessWidget {
  const _WordPreview();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 90,
      child: FittedBox(child: WordClock()),
    );
  }
}
