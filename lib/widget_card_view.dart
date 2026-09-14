import 'builtin_entries.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_icon.dart';
import 'app_list_settings_controller.dart' show appListColorPalette;
import 'app_strings.dart';
import 'data_sources_controller.dart';
import 'device_stats_controller.dart';
import 'expression_calculator.dart';
import 'folder_sheet.dart';
import 'launcher_entries_controller.dart';
import 'locale_controller.dart';
import 'location_controller.dart';
import 'panel_blocks_controller.dart';
import 'widget_action.dart';
import 'widget_element.dart';
import 'widget_input_store.dart';
import 'widget_search_service.dart';

/// Draws a widget card: its elements stacked on top of each other, each at
/// the spot it was dragged to, with the placeholders in them filled from the
/// data sources' last fetched values. The list order is the stacking order,
/// so the first element is at the back.
class WidgetCardView extends StatelessWidget {
  const WidgetCardView({super.key, required this.block, required this.s});

  final PanelBlock block;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      // The place name arrives separately from the fetched values, so both
      // have to be able to bring the card up to date.
      listenable: Listenable.merge([
        DataSourcesController.instance,
        LocationController.instance,
        DeviceStatsController.instance,
        WidgetInputStore.instance,
      ]),
      builder: (context, child) {
        Widget card;
        if (block.elements.isEmpty) {
          card = SizedBox(
            height: 72,
            child: Row(
              children: [
                const Icon(Icons.widgets_outlined, color: Colors.black45),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    block.title.isEmpty ? s.emptyWidget : block.title,
                    style: const TextStyle(color: Colors.black54),
                  ),
                ),
              ],
            ),
          );
        } else {
          card = WidgetCardStack(
            block: block,
            builder: (element, cardWidth) =>
                WidgetElementView(element: element, cardWidth: cardWidth),
          );
        }

        if (block.linkedKey.isEmpty) return card;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _openLink(context),
          child: card,
        );
      },
    );
  }

  Future<void> _openLink(BuildContext context) async {
    final entries = LauncherEntriesController.instance.resolve(
      [block.linkedKey],
    );
    if (entries.isEmpty) return;
    final entry = entries.first;
    if (entry.isFolder) {
      showFolderSheet(context, entry.folder!);
    } else if (entry.isBuiltIn) {
      await openBuiltIn(context, entry.builtIn!);
    } else {
      await entry.launch();
    }
  }
}

/// How tall an element wants to be, worked out from its own settings rather
/// than from anything the framework measured.
///
/// Deliberately not a measurement: the card's height would then be decided by
/// how tall the elements came out under a constraint that is itself the
/// card's height, and that chases its own tail. Everything here is a number
/// the element already carries, so the answer is the same however tall the
/// card happens to be right now.
///
/// The results list is the one element whose height depends on what is on
/// screen, and it reports its own through [CardHeightReports].
double naturalElementHeight(WidgetElement element) => switch (element.type) {
  // Roughly one line of type. A wrapped line makes this an underestimate,
  // which on a flexible card costs the second line - the width slider is
  // right there, and guessing high would leave every card padded instead.
  WidgetElementType.text => element.fontSize * 1.45,
  WidgetElementType.icon || WidgetElementType.action => element.iconSize,
  WidgetElementType.box || WidgetElementType.image => element.height,
  // A dense TextField: the line itself, its padding and the underline.
  WidgetElementType.input => element.fontSize * 1.45 + 18,
  // Its ceiling, until the list itself says how much of that it is using.
  WidgetElementType.results => element.height,
};

/// How tall one row of a results list is, worked out the same way the list
/// builds it. Its height at rest, which is where the list is anchored - see
/// [WidgetCardStack].
double resultsRowHeight(WidgetElement element) {
  final fontSize = element.fontSize;
  final glyph = fontSize * 1.3;
  final twoLines = fontSize * 1.3 + fontSize * 0.75 * 1.3;
  return math.max(glyph, twoLines) + fontSize * 0.6;
}

/// Lets the results list tell the card around it how tall it actually is,
/// so a flexible card can shrink back when a search returns two rows instead
/// of six. Absent in the element editor's standalone preview, where there is
/// no card to tell.
class CardHeightReports extends InheritedWidget {
  const CardHeightReports({
    super.key,
    required this.report,
    required super.child,
  });

