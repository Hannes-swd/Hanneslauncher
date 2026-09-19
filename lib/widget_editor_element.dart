/// The editor for one line of a card: what it shows, how it looks, and the
/// picker behind its value.
part of 'widget_editor_screen.dart';

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
