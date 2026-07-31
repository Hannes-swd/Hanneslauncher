import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';

import 'app_list_settings_controller.dart';

/// Full app list for the home screen with an A-Z index bar on the right.
/// All present letters are shown at all times; hovering/dragging over one
/// filters the list below to only that letter's apps and shows a floating
/// bubble with the current letter.
class AppListView extends StatefulWidget {
  const AppListView({super.key});

  @override
  State<AppListView> createState() => _AppListViewState();
}

class _AppListViewState extends State<AppListView> {
  static const double _headerHeight = 36;

  // How far left of the alphabet bar the finger needs to be dragged before
  // it counts as aiming at an app row instead of just picking a letter.
  static const double _listTargetThreshold = 60;

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
  }

  void _onSettingsChanged() {
    setState(() => _settings = AppListSettingsController.instance.value);
  }

  @override
  void dispose() {
    AppListSettingsController.instance.removeListener(_onSettingsChanged);
    _bubblePosition.dispose();
    super.dispose();
  }

  Future<void> _loadApps() async {
    final apps = await InstalledApps.getInstalledApps(
      excludeSystemApps: false,
      excludeNonLaunchableApps: true,
      withIcon: true,
    );
    apps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    _grouped.clear();
    for (final app in apps) {
      final letter = app.name.isEmpty ? '#' : app.name[0].toUpperCase();
      _grouped.putIfAbsent(letter, () => []).add(app);
    }

    if (!mounted) return;
    setState(() {
      _letters = _grouped.keys.toList();
      _loaded = true;
    });
  }

  // Which app row (if any) in the given letter's group sits under the given
  // y position, using the list's own top-down layout. Null if out of range.
  int? _targetIndexFor(String letter, double localDy) {
    final group = _grouped[letter];
    if (group == null || group.isEmpty) return null;
    final itemIndex = ((localDy - _headerHeight) / _rowHeight).floor();
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
                  final target =
                      targeting ? _targetIndexFor(letter, localDy) : null;
                  if (letter != _activeLetter || target != _targetAppIndex) {
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
        if (_isDragging && _activeLetter != null)
          ValueListenableBuilder<Offset>(
            valueListenable: _bubblePosition,
            builder: (context, position, child) {
              return Positioned(
                // Grows past 60 as the finger drags further left, so the
                // bubble follows it instead of staying pinned at the edge.
                right: 60 + position.dx,
                top: (position.dy - 40).clamp(0.0, double.infinity),
                child: child!,
              );
            },
            child: _LetterBubble(letter: _activeLetter!, color: _settings.color),
          ),
      ],
    );
  }

  Widget _buildList() {
    if (_activeLetter == null || !_grouped.containsKey(_activeLetter)) {
      // Nothing selected on the alphabet bar -> show no apps.
      return const SizedBox.shrink();
    }
    final letter = _activeLetter!;
    final appsInGroup = _grouped[letter]!;

    final items = <Widget>[
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
    ];
    for (var i = 0; i < appsInGroup.length; i++) {
      final app = appsInGroup[i];
      final isTargeted = i == _targetAppIndex;
      items.add(
        AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          height: _rowHeight,
          color: isTargeted ? Colors.black12 : Colors.transparent,
          child: ListTile(
            leading: app.icon != null
                ? Image.memory(app.icon!, width: 40, height: 40)
                : const Icon(Icons.apps, color: Colors.black),
            title: Text(
              app.name,
              style: TextStyle(
                color: _settings.color,
                fontSize: _settings.fontSize,
                fontFamily: _settings.fontFamily.isEmpty
                    ? null
                    : _settings.fontFamily,
                fontWeight: isTargeted ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            onTap: () => InstalledApps.startApp(app.packageName),
          ),
        ),
      );
    }

    // Keying by the active letter gives the list a fresh scroll position
    // whenever the filter changes instead of keeping the old offset.
    return ListView(key: ValueKey(_activeLetter), children: items);
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

  // Fixed height per letter row so the letters sit close together instead
  // of being stretched across the whole bar, while still lining up exactly
  // with where a touch/drag is mapped to an index below.
  static const double _rowHeight = 30;

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

  void _handlePosition(Offset localPosition, double height) {
    final letters = widget.letters;
    if (letters.isEmpty) return;
    final blockHeight = letters.length * _AlphabetBar._rowHeight;
    final blockTop = (height - blockHeight) * _AlphabetBar._verticalBias;
    final index = ((localPosition.dy - blockTop) / _AlphabetBar._rowHeight)
        .floor()
        .clamp(0, letters.length - 1);
    // localPosition.dx is 0 at the bar's left edge, so it goes negative once
    // the finger has moved left of it (e.g. over the app list). Rounded so
    // sub-pixel jitter doesn't cause extra rebuilds.
    final draggedLeft =
        (-localPosition.dx).clamp(0.0, _maxDragShift).roundToDouble();
    if (index != _hoveredIndex || draggedLeft != _dragShift) {
      setState(() {
        _hoveredIndex = index;
        _dragShift = draggedLeft;
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
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragStart: (details) {
            widget.onDragStateChanged(true);
            _handlePosition(details.localPosition, constraints.maxHeight);
          },
          onVerticalDragUpdate: (details) {
            _handlePosition(details.localPosition, constraints.maxHeight);
          },
          onVerticalDragEnd: (_) => _endHover(),
          onVerticalDragCancel: _endHover,
          onTapDown: (details) {
            widget.onDragStateChanged(true);
            _handlePosition(details.localPosition, constraints.maxHeight);
          },
          onTapUp: (_) => _endHover(),
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

    return SizedBox(
      height: _AlphabetBar._rowHeight,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(-maxShift * strength, 0, 0),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 90),
            curve: Curves.easeOut,
            style: TextStyle(
              fontSize: 11 + _maxExtraFontSize * strength,
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
