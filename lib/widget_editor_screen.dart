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

/// Everything about a single line: its value, its look, and - for an icon -
/// the rules that decide which glyph is shown.
class ElementEditorScreen extends StatelessWidget {
  const ElementEditorScreen({
    super.key,
    required this.blockId,
    required this.elementId,
  });

  final String blockId;
  final String elementId;

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
            final element = block?.elements
                .where((e) => e.id == elementId)
                .firstOrNull;
            if (block == null || element == null) return const Scaffold();

            return Scaffold(
              appBar: AppBar(
                title: Text(WidgetEditorScreen._labelFor(element.type, s)),
                actions: [
                  if (element.type == WidgetElementType.icon)
                    IconButton(
                      icon: const Icon(Icons.auto_awesome),
                      tooltip: s.insertWeatherTemplate,
                      onPressed: () =>
                          _insertWeatherTemplate(context, block, element, s),
                    ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: s.deleteBlock,
                    onPressed: () async {
                      await _save(
                        block,
                        [
                          for (final e in block.elements)
                            if (e.id != elementId) e,
                        ],
                      );
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Where a text element's line comes from. First, because
                  // it decides whether the value field below applies at all.
                  if (element.type == WidgetElementType.text) ...[
                    FieldLabel(s.textModeLabel),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final mode in WidgetTextMode.values)
                          ChoiceChip(
                            label: Text(switch (mode) {
                              WidgetTextMode.free => s.textModeFree,
                              WidgetTextMode.inputValue => s.textModeInputValue,
                              WidgetTextMode.calculation =>
                                s.textModeCalculation,
                            }),
                            selected: element.textMode == mode,
                            onSelected: (_) => _update(
                              block,
                              element.copyWith(
                                textMode: mode,
                                // Pointed at a field straight away, so
                                // switching mode shows something rather
                                // than nothing until a field is picked.
                                inputName: element.inputName.isEmpty
                                    ? (WidgetInputStore
                                              .instance
                                              .names
                                              .firstOrNull ??
                                          '')
                                    : element.inputName,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (element.textMode != WidgetTextMode.free) ...[
                      const SizedBox(height: 12),
                      _InputFieldPicker(
                        element: element,
                        s: s,
                        onChanged: (updated) => _update(block, updated),
                      ),
                      if (element.textMode == WidgetTextMode.calculation)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            s.textModeCalculationHint,
                            style: TextStyle(
                              fontSize: context.design.typeCaption,
                              color: context.design.textSecondary,
                            ),
                          ),
                        ),
                    ],
                    const SizedBox(height: 24),
                  ],

                  if (element.type == WidgetElementType.results) ...[
                    _ResultsSettings(
                      element: element,
                      s: s,
                      onChanged: (updated) => _update(block, updated),
                    ),
                    const SizedBox(height: 24),
                    FieldLabel('${s.widthShort} '
                        '(${element.width.round()})'),
                    Slider(
                      value: element.width,
                      min: 80,
                      max: 500,
                      divisions: 42,
                      onChanged: (value) => _update(
                        block,
                        element.copyWith(width: value),
                      ),
                    ),
                    FieldLabel('${s.searchMaxHeight} '
                        '(${element.height.round()})'),
                    Slider(
                      value: element.height,
                      min: 40,
                      max: 500,
                      divisions: 46,
                      onChanged: (value) => _update(
                        block,
                        element.copyWith(height: value),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        s.searchMaxHeightHint,
                        style: TextStyle(
                          fontSize: context.design.typeCaption,
                          color: context.design.textSecondary,
                        ),
                      ),
                    ),
                  ],

                  // A box draws nothing but itself, an action has its own
                  // icon picker below instead of a `{{...}}` value, an input
                  // field has no value at all, and the results list reads
                  // its field rather than a template. A text element only
                  // has one while it is written by hand.
                  if (element.type != WidgetElementType.box &&
                      element.type != WidgetElementType.action &&
                      element.type != WidgetElementType.input &&
                      element.type != WidgetElementType.results &&
                      !(element.type == WidgetElementType.text &&
                          element.textMode != WidgetTextMode.free)) ...[
                    FieldLabel(
                      element.type == WidgetElementType.image
                          ? s.sourceUrl
                          : s.elementValue,
                    ),
                    _TemplateField(
                      key: ValueKey(element.id),
                      element: element,
                      s: s,
                      onChanged: (template) => _update(
                        block,
                        element.copyWith(template: template),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  if (element.type == WidgetElementType.input) ...[
                    _InputSettings(
                      key: ValueKey(element.id),
                      block: block,
                      element: element,
                      s: s,
                      onChanged: (updated) => _update(block, updated),
                    ),
                    const SizedBox(height: 24),
                    FieldLabel('${s.widthShort} '
                        '(${element.width.round()})'),
                    Slider(
                      value: element.width,
                      min: 60,
                      max: 500,
                      divisions: 44,
                      onChanged: (value) => _update(
                        block,
                        element.copyWith(width: value),
                      ),
                    ),
                  ],

                  if (element.type == WidgetElementType.text ||
                      element.type == WidgetElementType.input ||
                      element.type == WidgetElementType.results) ...[
                    FieldLabel('${s.textSizeShort} '
                        '(${element.fontSize.round()})'),
                    Slider(
                      value: element.fontSize,
                      min: 10,
                      max: 64,
                      divisions: 27,
                      onChanged: (value) => _update(
                        block,
                        element.copyWith(fontSize: value),
                      ),
                    ),
                  ],

                  if (element.type == WidgetElementType.text) ...[
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(s.boldLabel),
                      value: element.bold,
                      onChanged: (value) => _update(
                        block,
                        element.copyWith(bold: value),
                      ),
                    ),
                  ],

                  if (element.type == WidgetElementType.icon ||
                      element.type == WidgetElementType.action) ...[
                    FieldLabel('${s.iconSizeShort} '
                        '(${element.iconSize.round()})'),
                    Slider(
                      value: element.iconSize,
                      min: 16,
                      max: 96,
                      divisions: 20,
                      onChanged: (value) => _update(
                        block,
                        element.copyWith(iconSize: value),
                      ),
                    ),
                  ],

                  if (element.type == WidgetElementType.image ||
                      element.type == WidgetElementType.box) ...[
                    FieldLabel('${s.heightShort} '
                        '(${element.height.round()})'),
                    Slider(
                      value: element.height,
                      min: 20,
                      max: 400,
                      divisions: 38,
                      onChanged: (value) => _update(
                        block,
                        element.copyWith(height: value),
                      ),
                    ),
                    FieldLabel('${s.widthShort} '
                        '(${element.width.round()})'),
                    Slider(
                      value: element.width,
                      min: 20,
                      max: 500,
                      divisions: 48,
                      onChanged: (value) => _update(
                        block,
                        element.copyWith(width: value),
                      ),
                    ),
                    FieldLabel('${s.radiusShort} '
                        '(${element.radius.round()})'),
                    Slider(
                      value: element.radius,
                      min: 0,
                      max: 40,
                      divisions: 20,
                      onChanged: (value) => _update(
                        block,
                        element.copyWith(radius: value),
                      ),
                    ),
                  ],

                  if (element.type == WidgetElementType.box) ...[
                    FieldLabel('${s.opacityShort} '
                        '(${(element.opacity * 100).round()}%)'),
                    Slider(
                      value: element.opacity,
                      min: 0,
                      max: 1,
                      divisions: 20,
                      onChanged: (value) => _update(
                        block,
                        element.copyWith(opacity: value),
                      ),
                    ),
                    FieldLabel(s.colorLabel),
                    ColorSwatchPicker(
                      s: s,
                      selectedIndex: element.colorIndex,
                      onSelected: (i) => _update(
                        block,
                        element.copyWith(colorIndex: i),
                      ),
                    ),
                  ],

                  if (element.type == WidgetElementType.text ||
                      element.type == WidgetElementType.icon ||
                      element.type == WidgetElementType.input ||
                      element.type == WidgetElementType.results) ...[
                    const SizedBox(height: 8),
                    FieldLabel(s.alignLabel),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final alignment in WidgetAlignment.values)
                          ChoiceChip(
                            label: Icon(
                              switch (alignment) {
                                WidgetAlignment.left => Icons.format_align_left,
                                WidgetAlignment.center =>
                                  Icons.format_align_center,
                                WidgetAlignment.right =>
                                  Icons.format_align_right,
                              },
                              size: 18,
                            ),
                            selected: element.alignment == alignment,
                            onSelected: (_) => _update(
                              block,
                              element.copyWith(alignment: alignment),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    FieldLabel(s.colorLabel),
                    ColorSwatchPicker(
                      s: s,
                      selectedIndex: element.colorIndex,
                      onSelected: (i) => _update(
                        block,
                        element.copyWith(colorIndex: i),
                      ),
                    ),
                  ],

                  if (element.type == WidgetElementType.action) ...[
                    FieldLabel(s.iconLabel),
                    _IconPicker(
                      selected: element.template,
                      onSelected: (iconName) => _update(
                        block,
                        element.copyWith(template: iconName),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FieldLabel(s.colorLabel),
                    ColorSwatchPicker(
                      s: s,
                      selectedIndex: element.colorIndex,
                      onSelected: (i) => _update(
                        block,
                        element.copyWith(colorIndex: i),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _ActionSettings(
                      key: ValueKey(element.id),
                      element: element,
                      s: s,
                      onChanged: (updated) => _update(block, updated),
                    ),
                  ],

                  if (element.type == WidgetElementType.icon)
                    _RuleDiagnosis(
                      key: ValueKey(element.id),
                      element: element,
                      s: s,
                      block: block,
                    ),

                  const SizedBox(height: 24),
                  FieldLabel(s.preview),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.design.fillSubtle,
                      borderRadius: BorderRadius.circular(
                        context.design.radiusMedium,
                      ),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) => WidgetElementView(
                        element: element,
                        cardWidth: constraints.maxWidth,
                        interactive: false,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _update(PanelBlock block, WidgetElement element) {
    return _save(block, [
      for (final e in block.elements)
        if (e.id == element.id) element else e,
    ]);
  }

  Future<void> _save(PanelBlock block, List<WidgetElement> elements) {
    return PanelBlocksController.instance.update(
      block.copyWith(elements: elements),
    );
  }

  Future<void> _insertWeatherTemplate(
    BuildContext context,
    PanelBlock block,
    WidgetElement element,
    AppStrings s,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(s.insertWeatherTemplate),
          content: Text(s.replaceRulesConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(s.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(s.insertWeatherTemplate),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) return;

    final key = DataSourcesController.instance.weatherSourceKey();
    await _update(
      block,
      element.copyWith(
        rules: weatherWmoRules,
        // Only filled in when it isn't already pointing somewhere - the
        // rules are what's actually broken here, the value field may
        // already be correct.
        template: element.template.trim().isEmpty && key != null
            ? '{{$key.current.weather_code}}'
            : element.template,
      ),
    );
    if (key == null && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.noWeatherSourceHint)));
    }
  }
}

/// The element's template, with a button that appends a placeholder picked
/// from a live API response instead of making anyone type JSON paths.
class _TemplateField extends StatefulWidget {
  const _TemplateField({
    super.key,
    required this.element,
    required this.s,
    required this.onChanged,
  });

  final WidgetElement element;
  final AppStrings s;
  final ValueChanged<String> onChanged;

  @override
  State<_TemplateField> createState() => _TemplateFieldState();
}

class _TemplateFieldState extends State<_TemplateField> {
  late final TextEditingController _field = TextEditingController(
    text: widget.element.template,
  );

  @override
  void initState() {
    super.initState();
    // A source that has never been fetched contributes no values, so the
    // list below would be missing exactly the one just set up.
    DataSourcesController.instance.refreshStale();
  }

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  /// Inserts at the cursor rather than at the end, so a placeholder can be
  /// dropped into the middle of an existing line.
  void _insert(String placeholder) {
    final selection = _field.selection;
    final text = _field.text;
    final at = selection.isValid ? selection.start : text.length;
    _field.text = text.replaceRange(at, selection.end.clamp(at, text.length),
        placeholder);
    _field.selection = TextSelection.collapsed(
      offset: at + placeholder.length,
    );
    widget.onChanged(_field.text);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _field,
          maxLines: null,
          decoration: InputDecoration(
            hintText: widget.element.type == WidgetElementType.image
                ? 'https://…'
                : '{{${DataSourcesController.displayKey('zeit')}}} · '
                      '{{${LocaleController.instance.value == AppLanguage.en
                          ? 'weather'
                          : 'wetter'}.current.temperature_2m}} °C',
          ),
          // Persisting synchronously from inside onChanged rebuilds this
          // whole screen mid-keystroke, which on some keyboards drops the
          // field's focus entirely. A microtask defers it to just after the
          // keyboard is done handling this one keystroke.
          onChanged: (value) => Future.microtask(() => widget.onChanged(value)),
        ),
        const SizedBox(height: 8),
        _ValueDropdown(s: widget.s, onPick: _insert),
      ],
    );
  }
}

/// Every value that can go into the line right now - the built-in ones plus
/// whatever the sources last returned - each with the value it currently
/// holds, filterable by typing. Tapping one inserts its placeholder.
class _ValueDropdown extends StatelessWidget {
  const _ValueDropdown({
    required this.s,
    required this.onPick,
    this.onlyBoolean = false,
    this.urlEncodeInputs = false,
  });

  final AppStrings s;
  final ValueChanged<String> onPick;

  /// Inserts an input field's placeholder with the `|url` modifier. Set
  /// where the text being built is an address, which is the only place the
  /// difference matters - and the one place forgetting it silently breaks
  /// the result as soon as somebody types a space.
  final bool urlEncodeInputs;

  /// Restricts the list to values that resolve to exactly "true"/"false"
  /// right now - used for the toggle action's "current value" field, where
  /// anything else (a temperature, a clock) could never be a usable pick.
  final bool onlyBoolean;

  // Not a placeholder, so it can never collide with a real entry.
  static const _addEntry = '+';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DataSourcesController.instance,
      builder: (context, child) {
        final allOptions = DataSourcesController.instance.options();
        final options = onlyBoolean
            ? [
                for (final option in allOptions)
                  if (const {
                    'true',
                    'false',
                  }.contains(option.preview.trim().toLowerCase()))
                    option,
              ]
            : allOptions;
        return PopupMenuButton<String>(
          tooltip: s.availableValues,
          position: PopupMenuPosition.under,
          // Tall enough to scan, and the menu scrolls past that on its own.
          constraints: const BoxConstraints(
            minWidth: 280,
            maxWidth: 400,
            maxHeight: 420,
          ),
          onSelected: (selected) {
            if (selected == _addEntry) {
              addDataSource(context, s);
            } else {
              onPick(selected);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: _addEntry,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(Icons.add),
                title: Text(s.addDataSource),
              ),
            ),
            const PopupMenuDivider(),
            if (onlyBoolean && options.isEmpty)
              PopupMenuItem(
                enabled: false,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    s.actionToggleSourceNoneYet,
                    style: TextStyle(fontSize: context.design.typeCaption),
                  ),
                ),
              ),
            for (final option in options)
              PopupMenuItem(
                value: urlEncodeInputs && option.isInput
                    ? option.placeholder.replaceFirst('}}', '|url}}')
                    : option.placeholder,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(option.label),
                  // The value as it stands right now, so the right entry can
                  // be picked by looking rather than by guessing the name.
                  subtitle: Text(
                    option.sourceName == null
                        ? option.preview
                        : '${option.sourceName} · ${option.preview}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          ],
          child: InputDecorator(
            decoration: const InputDecoration(isDense: true),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    s.availableValues,
                    style: TextStyle(color: context.design.textSecondary),
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  color: context.design.textSecondary,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Says what the icon element is working with right now: the value its
/// placeholder currently yields, and which rule - if any - catches it. A
/// question mark on the card otherwise gives no clue whether the value is
/// missing or simply uncovered by the rules.
///
/// Also lets a value be typed in and checked directly against the rules,
/// bypassing the placeholder entirely - the only way to tell apart "the
/// fetched value isn't what I expect" from "my rule doesn't cover the value
/// it clearly should".
class _RuleDiagnosis extends StatefulWidget {
  const _RuleDiagnosis({
    super.key,
    required this.element,
    required this.s,
    required this.block,
  });

  final WidgetElement element;
  final AppStrings s;
  final PanelBlock block;

  @override
  State<_RuleDiagnosis> createState() => _RuleDiagnosisState();
}

class _RuleDiagnosisState extends State<_RuleDiagnosis> {
  final TextEditingController _test = TextEditingController();

  @override
  void dispose() {
    _test.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return ListenableBuilder(
      listenable: DataSourcesController.instance,
      builder: (context, child) {
        final liveValue = DataSourcesController.instance.resolve(
          widget.element.template,
        );
        final testing = _test.text.trim().isNotEmpty;
        final value = testing ? _test.text.trim() : liveValue;

        final matches = widget.element.rules.where(
          (rule) => rule.matches(value),
        );
        // A dash is what a placeholder that leads nowhere resolves to.
        final missing = value.trim().isEmpty || value.trim() == '-';

        return Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.design.fillSubtle,
              borderRadius: BorderRadius.circular(context.design.radiusMedium),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.currentValue(liveValue)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      matches.isEmpty
                          ? Icons.warning_amber
                          : widgetIcons[matches.first.iconName] ??
                                Icons.help_outline,
                      size: 18,
                      color: matches.isEmpty
                          ? Colors.orange
                          : context.design.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        matches.isNotEmpty
                            ? s.ruleMatches(matches.first.iconName)
                            : missing
                            ? s.valueMissing
                            : s.noRuleMatches,
                        style: TextStyle(color: context.design.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _test,
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: s.testAnotherValue,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                _Rules(
                  block: widget.block,
                  element: widget.element,
                  s: s,
                  testValue: value,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The icon element's rules: first match wins, so the order is the priority.
/// Checked against [testValue] - either the live resolved value, or one
/// typed into the diagnosis box above to test a rule directly.
class _Rules extends StatelessWidget {
  const _Rules({
    required this.block,
    required this.element,
    required this.s,
    required this.testValue,
  });

  final PanelBlock block;
  final WidgetElement element;
  final AppStrings s;
  final String testValue;

  @override
  Widget build(BuildContext context) {
    final value = testValue;
    // Only the first match counts, so later ones are marked as shadowed
    // rather than as matching - otherwise two ticks would suggest both are
    // in play.
    var alreadyMatched = false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        FieldLabel(s.rulesLabel),
        for (var i = 0; i < element.rules.length; i++)
          Builder(
            builder: (context) {
              final matches = element.rules[i].matches(value);
              final effective = matches && !alreadyMatched;
              alreadyMatched = alreadyMatched || matches;
              return _RuleRow(
                rule: element.rules[i],
                s: s,
                matches: matches,
                effective: effective,
                testValue: value,
                onChanged: (rule) => _replace(i, rule),
                onRemove: () => _replace(i, null),
              );
            },
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _append(context),
            icon: const Icon(Icons.add),
            label: Text(s.addRule),
          ),
        ),
      ],
    );
  }

  Future<void> _append(BuildContext context) async {
    // Straight into editing it, with the test value already in hand -
    // adding a rule and then finding out separately whether it matches is
    // two steps for something that should be one.
    final created = await showDialog<IconRule>(
      context: context,
      builder: (context) => _RuleDialog(
        rule: const IconRule(iconName: 'sunny'),
        s: s,
        testValue: testValue,
      ),
    );
    if (created == null) return;
    await _write([...element.rules, created]);
  }

  Future<void> _replace(int index, IconRule? rule) {
    final rules = [...element.rules];
    if (rule == null) {
      rules.removeAt(index);
    } else {
      rules[index] = rule;
    }
    return _write(rules);
  }

  Future<void> _write(List<IconRule> rules) {
    return PanelBlocksController.instance.update(
      block.copyWith(
        elements: [
          for (final e in block.elements)
            if (e.id == element.id) e.copyWith(rules: rules) else e,
        ],
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({
    required this.rule,
    required this.s,
    required this.matches,
    required this.effective,
    required this.testValue,
    required this.onChanged,
    required this.onRemove,
  });

  final IconRule rule;
  final AppStrings s;

  /// Carried into the edit dialog, so it can show right away whether the
  /// range being typed would match - without saving first to find out.
  final String testValue;

  /// Whether the value as it stands falls under this rule, and whether this
  /// is the rule that actually decides - an earlier one may have won.
  final bool matches;
  final bool effective;

  final ValueChanged<IconRule> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final range = [
      if (rule.min != null) '${s.ruleFrom} ${_short(rule.min!)}',
      if (rule.max != null) '${s.ruleTo} ${_short(rule.max!)}',
      if (rule.equals != null && rule.equals!.isNotEmpty)
        '${s.ruleEquals} ${rule.equals}',
    ];
    // A crossed range (e.g. "from 3 to 2") never matches anything - easy to
    // create by a typo and, glanced at quickly, easy to mistake for a
    // sensible range.
    final inverted =
        rule.min != null && rule.max != null && rule.min! > rule.max!;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(widgetIcons[rule.iconName] ?? Icons.help_outline),
      title: Text(range.isEmpty ? s.ruleAny : range.join(', ')),
      subtitle: inverted
          ? Text(
              s.rangeInverted,
              style: const TextStyle(color: Colors.red),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (matches)
            Icon(
              effective ? Icons.check_circle : Icons.check_circle_outline,
              size: 18,
              color: effective ? Colors.green : context.design.border,
            ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: onRemove,
          ),
        ],
      ),
      onTap: () => _edit(context),
    );
  }

  static String _short(double value) =>
      value == value.roundToDouble() ? '${value.round()}' : '$value';

  Future<void> _edit(BuildContext context) async {
    final updated = await showDialog<IconRule>(
      context: context,
      builder: (context) =>
          _RuleDialog(rule: rule, s: s, testValue: testValue),
    );
    if (updated != null) onChanged(updated);
  }
}

/// What a rule's live test value looks like, so the dialog only shows the
/// input that actually applies to it.
enum _ValueKind { unknown, boolean, numeric, text }

class _RuleDialog extends StatefulWidget {
  const _RuleDialog({
    required this.rule,
    required this.s,
    required this.testValue,
  });

  final IconRule rule;
  final AppStrings s;
  final String testValue;

  @override
  State<_RuleDialog> createState() => _RuleDialogState();
}

class _RuleDialogState extends State<_RuleDialog> {
  late final TextEditingController _min = TextEditingController(
    text: widget.rule.min?.toString() ?? '',
  );
  late final TextEditingController _max = TextEditingController(
    text: widget.rule.max?.toString() ?? '',
  );
  late final TextEditingController _equals = TextEditingController(
    text: widget.rule.equals ?? '',
  );
  late String _iconName = widget.rule.iconName;

  @override
  void initState() {
    super.initState();
    for (final field in [_min, _max, _equals]) {
      field.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    _equals.dispose();
    super.dispose();
  }

  /// The rule as it stands in the fields right now, saved or not - so
  /// whether it would match can be shown immediately.
  IconRule get _draftRule {
    final equals = _equals.text.trim();
    return IconRule(
      min: double.tryParse(_min.text.trim()),
      max: double.tryParse(_max.text.trim()),
      equals: equals.isEmpty ? null : equals,
      iconName: _iconName,
    );
  }

  static final _numberPattern = RegExp(r'-?\d+([.,]\d+)?');

  /// What kind of value is actually being matched, going only off the live
  /// test value - a numeric range makes no sense for "true"/"false" or for
  /// arbitrary text like a connection type, so those get a simpler field
  /// instead of every input shown regardless of whether it applies.
  /// Unknown (nothing to test against yet) keeps every field, since there's
  /// no way to tell which one is wanted.
  _ValueKind get _valueKind {
    final value = widget.testValue.trim();
    if (value.isEmpty) return _ValueKind.unknown;
    final lower = value.toLowerCase();
    if (lower == 'true' || lower == 'false') return _ValueKind.boolean;
    if (_numberPattern.hasMatch(value)) return _ValueKind.numeric;
    return _ValueKind.text;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final draft = _draftRule;
    final inverted =
        draft.min != null && draft.max != null && draft.min! > draft.max!;
    final hasTestValue = widget.testValue.trim().isNotEmpty;
    final matches = hasTestValue && draft.matches(widget.testValue);
    final kind = _valueKind;
    final showRange =
        kind == _ValueKind.unknown || kind == _ValueKind.numeric;
    final showBooleanChoice = kind == _ValueKind.boolean;

    return AlertDialog(
      title: Text(s.addRule),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasTestValue)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(
                      matches ? Icons.check_circle : Icons.cancel_outlined,
                      size: 18,
                      color: matches ? Colors.green : context.design.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.currentValue(widget.testValue),
                        style: TextStyle(color: context.design.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            if (showRange) ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _min,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: s.ruleFrom),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _max,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: s.ruleTo),
                    ),
                  ),
                ],
              ),
              if (inverted)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    s.rangeInverted,
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: context.design.typeCaption,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
            ],
            if (showBooleanChoice)
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(s.ruleTrue),
                    selected: _equals.text.trim().toLowerCase() == 'true',
                    onSelected: (_) => setState(() => _equals.text = 'true'),
                  ),
                  ChoiceChip(
                    label: Text(s.ruleFalse),
                    selected: _equals.text.trim().toLowerCase() == 'false',
                    onSelected: (_) => setState(() => _equals.text = 'false'),
                  ),
                ],
              )
            else
              TextField(
                controller: _equals,
                decoration: InputDecoration(labelText: s.ruleEquals),
              ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in widgetIcons.entries)
                  GestureDetector(
                    onTap: () => setState(() => _iconName = entry.key),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          context.design.radiusSmall,
                        ),
                        border: Border.all(
                          color: entry.key == _iconName
                              ? context.design.accent
                              : context.design.border,
                          width: entry.key == _iconName ? 2 : 1,
                        ),
                      ),
                      child: Icon(entry.value),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(draft),
          child: Text(s.save),
        ),
      ],
    );
  }
}

