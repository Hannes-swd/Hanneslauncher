/// An input element's own settings: its name, its placeholder and its
/// keyboard.
part of 'widget_editor_screen.dart';

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
