import 'package:flutter/material.dart';

import 'app_list_view.dart';
import 'locale_controller.dart';
import 'settings_screen.dart';
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
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details, double height) {
    _controller.value += details.delta.dy / height;
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
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
                  const Expanded(child: AppListView()),
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
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: (details) =>
                      _onDragUpdate(details, height),
                  onVerticalDragEnd: _onDragEnd,
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
                            child: Align(
                              alignment: Alignment.topRight,
                              child: IconButton(
                                icon: const Icon(Icons.settings),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const SettingsScreen(),
                                    ),
                                  );
                                },
                              ),
                            ),
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