  final void Function(String elementId, double height) report;

  static CardHeightReports? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CardHeightReports>();

  @override
  bool updateShouldNotify(CardHeightReports oldWidget) => false;
}

/// Lays a card's elements out at the spots they were dragged to, and works
/// out how tall the card has to be for them.
///
/// A fixed card is simply [PanelBlock.cardHeight] tall. A flexible one is as
/// short as its contents allow: the height of the tallest element, kept
/// between the card's own minimum and maximum.
class WidgetCardStack extends StatefulWidget {
  const WidgetCardStack({
    super.key,
    required this.block,
    required this.builder,
    this.positionOf,
    this.overlay,
  });

  final PanelBlock block;

  /// Draws one element. The canvas editor wraps it in its own drag handling,
  /// the real card doesn't, so the caller decides.
  final Widget Function(WidgetElement element, double cardWidth) builder;

  /// Where an element sits as a 0..1 pair, when that isn't simply its stored
  /// position - the canvas editor moves the one under the finger before it
  /// is committed.
  final Offset Function(WidgetElement element)? positionOf;

  /// Drawn on top of everything, for the canvas editor's snap guides.
  final List<Widget> Function(Size size)? overlay;

  @override
  State<WidgetCardStack> createState() => _WidgetCardStackState();
}

class _WidgetCardStackState extends State<WidgetCardStack> {
  /// What the results lists on this card have said about themselves, by
  /// element id. Everything else is worked out from its own settings.
  final Map<String, double> _reported = {};

  @override
  void didUpdateWidget(WidgetCardStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A deleted element must not keep its last height on file - an id is
    // the creation time and never comes round again, so nothing would ever
    // clear it.
    if (_reported.isEmpty) return;
    final live = {for (final e in widget.block.elements) e.id};
    _reported.removeWhere((id, _) => !live.contains(id));
  }

