import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_icon.dart';
import 'app_list_settings_controller.dart';
import 'app_strings.dart';
import 'clock_settings_controller.dart';
import 'clock_widget.dart';
import 'custom_colors_controller.dart';
import 'folder_sheet.dart';
import 'launcher_entries_controller.dart';
import 'launcher_entry.dart';
import 'locale_controller.dart';
import 'pinned_apps_controller.dart';
import 'pinned_quick_actions.dart';

/// Full app list for the home screen with an A-Z index bar on the right.
/// All present letters are shown at all times; hovering/dragging over one
/// filters the list below to only that letter's apps and shows a floating
/// bubble with the current letter.
class AppListView extends StatefulWidget {
  const AppListView({
    super.key,
    this.onPanelDragUpdate,
    this.onPanelDragEnd,
  });

  /// Dragging anywhere on the home screen (except the alphabet bar, which
  /// has its own vertical drag) opens/closes the settings panel, instead of
  /// just a thin strip at the very top of the screen.
  final GestureDragUpdateCallback? onPanelDragUpdate;
  final GestureDragEndCallback? onPanelDragEnd;

  @override
  State<AppListView> createState() => _AppListViewState();
}

class _AppListViewState extends State<AppListView> {
  static const double _headerHeight = 36;

  // How far left of the alphabet bar the finger needs to be dragged before
  // it counts as aiming at an app row instead of just picking a letter.
  static const double _listTargetThreshold = 60;

  // Matches the alphabet bar's own width below, so the background
  // drag-to-open-panel detector never overlaps its scrub gesture.
  static const double _alphabetBarWidth = 28;

  final SplayTreeMap<String, List<LauncherEntry>> _grouped = SplayTreeMap();
  List<String> _letters = [];

  bool get _loaded => LauncherEntriesController.instance.isLoaded;
  bool _isDragging = false;
  String? _activeLetter;
  // Index of the app row currently under the finger while dragged past the
  // alphabet bar, or null when only a letter (not a specific app) is picked.
  int? _targetAppIndex;
  // Bubble position updates on every pixel of drag, so it's kept in its own
  // notifier and only rebuilds the small bubble widget below instead of the
  // whole list + alphabet bar on every frame. dx is how far left of the
  // alphabet bar the finger is (0 = resting at the bar).
  final ValueNotifier<Offset> _bubblePosition = ValueNotifier(Offset.zero);

  // Whether the finger is currently over the search icon at the bottom of
  // the alphabet bar (shows a search bubble instead of a letter one), and
  // whether search has actually been opened (released while over it).
  bool _searchHovering = false;
  bool _searchMode = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  AppListSettings _settings = AppListSettingsController.instance.value;
  double get _rowHeight => _settings.rowHeight;

  @override
  void initState() {
    super.initState();
    LauncherEntriesController.instance.load();
    LauncherEntriesController.instance.addListener(_onEntriesChanged);
    AppListSettingsController.instance.load();
    AppListSettingsController.instance.addListener(_onSettingsChanged);
    CustomColorsController.instance.load();
    ClockSettingsController.instance.load();
    PinnedAppsController.instance.load();
    PinnedAppsLayoutController.instance.load();
  }

  // Rapid drag input (or another widget's build/notifyListeners) can call
  // this while the widget tree is still locked for the current frame. A
  // microtask runs right after, once the frame is no longer locked, so
  // setState is never invoked synchronously from such a callback.
  void _safeSetState(VoidCallback fn) {
    Future.microtask(() {
      if (!mounted) return;
      setState(fn);
    });
  }

  void _onSettingsChanged() {
    _safeSetState(() => _settings = AppListSettingsController.instance.value);
  }

  // A rename can move an app to a different letter, and web apps or folders
  // can appear or vanish at any time, so the whole grouping is rebuilt
  // rather than just repainting the rows.
  void _onEntriesChanged() => _safeSetState(_group);

