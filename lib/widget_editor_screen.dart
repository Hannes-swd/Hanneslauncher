
/// Building one widget card, split across several files.
///
/// It is one library in [part] files rather than several libraries: nearly
/// every class here is private to it, they call each other constantly, and
/// making them public to move them apart would widen the surface of the
/// editor to the whole app for no reason anybody asked for. A part sees the
/// library's imports and its private names, so this is a move and nothing
/// else - no renaming, no new API.
///
/// What is in each:
///
///   widget_editor_screen.dart - this file: the card as a whole, its list of
///     lines, and the tile and picker for the entry a card is linked to.
///   widget_editor_element.dart - one line: its value, its look, the value
///     picker behind it.
///   widget_editor_rules.dart - an icon element's rules and their diagnosis.
///   widget_editor_pickers.dart - the small pickers several kinds share.
///   widget_editor_input.dart - an input element's own settings.
///   widget_editor_action.dart - an action element's own settings.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_icon.dart';
import 'app_strings.dart';
import 'color_swatch_picker.dart';
import 'data_sources_controller.dart';
import 'design_tokens.dart';
import 'design_widgets.dart';
import 'data_sources_settings_screen.dart';
import 'header_text_format.dart';
import 'launcher_entries_controller.dart';
import 'locale_controller.dart';
import 'panel_blocks_controller.dart';
import 'text_prompt_dialog.dart';
import 'widget_action.dart';
import 'widget_canvas_editor.dart';
import 'widget_card_view.dart';
import 'widget_element.dart';
import 'widget_input_store.dart';
import 'widget_search_service.dart';

part 'widget_editor_element.dart';
part 'widget_editor_rules.dart';
part 'widget_editor_pickers.dart';
part 'widget_editor_input.dart';
part 'widget_editor_action.dart';

/// Builds one widget card: its lines, in order, each editable on its own.
class WidgetEditorScreen extends StatelessWidget {
  const WidgetEditorScreen({super.key, required this.blockId});