  void _report(String elementId, double height) {
    final known = _reported[elementId];
    if (known != null && (known - height).abs() < 0.5) return;
    // Reported from a child's build, so applying it straight away would be a
    // setState during a build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _reported[elementId] = height);
    });
  }

  double _heightOf(WidgetElement element) =>
      _reported[element.id] ?? naturalElementHeight(element);

  Offset _positionOf(WidgetElement element) =>
      widget.positionOf?.call(element) ?? Offset(element.x, element.y);

  /// The element's top edge, in pixels down from the top of the card.
  ///
  /// Everything but the results list is placed the way it always was: the
  /// stored 0..1 spreads it across the card, resting against an edge at 0
  /// and 1 rather than hanging over it.
  ///
  /// A results list is anchored by its top instead. Placed like the others
  /// it would sit centred on its position, so every row a search adds would
  /// push it half a row upwards - straight over the field it belongs to.
  /// Pinning the top means a longer list only ever grows downwards, and at
  /// one row it lands exactly where the old rule put it.
  double _topOf(WidgetElement element, double anchor) {
    final y = _positionOf(element).dy;
    final resting = element.type == WidgetElementType.results
        ? math.min(resultsRowHeight(element), element.height)
        : _heightOf(element);
    final room = math.max(anchor - resting, 0.0);
    return (room * y).clamp(0.0, room);
  }

  /// How tall the card has to be for everything to fit: the lowest bottom
  /// edge on it. Positions are worked out against the card's resting height,
  /// never against the height this produces, so the two can't chase each
  /// other.
  double get _contentHeight {
    final anchor = widget.block.cardHeight;
    var lowest = 0.0;
    for (final element in widget.block.elements) {
      final bottom = _topOf(element, anchor) + _heightOf(element);
      if (bottom > lowest) lowest = bottom;
    }
    return lowest;
  }

  @override
  Widget build(BuildContext context) {
    final block = widget.block;
    final flexible = block.cardHeightFlexible;
    // The minimum doubles as the fixed height, so switching a card to
    // flexible never makes it taller than it already was.
    final maxHeight = math.max(block.cardMaxHeight, block.cardHeight);
    final height = flexible
        ? _contentHeight.clamp(block.cardHeight, maxHeight)
        : block.cardHeight;
    // Elements are placed within the card's resting height even when it has
    // grown past it, so a growing list pushes the card's bottom edge down
    // instead of shuffling everything else around.
    final anchor = flexible ? block.cardHeight : height;

    return CardHeightReports(
      report: _report,
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            return Stack(
              // Nothing may be drawn outside the card, whatever an element
              // does - an overflow used to put stripes across the panel.
              clipBehavior: Clip.hardEdge,
              children: [
                for (final element in block.elements)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: _topOf(element, anchor),
                    // heightFactor so the row is exactly as tall as the
                    // element; the alignment then only decides across.
                    child: Align(
                      alignment: Alignment(_positionOf(element).dx * 2 - 1, 0),
                      heightFactor: 1,
                      child: widget.builder(element, size.width),
                    ),
                  ),
                ...?widget.overlay?.call(size),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A single element, both on the card and in the editor's preview.
class WidgetElementView extends StatelessWidget {
  const WidgetElementView({
    super.key,
    required this.element,
    required this.cardWidth,
    this.interactive = true,
  });

  final WidgetElement element;

  /// Needed for the elements sized as a share of the card.
  final double cardWidth;

  /// False in the canvas editor and the element editor's preview, where a
  /// tap is meant to open the element for editing (or just show what it
  /// looks like) - not actually fire an action element's HTTP call.
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    // Also used on its own in the element editor's preview, so it listens
    // for itself rather than relying on the card around it.
    return ListenableBuilder(
      listenable: Listenable.merge([
        DataSourcesController.instance,
        LocationController.instance,
        DeviceStatsController.instance,
        WidgetInputStore.instance,
      ]),
      builder: (context, child) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final sources = DataSourcesController.instance;
    final color = appListColorPalette[element.colorIndex];

    switch (element.type) {
      case WidgetElementType.text:
        return Text(
          _textOf(element, sources),
          textAlign: element.alignment.textAlign,
          style: TextStyle(
            fontSize: element.fontSize,
            fontWeight: element.bold ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        );

      case WidgetElementType.icon:
        final value = sources.resolve(element.template);
        final match = element.rules.where((rule) => rule.matches(value));
        final iconName = match.isEmpty ? null : match.first.iconName;
        return Icon(
          widgetIcons[iconName] ?? Icons.help_outline,
          size: element.iconSize,
          color: color,
        );

      case WidgetElementType.box:
        return Container(
          width: math.min(element.width, cardWidth),
          height: element.height,
          decoration: BoxDecoration(
            color: color.withValues(alpha: element.opacity),
            borderRadius: BorderRadius.circular(element.radius),
          ),
        );

      case WidgetElementType.image:
        final url = sources.resolve(element.template);
        return ClipRRect(
          borderRadius: BorderRadius.circular(element.radius),
          child: SizedBox(
            height: element.height,
            width: math.min(element.width, cardWidth),
            child: Uri.tryParse(url)?.hasScheme != true
                ? const ColoredBox(color: Colors.black12)
                : Image.network(
                    url,
                    fit: BoxFit.cover,
                    // A broken or unreachable picture must not tear a hole
                    // in the panel, so it degrades to an empty tile.
                    errorBuilder: (context, error, stack) =>
                        const ColoredBox(color: Colors.black12),
                  ),
          ),
        );

      case WidgetElementType.action:
        return _ActionButton(
          element: element,
          color: color,
          interactive: interactive,
        );

      case WidgetElementType.input:
        return _InputField(
          element: element,
          color: color,
          cardWidth: cardWidth,
          interactive: interactive,
        );

      case WidgetElementType.results:
        return _ResultsList(
          element: element,
          color: color,
          cardWidth: cardWidth,
          interactive: interactive,
        );
    }
  }

  /// A text element's line. Modes other than [WidgetTextMode.free] exist so
  /// a display can be set up by picking a field from a dropdown instead of
  /// knowing the placeholder syntax - so they read the field directly rather
  /// than going through a template the user never sees.
  static String _textOf(WidgetElement element, DataSourcesController sources) {
    switch (element.textMode) {
      case WidgetTextMode.free:
        return sources.resolve(element.template);
      case WidgetTextMode.inputValue:
        return WidgetInputStore.instance.textOf(element.inputName) ?? '';
      case WidgetTextMode.calculation:
        final typed = WidgetInputStore.instance.textOf(element.inputName) ?? '';
        // Empty rather than a dash while what's in the field isn't a sum:
        // this sits under a field somebody is still typing into, and a "-"
        // flashing between every keystroke would be worse than nothing.
        return calculateExpression(typed) ?? '';
    }
  }
}

/// An input element: a plain text field whose contents are readable
/// everywhere a `{{...}}` placeholder is. Nothing is stored - see
/// [WidgetInputStore] for why.
class _InputField extends StatefulWidget {
  const _InputField({
    required this.element,
    required this.color,
    required this.cardWidth,
    required this.interactive,
  });

  final WidgetElement element;
  final Color color;
  final double cardWidth;

  /// False in the editor's canvas and preview, where the field has to stay
  /// a shape that can be dragged and tapped to open its settings - a real
  /// one would swallow both and put the keyboard up instead.
  final bool interactive;

  @override
  State<_InputField> createState() => _InputFieldState();
}

class _InputFieldState extends State<_InputField> {
  late final TextEditingController _controller = TextEditingController(
    text: WidgetInputStore.instance.textOf(widget.element.inputName) ?? '',
  );

  @override
  void initState() {
    super.initState();
    WidgetInputStore.instance.addListener(_followStore);
  }

  /// The store can be emptied from outside this field - the panel closing,
  /// a search result being tapped - and the box on screen has to follow, or
  /// it goes on showing words that nothing else still holds.
  ///
  /// Typing arrives here too and finds the two already in agreement, so it
  /// costs nothing and never fights the cursor.
  void _followStore() {
    final text =
        WidgetInputStore.instance.textOf(widget.element.inputName) ?? '';
    if (_controller.text == text) return;
    _controller.text = text;
  }

  @override
  void didUpdateWidget(_InputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Renaming the field in the editor points it at a different slot, and
    // the text on screen has to follow - otherwise the field keeps showing
    // what the old name held while writing to the new one.
    final oldName = WidgetInputStore.normalizeName(oldWidget.element.inputName);
    final newName = WidgetInputStore.normalizeName(widget.element.inputName);
    if (oldName == newName) return;
    final text = WidgetInputStore.instance.textOf(newName) ?? '';
    if (_controller.text != text) _controller.text = text;
  }

  @override
  void dispose() {
    WidgetInputStore.instance.removeListener(_followStore);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final element = widget.element;
    final field = TextField(
      controller: _controller,
      enabled: widget.interactive,
      keyboardType: switch (element.inputKeyboard) {
        WidgetInputKeyboard.text => TextInputType.text,
        WidgetInputKeyboard.number => TextInputType.number,
        WidgetInputKeyboard.url => TextInputType.url,
      },
      textAlign: element.alignment.textAlign,
      style: TextStyle(fontSize: element.fontSize, color: widget.color),
      cursorColor: widget.color,
      // No selection handles, no magnifier, no copy/paste bar.
      //
      // Two reasons, and the second one is a crash. A long press here is
      // already the panel's own gesture for picking a card up to reorder it,
      // so selecting text was never going to work anyway. And when both
      // happen at once, the selection handles and the card's drag copy end
      // up in the same overlay - with the card's copy added last, so the
      // anchor gets painted after the thing anchored to it, which trips a
      // rendering assert ("LeaderLayer anchor must come before
      // FollowerLayer in paint order").
      enableInteractiveSelection: false,
      decoration: InputDecoration(
        isDense: true,
        // The hint goes through the placeholders like any other text, so it
        // can name what the field is for using a value the card already has.
        hintText: DataSourcesController.instance.resolve(element.inputHint),
        hintStyle: TextStyle(
          fontSize: element.fontSize,
          color: widget.color.withValues(alpha: 0.45),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 6),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: widget.color.withValues(alpha: 0.5)),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: widget.color),
        ),
        // A disabled field greys its own border out, which in the editor
        // looks like something is broken rather than merely not typeable.
        disabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: widget.color.withValues(alpha: 0.5)),
        ),
      ),
      onChanged: (text) =>
          WidgetInputStore.instance.setText(element.inputName, text),
    );

    return SizedBox(
      width: math.min(element.width, widget.cardWidth),
      child: widget.interactive ? field : IgnorePointer(child: field),
    );
  }
}