/// The icon grid an action element picks its glyph from - same look as the
/// icon rule dialog's, just standalone since an action has no rules to sit
/// inside.
class _IconPicker extends StatelessWidget {
  const _IconPicker({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in widgetIcons.entries)
          GestureDetector(
            onTap: () => onSelected(entry.key),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(context.design.radiusSmall),
                border: Border.all(
                  color: entry.key == selected
                      ? context.design.accent
                      : context.design.border,
                  width: entry.key == selected ? 2 : 1,
                ),
              ),
              child: Icon(entry.value),
            ),
          ),
      ],
    );
  }
}

/// What an action element's tap sends: address, method, headers and (for
/// anything but GET) a body - plus a "Test" button that fires it once right
/// away, the only way to know it actually reaches the device before relying
/// on it from the home screen.
/// Picks which input field an element follows, from the ones that exist.
/// A dropdown rather than a typed name: this is the whole point of not
/// having to know that `{{eingabe.feld1}}` is a thing.
class _InputFieldPicker extends StatelessWidget {
  const _InputFieldPicker({
    required this.element,
    required this.s,
    required this.onChanged,
  });

  final WidgetElement element;
  final AppStrings s;
  final ValueChanged<WidgetElement> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: WidgetInputStore.instance,
      builder: (context, child) {
        final names = WidgetInputStore.instance.names;
        if (names.isEmpty) {
          return Text(
            s.searchNoFieldYet,
            style: TextStyle(
              color: Colors.red,
              fontSize: context.design.typeCaption,
            ),
          );
        }
        final current = WidgetInputStore.normalizeName(element.inputName);
        return DropdownButtonFormField<String>(
          // A field that was deleted or renamed leaves the element pointing
          // at a name that is no longer in the list, and a dropdown whose
          // value isn't among its items throws.
          initialValue: names.contains(current) ? current : null,
          decoration: InputDecoration(
            labelText: s.searchWatchesField,
            helperText: s.searchWatchesFieldHint,
            helperMaxLines: 3,
          ),
          items: [
            for (final name in names)
              DropdownMenuItem(value: name, child: Text(name)),
          ],
          onChanged: (name) {
            if (name == null) return;
            onChanged(element.copyWith(inputName: name));
          },
        );
      },
    );
  }
}

