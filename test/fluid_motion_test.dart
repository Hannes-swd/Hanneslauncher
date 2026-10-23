import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanneslauncher/app_dialogs.dart';
import 'package:hanneslauncher/design_controller.dart';
import 'package:hanneslauncher/design_tokens.dart';
import 'package:hanneslauncher/fluid_motion.dart';
import 'package:hanneslauncher/panel_scroll.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The movement under the panel and the app list: the spring things settle
/// on once a finger lets go, and the block list handing a push past its end
/// on to the panel.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DesignController.instance.update(DesignSettings());
  });

  group('settle', () {
    testWidgets('lands exactly on the target', (tester) async {
      // A panel resting at 0.0004 still counts as open - the back button
      // stays caught - so "nearly there" is a bug, not a rounding.
      final controller = AnimationController(vsync: const TestVSync());
      addTearDown(controller.dispose);
      controller.value = 0.6;

      settle(controller, 0, velocity: -2);
      await tester.pumpAndSettle();
      expect(controller.value, 0);

      settle(controller, 1, velocity: 6);
      await tester.pumpAndSettle();
      expect(controller.value, 1);
    });

    testWidgets('carries the speed it is handed', (tester) async {
      // Let go fast, the spring is further along after the same time than
      // let go from standstill - which is the whole point of it.
      final still = AnimationController(vsync: const TestVSync());
      final flung = AnimationController(vsync: const TestVSync());
      addTearDown(still.dispose);
      addTearDown(flung.dispose);
      still.value = 0;
      flung.value = 0;

      settle(still, 1);
      settle(flung, 1, velocity: 8);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(flung.value, greaterThan(still.value));
      await tester.pumpAndSettle();
    });

    testWidgets('jumps with motion switched off', (tester) async {
      await DesignController.instance.update(DesignSettings(motion: 0));
      final controller = AnimationController(vsync: const TestVSync());
      addTearDown(controller.dispose);

      settle(controller, 1);
      // No frame needed: off means there is nothing to watch.
      expect(controller.value, 1);
    });
  });

  group('PressScale', () {
    testWidgets('dips under the finger and still lets the tap through', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        Center(
          child: GestureDetector(
            onTap: () => taps++,
            child: const PressScale(
              child: SizedBox(width: 48, height: 48, child: ColoredBox(
                color: Color(0xFF000000),
              )),
            ),
          ),
        ),
      );

      double scale() => tester
          .widget<ScaleTransition>(find.byType(ScaleTransition))
          .scale
          .value;

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(PressScale)),
      );
      // One frame to start the animation on, then time for it to run.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(scale(), lessThan(1));

      await gesture.up();
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(scale(), closeTo(1, 0.001));
    });

    testWidgets('lets go as soon as the finger sets off to scroll', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Center(
          child: PressScale(
            child: SizedBox(width: 48, height: 48, child: ColoredBox(
              color: Color(0xFF000000),
            )),
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(PressScale)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(
        tester
            .widget<ScaleTransition>(find.byType(ScaleTransition))
            .scale
            .value,
        lessThan(1),
      );
      await gesture.moveBy(const Offset(0, 40));
      await tester.pumpAndSettle();
      final scale = tester
          .widget<ScaleTransition>(find.byType(ScaleTransition))
          .scale
          .value;
      expect(scale, closeTo(1, 0.001));
      await gesture.up();
    });
  });

  group('showAppDialog', () {
    Future<BuildContext> pumpHost(WidgetTester tester) async {
      late BuildContext host;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              host = context;
              return const SizedBox.expand();
            },
          ),
        ),
      );
      return host;
    }

    double dialogScale(WidgetTester tester) => tester
        .widget<ScaleTransition>(
          find
              .ancestor(
                of: find.text('hello'),
                matching: find.byType(ScaleTransition),
              )
              .first,
        )
        .scale
        .value;

    testWidgets('grows into place and hands back what it was closed with', (
      tester,
    ) async {
      final host = await pumpHost(tester);
      final result = showAppDialog<int>(
        context: host,
        builder: (context) => AlertDialog(
          content: const Text('hello'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(7),
              child: const Text('ok'),
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      // On its way in: smaller than it will end up.
      expect(dialogScale(tester), lessThan(1));

      await tester.pumpAndSettle();
      expect(dialogScale(tester), closeTo(1, 0.001));

      await tester.tap(find.text('ok'));
      await tester.pumpAndSettle();
      expect(await result, 7);
      expect(find.text('hello'), findsNothing);
    });

    testWidgets('grows out of the spot it was opened from', (tester) async {
      final host = await pumpHost(tester);
      final view = tester.view;
      // Bottom right corner of the screen, in physical pixels.
      final size = view.physicalSize;
      showAppDialog<void>(
        context: host,
        from: Rect.fromLTWH(size.width - 20, size.height - 20, 10, 10),
        builder: (context) => const AlertDialog(content: Text('hello')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      final transition = tester.widget<ScaleTransition>(
        find
            .ancestor(
              of: find.text('hello'),
              matching: find.byType(ScaleTransition),
            )
            .first,
      );
      final origin = transition.alignment;
      expect(origin.x, greaterThan(0.8));
      expect(origin.y, greaterThan(0.8));
      await tester.pumpAndSettle();
    });

    testWidgets('comes straight up with motion switched off', (tester) async {
      await DesignController.instance.update(DesignSettings(motion: 0));
      final host = await pumpHost(tester);
      showAppDialog<void>(
        context: host,
        builder: (context) => const AlertDialog(content: Text('hello')),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('hello'), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('a sheet opens and closes through the same place', (
      tester,
    ) async {
      final host = await pumpHost(tester);
      showAppBottomSheet<void>(
        context: host,
        showDragHandle: true,
        builder: (context) => const SizedBox(height: 200, child: Text('sheet')),
      );
      await tester.pumpAndSettle();
      expect(find.text('sheet'), findsOneWidget);
      Navigator.of(host).pop();
      await tester.pumpAndSettle();
      expect(find.text('sheet'), findsNothing);
    });
  });

  group('RouteStagger', () {
    testWidgets('later items arrive later, all of them arrive', (
      tester,
    ) async {
      late BuildContext host;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              host = context;
              return const SizedBox.expand();
            },
          ),
        ),
      );
      showAppDialog<void>(
        context: host,
        builder: (context) => Dialog(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 6; i++)
                RouteStagger(index: i, child: Text('item $i')),
            ],
          ),
        ),
      );

      double opacityOf(int i) => tester
          .widget<FadeTransition>(
            find
                .ancestor(
                  of: find.text('item $i'),
                  matching: find.byType(FadeTransition),
                )
                .first,
          )
          .opacity
          .value;

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      expect(opacityOf(0), greaterThan(opacityOf(5)));

      await tester.pumpAndSettle();
      for (var i = 0; i < 6; i++) {
        expect(opacityOf(i), 1);
      }
    });
  });

  group('PanelScrollController', () {
    // Where the drags went: the panel's share, and what it was let go with.
    late List<double> panelDrags;
    late List<double> releases;
    late double panel;

    Future<PanelScrollController> pumpList(
      WidgetTester tester, {
      int items = 40,
    }) async {
      panelDrags = [];
      releases = [];
      panel = 1;
      final controller = PanelScrollController(
        onPanelDrag: (delta) {
          panelDrags.add(delta);
          panel = (panel + delta / 600).clamp(0.0, 1.0);
        },
        onPanelRelease: releases.add,
        isPanelPulled: () => panel < 1,
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              controller: controller,
              // As on the panel - see panel_view.dart.
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: items,
              itemExtent: 60,
              itemBuilder: (context, index) => Text('$index'),
            ),
          ),
        ),
      );
      return controller;
    }

    testWidgets('an ordinary scroll stays the list\'s', (tester) async {
      final controller = await pumpList(tester);
      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(controller.offset, greaterThan(0));
      expect(panelDrags, isEmpty);
      expect(releases, isEmpty);
    });

    testWidgets('a push up past the end moves the panel instead', (
      tester,
    ) async {
      final controller = await pumpList(tester);
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(ListView)),
      );
      for (var i = 0; i < 6; i++) {
        await gesture.moveBy(const Offset(0, -30));
        await tester.pump(const Duration(milliseconds: 16));
      }
      // Moved with the finger, upwards - and the list itself stayed put.
      expect(panelDrags, isNotEmpty);
      expect(panelDrags.every((delta) => delta < 0), isTrue);
      expect(panel, lessThan(1));
      expect(controller.offset, controller.position.maxScrollExtent);

      // Turning round brings the panel back down rather than scrolling.
      final before = panelDrags.length;
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump(const Duration(milliseconds: 16));
      expect(panelDrags.length, greaterThan(before));
      expect(panelDrags.last, greaterThan(0));
      expect(controller.offset, controller.position.maxScrollExtent);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(releases, hasLength(1));
    });

    testWidgets('a flick up hands an upward speed to the panel', (
      tester,
    ) async {
      final controller = await pumpList(tester, items: 3);
      // Too short to scroll at all: every push up is the panel's.
      expect(controller.position.maxScrollExtent, 0);
      await tester.fling(find.byType(ListView), const Offset(0, -150), 2000);
      await tester.pumpAndSettle();
      expect(releases, hasLength(1));
      expect(releases.single, lessThan(0));
    });

    testWidgets('a fling that runs into the end on its own stops there', (
      tester,
    ) async {
      final controller = await pumpList(tester);
      await tester.fling(find.byType(ListView), const Offset(0, -300), 6000);
      await tester.pumpAndSettle();
      expect(controller.offset, controller.position.maxScrollExtent);
      expect(releases, isEmpty);
      expect(panel, 1);
    });
  });
}
