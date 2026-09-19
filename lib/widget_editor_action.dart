/// An action element's own settings: the request it fires, the headers and
/// body that go with it, and the try-it-now button.
part of 'widget_editor_screen.dart';

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