/// Everything a search element does, as tick boxes and one dropdown - no
/// address to type, no placeholder to know.
class _ResultsSettings extends StatelessWidget {
  const _ResultsSettings({
    required this.element,
    required this.s,
    required this.onChanged,
  });

  final WidgetElement element;
  final AppStrings s;
  final ValueChanged<WidgetElement> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InputFieldPicker(element: element, s: s, onChanged: onChanged),
        const SizedBox(height: 20),

        FieldLabel(s.searchSourcesLabel),
        _sourceTile(
          title: s.searchSourceApps,
          subtitle: s.searchSourceAppsHint,
          value: element.searchApps,
          onChanged: (v) => onChanged(element.copyWith(searchApps: v)),
        ),
        _sourceTile(
          title: s.searchSourceSettings,
          subtitle: s.searchSourceSettingsHint,
          value: element.searchSettings,
          onChanged: (v) => onChanged(element.copyWith(searchSettings: v)),
        ),
        _sourceTile(
          title: s.searchSourceCalculation,
          subtitle: s.searchSourceCalculationHint,
          value: element.searchCalculation,
          onChanged: (v) => onChanged(element.copyWith(searchCalculation: v)),
        ),
        _sourceTile(
          title: s.searchSourceContacts,
          subtitle: s.searchSourceContactsHint,
          value: element.searchContacts,
          onChanged: (v) => onChanged(element.copyWith(searchContacts: v)),
        ),
        const SizedBox(height: 20),