/// An action element: an icon that fires the element's HTTP call when
/// tapped, with a brief spinner while it's in flight and a snackbar saying
/// whether it went through - the only feedback a fire-and-forget request
/// can give.
class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.element,
    required this.color,
    required this.interactive,
  });

  final WidgetElement element;
  final Color color;
  final bool interactive;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _running = false;

  Future<void> _run() async {
    if (_running) return;
    setState(() => _running = true);
    final result = await runWidgetAction(widget.element);
    if (!mounted) return;
    setState(() => _running = false);
    final s = AppStrings(LocaleController.instance.value);
    // Both kinds that leave the launcher succeed by the other app coming up
    // in front, so a snackbar saying so would land behind it and be read on
    // the way back as if something had just happened. Only a request, which
    // shows nothing at all by itself, needs the confirmation - and a failure
    // always needs saying, or the tap looks ignored.
    final leaves = widget.element.actionKind != WidgetActionKind.http;
    if (result.success && leaves) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.success ? s.actionSucceeded : s.actionFailed(
            result.detail ?? '',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final icon = widgetIcons[widget.element.template] ??
        switch (widget.element.actionKind) {
          WidgetActionKind.open => Icons.open_in_new,
          WidgetActionKind.search => Icons.search,
          WidgetActionKind.http => Icons.touch_app,
        };
    final glyph = _running
        ? SizedBox(
            width: widget.element.iconSize,
            height: widget.element.iconSize,
            child: Padding(
              padding: EdgeInsets.all(widget.element.iconSize * 0.15),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: widget.color,
              ),
            ),
          )
        : Icon(icon, size: widget.element.iconSize, color: widget.color);

    if (!widget.interactive) return glyph;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _run,
      child: glyph,
    );
  }
}