  final String blockId;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LocaleController.instance,
      builder: (context, language, child) {
        final s = AppStrings(language);
        return ValueListenableBuilder<List<PanelBlock>>(
          valueListenable: PanelBlocksController.instance,
          builder: (context, blocks, child) {
            final block = PanelBlocksController.instance.byId(blockId);
            // Deleted from this very screen.
            if (block == null) return const Scaffold();

            return Scaffold(
              appBar: AppBar(
                title: Text(
                  block.title.isEmpty ? s.blockWidget : block.title,
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: s.widgetTitle,
                    onPressed: () => _rename(context, block, s),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: s.deleteBlock,
                    onPressed: () async {
                      await PanelBlocksController.instance.remove(blockId);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
              floatingActionButton: FloatingActionButton.extended(
                onPressed: () => _addElement(context, block, s),
                icon: const Icon(Icons.add),
                label: Text(s.addElement),
              ),
              body: ListView(
                padding: const EdgeInsets.only(bottom: 88),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(
                      s.preview,
                      style: TextStyle(
                        fontSize: context.design.typeLabel,
                        fontWeight: FontWeight.bold,
                        color: context.design.textSecondary,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      s.canvasHint,
                      style: TextStyle(
                        color: context.design.textSecondary,
                        fontSize: context.design.typeCaption,
                      ),
                    ),
                  ),
                  Padding(
                    padding: context.design.pagePadding,
                    child: WidgetCanvasEditor(
                      block: block,
                      onTapElement: (element) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => ElementEditorScreen(
                              blockId: block.id,
                              elementId: element.id,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      s.cardHeightLabel,
                      style: TextStyle(
                        fontSize: context.design.typeLabel,
                        fontWeight: FontWeight.bold,
                        color: context.design.textSecondary,
                      ),
                    ),
                  ),
                  Padding(
                    padding: context.design.pagePadding,
                    child: Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: Text(s.cardHeightFixed),
                          selected: !block.cardHeightFlexible,
                          onSelected: (_) => PanelBlocksController.instance
                              .update(
                                block.copyWith(cardHeightFlexible: false),
                              ),
                        ),
                        ChoiceChip(
                          label: Text(s.cardHeightFlexible),
                          selected: block.cardHeightFlexible,
                          onSelected: (_) => PanelBlocksController.instance
                              .update(
                                block.copyWith(cardHeightFlexible: true),
                              ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                    child: Text(
                      block.cardHeightFlexible
                          ? s.cardHeightFlexibleHint
                          : s.cardHeightFixedHint,
                      style: TextStyle(
                        fontSize: context.design.typeCaption,
                        color: context.design.textSecondary,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Text(
                      '${block.cardHeightFlexible ? s.cardMinHeightLabel : s.cardHeightLabel}'
                      ' (${block.cardHeight.round()})',
                      style: TextStyle(
                        fontSize: context.design.typeLabel,
                        fontWeight: FontWeight.bold,
                        color: context.design.textSecondary,
                      ),
                    ),
                  ),
                  Slider(
                    value: block.cardHeight,
                    min: 40,
                    max: 400,
                    divisions: 36,
                    onChanged: (value) => PanelBlocksController.instance
                        .update(block.copyWith(cardHeight: value)),
                  ),
                  if (block.cardHeightFlexible) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Text(
                        '${s.cardMaxHeightLabel} '
                        '(${math.max(block.cardMaxHeight, block.cardHeight).round()})',
                        style: TextStyle(
                          fontSize: context.design.typeLabel,
                          fontWeight: FontWeight.bold,
                          color: context.design.textSecondary,
                        ),
                      ),
                    ),
                    Slider(
                      // Never below the minimum - a maximum under it would
                      // read as a contradiction, and the card would only
                      // ever be the minimum anyway.
                      value: math
                          .max(block.cardMaxHeight, block.cardHeight)
                          .clamp(block.cardHeight, 600.0),
                      min: block.cardHeight,
                      max: 600,
                      onChanged: (value) => PanelBlocksController.instance
                          .update(block.copyWith(cardMaxHeight: value)),
                    ),
                  ],
                  const Divider(height: 32),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      s.openOnTap,
                      style: TextStyle(
                        fontSize: context.design.typeLabel,
                        fontWeight: FontWeight.bold,
                        color: context.design.textSecondary,
                      ),
                    ),
                  ),
                  _LinkedEntryTile(block: block, s: s),
                  const Divider(height: 32),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      s.layersHint,
                      style: TextStyle(
                        color: context.design.textSecondary,
                        fontSize: context.design.typeCaption,
                      ),
                    ),
                  ),
                  for (final element in block.elements)
                    ListTile(
                      leading: Icon(_iconFor(element.type)),
                      title: Text(
                        _summaryFor(element, s),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(_labelFor(element.type, s)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_upward),
                            onPressed: () =>
                                _move(block, element, -1),
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_downward),
                            onPressed: () => _move(block, element, 1),
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => ElementEditorScreen(
                              blockId: block.id,
                              elementId: element.id,
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static IconData _iconFor(WidgetElementType type) => switch (type) {
    WidgetElementType.text => Icons.text_fields,
    WidgetElementType.icon => Icons.emoji_symbols_outlined,
    WidgetElementType.image => Icons.image_outlined,
    WidgetElementType.box => Icons.rectangle_outlined,
    WidgetElementType.action => Icons.touch_app_outlined,
    WidgetElementType.input => Icons.edit_outlined,
    WidgetElementType.results => Icons.manage_search,
  };

  /// What the layer list shows for one element: whatever identifies it at
  /// a glance. An input element has no template at all, so its own name is
  /// the only thing that tells two of them apart.
  static String _summaryFor(WidgetElement element, AppStrings s) {
    if (element.type == WidgetElementType.input) {
      final name = element.inputName.trim();
      return name.isEmpty ? s.inputNameEmpty : name;
    }
    if (element.type == WidgetElementType.results ||
        (element.type == WidgetElementType.text &&
            element.textMode != WidgetTextMode.free)) {
      final name = element.inputName.trim();
      return name.isEmpty
          ? s.searchNoFieldYet
          : '${s.searchWatchesField}: $name';
    }
    if (element.template.isEmpty) return _labelFor(element.type, s);
    return element.template;
  }

  static String _labelFor(WidgetElementType type, AppStrings s) =>
      switch (type) {
        WidgetElementType.text => s.elementText,
        WidgetElementType.icon => s.elementIcon,
        WidgetElementType.image => s.elementImage,
        WidgetElementType.box => s.elementBox,
        WidgetElementType.action => s.elementAction,
        WidgetElementType.input => s.elementInput,
        WidgetElementType.results => s.elementResults,
      };

  /// The one line under a type's name in the add dialog. Without it the
  /// list is seven words you have to try your way through.
  static String _describes(WidgetElementType type, AppStrings s) =>
      switch (type) {
        WidgetElementType.text => s.elementTextWhat,
        WidgetElementType.icon => s.elementIconWhat,
        WidgetElementType.image => s.elementImageWhat,
        WidgetElementType.box => s.elementBoxWhat,
        WidgetElementType.action => s.elementActionWhat,
        WidgetElementType.input => s.elementInputWhat,
        WidgetElementType.results => s.elementResultsWhat,
      };

  Future<void> _rename(
    BuildContext context,
    PanelBlock block,
    AppStrings s,
  ) async {
    final title = await showDialog<String>(
      context: context,
      builder: (context) => TextPromptDialog(
        title: s.widgetTitle,
        label: s.widgetTitle,
        initialValue: block.title,
        s: s,
      ),
    );
    if (title == null) return;
    await PanelBlocksController.instance.update(
      block.copyWith(title: title.trim()),
    );
  }

  Future<void> _addElement(
    BuildContext context,
    PanelBlock block,
    AppStrings s,
  ) async {
    final type = await showDialog<WidgetElementType>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: Text(s.addElement),
          children: [
            for (final type in WidgetElementType.values)
              SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop(type),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(_iconFor(type)),
                  title: Text(_labelFor(type, s)),
                  subtitle: Text(
                    _describes(type, s),
                    style: TextStyle(fontSize: context.design.typeCaption),
                  ),
                ),
              ),
          ],
        );
      },
    );
    if (type == null || !context.mounted) return;

    var rules = const <IconRule>[];
    var template = '';
    if (type == WidgetElementType.icon) {
      final useWeatherTemplate = await showDialog<bool>(
        context: context,
        builder: (context) {
          return SimpleDialog(
            title: Text(s.iconTemplateTitle),
            children: [
              SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop(true),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.wb_sunny_outlined),
                  title: Text(s.weatherIconTemplate),
                  subtitle: Text(s.weatherIconTemplateHint),
                ),
              ),
              SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop(false),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.rule_outlined),
                  title: Text(s.ownRules),
                ),
              ),
            ],
          );
        },
      );
      if (!context.mounted) return;
      if (useWeatherTemplate == true) {
        rules = weatherWmoRules;
        final key = DataSourcesController.instance.weatherSourceKey();
        if (key != null) template = '{{$key.current.weather_code}}';
      } else {
        // A fresh icon element without rules would always show the fallback
        // glyph, so it starts with one catch-all rule to edit.
        rules = const [IconRule(iconName: 'sunny')];
      }
    } else if (type == WidgetElementType.action) {
      // Otherwise the button would start out on the generic fallback glyph.
      template = 'power';
    }

    final element = WidgetElement(
      id: _newElementId(block),
      type: type,
      template: template,
      rules: rules,
      // A field nothing can reference is useless, and an empty name is the
      // one state that can't be referenced - so it starts out named.
      inputName: switch (type) {
        // A field nothing can reference is useless, and an empty name is
        // the one state that can't be referenced.
        WidgetElementType.input => _newInputName(block, s),
        // Pointed at whatever field already exists, so a search element
        // dropped next to a field works without being configured first.
        WidgetElementType.results =>
          WidgetInputStore.instance.names.firstOrNull ?? '',
        _ => '',
      },
      // A search that finds nothing on the web is half a search, and
      // picking the engine is exactly the sort of thing this should not
      // make anybody do before it works once.
      webSearchUrl: type == WidgetElementType.results
          ? webSearchPresets.values.first
          : '',
    );
    await PanelBlocksController.instance.update(
      block.copyWith(elements: [...block.elements, element]),
    );
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ElementEditorScreen(
          blockId: block.id,
          elementId: element.id,
        ),
      ),
    );
  }

  /// "feld1", "feld2", ... - counting past whatever is taken, across the
  /// whole panel rather than this card alone, since the names all share one
  /// namespace.
  static String _newInputName(PanelBlock block, AppStrings s) {
    final taken = WidgetInputStore.instance.names.toSet();
    final stem = s.language == AppLanguage.en ? 'field' : 'feld';
    var index = 1;
    while (taken.contains('$stem$index')) {
      index++;
    }
    return '$stem$index';
  }

  /// Ids are the creation time; two lines added in the same microsecond
  /// would otherwise be edited together. Step past anything taken.
  static String _newElementId(PanelBlock block) {
    var stamp = DateTime.now().microsecondsSinceEpoch;
    while (block.elements.any((element) => element.id == stamp.toString())) {
      stamp++;
    }
    return stamp.toString();
  }

  Future<void> _move(PanelBlock block, WidgetElement element, int by) async {
    final elements = [...block.elements];
    final index = elements.indexWhere((e) => e.id == element.id);
    final target = index + by;
    if (index < 0 || target < 0 || target >= elements.length) return;
    elements.removeAt(index);
    elements.insert(target, element);
    await PanelBlocksController.instance.update(
      block.copyWith(elements: elements),
    );
  }
}