        FieldLabel(s.searchWebLabel),
        _WebSearchPicker(
          element: element,
          s: s,
          onChanged: onChanged,
          allowNone: true,
        ),
        const SizedBox(height: 20),

        FieldLabel(
          '${s.searchResultLimit} (${element.resultLimit})',
        ),
        Slider(
          value: element.resultLimit.toDouble(),
          min: 1,
          max: 8,
          divisions: 7,
          onChanged: (value) =>
              onChanged(element.copyWith(resultLimit: value.round())),
        ),
      ],
    );
  }

  Widget _sourceTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      dense: true,
      title: Text(title),
      subtitle: Builder(
        builder: (context) => Text(
          subtitle,
          style: TextStyle(fontSize: context.design.typeCaption),
        ),
      ),
      value: value,
      onChanged: (v) => onChanged(v ?? false),
    );
  }
}

/// Picks the search engine, from presets plus a hand-typed escape hatch.
/// Shared by the search element and the search button, so the two can never
/// offer a different list.
class _WebSearchPicker extends StatelessWidget {
  const _WebSearchPicker({
    required this.element,
    required this.s,
    required this.onChanged,
    required this.allowNone,
  });

  final WidgetElement element;
  final AppStrings s;
  final ValueChanged<WidgetElement> onChanged;