/// The answers to whatever is in the input field this element watches:
/// matching apps, settings and contacts, the result of a sum, and a web
/// search as the last row. Each one tappable.
class _ResultsList extends StatefulWidget {
  const _ResultsList({
    required this.element,
    required this.color,
    required this.cardWidth,
    required this.interactive,
  });

  final WidgetElement element;
  final Color color;
  final double cardWidth;
  final bool interactive;

  @override
  State<_ResultsList> createState() => _ResultsListState();
}

class _ResultsListState extends State<_ResultsList> {
  List<SearchHit> _hits = const [];
  String _shown = '';

  /// Rises with every search started, so a slow one (contacts go through a
  /// platform channel) can't land after a newer one and put stale rows back
  /// on screen.
  int _run = 0;

  @override
  void didUpdateWidget(_ResultsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    _searchIfNeeded();
  }

  /// One row: the icon or the two lines of text, whichever is taller, plus
  /// the padding above and below. Worked out the same way [_row] builds it,
  /// so the card can size itself without waiting for a measurement.
  double get _rowHeight {
    final fontSize = widget.element.fontSize;
    final glyph = fontSize * 1.3;
    final twoLines = fontSize * 1.3 + fontSize * 0.75 * 1.3;
    return math.max(glyph, twoLines) + fontSize * 0.6;
  }

  @override
  Widget build(BuildContext context) {
    _searchIfNeeded();
    final s = AppStrings(LocaleController.instance.value);
    final query = _query;

    // Tell the card how much of the ceiling is actually in use, so a
    // flexible one sits tight around two rows instead of always standing at
    // the height six would need.
    final rows = _hits.isEmpty ? 1 : _hits.length;
    CardHeightReports.maybeOf(context)?.report(
      widget.element.id,
      math.min(rows * _rowHeight, widget.element.height),
    );

    final Widget body;
    if (query == null) {
      body = _placeholderRow(s.searchNoFieldYet);
    } else if (query.isEmpty) {
      body = _placeholderRow(s.searchTypeSomething);
    } else if (_hits.isEmpty) {
      body = _placeholderRow(s.searchNothingFound);
    } else {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: switch (widget.element.alignment) {
          WidgetAlignment.left => CrossAxisAlignment.start,
          WidgetAlignment.center => CrossAxisAlignment.center,
          WidgetAlignment.right => CrossAxisAlignment.end,
        },
        children: [for (final hit in _hits) _row(hit)],
      );
    }

