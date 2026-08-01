import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';

import 'app_icon.dart';
import 'app_list_settings_controller.dart';
import 'app_overrides_controller.dart';
import 'clock_settings_controller.dart';
import 'clock_widget.dart';
import 'pinned_apps_controller.dart';

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

  /// Dragging anywhere on the clock also opens/closes the settings panel,
  /// so the whole clock area works as a pull-down handle instead of just a
  /// thin strip at the very top of the screen.
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

  // Every installed app, kept so the grouping below can be redone whenever a
  // renamed app changes which letter it belongs under.
  List<AppInfo> _apps = [];
  final SplayTreeMap<String, List<AppInfo>> _grouped = SplayTreeMap();
  List<String> _letters = [];

  bool _loaded = false;
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

  AppListSettings _settings = AppListSettingsController.instance.value;
  double get _rowHeight => _settings.rowHeight;

  @override
  void initState() {
    super.initState();
    _loadApps();
    AppListSettingsController.instance.load();
    AppListSettingsController.instance.addListener(_onSettingsChanged);
    AppOverridesController.instance.load();
    AppOverridesController.instance.addListener(_onOverridesChanged);
    ClockSettingsController.instance.load();
    PinnedAppsController.instance.load();
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

  // A renamed app can move to a different letter, so the whole grouping is
  // rebuilt rather than just repainting the rows.
  void _onOverridesChanged() => _safeSetState(_group);

  @override
  void dispose() {
    AppListSettingsController.instance.removeListener(_onSettingsChanged);
    AppOverridesController.instance.removeListener(_onOverridesChanged);
    _bubblePosition.dispose();
    super.dispose();
  }

  String _nameOf(AppInfo app) =>
      AppOverridesController.instance.nameFor(app.packageName, app.name);

  Future<void> _loadApps() async {
    final apps = await InstalledApps.getInstalledApps(
      excludeSystemApps: false,
      excludeNonLaunchableApps: true,
      withIcon: true,
    );
    _apps = apps;

    _safeSetState(() {
      _group();
      _loaded = true;
    });
  }

  /// Sorts and buckets [_apps] by their displayed (possibly renamed) name.
  void _group() {
    _apps.sort(
      (a, b) => _nameOf(a).toLowerCase().compareTo(_nameOf(b).toLowerCase()),
    );

    _grouped.clear();
    for (final app in _apps) {
      final name = _nameOf(app);
      final letter = name.isEmpty ? '#' : name[0].toUpperCase();
      _grouped.putIfAbsent(letter, () => []).add(app);
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
    InstalledApps.startApp(group[index].packageName);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
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
          offstage: _activeLetter != null,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // IntrinsicWidth sizes this column to its widest child (the
              // clock), so aligning the icons to its start puts them flush
              // with the clock's left edge instead of floating at some
              // arbitrary distance from the screen edge.
              return Center(
                child: IntrinsicWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // deferToChild: only the clock's own painted area
                      // reacts, so touches beside it fall through to what's
                      // underneath.
                      GestureDetector(
                        behavior: HitTestBehavior.deferToChild,
                        onVerticalDragUpdate: widget.onPanelDragUpdate,
                        onVerticalDragEnd: widget.onPanelDragEnd,
                        child: ConstrainedBox(
                          // Caps how much of the screen the clock may claim,
                          // so the pinned apps always keep room below it.
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
                  ),
                ),
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
                  // Cheap update: only the bubble listens to this, so it
                  // doesn't trigger a rebuild of the list/alphabet bar.
                  _bubblePosition.value = Offset(draggedLeft, localDy);
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
            if (!_isDragging || _activeLetter == null) {
              return const SizedBox.shrink();
            }
            return Positioned(
              // Grows past 60 as the finger drags further left, so the
              // bubble follows it instead of staying pinned at the edge.
              right: 60 + position.dx,
              top: (position.dy - 40).clamp(0.0, double.infinity),
              child: _LetterBubble(
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

  Widget _buildPinnedApps() {
    return ValueListenableBuilder<List<String>>(
      valueListenable: PinnedAppsController.instance,
      builder: (context, pinnedPackages, child) {
        if (pinnedPackages.isEmpty) return const SizedBox.shrink();

        // Resolve packages against the already loaded app list so the icons
        // come for free; anything uninstalled meanwhile is skipped.
        final byPackage = {
          for (final apps in _grouped.values)
            for (final app in apps) app.packageName: app,
        };
        final pinnedApps = [
          for (final package in pinnedPackages)
            if (byPackage[package] != null) byPackage[package]!,
        ];
        if (pinnedApps.isEmpty) return const SizedBox.shrink();

        // Positioning is handled by the caller; this just lays the icons out.
        // A small inset keeps them from sitting hard against the clock's edge.
        return Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final app in pinnedApps)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: GestureDetector(
                    onTap: () => InstalledApps.startApp(app.packageName),
                    child: AppIcon(app: app, size: 48),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAppRow(AppInfo app, int index) {
    final isTargeted = index == _targetAppIndex;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      height: _rowHeight,
      color: isTargeted ? Colors.black12 : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          AppIcon(app: app, size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _nameOf(app),
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
    required this.onDragStateChanged,
  });

  final List<String> letters;
  final Color color;
  final ScrubCallback onScrub;
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

  void _updateRowHeight(double height) {
    final count = widget.letters.length;
    if (count == 0) return;
    final fitted = height / count;
    _rowHeight = fitted < _AlphabetBar._maxRowHeight
        ? fitted
        : _AlphabetBar._maxRowHeight;
  }

  void _handlePosition(Offset localPosition, double height) {
    final letters = widget.letters;
    if (letters.isEmpty) return;
    final blockHeight = letters.length * _rowHeight;
    final blockTop = (height - blockHeight) * _AlphabetBar._verticalBias;
    final index = ((localPosition.dy - blockTop) / _rowHeight)
        .floor()
        .clamp(0, letters.length - 1);
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
    widget.onScrub(letters[index], localPosition.dy, draggedLeft);
  }

  void _endHover() {
    setState(() {
      _hoveredIndex = null;
      _dragShift = 0;
    });
    widget.onDragStateChanged(false);
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
                for (var i = 0; i < widget.letters.length; i++)
                  _buildLetter(i, widget.letters[i]),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLetter(int index, String letter) {
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

    return SizedBox(
      height: _rowHeight,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(-maxShift * strength, 0, 0),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 90),
            curve: Curves.easeOut,
            style: TextStyle(
              fontSize: baseFontSize + extraFontSize * strength,
              fontWeight: FontWeight.w600,
              color: widget.color,
            ),
            child: Text(letter),
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
