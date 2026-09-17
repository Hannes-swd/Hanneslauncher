import 'package:flutter/material.dart';

import 'app_customize_screen.dart';
import 'app_icon.dart';
import 'app_overrides_controller.dart';
import 'app_strings.dart';
import 'color_swatch_picker.dart';
import 'design_tokens.dart';
import 'design_widgets.dart';
import 'icon_pack_controller.dart';
import 'icon_theme_controller.dart';
import 'launcher_entries_controller.dart';
import 'launcher_entry.dart';
import 'locale_controller.dart';

/// Where the icons come from: the apps themselves, an installed icon pack, or
/// one color for all of them - plus the way to the per-app pictures, which sit
/// on top of whichever of the three is chosen.
class IconThemeSettingsScreen extends StatefulWidget {
  const IconThemeSettingsScreen({super.key});

  @override
  State<IconThemeSettingsScreen> createState() =>
      _IconThemeSettingsScreenState();
}

class _IconThemeSettingsScreenState extends State<IconThemeSettingsScreen> {
  /// Read once when the screen opens rather than held in a controller: the
  /// list only changes when a pack is installed or removed, which cannot
  /// happen while this screen is in front.
  final Future<List<IconPack>> _packs = IconPacksController.installed();
  final Future<List<String>> _formats = IconPacksController.supportedFormats();

  IconThemeSettings get _settings => IconThemeController.instance.value;

  Future<void> _setStyle(IconStyle style) async {
    await IconThemeController.instance.update(_settings.copyWith(style: style));
  }

  /// Picking a pack also switches the style to it - choosing one and seeing
  /// nothing happen would just be confusing. Same for picking a color.
  Future<void> _setPack(String package) async {
    await IconThemeController.instance.update(
      _settings.copyWith(style: IconStyle.pack, packPackage: package),
    );
  }

  Future<void> _clearPickedIcons(AppStrings s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.iconPickedClear),
        content: Text(s.iconPickedClearConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(s.remove),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await AppOverridesController.instance.clearAllIcons();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LocaleController.instance,
      builder: (context, language, child) {
        final s = AppStrings(language);
        return ValueListenableBuilder<IconThemeSettings>(
          valueListenable: IconThemeController.instance,
          builder: (context, iconTheme, child) {
            final design = context.design;
            return Scaffold(
              appBar: AppBar(title: Text(s.iconTheme)),
              body: ListView(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      design.spaceMd,
                      design.spaceMd,
                      design.spaceMd,
                      0,
                    ),
                    child: Text(
                      s.iconThemeHint,
                      style: design.textStyle(
                        TypeRole.body,
                        color: design.textSecondary,
                      ),
                    ),
                  ),
                  _StyleTiles(settings: iconTheme, s: s, onPick: _setStyle),
                  if (iconTheme.style == IconStyle.pack) ...[
                    SettingsHeading(s.iconPackChoose),
                    _PackList(
                      packs: _packs,
                      formats: _formats,
                      selected: iconTheme.packPackage,
                      s: s,
                      onPick: _setPack,
                    ),
                  ],
                  if (iconTheme.style == IconStyle.color) ...[
                    SettingsHeading(s.colorLabel),
                    Padding(
                      padding: design.pagePadding,
                      child: ColorSwatchPicker(
                        s: s,
                        swatchSize: 40,
                        selectedIndex: iconTheme.colorIndex,
                        onSelected: (i) =>
                            IconThemeController.instance.update(
                              iconTheme.copyWith(
                                colorIndex: i,
                                style: IconStyle.color,
                              ),
                            ),
                      ),
                    ),
                  ],
                  SettingsHeading(s.iconStyleCustom),
                  _PickedIcons(s: s, onClear: () => _clearPickedIcons(s)),
                  SettingsHeading(s.preview),
                  const _Preview(),
                  SizedBox(height: design.spaceLg),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// The three styles as tiles, each previewing itself on a real icon from the
/// phone - a set of made-up squares would say nothing about what the color or
/// the pack does to the apps that are actually installed.
class _StyleTiles extends StatelessWidget {
  const _StyleTiles({
    required this.settings,
    required this.s,
    required this.onPick,
  });

  final IconThemeSettings settings;
  final AppStrings s;
  final ValueChanged<IconStyle> onPick;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final styles = <({IconStyle style, String title})>[
      (style: IconStyle.system, title: s.iconStyleSystem),
      (style: IconStyle.pack, title: s.iconStylePack),
      (style: IconStyle.color, title: s.iconStyleColor),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GridView(
          // Inside the settings list, so it neither scrolls on its own nor
          // guesses a height - the page it sits in does the scrolling.
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            design.spaceMd,
            design.spaceMd,
            design.spaceMd,
            0,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: design.spaceSm,
            crossAxisSpacing: design.spaceSm,
            mainAxisExtent:
                design.surfaceStyle(SurfaceLevel.compact).minHeight * 1.1,
          ),
          children: [
            for (final entry in styles)
              OptionTile(
                title: entry.title,
                selected: settings.style == entry.style,
                preview: _StylePreview(style: entry.style),
                onTap: () => onPick(entry.style),
              ),
          ],
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            design.spaceMd,
            design.spaceSm,
            design.spaceMd,
            0,
          ),
          child: Text(
            switch (settings.style) {
              IconStyle.system => s.iconStyleSystemHint,
              IconStyle.pack => s.iconStylePackHint,
              IconStyle.color => s.iconStyleColorHint,
            },
            style: design.textStyle(TypeRole.body, color: design.textSecondary),
          ),
        ),
      ],
    );
  }
}

/// One tile's preview: the first real app on the phone, drawn the way that
/// style would draw it. Drawn through the same widget the app list uses, so a
/// tile cannot promise something the list then draws differently. Falls back
/// to a glyph before the app list has loaded.
class _StylePreview extends StatelessWidget {
  const _StylePreview({required this.style});

