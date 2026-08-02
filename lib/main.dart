import 'package:flutter/material.dart';

import 'app_list_view.dart';
import 'calendar_controller.dart';
import 'data_packages_controller.dart';
import 'data_sources_controller.dart';
import 'device_stats_controller.dart';
import 'icon_theme_controller.dart';
import 'locale_controller.dart';
import 'panel_view.dart';
import 'system_gesture_exclusion.dart';
import 'wallpaper_controller.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: LauncherRoot(),
    );
  }
}

class LauncherRoot extends StatefulWidget {
  const LauncherRoot({super.key});

  @override
  State<LauncherRoot> createState() => _LauncherRootState();
}

class _LauncherRootState extends State<LauncherRoot>
    with SingleTickerProviderStateMixin {
  // 0 = panel fully hidden (above the screen), 1 = panel fully open.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: 0,
  );

  @override
  void initState() {
    super.initState();
    WallpaperController.instance.load();
    LocaleController.instance.load();
    IconThemeController.instance.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details, double height) {
    _controller.value += details.delta.dy / height;
  }

  void _closePanel() {
    if (_controller.value == 0) return;
    _controller.animateTo(0, curve: Curves.easeOut);
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final bool open;
    if (velocity.abs() > 300) {
      // Fast flick: go with the direction of the flick.
      open = velocity > 0;
    } else {
      // Slow drag released: snap to whichever side is closer.
      open = _controller.value > 0.5;
    }
    _controller.animateTo(open ? 1 : 0, curve: Curves.easeOut);
    // Opening the panel is the moment its widgets become visible, so that's
    // when anything past its refresh interval is fetched - a panel nobody
    // pulls down costs no data at all.
    if (open) {
      DataSourcesController.instance.refreshStale();
      CalendarController.instance.refresh();
      DeviceStatsController.instance.ensureFresh(
        wantsSteps: DeviceDataController.instance.value,
        wantsMostUsedApp: DeviceDataController.instance.value,
      );
    }
  }

  static const _panelRadius = BorderRadius.only(
    bottomLeft: Radius.circular(32),
    bottomRight: Radius.circular(32),
  );

  // Height of the invisible strip at the top of the home screen that opens
  // the settings panel on swipe-down. Kept separate from the app list below
  // so dragging in the list (scrolling) and on the alphabet bar don't fight
  // with this gesture.
  static const _dragStripHeight = 36.0;

  // Must match the alphabet bar's width in app_list_view.dart.
  static const _alphabetBarWidth = 28.0;

  double? _exclusionHeightSent;

  void _updateGestureExclusion(double totalHeight) {
    if (_exclusionHeightSent == totalHeight) return;
    _exclusionHeightSent = totalHeight;
    SystemGestureExclusion.excludeRightEdge(
      barWidth: _alphabetBarWidth,
      top: _dragStripHeight,
      bottom: totalHeight,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Read here because this is the highest place that sees the phone's
    // clock setting; the widget cards format {{zeit}} from it.
    DataSourcesController.use24HourFormat =
        MediaQuery.of(context).alwaysUse24HourFormat;

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _updateGestureExclusion(height),
        );
        return Stack(
          children: [
            ValueListenableBuilder(
              valueListenable: WallpaperController.instance,
              builder: (context, wallpaper, child) {
                return Container(
                  color: Colors.white,
                  width: double.infinity,
                  height: double.infinity,
                  child: wallpaper == null
                      ? null
                      : Image.file(
                          wallpaper,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                );
              },
            ),
            Scaffold(
              backgroundColor: Colors.transparent,
              body: Column(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onVerticalDragUpdate: (details) =>
                        _onDragUpdate(details, height),
                    onVerticalDragEnd: _onDragEnd,
                    child: const SizedBox(
                      height: _dragStripHeight,
                      width: double.infinity,
                    ),
                  ),
                  Expanded(
                    child: AppListView(
                      onPanelDragUpdate: (details) =>
                          _onDragUpdate(details, height),
                      onPanelDragEnd: _onDragEnd,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final dy = (_controller.value - 1) * height;
                  return Transform.translate(
                    offset: Offset(0, dy),
                    child: child,
                  );
                },
                // No drag handler around the whole panel any more: the block
                // list inside scrolls, and the two gestures would fight over
                // every touch. The panel is dragged by its header instead.
                child: Scaffold(
                  backgroundColor: Colors.transparent,
                  body: Container(
                    decoration: BoxDecoration(
                      borderRadius: _panelRadius,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: _panelRadius,
                      child: Container(
                        color: Colors.white.withValues(alpha: 0.85),
                        child: SafeArea(
                          child: PanelView(
                            onHandleDragUpdate: (details) =>
                                _onDragUpdate(details, height),
                            onHandleDragEnd: _onDragEnd,
                            onCloseRequested: _closePanel,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
        );
      },
    );
  }
}
