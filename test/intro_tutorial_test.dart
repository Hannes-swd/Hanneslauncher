import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanneslauncher/app_strings.dart';
import 'package:hanneslauncher/intro_tutorial_controller.dart';
import 'package:hanneslauncher/intro_tutorial_overlay.dart';
import 'package:hanneslauncher/locale_controller.dart';
import 'package:hanneslauncher/panel_blocks_controller.dart';
import 'package:hanneslauncher/panel_visibility.dart';
import 'package:hanneslauncher/pinned_apps_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final controller = IntroTutorialController.instance;
  final blocks = PanelBlocksController.instance;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PinnedAppsController.instance.value = const [];
    blocks.value = const [];
  });

  tearDown(() {
    controller.finish();
    PanelVisibility.instance.value = false;
  });

  group('the first start', () {
    test('shows the walk-through once, then never on its own again', () async {
      expect(await controller.takeFirstRun(), isTrue);
      expect(await controller.takeFirstRun(), isFalse);
    });
  });

  group('moving through it', () {
    test('starts on the language step, and goes forward and back', () {
      controller.start();
      expect(controller.step.value, 0);

      controller.next();
      expect(controller.step.value, 1);

      controller.back();
      expect(controller.step.value, 0);
    });

    test('finishing completes the future and clears the step', () async {
      final done = controller.start();
      controller.finish();

      await done;
      expect(controller.step.value, isNull);
    });

    test('going past the last task finishes it', () async {
      final done = controller.start();
      for (var i = 0; i <= IntroTutorialController.taskCount; i++) {
        controller.next();
      }

      await done;
      expect(controller.step.value, isNull);
    });
  });

  group('each task waits for its real gesture', () {
    test('picking an app on the home screen counts for the first task', () async {
      controller.start();
      controller.next();
      expect(controller.achieved.value, isFalse);

      await PinnedAppsController.instance.toggle('com.example.app');

      expect(controller.achieved.value, isTrue);
    });

    test('an app pinned before the task started does not count', () async {
      await PinnedAppsController.instance.toggle('com.example.app');

      controller.start();
      controller.next();

      expect(controller.achieved.value, isFalse);
    });

    test('swiping a letter counts for the letter task', () {
      controller.start();
      controller.next();
      controller.next();
      expect(controller.achieved.value, isFalse);

      controller.noteLetter();

      expect(controller.achieved.value, isTrue);
    });

    test('pulling the panel down counts for the panel task', () {
      controller.start();
      for (var i = 0; i < 3; i++) {
        controller.next();
      }
      expect(controller.achieved.value, isFalse);

      PanelVisibility.instance.value = true;

      expect(controller.achieved.value, isTrue);
    });

    test('adding a block to the panel counts for the widget task', () async {
      controller.start();
      for (var i = 0; i < 4; i++) {
        controller.next();
      }
      expect(controller.achieved.value, isFalse);

      blocks.debugResetLoadedForTest();
      await blocks.addNotes('Test');

      expect(controller.achieved.value, isTrue);
    });

    test('a panel opened before the task does not count for it', () {
      controller.start();
      controller.next();
      controller.next();
      PanelVisibility.instance.value = true;
      PanelVisibility.instance.value = false;

      controller.next();
      expect(controller.achieved.value, isFalse);

      PanelVisibility.instance.value = true;
      expect(controller.achieved.value, isTrue);
    });

    test('opening the settings counts for the last task', () {
      controller.start();
      for (var i = 0; i < 5; i++) {
        controller.next();
      }
      expect(controller.achieved.value, isFalse);

      controller.noteSettingsOpened();

      expect(controller.achieved.value, isTrue);
    });
  });

  group('moving on by itself', () {
    test('the card moves on once a task is done', () async {
      controller.start();
      controller.next();

      await PinnedAppsController.instance.toggle('com.example.app');
      await Future<void>.delayed(
        IntroTutorialController.advanceDelay + const Duration(milliseconds: 200),
      );

      expect(controller.step.value, 2);
    });

    test('it waits while the menu is still open', () async {
      controller.start();
      controller.next();
      controller.noteHomeEditOpened();

      await PinnedAppsController.instance.toggle('com.example.app');
      await Future<void>.delayed(
        IntroTutorialController.advanceDelay + const Duration(milliseconds: 200),
      );
      expect(controller.step.value, 1);

      controller.noteHomeEditClosed();
      await Future<void>.delayed(
        IntroTutorialController.advanceDelay + const Duration(milliseconds: 200),
      );
      expect(controller.step.value, 2);
    });
  });

  group('the card', () {
    testWidgets('asks for the language first, and follows the choice', (
      tester,
    ) async {
      addTearDown(() => LocaleController.instance.update(AppLanguage.en));
      await tester.pumpWidget(
        const MaterialApp(home: Stack(children: [IntroTutorialOverlay()])),
      );
      controller.start();
      await tester.pump();

      final s = AppStrings(LocaleController.instance.value);
      expect(find.text(s.introLanguageTitle), findsOneWidget);

      await tester.tap(find.text('Deutsch'));
      await tester.pump();

      final de = AppStrings(AppLanguage.de);
      expect(LocaleController.instance.value, AppLanguage.de);
      expect(find.text(de.introLanguageTitle), findsOneWidget);
    });

    testWidgets('closes from its button when drawn above the navigator', (
      tester,
    ) async {
      // The same place main.dart puts it: above the navigator, so there is
      // no Overlay for a tooltip to use.
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => Stack(
            children: [child!, const IntroTutorialOverlay()],
          ),
          home: const Scaffold(body: Text('home')),
        ),
      );
      controller.start();
      await tester.pump();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(controller.step.value, isNull);
    });

    testWidgets('is not drawn while the walk-through is not running', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Stack(children: [IntroTutorialOverlay()])),
      );

      final s = AppStrings(LocaleController.instance.value);
      expect(find.text(s.introLanguageTitle), findsNothing);
    });
  });
}