    return ConstrainedBox(
      // Its own ceiling, on top of whatever the card allows. Without this a
      // long list grows straight out of the card and over whatever else is
      // on it - which is exactly what the overflow stripes were about.
      constraints: BoxConstraints(
        maxWidth: math.min(widget.element.width, widget.cardWidth),
        maxHeight: widget.element.height,
      ),
      // Shrink-wraps while the rows fit and scrolls once they don't, so
      // nothing is ever silently out of reach.
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: body,
      ),
    );
  }

  /// What is in the field, or null when the element points at no field at
  /// all - which is worth saying out loud rather than showing the same
  /// "type something" as an empty field does.
  String? get _query =>
      WidgetInputStore.instance.textOf(widget.element.inputName);

  /// Everything besides the typed words that changes what a search returns.
  ///
  /// Comparing the words alone was not enough: ticking "Kontakte" on, or
  /// switching the search engine, leaves the words exactly as they were, so
  /// the rows on screen would keep answering the old settings until the next
  /// keystroke happened to come along.
  String get _searchKey {
    final e = widget.element;
    return [
      LocaleController.instance.value.name,
      e.inputName,
      e.searchApps,
      e.searchSettings,
      e.searchCalculation,
      e.searchContacts,
      e.webSearchUrl,
      e.resultLimit,
      _query,
    ].join(' ');
  }

  /// Runs whenever the answer on screen no longer matches what is being
  /// asked - once per keystroke or setting changed, and not at all otherwise.
  void _searchIfNeeded() {
    final key = _searchKey;
    if (key == _shown) return;
    _shown = key;
    final query = _query ?? '';
    final run = ++_run;

    if (query.trim().isEmpty) {
      if (_hits.isNotEmpty) {
        // Already inside a build here, so the emptying is deferred rather
        // than done straight away.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && run == _run) setState(() => _hits = const []);
        });
      }
      return;
    }

    runWidgetSearch(
      query: query,
      element: widget.element,
      s: AppStrings(LocaleController.instance.value),
    ).then((hits) {
      if (!mounted || run != _run) return;
      setState(() => _hits = hits);
    });
  }

  Widget _placeholderRow(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Text(
      text,
      textAlign: widget.element.alignment.textAlign,
      style: TextStyle(
        fontSize: widget.element.fontSize,
        color: widget.color.withValues(alpha: 0.45),
      ),
    ),
  );

  /// Opens what was tapped and empties the field behind it.
  ///
  /// The words were a question, and it has just been answered - leaving
  /// them there only means deleting them by hand before the next one can
  /// be asked. The answer to a sum is the exception: that row goes nowhere,
  /// so clearing it would wipe out the very thing that was being looked at.
  void _tap(SearchHit hit) {
    hit.onTap(context);
    if (hit.kind == SearchHitKind.calculation) return;
    WidgetInputStore.instance.clear(widget.element.inputName);
  }

  Widget _row(SearchHit hit) {
    final iconSize = widget.element.fontSize * 1.3;
    final row = Padding(
      // Enough that two rows read as two rows rather than as one block of
      // text, and it grows with the type size instead of staying at a fixed
      // three pixels that only looked right at the default.
      padding: EdgeInsets.symmetric(vertical: widget.element.fontSize * 0.3),
      child: Row(
        // Shrinks to its content, so the alignment below can put the whole
        // row where it belongs instead of it always filling the width.
        mainAxisSize: MainAxisSize.min,
        children: [
          // An app hit shows the app's real icon; everything else gets the
          // glyph for its kind, so the piles stay tellable apart at a glance.
          if (hit.entry != null)
            AppIcon(entry: hit.entry!, size: iconSize)
          else
            Icon(hit.icon, size: iconSize, color: widget.color),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: switch (widget.element.alignment) {
                WidgetAlignment.left => CrossAxisAlignment.start,
                WidgetAlignment.center => CrossAxisAlignment.center,
                WidgetAlignment.right => CrossAxisAlignment.end,
              },
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  hit.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: widget.element.fontSize,
                    color: widget.color,
                    // The answer to a sum is the one row that is the result
                    // rather than a way to get to one.
                    fontWeight: hit.kind == SearchHitKind.calculation
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                if (hit.subtitle.isNotEmpty)
                  Text(
                    hit.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: widget.element.fontSize * 0.75,
                      color: widget.color.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    if (!widget.interactive) return row;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _tap(hit),
      child: row,
    );
  }
}
