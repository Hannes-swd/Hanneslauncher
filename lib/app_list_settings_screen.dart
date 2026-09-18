import 'package:flutter/material.dart';

import 'app_list_settings_controller.dart';
import 'app_strings.dart';
import 'color_swatch_picker.dart';
import 'design_tokens.dart';
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
                    style: TextStyle(
                      fontSize: context.design.typeCaption,
                      color: context.design.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _SectionLabel(s.appListHand),
                  _HandPicker(settings: settings, s: s),
                  const SizedBox(height: 6),
                  Text(
                    s.appListHandHint,
                    style: TextStyle(
                      fontSize: context.design.typeCaption,
                      color: context.design.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(s.hideAlphabet),
                    subtitle: Text(
                      s.hideAlphabetHint,
                      style: TextStyle(
                        fontSize: context.design.typeCaption,
                        color: context.design.textSecondary,
                      ),
                    ),
                    value: settings.hideAlphabet,
                    onChanged: (value) {
                      AppListSettingsController.instance.update(
                        settings.copyWith(hideAlphabet: value),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  _SectionLabel(s.searchSection),
                  Text(
                    s.searchSectionHint,
                    style: TextStyle(
                      fontSize: context.design.typeCaption,
                      color: context.design.textSecondary,
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(s.searchExtras),
                    subtitle: Text(
                      s.searchExtrasHint,
                      style: TextStyle(
                        fontSize: context.design.typeCaption,
                        color: context.design.textSecondary,
                      ),
                    ),
                    value: settings.searchExtras,
                    onChanged: (value) {
                      AppListSettingsController.instance.update(
                        settings.copyWith(searchExtras: value),
                      );
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(s.searchContacts),
                    subtitle: Text(
                      s.searchContactsHint,
                      style: TextStyle(
                        fontSize: context.design.typeCaption,
                        color: context.design.textSecondary,
                      ),
                    ),
                    value: settings.searchContacts,
                    onChanged: (value) {
                      AppListSettingsController.instance.update(
                        settings.copyWith(searchContacts: value),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _WebSearchField(settings: settings, s: s),
                  const SizedBox(height: 24),
                  _SectionLabel(
                    settings.backgroundBlur == 0
                        ? s.backgroundBlur(s.backgroundBlurOff)
                        : s.backgroundBlur(
                            '${settings.backgroundBlur.round()}',
                          ),
                  ),
                  Slider(
                    value: settings.backgroundBlur,
                    max: 30,
                    divisions: 15,
                    onChanged: (value) {
                      AppListSettingsController.instance.update(
                        settings.copyWith(backgroundBlur: value),
                      );
                    },
                  ),
                  Text(
                    s.backgroundBlurHint,
                    style: TextStyle(
                      fontSize: context.design.typeCaption,
                      color: context.design.textSecondary,
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
      style: TextStyle(
        fontSize: context.design.typeLabel,
        fontWeight: FontWeight.bold,
        color: context.design.textSecondary,
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
        color: context.design.fillSubtle,
        borderRadius: BorderRadius.circular(context.design.radiusMedium),
      ),
      child: Row(
        children: [
          Icon(Icons.apps, color: context.design.textMuted),
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

/// Where the search sends whatever it could not find here.
///
/// A plain field rather than a list of search engines to pick from: the
/// address format is the one the search widget already uses, so an address
/// that works in one works in the other, and a list would need maintaining
/// every time one of them changed a parameter.
class _WebSearchField extends StatefulWidget {
  const _WebSearchField({required this.settings, required this.s});

  final AppListSettings settings;
  final AppStrings s;

  @override
  State<_WebSearchField> createState() => _WebSearchFieldState();
}

class _WebSearchFieldState extends State<_WebSearchField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.settings.searchWebUrl,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: s.searchWebUrl,
            hintText: 'https://duckduckgo.com/?q={{suche}}',
          ),
          // On every keystroke rather than on submit: there is no submit
          // button on this screen, and a setting that only takes effect if
          // you happen to press the keyboard's return key is one that looks
          // broken half the time.
          onChanged: (value) => AppListSettingsController.instance.update(
            widget.settings.copyWith(searchWebUrl: value),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          s.searchWebUrlHint,
          style: TextStyle(
            fontSize: context.design.typeCaption,
            color: context.design.textSecondary,
          ),
        ),
      ],
    );
  }
}
