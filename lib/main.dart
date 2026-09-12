import 'package:flutter/material.dart';

import 'app_list_settings_controller.dart';
import 'app_list_view.dart';
import 'calendar_controller.dart';
import 'data_packages_controller.dart';
import 'data_sources_controller.dart';
import 'default_launcher_controller.dart';
import 'default_launcher_screen.dart';
import 'device_stats_controller.dart';
import 'icon_theme_controller.dart';
import 'locale_controller.dart';
import 'offline_mode_controller.dart';
import 'panel_view.dart';
import 'system_gesture_exclusion.dart';
import 'update_controller.dart';
import 'wallpaper_controller.dart';
import 'wallpaper_view.dart';

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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // 0 = panel fully hidden (above the screen), 1 = panel fully open.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: 0,
  );

  // Whether the home screen is the thing on screen right now: the launcher
  // is in front and the panel isn't covering it. A moving wallpaper (GIF or
  // video) only runs while this holds - kept as its own notifier so the
  // wallpaper is the only thing that rebuilds when it flips.
  final ValueNotifier<bool> _homeVisible = ValueNotifier(true);

  // Whether the panel is showing at all, even part way. Its own notifier so
  // that the back button's handler is the only thing rebuilt when it flips,
  // rather than the whole tree once per animation frame.
  final ValueNotifier<bool> _panelOpen = ValueNotifier(false);

  bool _inForeground = true;

  // The panel's block list. Lives up here because the panel is never torn
  // down - it is only moved off-screen - so its scroll offset survives every
  // close and has to be reset from outside.
  final ScrollController _panelScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_updateHomeVisible);
    _controller.addListener(_resetScrollWhenClosed);
    AppListSettingsController.instance.addListener(_onAppListSettingsChanged);
    WallpaperController.instance.load();
    LocaleController.instance.load();
    IconThemeController.instance.load();
    OfflineModeController.instance.load();
    // Reads the installed version and the last check's result from disk, so
    // the settings button already carries the update mark on the first
    // frame. The check itself waits for the panel to be opened.
    UpdateController.instance.load();
    _maybeAskAboutDefaultLauncher();
  }

  /// A launcher that was installed but never made the home app never opens
  /// on its own, so nothing in it can point that out - except once, here.
  Future<void> _maybeAskAboutDefaultLauncher() async {
    if (!await DefaultLauncherController.instance.takeFirstRunPrompt()) return;
    if (!mounted) return;
    await showDefaultLauncherPrompt(context);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppListSettingsController.instance.removeListener(
      _onAppListSettingsChanged,
    );
    _controller.dispose();
    _panelScroll.dispose();
    _homeVisible.dispose();
    _panelOpen.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Anything short of `resumed` means the home screen isn't being looked
    // at: another app opened on top, the screen turned off, the notification
    // shade pulled down.
    _inForeground = state == AppLifecycleState.resumed;
    // Tapping an app in the panel leaves it open behind that app, so coming
    // back from it would land in the panel instead of on the home screen.
    // Snapped shut rather than animated: nobody is looking at this moment,
    // and on return the home screen is simply there. Only `paused` (fully
    // covered) counts - `inactive` is also what a pulled-down notification
    // shade or a passing system dialog looks like.
    if (state == AppLifecycleState.paused) _controller.value = 0;
    _updateHomeVisible();
  }

  // Whatever was scrolled to last time is not where the next open should
  // start; the top of the list is.
  void _resetScrollWhenClosed() {
    if (_controller.value != 0) return;
    if (!_panelScroll.hasClients) return;
    if (_panelScroll.offset == 0) return;
    _panelScroll.jumpTo(0);
  }

  void _updateHomeVisible() {
    // The panel is a full screen sheet, so once it's all the way down there
    // is nothing left of the wallpaper worth animating.
    _homeVisible.value = _inForeground && _controller.value < 0.99;
    _panelOpen.value = _controller.value > 0;
  }

  // How far the drag in progress has travelled, and the screen height it is
  // measured against. Both are needed when it ends: see _onDragEnd for why
  // the distance alone decides some of those cases.
  double _dragTotal = 0;
  double _dragHeight = 1;

  // Every new drag starts the running total over. Doing it here rather than
  // when the last one ended also covers a drag that was cancelled instead of
  // finished - that one never reaches _onDragEnd, and its leftover distance
  // would then decide the next drag.
  void _onDragStart(DragStartDetails details) {
    _dragTotal = 0;
  }

  // The panel follows the finger one to one: dragging down pulls it in,
  // dragging up pushes it back out. So it is dismissed by the reverse of the
  // gesture that opened it, never by swiping down again.
  void _onDragUpdate(DragUpdateDetails details, double height) {
    _dragTotal += details.delta.dy;
    _dragHeight = height;
    _controller.value += details.delta.dy / height;
  }

  void _closePanel() {
    if (_controller.value == 0) return;
    _controller.animateTo(0, curve: Curves.easeOut);
  }

  void _onDragEnd(DragEndDetails details) {
    // Downwards is positive, so a flick means "keep going" either way round.
    final velocity = details.primaryVelocity ?? 0;
    final total = _dragTotal;
    final height = _dragHeight;
    _dragTotal = 0;

    final bool open;
    if (velocity.abs() > 300) {
      // Fast flick: go with the direction of the flick.
      open = velocity > 0;
    } else if (total.abs() >= 6 && total.abs() < height * 0.15) {
      // Both handles sit against an edge of the screen - the panel's at the
      // top, the home screen's strip just under it - and the panel travels
      // with the finger. A drag away from that edge therefore runs out of
      // screen after a few dozen pixels and can never reach the half-way
      // mark the rule below wants, so slowly dragging the panel shut did
      // nothing at all. A short drag goes by its direction instead.
      open = total > 0;
    } else {
      // Dragged a real distance and released: snap to whichever side is
      // closer.
      open = _controller.value > 0.5;
    }
    _controller.animateTo(open ? 1 : 0, curve: Curves.easeOut);
    // Opening the panel is the moment its widgets become visible, so that's
    // when anything past its refresh interval is fetched - a panel nobody
    // pulls down costs no data at all.
    if (open) {
      DataSourcesController.instance.refreshStale();
      CalendarController.instance.refresh();
      // Same reasoning, and the settings button that carries the mark is
      // right there in the panel's header.
      UpdateController.instance.refreshStale();
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
  bool? _exclusionLeftEdgeSent;

  void _updateGestureExclusion(double totalHeight) {
    // Which edge the bar is on moves with the left-handed setting, so the
    // strip Android must keep its hands off moves with it too.
    final leftEdge = AppListSettingsController.instance.value.leftHanded;
    if (_exclusionHeightSent == totalHeight &&
        _exclusionLeftEdgeSent == leftEdge) {
      return;
    }
    _exclusionHeightSent = totalHeight;
    _exclusionLeftEdgeSent = leftEdge;
    SystemGestureExclusion.excludeBarEdge(
      barWidth: _alphabetBarWidth,
      top: _dragStripHeight,
      bottom: totalHeight,
      leftEdge: leftEdge,
    );
  }

  // Switching hands doesn't resize anything, so nothing else would ever ask
  // for the exclusion strip to be moved.
  void _onAppListSettingsChanged() {
    final height = _exclusionHeightSent;
    if (height != null) _updateGestureExclusion(height);
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
        return ValueListenableBuilder<bool>(
          valueListenable: _panelOpen,
          builder: (context, panelOpen, child) => PopScope(
            // Back closes the panel rather than doing nothing, which is what
            // it does on a home screen otherwise - and it is the way out
            // that needs no aiming at all. With the panel shut it goes back
            // to doing nothing, same as any launcher.
            canPop: !panelOpen,
            onPopInvokedWithResult: (didPop, result) {
              if (!didPop) _closePanel();
            },
            child: child!,
          ),
          child: Stack(
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: _homeVisible,
              builder: (context, visible, child) =>
                  WallpaperView(animate: visible),
            ),
            Scaffold(
              backgroundColor: Colors.transparent,
              body: Column(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onVerticalDragStart: _onDragStart,
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
                      onPanelDragStart: _onDragStart,
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
                            onHandleDragStart: _onDragStart,
                            onHandleDragUpdate: (details) =>
                                _onDragUpdate(details, height),
                            onHandleDragEnd: _onDragEnd,
                            onCloseRequested: _closePanel,
                            scrollController: _panelScroll,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