  final IconStyle style;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LauncherEntriesController.instance,
      builder: (context, child) {
        final entry = _sampleEntry();
        if (entry == null) {
          return Icon(Icons.apps, size: 36, color: context.design.textMuted);
        }
        return AppIcon(entry: entry, size: 36, styleOverride: style);
      },
    );
  }
}

/// The first installed app in the list, or null while it is still loading.
/// The same app for every tile, so the three previews differ only in style.
LauncherEntry? _sampleEntry() {
  for (final entry in LauncherEntriesController.instance.entries) {
    // One without a picked picture, otherwise all three tiles would show the
    // same picture and say nothing at all.
    if (entry.app != null && entry.customIcon == null) return entry;
  }
  return null;
}

/// The list of installed packs, one tappable row each.
class _PackList extends StatelessWidget {
  const _PackList({
    required this.packs,
    required this.formats,
    required this.selected,
    required this.s,
    required this.onPick,
  });

  final Future<List<IconPack>> packs;
  final Future<List<String>> formats;
  final String? selected;
  final AppStrings s;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    return FutureBuilder<List<IconPack>>(
      future: packs,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Padding(
            padding: design.pagePadding,
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        final found = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (found.isEmpty)
              ListTile(
                leading: const Icon(Icons.extension_outlined),
                title: Text(s.iconPackNone),
                subtitle: Text(s.iconPackNoneHint),
              )
            else
              RadioGroup<String>(
                groupValue: selected,
                onChanged: (value) {
                  if (value != null) onPick(value);
                },
                child: Column(
                  children: [
                    for (final pack in found)
                      RadioListTile<String>(
                        value: pack.package,
                        title: Text(pack.label),
                        // The package name under it: two packs can carry the
                        // same name in the store, and this is what tells them
                        // apart.
                        subtitle: Text(
                          pack.package,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            if (selected != null && found.isNotEmpty) _PackStatus(s: s),
            // Always shown, not just when nothing was found: a pack that is
            // installed but missing from the list above is exactly the case
            // this is here to explain.
            _SupportedFormats(formats: formats, s: s),
          ],
        );
      },
    );
  }
}

/// How far the chosen pack got: how many apps it answered for, whether it is
/// still working, and the way to run it again after the pack itself was
/// updated.
class _PackStatus extends StatelessWidget {
  const _PackStatus({required this.s});

  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        IconPacksController.instance,
        LauncherEntriesController.instance,
      ]),
      builder: (context, child) {
        final controller = IconPacksController.instance;
        final total = [
          for (final entry in LauncherEntriesController.instance.entries)
            if (entry.app != null) entry,
        ].length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: controller.isWorking
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.done),
              title: Text(
                controller.isWorking
                    ? s.iconPackWorking
                    : s.iconPackCovered(controller.coveredCount, total),
              ),
              subtitle: Text(s.iconPackRest),
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: Text(s.iconPackRefresh),
              subtitle: Text(s.iconPackRefreshHint),
              onTap: controller.isWorking ? null : controller.refresh,
            ),
          ],
        );
      },
    );
  }
}

/// The declarations a pack is recognised by, read from the platform side that
/// looks for them - so this list cannot promise support that isn't there, and
/// a pack that doesn't show up can be checked against it.
class _SupportedFormats extends StatelessWidget {
  const _SupportedFormats({required this.formats, required this.s});

  final Future<List<String>> formats;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    return FutureBuilder<List<String>>(
      future: formats,
      builder: (context, snapshot) {
        final actions = snapshot.data ?? const <String>[];
        if (actions.isEmpty) return const SizedBox.shrink();
        return ExpansionTile(
          leading: const Icon(Icons.help_outline),
          title: Text(s.iconPackFormats),
          childrenPadding: EdgeInsets.fromLTRB(
            design.spaceMd,
            0,
            design.spaceMd,
            design.spaceMd,
          ),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.iconPackFormatsHint,
              style: design.textStyle(
                TypeRole.body,
                color: design.textSecondary,
              ),
            ),
            SizedBox(height: design.spaceSm),
            for (final action in actions)
              Padding(
                padding: EdgeInsets.only(bottom: design.space2xs),
                child: Text(
                  action,
                  style: design
                      .textStyle(TypeRole.label, color: design.textPrimary)
                      .copyWith(fontFamily: 'monospace'),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The per-app pictures: how many there are, the way to set one, and the way
/// to drop them all so those apps follow the style again.
class _PickedIcons extends StatelessWidget {
  const _PickedIcons({required this.s, required this.onClear});

  final AppStrings s;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    return ValueListenableBuilder<Map<String, AppOverride>>(
      valueListenable: AppOverridesController.instance,
      builder: (context, overrides, child) {
        final count = AppOverridesController.instance.pickedIconCount;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: design.spaceMd),
              child: Text(
                s.iconStyleCustomHint,
                style: design.textStyle(
                  TypeRole.body,
                  color: design.textSecondary,
                ),
              ),
            ),
            SizedBox(height: design.spaceSm),
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: Text(s.iconPickedEdit),
              subtitle: Text(
                count == 0 ? s.iconPickedNone : s.iconPickedCount(count),
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const AppCustomizeScreen(),
                ),
              ),
            ),
            if (count > 0)
              ListTile(
                leading: const Icon(Icons.restore),
                title: Text(s.iconPickedClear),
                onTap: onClear,
              ),
          ],
        );
      },
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview();

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
          padding: context.design.pagePadding,
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
