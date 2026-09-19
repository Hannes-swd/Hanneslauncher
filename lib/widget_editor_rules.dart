/// An icon element's rules - the list, one row of it, the dialog that edits
/// one, and the readout saying which rule currently catches the value.
part of 'widget_editor_screen.dart';

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