  /// True on the results element, where the web row is one pile among
  /// several and can be left out. False on a search button, where "no
  /// engine" would leave a button that does nothing at all.
  final bool allowNone;

  static const _ownAddress = '#own';
  static const _noWeb = '#none';

  /// Which preset the stored address is, or null when it is a hand-typed
  /// one - which is what puts the dropdown on "own address".
  String? get _presetName {
    for (final entry in webSearchPresets.entries) {
      if (entry.value == element.webSearchUrl) return entry.key;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final url = element.webSearchUrl.trim();
    final custom = url.isNotEmpty && _presetName == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: url.isEmpty
              ? (allowNone ? _noWeb : null)
              : (_presetName ?? _ownAddress),
          items: [
            if (allowNone)
              DropdownMenuItem(value: _noWeb, child: Text(s.searchWebNone)),
            for (final name in webSearchPresets.keys)
              DropdownMenuItem(value: name, child: Text(name)),
            DropdownMenuItem(value: _ownAddress, child: Text(s.searchWebOwn)),
          ],
          onChanged: (choice) {
            if (choice == null) return;
            if (choice == _noWeb) {
              onChanged(element.copyWith(webSearchUrl: ''));
            } else if (choice == _ownAddress) {
              // Something to edit rather than an empty field, which reads as
              // "off" and is also the one value that means off.
              onChanged(
                element.copyWith(
                  webSearchUrl: custom
                      ? element.webSearchUrl
                      : 'https://example.com/?q=$webSearchQueryToken',
                ),
              );
            } else {
              onChanged(
                element.copyWith(webSearchUrl: webSearchPresets[choice]),
              );
            }
          },
        ),
        if (custom) ...[
          const SizedBox(height: 12),
          _OwnSearchUrlField(
            key: ValueKey(element.id),
            element: element,
            s: s,
            onChanged: onChanged,
          ),
        ],
      ],
    );
  }
}

/// The escape hatch under "own address": a search URL typed by hand, with
/// {{suche}} where the words go.
class _OwnSearchUrlField extends StatefulWidget {
  const _OwnSearchUrlField({
    super.key,
    required this.element,
    required this.s,
    required this.onChanged,
  });

  final WidgetElement element;
  final AppStrings s;
  final ValueChanged<WidgetElement> onChanged;

  @override
  State<_OwnSearchUrlField> createState() => _OwnSearchUrlFieldState();
}

class _OwnSearchUrlFieldState extends State<_OwnSearchUrlField> {
  late final TextEditingController _url = TextEditingController(
    text: widget.element.webSearchUrl,
  );

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _url,
      keyboardType: TextInputType.url,
      maxLines: null,
      decoration: InputDecoration(
        labelText: widget.s.searchWebOwn,
        helperText: widget.s.searchWebOwnHint,
        helperMaxLines: 3,
        hintText: 'https://example.com/?q=$webSearchQueryToken',
      ),
      // Deferred for the same reason every other field here is: saving
      // mid-keystroke rebuilds this block and can cost it the focus.
      onChanged: (text) => Future.microtask(
        () => widget.onChanged(widget.element.copyWith(webSearchUrl: text)),
      ),
    );
  }
}

/// The settings an input element has of its own: what it is called (which
/// is how everything else reaches it), what it shows while empty, and which
/// keyboard it brings up.
class _InputSettings extends StatefulWidget {
  const _InputSettings({
    super.key,
    required this.block,
    required this.element,
    required this.s,
    required this.onChanged,
  });

  final PanelBlock block;
  final WidgetElement element;
  final AppStrings s;
  final ValueChanged<WidgetElement> onChanged;

  @override
  State<_InputSettings> createState() => _InputSettingsState();
}

class _InputSettingsState extends State<_InputSettings> {
  late final TextEditingController _name = TextEditingController(
    text: widget.element.inputName,
  );
  late final TextEditingController _hint = TextEditingController(
    text: widget.element.inputHint,
  );

  @override
  void initState() {
    super.initState();
    // So the reference line and the two warnings below follow the typing
    // rather than the last saved state.
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _hint.dispose();
    super.dispose();
  }

  // Same reasoning as in _ActionSettings: persisting straight out of
  // onChanged rebuilds the screen mid-keystroke and can cost the field its
  // focus, so it is deferred by one microtask.
  void _emit() {
    final updated = widget.element.copyWith(
      inputName: _name.text,
      inputHint: _hint.text,
    );
    Future.microtask(() => widget.onChanged(updated));
  }

  /// What other elements have to write to read this field. Always shown in
  /// the normalised spelling, since that is what a lookup actually uses -
  /// typing "Meine Suche" and being shown `{{eingabe.meine_suche}}` is the
  /// only way that rule is ever visible.
  String get _reference {
    final english = widget.s.language == AppLanguage.en;
    final prefix = WidgetInputStore.prefixFor(english);
    return '{{$prefix.${WidgetInputStore.normalizeName(_name.text)}}}';
  }