  @override
  void dispose() {
    AppListSettingsController.instance.removeListener(_onSettingsChanged);
    LauncherEntriesController.instance.removeListener(_onEntriesChanged);
    _bubblePosition.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// Buckets the entries (apps, web apps and folders) by the displayed -
  /// possibly renamed - name.
  void _group() {
    _grouped.clear();
    for (final entry in LauncherEntriesController.instance.entries) {
      final name = entry.name;
      final letter = name.isEmpty ? '#' : name[0].toUpperCase();
      _grouped.putIfAbsent(letter, () => []).add(entry);
    }
    _letters = _grouped.keys.toList();
  }

  // Size of the list area (everything left of the alphabet bar), captured
  // during layout so the hit-testing below can use the same geometry the
  // list is actually drawn with.
  Size? _listSize;

  /// Column layout for a group of [itemCount] apps: apps fill a column
  /// top-to-bottom and spill into further columns once a column is full,
  /// so nothing is cut off on shorter screens.
  ({int rowsPerColumn, int columnCount, double columnWidth})? _gridFor(
    int itemCount,
  ) {
    final size = _listSize;
    if (size == null || itemCount == 0 || size.width <= 0) return null;
    final availableHeight = size.height - _headerHeight;
    if (availableHeight <= 0) return null;
    final rowsPerColumn = math.max(1, (availableHeight / _rowHeight).floor());
    final columnCount = (itemCount / rowsPerColumn).ceil();
    return (
      rowsPerColumn: rowsPerColumn,
      columnCount: columnCount,
      columnWidth: size.width / columnCount,
    );
  }

  // Which app (if any) sits under the finger, given how far left of the
  // alphabet bar it is and its vertical position. Null if outside the grid.
  int? _targetIndexFor(String letter, double localDy, double draggedLeft) {
    final group = _grouped[letter];
    if (group == null || group.isEmpty) return null;
    final grid = _gridFor(group.length);
    if (grid == null) return null;

    // draggedLeft counts leftwards from the bar's left edge, which is the
    // list's right edge.
    final x = _listSize!.width - draggedLeft;
    final column = (x / grid.columnWidth).floor();
    if (column < 0 || column >= grid.columnCount) return null;

    final row = ((localDy - _headerHeight) / _rowHeight).floor();
    if (row < 0 || row >= grid.rowsPerColumn) return null;

    final itemIndex = column * grid.rowsPerColumn + row;
    if (itemIndex < 0 || itemIndex >= group.length) return null;
    return itemIndex;
  }

  void _launchTargetedApp() {
    final letter = _activeLetter;
    final index = _targetAppIndex;
    if (letter == null || index == null) return;
    final group = _grouped[letter];
    if (group == null || index >= group.length) return;
    _open(group[index]);
  }

  /// Launches an entry, or - for a folder - shows its contents instead.
  void _open(LauncherEntry entry) {
    if (entry.isFolder) {
      showFolderSheet(context, entry.folder!);
    } else {
      entry.launch();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        // Lets dragging down open/close the settings panel from anywhere on
        // the home screen, not just on the clock - translucent so it never
        // blocks taps on the icons/list items painted on top of it, and
        // inset from the alphabet bar so its own vertical scrub gesture is
        // never contested.
        Positioned(
          left: 0,
          right: _alphabetBarWidth,
          top: 0,
          bottom: 0,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onVerticalDragUpdate: widget.onPanelDragUpdate,
            onVerticalDragEnd: widget.onPanelDragEnd,
          ),
        ),
        // Kept as a permanent child (hidden via Offstage rather than being
        // added/removed) so the Stack's children never shift position. If
        // they did, Flutter would rebuild the alphabet bar below and cancel
        // whatever drag is currently in progress on it.
        //
        // Positioned at the Stack level (full screen width) rather than
        // inside the narrower list column, so it's centered on the whole
        // screen instead of being skewed left by the alphabet bar's width.
        // deferToChild: only the clock's own painted area reacts, so touches
        // on the empty space below it still fall through to whatever is
        // underneath. The alphabet bar sits later in the Stack, so it wins
        // the hit test in the strip they overlap.
        // Clock on top with the pinned apps centred in the space left below
        // it. Both hidden while browsing the alphabet, and kept as one
        // permanent Stack child so the children never shift position.
        Offstage(
          offstage: _activeLetter != null || _searchMode,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // The clock is centered on its own, independently of the
              // pinned apps below it - previously both sat in one column
              // sized to the clock's width (via IntrinsicWidth), so the
              // pinned icons landed flush with whatever the clock's left
              // edge happened to be instead of a spot the user picks.
              return Column(
                children: [
                  ValueListenableBuilder<ClockSettings>(
                    valueListenable: ClockSettingsController.instance,
                    builder: (context, settings, child) {
                      // Always anchored to the top - only how far down and
                      // how far to the side is adjustable.
                      final alignment = switch (settings.alignment) {
                        ClockAlignment.left => Alignment.topLeft,
                        ClockAlignment.center => Alignment.topCenter,
                        ClockAlignment.right => Alignment.topRight,
                      };
                      return Padding(
                        padding: EdgeInsets.only(top: settings.topPadding),
                        child: Align(
                          alignment: alignment,
                          child: Padding(
                            padding: EdgeInsets.only(
                              left: settings.alignment == ClockAlignment.left
                                  ? settings.sidePadding
                                  : 0,
                              right:
                                  settings.alignment == ClockAlignment.right
                                  ? settings.sidePadding
                                  : 0,
                            ),
                            child: child,
                          ),
                        ),
                      );
                    },
                    // No drag handler here any more - the background
                    // detector at the bottom of the Stack now covers this
                    // whole area already, and stacking a second competing
                    // vertical-drag recognizer on top of it would just
                    // leave which one wins ambiguous.
                    child: ConstrainedBox(
                      // Caps how much of the screen the clock may claim, so
                      // the pinned apps always keep room below it.
                      constraints: BoxConstraints(
                        maxHeight: constraints.maxHeight * 0.7,
                      ),
                      child: const ClockDisplay(),
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _buildPinnedApps(),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        Row(
          children: [
            Expanded(child: _buildList()),
            SizedBox(
              width: 28,
              child: _AlphabetBar(
                letters: _letters,
                color: _settings.color,
                onScrub: (barLetter, localDy, draggedLeft) {
                  // Below the threshold: scrubbing up/down on the bar picks
                  // the letter. Past it, the letter locks to whatever it
                  // was when the finger crossed over, and dy instead picks
                  // an app row within that group (using the list's own
                  // layout, not the bar's).
                  final targeting = draggedLeft >= _listTargetThreshold;
                  final letter = targeting
                      ? (_activeLetter ?? barLetter)
                      : barLetter;
                  final target = targeting
                      ? _targetIndexFor(letter, localDy, draggedLeft)
                      : null;
                  if (letter != _activeLetter || target != _targetAppIndex) {
                    // Stays synchronous: the release handler below reads
                    // _targetAppIndex right away to decide what to launch,
                    // so it must always reflect the latest drag position.
                    setState(() {
                      _activeLetter = letter;
                      _targetAppIndex = target;
                    });
                  }
                },
                onBubblePositionChanged: (offset) {
                  // Cheap update: only the bubble listens to this, so it
                  // doesn't trigger a rebuild of the list/alphabet bar.
                  _bubblePosition.value = offset;
                },
                onSearchHoverChanged: (hovering) {
                  if (hovering == _searchHovering) return;
                  setState(() {
                    _searchHovering = hovering;
                    if (hovering) {
                      // Reaching the search icon drops whatever letter/app
                      // was targeted a moment ago in the same drag, so
                      // releasing there can never also launch a stale
                      // target.
                      _activeLetter = null;
                      _targetAppIndex = null;
                    }
                  });
                },
                onSearchActivate: () {
                  setState(() => _searchMode = true);
                  // The field needs to exist first before it can take focus.
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _searchFocusNode.requestFocus();
                  });
                },
                onDragStateChanged: (dragging) {
                  if (!dragging) _launchTargetedApp();
                  setState(() {
                    _isDragging = dragging;
                    if (!dragging) {
                      _activeLetter = null;
                      _targetAppIndex = null;
                    }
                  });
                },
              ),
            ),
          ],
        ),
        // Also a permanent child for the same reason as the clock above.
        ValueListenableBuilder<Offset>(
          valueListenable: _bubblePosition,
          builder: (context, position, child) {
            if (!_isDragging || (_activeLetter == null && !_searchHovering)) {
              return const SizedBox.shrink();
            }
            return Positioned(
              // Grows past 60 as the finger drags further left, so the
              // bubble follows it instead of staying pinned at the edge.
              right: 60 + position.dx,
              top: (position.dy - 40).clamp(0.0, double.infinity),
              child: _searchHovering
                  ? _SearchBubble(color: _settings.color)
                  : _LetterBubble(
                      letter: _activeLetter!,
                      color: _settings.color,
                    ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildList() {
    if (_searchMode) return _buildSearchView();

    return LayoutBuilder(
      builder: (context, constraints) {
        // Recorded for _targetIndexFor above, so hit-testing and drawing
        // always agree on the column layout.
        _listSize = Size(constraints.maxWidth, constraints.maxHeight);

        if (_activeLetter == null || !_grouped.containsKey(_activeLetter)) {
          // Nothing selected on the alphabet bar -> the clock (rendered
          // above, at the Stack level) is the only thing shown.
          return const SizedBox.shrink();
        }
        final letter = _activeLetter!;
        final appsInGroup = _grouped[letter]!;
        final grid = _gridFor(appsInGroup.length);
        if (grid == null) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: _headerHeight,
              child: Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    letter,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var col = 0; col < grid.columnCount; col++)
                    SizedBox(
                      width: grid.columnWidth,
                      child: Column(
                        children: [
                          for (
                            var row = 0;
                            row < grid.rowsPerColumn &&
                                col * grid.rowsPerColumn + row <
                                    appsInGroup.length;
                            row++
                          )
                            _buildAppRow(
                              appsInGroup[col * grid.rowsPerColumn + row],
                              col * grid.rowsPerColumn + row,
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// The search icon's release swaps the list for this: a text field plus
  /// every entry whose name contains what's typed, spanning every letter
  /// instead of just the one group a scrub would reach.
  Widget _buildSearchView() {
    final s = AppStrings(LocaleController.instance.value);
    final query = _searchController.text.trim().toLowerCase();
    final allEntries = LauncherEntriesController.instance.entries;
    final results = [
      for (final entry in allEntries)
        if (query.isEmpty || entry.name.toLowerCase().contains(query)) entry,
    ];
    // The controller's own list is already alphabetical - only "newest
    // first" needs a resort here.
    if (_settings.sortMode == AppListSortMode.newestFirst) {
      results.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: _headerHeight,
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: s.searchApps,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
              PopupMenuButton<AppListSortMode>(
                icon: const Icon(Icons.sort),
                tooltip: s.sortBy,
                initialValue: _settings.sortMode,
                onSelected: (mode) => AppListSettingsController.instance
                    .update(_settings.copyWith(sortMode: mode)),
                itemBuilder: (context) => [
                  CheckedPopupMenuItem(
                    value: AppListSortMode.alphabetical,
                    checked: _settings.sortMode ==
                        AppListSortMode.alphabetical,
                    child: Text(s.sortAlphabetical),
                  ),
                  CheckedPopupMenuItem(
                    value: AppListSortMode.newestFirst,
                    checked:
                        _settings.sortMode == AppListSortMode.newestFirst,
                    child: Text(s.sortNewestFirst),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: _closeSearch,
              ),
            ],
          ),
        ),
        Expanded(
          child: results.isEmpty
              ? Center(
                  child: Text(
                    s.noSearchResults,
                    style: const TextStyle(color: Colors.black54),
                  ),
                )
              : ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final entry = results[index];
                    return GestureDetector(
                      onTap: () {
                        _closeSearch();
                        _open(entry);
                      },
                      child: _buildAppRow(entry, -1),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _closeSearch() {
    _searchFocusNode.unfocus();
    setState(() {
      _searchMode = false;
      _searchController.clear();
    });
  }

  Widget _buildPinnedApps() {
    return ValueListenableBuilder<List<String>>(
      valueListenable: PinnedAppsController.instance,
      builder: (context, pinnedKeys, child) {
        if (pinnedKeys.isEmpty) return const SizedBox.shrink();

        // Resolve the pinned keys against the already loaded entries so the
        // icons come for free; anything uninstalled (or a web app / folder
        // deleted meanwhile) is skipped.
        final pinnedApps = LauncherEntriesController.instance.resolve(
          pinnedKeys,
        );
        if (pinnedApps.isEmpty) return const SizedBox.shrink();

        // Positioning is handled by the caller; this just lays the icons
        // out, with the user's own left margin instead of one tied to the
        // clock's width.
        return ValueListenableBuilder<double>(
          valueListenable: PinnedAppsLayoutController.instance,
          builder: (context, leftMargin, child) => Padding(
            padding: EdgeInsets.only(left: leftMargin),
            child: child,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final entry in pinnedApps)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: GestureDetector(
                    onTap: () => _open(entry),
                    // Long press edits the pin itself (icon, or a folder's
                    // color) instead of opening it.
                    onLongPress: () => showPinnedQuickActions(context, entry),
                    child: AppIcon(entry: entry, size: 48),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAppRow(LauncherEntry entry, int index) {
    final isTargeted = index == _targetAppIndex;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      height: _rowHeight,
      color: isTargeted ? Colors.black12 : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          AppIcon(entry: entry, size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              entry.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _settings.color,
                fontSize: _settings.fontSize,
                fontFamily: _settings.fontFamily.isEmpty
                    ? null
                    : _settings.fontFamily,
                fontWeight: isTargeted ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Called with the currently hovered letter, the local vertical position
/// (for the letter bubble), and how far left of the bar the finger has
/// dragged (used to detect when it's over the app list, targeting a row).
typedef ScrubCallback = void Function(
  String letter,
  double localDy,
  double draggedLeft,
);

class _AlphabetBar extends StatefulWidget {
  const _AlphabetBar({
    required this.letters,
    required this.color,
    required this.onScrub,
    required this.onBubblePositionChanged,
    required this.onSearchHoverChanged,
    required this.onSearchActivate,
    required this.onDragStateChanged,
  });

  final List<String> letters;
  final Color color;
  final ScrubCallback onScrub;
  final ValueChanged<Offset> onBubblePositionChanged;

  /// Fired as the finger enters/leaves the search icon below the letters.
  final ValueChanged<bool> onSearchHoverChanged;

  /// Fired when the finger is released while over the search icon.
  final VoidCallback onSearchActivate;
  final ValueChanged<bool> onDragStateChanged;

  // Preferred height per letter row. Shrinks automatically when there are
  // more letters than comfortably fit, so the alphabet is never cut off on
  // shorter screens.
  static const double _maxRowHeight = 30;

  // Where the letter block sits vertically: 0.5 = centered, higher = lower
  // on screen. Kept in one place so the drawn position and the hit-test
  // math below always agree.
  static const double _verticalBias = 0.65;

  @override
  State<_AlphabetBar> createState() => _AlphabetBarState();
}

class _AlphabetBarState extends State<_AlphabetBar> {
  // How many rows out the wave bulge reaches at rest, and how much further
  // it reaches the more the finger is dragged out (so pulling further left
  // widens the wave instead of just making the same 2-3 neighbors steeper).
  static const double _waveReach = 3;
  static const double _extraReachAtMaxDrag = 5;
  static const double _maxExtraFontSize = 10;
  static const double _baseShift = 16;
  // How much extra the wave bulges out for every pixel the finger has
  // dragged left of the bar, and the cap on that extra pull.
  static const double _dragShiftFactor = 1.4;
  static const double _maxDragShift = 220;

  int? _hoveredIndex;
  double _dragShift = 0;

  // Row height actually in use, recalculated per layout so every letter
  // fits on screen. Drawing and hit-testing both read this.
  double _rowHeight = _AlphabetBar._maxRowHeight;

  // A search icon sits one row below the last letter, so the bar's own row
  // count is one more than the letter count throughout this class.
  int get _rowCount => widget.letters.length + 1;

  void _updateRowHeight(double height) {
    final fitted = height / _rowCount;
    _rowHeight = fitted < _AlphabetBar._maxRowHeight
        ? fitted
        : _AlphabetBar._maxRowHeight;
  }

  void _handlePosition(Offset localPosition, double height) {
    final letters = widget.letters;
    final blockHeight = _rowCount * _rowHeight;
    final blockTop = (height - blockHeight) * _AlphabetBar._verticalBias;
    final index = ((localPosition.dy - blockTop) / _rowHeight)
        .floor()
        .clamp(0, _rowCount - 1);
    // localPosition.dx is 0 at the bar's left edge, so it goes negative once
    // the finger has moved left of it (e.g. over the app list). Rounded so
    // sub-pixel jitter doesn't cause extra rebuilds.
    final draggedLeft = math.max(0.0, -localPosition.dx).roundToDouble();
    // The wave visual saturates, but the raw distance is reported onwards
    // so multi-column targeting can reach the leftmost column.
    final shiftForWave = draggedLeft.clamp(0.0, _maxDragShift);
    if (index != _hoveredIndex || shiftForWave != _dragShift) {
      setState(() {
        _hoveredIndex = index;
        _dragShift = shiftForWave;
      });
    }
    final onSearchRow = index == letters.length;
    widget.onSearchHoverChanged(onSearchRow);
    if (!onSearchRow) widget.onScrub(letters[index], localPosition.dy, draggedLeft);
    widget.onBubblePositionChanged(Offset(draggedLeft, localPosition.dy));
  }

  void _endHover() {
    final wasOnSearchRow = _hoveredIndex == widget.letters.length;
    setState(() {
      _hoveredIndex = null;
      _dragShift = 0;
    });
    widget.onSearchHoverChanged(false);
    widget.onDragStateChanged(false);
    if (wasOnSearchRow) widget.onSearchActivate();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _updateRowHeight(constraints.maxHeight);
        return GestureDetector(
          // Only a drag recognizer here (no tap recognizer competing for
          // the same pointer) so the very first touch-and-move is
          // recognized immediately, instead of waiting to see whether it
          // resolves as a tap first.
          // Pan (any direction) rather than vertical-only: dragging straight
          // sideways off the bar towards an app must work too, not just
          // scrubbing up/down first.
          behavior: HitTestBehavior.translucent,
          onPanStart: (details) {
            widget.onDragStateChanged(true);
            _handlePosition(details.localPosition, constraints.maxHeight);
          },
          onPanUpdate: (details) {
            _handlePosition(details.localPosition, constraints.maxHeight);
          },
          onPanEnd: (_) => _endHover(),
          onPanCancel: _endHover,
          child: Align(
            // _verticalBias is a 0..1 fraction; Alignment's y axis is -1..1.
            alignment: Alignment(0, _AlphabetBar._verticalBias * 2 - 1),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < _rowCount; i++) _buildRow(i),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Row `letters.length` (one past the last letter) is the search icon at
  /// the very bottom of the bar; every row before that is a letter.
  Widget _buildRow(int index) {
    final isSearchRow = index == widget.letters.length;
    final dragRatio = (_dragShift / _maxDragShift).clamp(0.0, 1.0);
    final effectiveReach = _waveReach + _extraReachAtMaxDrag * dragRatio;
    final distance = _hoveredIndex == null
        ? effectiveReach + 1
        : (index - _hoveredIndex!).abs().toDouble();
    // A smooth (cosine) falloff instead of a straight line, so neighbours
    // taper off gently rather than dropping sharply at the reach's edge.
    final linear = (1 - distance / effectiveReach).clamp(0.0, 1.0);
    final strength = math.sin(linear * math.pi / 2);
    final maxShift = _baseShift + _dragShift * _dragShiftFactor;

    // Scale the type down alongside the row when the alphabet had to be
    // squeezed, so tightly packed letters don't overlap each other. The
    // wave's magnification scales too, otherwise the enlarged letters would
    // collide with their neighbours on a tightly packed bar.
    final rawScale = _rowHeight / _AlphabetBar._maxRowHeight;
    final scale = rawScale < 1 ? rawScale : 1.0;
    final baseFontSize = 11 * scale;
    final extraFontSize = _maxExtraFontSize * scale;
    final animatedSize = baseFontSize + extraFontSize * strength;

    return SizedBox(
      height: _rowHeight,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(-maxShift * strength, 0, 0),
          child: isSearchRow
              ? Icon(Icons.search, size: animatedSize + 8, color: widget.color)
              : AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 90),
                  curve: Curves.easeOut,
                  style: TextStyle(
                    fontSize: animatedSize,
                    fontWeight: FontWeight.w600,
                    color: widget.color,
                  ),
                  child: Text(widget.letters[index]),
                ),
        ),
      ),
    );
  }
}

class _LetterBubble extends StatelessWidget {
  const _LetterBubble({required this.letter, required this.color});

  final String letter;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textColor = color == Colors.white ? Colors.black : color;
    return Text(
      letter,
      style: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
    );
  }
}

class _SearchBubble extends StatelessWidget {
  const _SearchBubble({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final iconColor = color == Colors.white ? Colors.black : color;
    return Icon(Icons.search, size: 32, color: iconColor);
  }
}
