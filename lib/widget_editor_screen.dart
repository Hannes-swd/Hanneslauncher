import 'package:flutter/material.dart';

import 'app_icon.dart';
import 'app_list_settings_controller.dart' show appListColorPalette;
import 'app_strings.dart';
import 'data_sources_controller.dart';
import 'data_sources_settings_screen.dart';
import 'launcher_entries_controller.dart';
import 'locale_controller.dart';
import 'panel_blocks_controller.dart';
import 'text_prompt_dialog.dart';
import 'widget_canvas_editor.dart';
import 'widget_card_view.dart';
import 'widget_element.dart';

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
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      s.canvasHint,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Text(
                      '${s.cardHeightLabel} (${block.cardHeight.round()})',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  Slider(
                    value: block.cardHeight,
                    min: 80,
                    max: 400,
                    divisions: 32,
                    onChanged: (value) => PanelBlocksController.instance
                        .update(block.copyWith(cardHeight: value)),
                  ),
                  const Divider(height: 32),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      s.openOnTap,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  _LinkedEntryTile(block: block, s: s),
                  const Divider(height: 32),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      s.layersHint,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  for (final element in block.elements)
                    ListTile(
                      leading: Icon(_iconFor(element.type)),
                      title: Text(
                        element.template.isEmpty
                            ? _labelFor(element.type, s)
                            : element.template,
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
  };

  static String _labelFor(WidgetElementType type, AppStrings s) =>
      switch (type) {
        WidgetElementType.text => s.elementText,
        WidgetElementType.icon => s.elementIcon,
        WidgetElementType.image => s.elementImage,
        WidgetElementType.box => s.elementBox,
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
    }

    final element = WidgetElement(
      id: _newElementId(block),
      type: type,
      template: template,
      rules: rules,
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: entry == null
              ? const Icon(Icons.touch_app_outlined, color: Colors.black45)
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
                leading: const Icon(Icons.block, color: Colors.black45),
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
                  // A box draws nothing but itself, so it has no value to
                  // fill in and no field for one.
                  if (element.type != WidgetElementType.box) ...[
                    _sectionLabel(
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

                  if (element.type == WidgetElementType.text) ...[
                    _sectionLabel('${s.textSizeShort} '
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

                  if (element.type == WidgetElementType.icon) ...[
                    _sectionLabel('${s.iconSizeShort} '
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
                    _sectionLabel('${s.heightShort} '
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
                    _sectionLabel('${s.widthShort} '
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
                    _sectionLabel('${s.radiusShort} '
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
                    _sectionLabel('${s.opacityShort} '
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
                    _sectionLabel(s.colorLabel),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (var i = 0; i < appListColorPalette.length; i++)
                          GestureDetector(
                            onTap: () => _update(
                              block,
                              element.copyWith(colorIndex: i),
                            ),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: appListColorPalette[i],
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: i == element.colorIndex
                                      ? Colors.black
                                      : Colors.black26,
                                  width: i == element.colorIndex ? 3 : 1,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],

                  if (element.type == WidgetElementType.text ||
                      element.type == WidgetElementType.icon) ...[
                    const SizedBox(height: 8),
                    _sectionLabel(s.alignLabel),
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
                    _sectionLabel(s.colorLabel),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (var i = 0; i < appListColorPalette.length; i++)
                          GestureDetector(
                            onTap: () => _update(
                              block,
                              element.copyWith(colorIndex: i),
                            ),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: appListColorPalette[i],
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: i == element.colorIndex
                                      ? Colors.black
                                      : Colors.black26,
                                  width: i == element.colorIndex ? 3 : 1,
                                ),
                              ),
                            ),
                          ),
                      ],
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
                  _sectionLabel(s.preview),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) => WidgetElementView(
                        element: element,
                        cardWidth: constraints.maxWidth,
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

  static Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Colors.black54,
      ),
    ),
  );

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
            border: const OutlineInputBorder(),
            hintText: widget.element.type == WidgetElementType.image
                ? 'https://…'
                : '{{zeit}} · {{wetter.current.temperature_2m}} °C',
          ),
          onChanged: widget.onChanged,
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
  const _ValueDropdown({required this.s, required this.onPick});

  final AppStrings s;
  final ValueChanged<String> onPick;

  // Not a placeholder, so it can never collide with a real entry.
  static const _addEntry = '+';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DataSourcesController.instance,
      builder: (context, child) {
        final options = DataSourcesController.instance.options();
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
            for (final option in options)
              PopupMenuItem(
                value: option.placeholder,
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
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    s.availableValues,
                    style: const TextStyle(color: Colors.black54),
                  ),
                ),
                const Icon(Icons.arrow_drop_down, color: Colors.black54),
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
              color: Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
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
                      color: matches.isEmpty ? Colors.orange : Colors.black54,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        matches.isNotEmpty
                            ? s.ruleMatches(matches.first.iconName)
                            : missing
                            ? s.valueMissing
                            : s.noRuleMatches,
                        style: const TextStyle(color: Colors.black54),
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
                    border: const OutlineInputBorder(),
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
        ElementEditorScreen._sectionLabel(s.rulesLabel),
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
              color: effective ? Colors.green : Colors.black26,
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

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final draft = _draftRule;
    final inverted =
        draft.min != null && draft.max != null && draft.min! > draft.max!;
    final hasTestValue = widget.testValue.trim().isNotEmpty;
    final matches = hasTestValue && draft.matches(widget.testValue);

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
                      color: matches ? Colors.green : Colors.black38,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.currentValue(widget.testValue),
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ),
                  ],
                ),
              ),
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
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
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
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: entry.key == _iconName
                              ? Colors.black
                              : Colors.black26,
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
