import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanneslauncher/app_list_settings_controller.dart';
import 'package:hanneslauncher/app_strings.dart';
import 'package:hanneslauncher/color_swatch_picker.dart';
import 'package:hanneslauncher/gesture_action.dart';
import 'package:hanneslauncher/gesture_shortcuts_controller.dart';
import 'package:hanneslauncher/gesture_stroke.dart';
import 'package:hanneslauncher/locale_controller.dart';
import 'package:hanneslauncher/settings_backup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'gesture_recognition_test.dart' show circle, triangle, checkMark;

GestureStroke stroke(List<Offset> points) => GestureStroke.fromDrawing(points)!;

/// A controller with nothing in it, as if the app had just been installed.
Future<GestureShortcutsController> freshController() async {
  SharedPreferences.setMockInitialValues({});
  final controller = GestureShortcutsController.instance;
  controller.value = const [];
  controller.debugResetLoadedForTest();
  await controller.load();
  return controller;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('saved shapes survive a restart', () {
    test('shape, action and name all come back', () async {
      final controller = await freshController();
      await controller.add(
        name: 'Musik',
        stroke: stroke(circle()),
        action: const GestureAction(
          kind: GestureActionKind.entry,
          target: 'com.spotify.music',
        ),
      );

      // Simulate a fresh app start: drop what's in memory and read back.
      controller.value = const [];
      controller.debugResetLoadedForTest();
      await controller.load();

      final restored = controller.value.single;
      expect(restored.name, 'Musik');
      expect(restored.action.kind, GestureActionKind.entry);
      expect(restored.action.target, 'com.spotify.music');
      // Not just present - still the same shape, which is the only part of
      // this that a lossy round trip would quietly ruin.
      expect(strokeScore(restored.stroke, stroke(circle())), greaterThan(0.99));
    });

    test('one damaged entry costs only that one', () async {
      SharedPreferences.setMockInitialValues({
        'gesture_shortcuts': [
          jsonEncode({
            'id': '1',
            'name': 'Gut',
            'stroke': stroke(circle()).toJson(),
            'action': {'kind': 'settings'},
          }),
          '{not json at all',
          jsonEncode({'id': '2', 'name': 'Kaputt'}),
          jsonEncode({
            'id': '3',
            'name': 'Auch gut',
            'stroke': stroke(triangle()).toJson(),
            'action': {'kind': 'address', 'target': 'https://example.com'},
          }),
        ],
      });
      final controller = GestureShortcutsController.instance;
      controller.value = const [];
      controller.debugResetLoadedForTest();
      await controller.load();

      expect(controller.value.map((s) => s.name), ['Gut', 'Auch gut']);
    });

    test('how the drawing behaves survives too', () async {
      SharedPreferences.setMockInitialValues({});
      final drawing = GestureDrawingController.instance;
      drawing.value = const GestureDrawingSettings();
      drawing.debugResetLoadedForTest();
      await drawing.load();
      // Watched for, drawn, and following the theme's colour: what a fresh
      // install does, and with no shape saved none of it changes anything.
      expect(drawing.value.enabled, isTrue);
      expect(drawing.value.showTrail, isTrue);
      expect(drawing.value.colorIndex, autoColorIndex);
      expect(drawing.value.fixedColor, isNull);

      await drawing.update(
        const GestureDrawingSettings(
          enabled: false,
          showTrail: false,
          colorIndex: 4,
        ),
      );
      drawing.value = const GestureDrawingSettings();
      drawing.debugResetLoadedForTest();
      await drawing.load();
      expect(drawing.value.enabled, isFalse);
      expect(drawing.value.showTrail, isFalse);
      expect(drawing.value.colorIndex, 4);
      expect(drawing.value.fixedColor, appListColorPalette[4]);
    });

    test('a colour index past the end of the palette still has a colour', () {
      // What a backup from a phone with more hand-picked colours than this
      // one has names. Indexing straight would throw, on the home screen, in
      // the middle of a stroke.
      const settings = GestureDrawingSettings(colorIndex: 999);
      expect(settings.fixedColor, appListColorPalette.last);
    });
  });

  group('what the home screen is allowed to match against', () {
    test('a shape that is switched off is not watched for', () async {
      final controller = await freshController();
      final saved = await controller.add(
        name: 'Kreis',
        stroke: stroke(circle()),
        action: const GestureAction(kind: GestureActionKind.settings),
      );
      expect(controller.templates.length, 1);

      await controller.update(saved!.id, enabled: false);
      expect(controller.templates, isEmpty);
      // The shape itself is still there - switching off is not deleting.
      expect(controller.value.single.stroke.points.length, sampleCount);
    });

    test('a shape pointing at nothing is not watched for either', () async {
      final controller = await freshController();
      // What a hand-edited backup can produce: a kind that needs a target,
      // with no target. Recognising it would fire nothing at all, which from
      // the home screen is indistinguishable from the shape not working.
      await controller.replaceAll([
        GestureShortcut(
          id: '1',
          name: 'Halb',
          stroke: stroke(circle()),
          action: const GestureAction(kind: GestureActionKind.entry),
        ),
      ]);
      expect(controller.value.length, 1);
      expect(controller.templates, isEmpty);
    });

    test('drawing one of them lands on that one', () async {
      final controller = await freshController();
      final kreis = await controller.add(
        name: 'Kreis',
        stroke: stroke(circle()),
        action: const GestureAction(kind: GestureActionKind.settings),
      );
      await controller.add(
        name: 'Haken',
        stroke: stroke(checkMark()),
        action: const GestureAction(kind: GestureActionKind.settings),
      );

      final result = recognizeStroke(
        [for (final point in circle()) point + const Offset(400, 700)],
        controller.templates,
      );
      expect(result.verdict, StrokeVerdict.match);
      expect(result.id, kreis!.id);
    });
  });

  test('the editor is told which saved shape a new one resembles', () async {
    final controller = await freshController();
    await controller.add(
      name: 'Kreis',
      stroke: stroke(circle()),
      action: const GestureAction(kind: GestureActionKind.settings),
    );

    final closest = controller.closestTo(stroke(circle(radius: 20)));
    expect(closest, isNotNull);
    expect(closest!.shortcut.name, 'Kreis');
    expect(closest.score, greaterThan(similarShapeScore));

    // And a shape being edited never resembles itself.
    final self = controller.closestTo(
      stroke(circle()),
      skipId: controller.value.single.id,
    );
    expect(self, isNull);
  });

  test('more shapes than the list holds are not taken on', () async {
    final controller = await freshController();
    await controller.replaceAll([
      for (var i = 0; i < GestureShortcutsController.maxShortcuts + 5; i++)
        GestureShortcut(
          id: '$i',
          name: 'Form $i',
          stroke: stroke(circle()),
          action: const GestureAction(kind: GestureActionKind.settings),
        ),
    ]);
    expect(
      controller.value.length,
      GestureShortcutsController.maxShortcuts,
    );
    expect(controller.isFull, isTrue);
    expect(
      await controller.add(
        name: 'Noch eine',
        stroke: stroke(triangle()),
        action: const GestureAction(kind: GestureActionKind.settings),
      ),
      isNull,
    );
  });

  test('a backup carries the shapes and brings them back', () async {
    final controller = await freshController();
    await controller.add(
      name: 'Timer',
      stroke: stroke(triangle()),
      action: const GestureAction(kind: GestureActionKind.timer, seconds: 300),
    );
    await GestureDrawingController.instance.update(
      const GestureDrawingSettings(showTrail: false, colorIndex: 5),
    );

    final document = SettingsBackupService.exportJson();

    // Wiped as thoroughly as a reinstall would.
    await controller.replaceAll(const []);
    await GestureDrawingController.instance.update(
      const GestureDrawingSettings(),
    );

    await SettingsBackupService.apply(document);

    final restored = controller.value.single;
    expect(restored.name, 'Timer');
    expect(restored.action.kind, GestureActionKind.timer);
    expect(restored.action.seconds, 300);
    expect(strokeScore(restored.stroke, stroke(triangle())), greaterThan(0.99));
    expect(GestureDrawingController.instance.value.showTrail, isFalse);
    expect(GestureDrawingController.instance.value.colorIndex, 5);
  });

  // The structural guards: every one of these fails the moment a new action
  // kind is added without the words that go with it, rather than shipping a
  // picker row with a blank label on it.
  group('every action kind is complete', () {
    for (final language in AppLanguage.values) {
      final s = AppStrings(language);
      test('named and explained in ${language.name}', () {
        for (final kind in GestureActionKind.values) {
          expect(
            gestureActionKindLabel(kind, s),
            isNotEmpty,
            reason: '${kind.name} has no label',
          );
          expect(
            gestureActionKindHint(kind, s),
            isNotEmpty,
            reason: '${kind.name} has no hint',
          );
        }
      });
    }

    test('each kind reads back as itself', () {
      for (final kind in GestureActionKind.values) {
        final action = GestureAction(
          kind: kind,
          target: 'com.example.app',
          seconds: 90,
        );
        final restored = GestureAction.fromJson(action.toJson())!;
        expect(restored.kind, kind);
        expect(restored.target, action.target);
        expect(restored.seconds, action.seconds);
      }
      expect(GestureAction.fromJson({'kind': 'was auch immer'}), isNull);
      expect(GestureAction.fromJson(null), isNull);
    });

    test('each kind can say what it does', () {
      final s = AppStrings(AppLanguage.de);
      for (final kind in GestureActionKind.values) {
        final action = GestureAction(
          kind: kind,
          target: 'com.example.app',
          seconds: 300,
        );
        expect(action.describe(s), isNotEmpty, reason: kind.name);
        expect(action.isComplete, isTrue, reason: kind.name);
      }
    });

    test('a kind missing what it needs knows it is not finished', () {
      expect(
        const GestureAction(kind: GestureActionKind.entry).isComplete,
        isFalse,
      );
      expect(
        const GestureAction(
          kind: GestureActionKind.address,
          target: '   ',
        ).isComplete,
        isFalse,
      );
      expect(
        const GestureAction(kind: GestureActionKind.timer).isComplete,
        isFalse,
      );
      // The only one that needs nothing at all.
      expect(
        const GestureAction(kind: GestureActionKind.settings).isComplete,
        isTrue,
      );
    });
  });

  test('a countdown is written out the way a person reads it', () {
    final s = AppStrings(AppLanguage.de);
    expect(formatGestureDuration(45, s), '45 Sek');
    expect(formatGestureDuration(60, s), '1 Min');
    expect(formatGestureDuration(300, s), '5 Min');
    expect(formatGestureDuration(90, s), '1:30 Min');
  });
}