  /// Whether another input element - on this card or any other - already
  /// answers to this name. Both would then be the same slot, so typing in
  /// one would show up in the other.
  bool get _nameTaken {
    final name = WidgetInputStore.normalizeName(_name.text);
    if (name.isEmpty) return false;
    for (final block in PanelBlocksController.instance.value) {
      for (final element in block.elements) {
        if (element.type != WidgetElementType.input) continue;
        if (element.id == widget.element.id) continue;
        if (WidgetInputStore.normalizeName(element.inputName) == name) {
          return true;
        }
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final empty = WidgetInputStore.normalizeName(_name.text).isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(s.inputNameLabel),
        TextField(
          controller: _name,
          decoration: InputDecoration(
            labelText: s.inputNameLabel,
            helperText: empty ? null : s.inputNameHint(_reference),
            helperMaxLines: 4,
            errorText: empty
                ? s.inputNameEmpty
                : (_nameTaken ? s.inputNameTaken : null),
            errorMaxLines: 3,
          ),
          onChanged: (_) => _emit(),
        ),
        const SizedBox(height: 20),

        TextField(
          controller: _hint,
          maxLines: null,
          decoration: InputDecoration(labelText: s.inputHintLabel),
          onChanged: (_) => _emit(),
        ),
        const SizedBox(height: 8),
        _ValueDropdown(
          s: s,
          onPick: (placeholder) {
            final selection = _hint.selection;
            final text = _hint.text;
            final at = selection.isValid ? selection.start : text.length;
            _hint.text = text.replaceRange(
              at,
              selection.end.clamp(at, text.length),
              placeholder,
            );
            _hint.selection = TextSelection.collapsed(
              offset: at + placeholder.length,
            );
            _emit();
          },
        ),
        const SizedBox(height: 20),

        FieldLabel(s.inputKeyboardLabel),
        Wrap(
          spacing: 8,
          children: [
            for (final keyboard in WidgetInputKeyboard.values)
              ChoiceChip(
                label: Text(switch (keyboard) {
                  WidgetInputKeyboard.text => s.inputKeyboardText,
                  WidgetInputKeyboard.number => s.inputKeyboardNumber,
                  WidgetInputKeyboard.url => s.inputKeyboardUrl,
                }),
                selected: widget.element.inputKeyboard == keyboard,
                onSelected: (_) => widget.onChanged(
                  widget.element.copyWith(inputKeyboard: keyboard),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),

        Text(
          s.inputNotStoredHint,
          style: TextStyle(
            fontSize: context.design.typeCaption,
            color: context.design.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          s.inputRecipe,
          style: TextStyle(
            fontSize: context.design.typeCaption,
            color: context.design.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _ActionSettings extends StatefulWidget {
  const _ActionSettings({
    super.key,
    required this.element,
    required this.s,
    required this.onChanged,
  });

  final WidgetElement element;
  final AppStrings s;
  final ValueChanged<WidgetElement> onChanged;

  @override
  State<_ActionSettings> createState() => _ActionSettingsState();
}

class _ActionSettingsState extends State<_ActionSettings> {
  late final TextEditingController _url = TextEditingController(
    text: widget.element.actionUrl,
  );
  late final TextEditingController _headers = TextEditingController(
    text: headersToText(widget.element.actionHeaders),
  );
  late final TextEditingController _body = TextEditingController(
    text: widget.element.actionBody,
  );
  late final TextEditingController _toggleSource = TextEditingController(
    text: widget.element.actionToggleSource,
  );

  bool _testing = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    // A source that has never been fetched contributes no values, so the
    // dropdowns below would be missing exactly the one just set up.
    DataSourcesController.instance.refreshStale();
    // So the "not a real address" warning below updates live while typing,
    // not just after the next full-screen rebuild - same for the live
    // "this is what would actually be sent" preview below, which depends
    // on all three.
    for (final field in [_url, _body, _toggleSource]) {
      field.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _url.dispose();
    _headers.dispose();
    _body.dispose();
    _toggleSource.dispose();
    super.dispose();
  }

  /// Inserts at the cursor rather than at the end, so a placeholder can be
  /// dropped into the middle of an existing address or body.
  void _insertInto(TextEditingController controller, String placeholder) {
    final selection = controller.selection;
    final text = controller.text;
    final at = selection.isValid ? selection.start : text.length;
    controller.text = text.replaceRange(
      at,
      selection.end.clamp(at, text.length),
      placeholder,
    );
    controller.selection = TextSelection.collapsed(
      offset: at + placeholder.length,
    );
    _emit();
  }

  // Persisting synchronously from inside a TextField's onChanged rebuilds
  // this whole (fairly heavy) settings block mid-keystroke, which on some
  // keyboards drops the field's focus entirely. A microtask defers it to
  // just after the keyboard is done handling this one keystroke.
  void _emit() {
    final updated = widget.element.copyWith(
      actionUrl: _url.text,
      actionHeaders: headersFromText(_headers.text),
      actionBody: _body.text,
      actionToggleSource: _toggleSource.text,
    );
    Future.microtask(() => widget.onChanged(updated));
  }

  Future<void> _test() async {
    // Whatever is on screen right now, saved or not - waiting for a field's
    // own onChanged to land first would test the value from before the
    // latest keystroke.
    final current = widget.element.copyWith(
      actionUrl: _url.text,
      actionHeaders: headersFromText(_headers.text),
      actionBody: _body.text,
      actionToggleSource: _toggleSource.text,
    );
    setState(() {
      _testing = true;
      _testResult = null;
    });
    final result = await runWidgetAction(current);
    if (!mounted) return;
    setState(() {
      _testing = false;
      _testResult = result.success
          ? (current.actionKind == WidgetActionKind.open
                ? '${widget.s.actionOpened}: ${result.detail ?? ''}'
                : widget.s.actionSucceeded)
          : (result.detail ?? '');
    });
  }

  /// One chip per configured data source - tapping one sets the address to
  /// that device's own host (scheme + host + port, plus a trailing "/" ready
  /// for the path to be typed after it), so only the bit that's actually
  /// specific to this action needs typing. Can't go further than the host
  /// automatically: the path that changes something (e.g. /toggle) is almost
  /// never the same as the one a data source reads its status from (e.g.
  /// /state), so there's nothing to copy for that part.
  ///
  /// Exactly one chip shows as selected - whichever source's host the
  /// address currently starts with - so it never looks like more than one
  /// could apply at once; picking a different one just re-fills the address.
  /// Uri.origin throws (rather than returning null) on anything without an
  /// http(s) scheme - which an in-progress or empty address field always is
  /// at first, so calling it unguarded here would crash every rebuild.
  static String? _originOf(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }
    return uri.origin;
  }

  Widget _sourceHostChips(AppStrings s) {
    return ValueListenableBuilder<List<DataSource>>(
      valueListenable: DataSourcesController.instance,
      builder: (context, sources, child) {
        if (sources.isEmpty) return const SizedBox.shrink();
        final currentOrigin = _originOf(_url.text);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.actionHostFromSource,
                style: TextStyle(
                  fontSize: context.design.typeCaption,
                  color: context.design.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  for (final source in sources)
                    ChoiceChip(
                      avatar: const Icon(Icons.dns_outlined, size: 16),
                      label: Text(source.name),
                      selected:
                          currentOrigin != null &&
                          currentOrigin == _originOf(source.url),
                      onSelected: (_) {
                        final origin = _originOf(source.url);
                        if (origin == null) return;
                        setState(() {
                          _url.text = '$origin/';
                          _url.selection = TextSelection.collapsed(
                            offset: _url.text.length,
                          );
                        });
                        _emit();
                      },
                    ),
                ],
              ),
              if (currentOrigin != null &&
                  _url.text.trim() == '$currentOrigin/')
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    s.actionHostPathReminder,
                    style: TextStyle(
                      fontSize: context.design.typeCaption,
                      color: Colors.orange,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// A one-tap way to drop in "true"/"false" (fixed mode - this is how two
  /// buttons become an on-switch and an off-switch) or the computed toggled
  /// value (toggle mode), instead of typing either by hand.
  Widget _quickInsertRow(
    ActionValueMode mode,
    AppStrings s,
    ValueChanged<String> onInsert,
  ) {
    if (mode == ActionValueMode.toggle) {
      return Align(
        alignment: Alignment.centerLeft,
        child: ActionChip(
          avatar: const Icon(Icons.sync, size: 16),
          label: Text(s.insertToggledValue),
          onPressed: () =>
              onInsert(toggleTokenFor(LocaleController.instance.value)),
        ),
      );
    }
    return Wrap(
      spacing: 8,
      children: [
        ActionChip(
          label: Text(s.ruleTrue),
          onPressed: () => onInsert('true'),
        ),
        ActionChip(
          label: Text(s.ruleFalse),
          onPressed: () => onInsert('false'),
        ),
      ],
    );
  }

  /// What a tap would actually send, right now - computed with the exact
  /// same logic a real send uses (see resolveAction/runWidgetAction), so a
  /// mistake like a placeholder landing right after the host with no `/`
  /// shows up here as broken before "Testen" is ever pressed, not after.
  Widget _resolvedPreview(AppStrings s) {
    final draft = widget.element.copyWith(
      actionUrl: _url.text,
      actionBody: _body.text,
      actionToggleSource: _toggleSource.text,
    );
    final resolved = resolveAction(draft);

    if (resolved.error != null) {
      return _previewBox(
        s.actionPreviewLabel,
        s.actionToggleUnreadable,
        isError: true,
      );
    }

    final uri = Uri.tryParse(resolved.url);
    // Opening is not limited to the web, so anything with a scheme counts;
    // a request really does have to be http(s).
    final valid = uri != null &&
        (widget.element.actionKind == WidgetActionKind.open
            ? uri.hasScheme
            : (uri.scheme == 'http' || uri.scheme == 'https'));
    final lines = [
      resolved.url.isEmpty ? s.actionPreviewEmpty : resolved.url,
      if (resolved.body != null && resolved.body!.isNotEmpty) resolved.body!,
    ];
    return _previewBox(
      s.actionPreviewLabel,
      lines.join('\n'),
      isError: !valid,
    );
  }

  Widget _previewBox(String label, String value, {required bool isError}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError
            ? Theme.of(context).colorScheme.error.withValues(alpha: 0.12)
            : context.design.fillSubtle,
        borderRadius: BorderRadius.circular(context.design.radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: context.design.typeCaption,
              fontWeight: FontWeight.bold,
              color: isError ? Colors.red : context.design.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: context.design.typeCaption,
              color: isError ? Colors.red : context.design.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final mode = widget.element.actionValueMode;
    final showBody = widget.element.actionMethod != ActionMethod.get;
    final kind = widget.element.actionKind;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Which kind of button this is comes first, and it is the only thing
        // every kind has in common: each one below shows just the fields it
        // actually uses, so a search button never asks about an HTTP method.
        FieldLabel(s.actionKindLabel),
        Wrap(
          spacing: 8,
          children: [
            for (final option in WidgetActionKind.values)
              ChoiceChip(
                label: Text(switch (option) {
                  WidgetActionKind.http => s.actionKindHttp,
                  WidgetActionKind.open => s.actionKindOpen,
                  WidgetActionKind.search => s.actionKindSearch,
                }),
                selected: kind == option,
                onSelected: (_) => widget.onChanged(
                  widget.element.copyWith(
                    actionKind: option,
                    // Switching to search lands on something that already
                    // works rather than on two empty dropdowns.
                    inputName:
                        option == WidgetActionKind.search &&
                            widget.element.inputName.isEmpty
                        ? (WidgetInputStore.instance.names.firstOrNull ?? '')
                        : widget.element.inputName,
                    webSearchUrl:
                        option == WidgetActionKind.search &&
                            widget.element.webSearchUrl.isEmpty
                        ? webSearchPresets.values.first
                        : widget.element.webSearchUrl,
                    // The glyph follows the kind while it is still the
                    // default one for the kind it was - a button somebody
                    // has already picked an icon for keeps it.
                    template: _defaultIcons.contains(widget.element.template)
                        ? _defaultIconFor(option)
                        : widget.element.template,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          switch (kind) {
            WidgetActionKind.http => s.actionKindHttpHint,
            WidgetActionKind.open => s.actionKindOpenHint,
            WidgetActionKind.search => s.actionKindSearchHint,
          },
          style: TextStyle(
            fontSize: context.design.typeCaption,
            color: context.design.textSecondary,
          ),
        ),
        const SizedBox(height: 20),

        ...switch (kind) {
          WidgetActionKind.http => _httpFields(s, mode, showBody),
          WidgetActionKind.open => _openFields(s),
          WidgetActionKind.search => _searchFields(s),
        },
      ],
    );
  }

  /// The glyph each kind starts on. Kept as a set as well, so switching kind
  /// can tell "still the default" from "the user picked this".
  static const Map<WidgetActionKind, String> _kindIcons = {
    WidgetActionKind.http: 'power',
    WidgetActionKind.open: 'open',
    WidgetActionKind.search: 'search',
  };
  static const Set<String> _defaultIcons = {'power', 'open', 'search'};
  static String _defaultIconFor(WidgetActionKind kind) =>
      _kindIcons[kind] ?? 'power';

  /// Two dropdowns and a preview - no address anywhere. Everything the HTTP
  /// kind needs is meaningless here, so none of it is shown.
  List<Widget> _searchFields(AppStrings s) {
    final query =
        WidgetInputStore.instance.textOf(widget.element.inputName) ?? '';
    final template = widget.element.webSearchUrl.trim();

    return [
      _InputFieldPicker(
        element: widget.element,
        s: s,
        onChanged: widget.onChanged,
      ),
      const SizedBox(height: 20),
      FieldLabel(s.searchWebLabel),
      _WebSearchPicker(
        element: widget.element,
        s: s,
        onChanged: widget.onChanged,
        allowNone: false,
      ),
      const SizedBox(height: 16),
      // The real address a tap would open, built by the same function the
      // tap uses - so a hand-typed engine missing its {{suche}} shows up
      // here as an address that never changes.
      _previewBox(
        s.actionSearchPreview,
        template.isEmpty
            ? s.searchButtonNotSetUp
            : (query.trim().isEmpty
                  ? s.searchButtonEmptyField
                  : buildSearchUrl(template, query.trim())),
        isError: template.isEmpty,
      ),
    ];
  }

  /// Opening needs one address and nothing else - no method, no body, no
  /// headers, no toggle. Showing those anyway would suggest they still do
  /// something here.
  List<Widget> _openFields(AppStrings s) {
    return [
      TextField(
        controller: _url,
        keyboardType: TextInputType.url,
        maxLines: null,
        decoration: InputDecoration(
          labelText: s.actionOpenUrlLabel,
          helperText: s.actionOpenUrlHint,
          helperMaxLines: 5,
          hintText: 'https://duckduckgo.com/?q={{eingabe.feld1|url}}',
        ),
        onChanged: (_) => _emit(),
      ),
      if (_url.text.trim().isNotEmpty && !_hasScheme(_url.text))
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            s.actionOpenNotValid,
            style: TextStyle(
              color: Colors.red,
              fontSize: context.design.typeCaption,
            ),
          ),
        ),
      const SizedBox(height: 8),
      // urlEncodeInputs: picked here, an input field is inserted with the
      // `|url` modifier, so a typed space cannot cut the address in half.
      _ValueDropdown(
        s: s,
        urlEncodeInputs: true,
        onPick: (p) => _insertInto(_url, p),
      ),
      const SizedBox(height: 16),
      _resolvedPreview(s),
      const SizedBox(height: 16),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.tonalIcon(
          onPressed: _testing ? null : _test,
          icon: const Icon(Icons.open_in_new),
          label: Text(s.testOpenAction),
        ),
      ),
      if (_testResult != null)
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.design.fillSubtle,
              borderRadius: BorderRadius.circular(context.design.radiusMedium),
            ),
            child: Text(
              _testResult!,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: context.design.typeCaption,
              ),
            ),
          ),
        ),
    ];
  }

  /// Anything with a scheme in front counts - which ones the phone actually
  /// answers is its business, so this only catches a bare "duckduckgo.com".
  static bool _hasScheme(String raw) =>
      Uri.tryParse(raw.trim())?.hasScheme ?? false;

  List<Widget> _httpFields(AppStrings s, ActionValueMode mode, bool showBody) {
    return [
        // Method and value mode come first: both change what the address
        // field below actually needs (which quick-insert row it shows, and
        // whether a body makes sense), so picking them after would mean
        // scrolling back up to react to them.
        FieldLabel(s.actionMethodLabel),
        Wrap(
          spacing: 8,
          children: [
            for (final method in ActionMethod.values)
              ChoiceChip(
                label: Text(method.name.toUpperCase()),
                selected: widget.element.actionMethod == method,
                onSelected: (_) => widget.onChanged(
                  widget.element.copyWith(actionMethod: method),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(_methodHint(s, widget.element.actionMethod),
            style: TextStyle(
              fontSize: context.design.typeCaption,
              color: context.design.textSecondary),
            ),
        const SizedBox(height: 20),

        FieldLabel(s.actionModeLabel),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: Text(s.actionModeFixed),
              selected: mode == ActionValueMode.fixed,
              onSelected: (_) => widget.onChanged(
                widget.element.copyWith(actionValueMode: ActionValueMode.fixed),
              ),
            ),
            ChoiceChip(
              label: Text(s.actionModeToggle),
              selected: mode == ActionValueMode.toggle,
              onSelected: (_) => widget.onChanged(
                widget.element.copyWith(
                  actionValueMode: ActionValueMode.toggle,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          mode == ActionValueMode.toggle
              ? s.actionModeToggleHint
              : s.actionModeFixedHint,
          style: TextStyle(
            fontSize: context.design.typeCaption,
            color: context.design.textSecondary,
          ),
        ),

        if (mode == ActionValueMode.toggle) ...[
          const SizedBox(height: 16),
          TextField(
            controller: _toggleSource,
            maxLines: null,
            decoration: InputDecoration(
              labelText: s.actionToggleSourceLabel,
              helperText: s.actionToggleSourceHint,
            ),
            onChanged: (_) => _emit(),
          ),
          const SizedBox(height: 8),
          _ValueDropdown(
            s: s,
            onlyBoolean: true,
            onPick: (p) => _insertInto(_toggleSource, p),
          ),
        ],
        const SizedBox(height: 20),

        _sourceHostChips(s),
        // The address that actually changes something - on a device with a
        // separate status page (like the test server's /state), this is
        // NOT that one; it's whatever path makes the change (e.g. /toggle).
        TextField(
          controller: _url,
          keyboardType: TextInputType.url,
          maxLines: null,
          decoration: InputDecoration(
            labelText: s.actionUrlLabel,
            helperText: s.actionUrlHint,
            hintText: 'http://192.168.1.50/toggle',
          ),
          onChanged: (_) => _emit(),
        ),
        // The placeholder pickers below add to this address, they don't
        // replace typing one in the first place - a field made entirely of
        // inserted placeholders (e.g. "{{schalter.on}}{{!wert}}", no
        // http://host at all) looks plausible but isn't a real address.
        if (_url.text.trim().isNotEmpty &&
            !_url.text.trim().startsWith('http://') &&
            !_url.text.trim().startsWith('https://'))
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              s.actionUrlNotValid,
              style: TextStyle(
                color: Colors.red,
                fontSize: context.design.typeCaption,
              ),
            ),
          ),
        const SizedBox(height: 8),
        _ValueDropdown(s: s, onPick: (p) => _insertInto(_url, p)),
        const SizedBox(height: 8),
        _quickInsertRow(mode, s, (v) => _insertInto(_url, v)),
        const SizedBox(height: 16),
        _resolvedPreview(s),
        const SizedBox(height: 8),

        Theme(
          // The default ExpansionTile divider looks out of place floating
          // inside this already-boxed settings section.
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            title: Text(
              s.advanced,
              style: TextStyle(
                fontSize: context.design.typeLabel,
                fontWeight: FontWeight.bold,
                color: context.design.textSecondary,
              ),
            ),
            children: [
              TextField(
                controller: _headers,
                maxLines: null,
                decoration: InputDecoration(labelText: s.sourceHeaders),
                onChanged: (_) => _emit(),
              ),
              if (showBody) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _body,
                  maxLines: null,
                  decoration: InputDecoration(labelText: s.actionBodyLabel),
                  onChanged: (_) => _emit(),
                ),
                const SizedBox(height: 8),
                _ValueDropdown(s: s, onPick: (p) => _insertInto(_body, p)),
                const SizedBox(height: 8),
                _quickInsertRow(mode, s, (v) => _insertInto(_body, v)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),

        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            onPressed: _testing ? null : _test,
            icon: const Icon(Icons.play_arrow),
            label: Text(s.testAction),
          ),
        ),
        if (_testing)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (_testResult != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.design.fillSubtle,
                borderRadius: BorderRadius.circular(
                  context.design.radiusMedium,
                ),
              ),
              child: Text(
                _testResult!,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: context.design.typeCaption,
                ),
              ),
            ),
          ),
    ];
  }

  static String _methodHint(AppStrings s, ActionMethod method) => switch (method) {
    ActionMethod.get => s.actionMethodGetHint,
    ActionMethod.post => s.actionMethodPostHint,
    ActionMethod.put => s.actionMethodPutHint,
  };
}
