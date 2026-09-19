/// The small pickers several element kinds share: a glyph, an input field,
/// what a search element lists, and which search engine it uses.
part of 'widget_editor_screen.dart';

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