/// Shows what the card opens when tapped, if anything, and leads to the
/// picker that changes it.
class _LinkedEntryTile extends StatelessWidget {
  const _LinkedEntryTile({required this.block, required this.s});

  final PanelBlock block;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LauncherEntriesController.instance,
      builder: (context, child) {
        final entry = LauncherEntriesController.instance
            .resolve([block.linkedKey])
            .firstOrNull;
        return ListTile(
          contentPadding: context.design.pagePadding,
          leading: entry == null
              ? Icon(Icons.touch_app_outlined, color: context.design.textMuted)
              : AppIcon(entry: entry, size: 36),
          title: Text(entry?.name ?? s.openOnTapNone),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            final key = await Navigator.of(context).push<String>(
              MaterialPageRoute(
                builder: (context) => _LinkedEntryPicker(s: s),
              ),
            );
            if (key == null) return;
            await PanelBlocksController.instance.update(
              block.copyWith(linkedKey: key),
            );
          },
        );
      },
    );
  }
}

/// Picks the single app, web app or folder a widget card opens when tapped.
/// Pops with the chosen key, or an empty string to clear the link.
class _LinkedEntryPicker extends StatelessWidget {
  const _LinkedEntryPicker({required this.s});

  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LauncherEntriesController.instance,
      builder: (context, child) {
        if (!LauncherEntriesController.instance.isLoaded) {
          return Scaffold(
            appBar: AppBar(title: Text(s.linkPickerTitle)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        // Folders and web apps first: there are only a handful of them and
        // they'd be tedious to find among hundreds of packages otherwise.
        final all = LauncherEntriesController.instance.entries;
        final entries = [
          for (final entry in all)
            if (entry.isFolder) entry,
          for (final entry in all)
            if (entry.isWebApp) entry,
          for (final entry in all)
            if (!entry.isFolder && !entry.isWebApp) entry,
        ];

        return Scaffold(
          appBar: AppBar(title: Text(s.linkPickerTitle)),
          body: ListView(
            children: [
              ListTile(
                leading: Icon(Icons.block, color: context.design.textMuted),
                title: Text(s.openOnTapNone),
                onTap: () => Navigator.of(context).pop(''),
              ),
              const Divider(height: 1),
              for (final entry in entries)
                ListTile(
                  leading: AppIcon(entry: entry, size: 36),
                  title: Text(entry.name),
                  onTap: () => Navigator.of(context).pop(entry.key),
                ),
            ],
          ),
        );
      },
    );
  }
}
