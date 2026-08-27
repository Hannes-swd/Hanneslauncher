import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanneslauncher/app_list_settings_controller.dart'
    show appListColorPalette;
import 'package:hanneslauncher/app_overrides_controller.dart';
import 'package:hanneslauncher/builtin_entries.dart';
import 'package:hanneslauncher/clock_font_picker.dart';
import 'package:hanneslauncher/clock_settings_controller.dart';
import 'package:hanneslauncher/launcher_entries_controller.dart';
import 'package:hanneslauncher/locale_controller.dart';
import 'package:hanneslauncher/offline_mode_controller.dart';
import 'package:hanneslauncher/offline_mode_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await OfflineModeController.instance.update(const OfflineModeSettings());
  });

  group('the clock settings the offline mode draws with', () {
    test('put the one chosen color into every slot a face reads', () {
      final clock = const OfflineModeSettings(colorIndex: 4).toClockSettings();

      expect(clock.digitalColorIndex, 4);
      expect(clock.romanColorIndex, 4);
      expect(clock.dotColorIndex, 4);
      expect(clock.orbitColorIndex, 4);
      expect(clock.verticalColorIndex, 4);
      expect(clock.barsFilledColorIndex, 4);
      expect(clock.barsTextColorIndex, 4);
      expect(clock.wordActiveColorIndex, 4);
      expect(clock.splitFlapTextColorIndex, 4);
    });

    test('leave the card backgrounds off the chosen color', () {
      // Both would otherwise be drawn in the clock's own color and swallow
      // the digits sitting on them.
      final clock = const OfflineModeSettings(colorIndex: 4).toClockSettings();

      expect(clock.wordBgColorIndex, 0);
      expect(clock.wordBgOpacity, 0);
      expect(clock.splitFlapBgColorIndex, 0);
    });

    test('are not the home screen clock, whatever that is set to', () async {
      await ClockSettingsController.instance.update(
        const ClockSettings(style: ClockStyle.bars, digitalColorIndex: 6),
      );

      final clock = const OfflineModeSettings(
        style: ClockStyle.roman,
        colorIndex: 1,
      ).toClockSettings();

      expect(clock.style, ClockStyle.roman);
      expect(clock.digitalColorIndex, 1);
    });
  });

  group('the digits font', () {
    test('reaches the digital face through the clock settings', () {
      final clock = const OfflineModeSettings(
        digitalFontFamily: 'monospace',
      ).toClockSettings();

      expect(clock.digitalFontFamily, 'monospace');
    });

    test('is a family Android ships, so nothing has to be bundled', () {
      // The empty string is the device's own default, which is why it is
      // stored that way rather than as a name.
      expect(clockFontFamilies, contains(''));
      expect(clockFontFamilies.toSet(), hasLength(clockFontFamilies.length));
    });

    testWidgets('is what the offline screen draws the time in', (tester) async {
      await OfflineModeController.instance.update(
        const OfflineModeSettings(digitalFontFamily: 'serif'),
      );
      await tester.pumpWidget(const MaterialApp(home: OfflineModeScreen()));

      final time = tester.widget<Text>(
        find.byWidgetPredicate(
          (widget) => widget is Text && widget.data?.contains(':') == true,
        ),
      );
      expect(time.style?.fontFamily, 'serif');
    });

    testWidgets('left at the default asks for no family at all', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: OfflineModeScreen()));

      final time = tester.widget<Text>(
        find.byWidgetPredicate(
          (widget) => widget is Text && widget.data?.contains(':') == true,
        ),
      );
      // Null rather than a name, so the phone's own system font is used.
      expect(time.style?.fontFamily, isNull);
    });

    test('the home screen clock keeps its own, separate from this one', () {
      const home = ClockSettings(digitalFontFamily: 'casual');
      final offline = const OfflineModeSettings(
        digitalFontFamily: 'monospace',
      ).toClockSettings();

      expect(home.digitalFontFamily, 'casual');
      expect(offline.digitalFontFamily, 'monospace');
    });
  });

  group('burn-in protection', () {
    testWidgets('creeps the clock along over time', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: OfflineModeScreen()));

      Matrix4? transform() => tester
          .widget<AnimatedContainer>(find.byType(AnimatedContainer))
          .transform;

      final start = transform();
      expect(start, isNotNull);

      // Two steps on, it must have moved somewhere else.
      await tester.pump(const Duration(minutes: 2));
      final moved = transform();
      expect(moved, isNot(start));

      await tester.pump(const Duration(minutes: 2));
      expect(transform(), isNot(moved));
    });

    testWidgets('holds still when it is switched off', (tester) async {
      await OfflineModeController.instance.update(
        const OfflineModeSettings(burnInProtection: false),
      );
      await tester.pumpWidget(const MaterialApp(home: OfflineModeScreen()));

      Matrix4? transform() => tester
          .widget<AnimatedContainer>(find.byType(AnimatedContainer))
          .transform;

      final start = transform();
      await tester.pump(const Duration(minutes: 10));
      expect(transform(), start);
    });
  });

  group('the offline mode behaves like an app', () {
    setUp(() async {
      await AppOverridesController.instance.restoreNames({});
      LauncherEntriesController.instance.debugSetInstalledApps([]);
    });

    test('sits in the app list, so it can be opened and pinned like one', () {
      final entry = LauncherEntriesController.instance.entries.singleWhere(
        (entry) => entry.isBuiltIn,
      );

      expect(entry.builtIn, BuiltInEntry.offlineMode);
      expect(entry.isFolder, false);
      expect(entry.isWebApp, false);
    });

    test('is reachable by the key a pin stores', () {
      final resolved = LauncherEntriesController.instance.resolve([
        BuiltInEntry.offlineMode.key,
      ]);

      expect(resolved, hasLength(1));
      expect(resolved.single.builtIn, BuiltInEntry.offlineMode);
    });

    test('the key cannot be mistaken for a package name', () {
      expect(BuiltInEntry.offlineMode.key.startsWith(builtInKeyPrefix), true);
      expect(
        builtInFromKey(BuiltInEntry.offlineMode.key),
        BuiltInEntry.offlineMode,
      );
      expect(builtInFromKey('com.example.mail'), isNull);
      expect(builtInFromKey('builtin:somethingElse'), isNull);
    });

    // The override store is shared with the apps, keyed by the entry key
    // instead of a package name - which is also what a picked icon and a
    // restored backup write into.
    test('follows the app language, and honours a name override', () async {
      await LocaleController.instance.update(AppLanguage.de);
      final entry = LauncherEntriesController.instance.entries.singleWhere(
        (entry) => entry.isBuiltIn,
      );
      expect(entry.name, 'Offline-Modus');

      await LocaleController.instance.update(AppLanguage.en);
      expect(
        LauncherEntriesController.instance.entries
            .singleWhere((entry) => entry.isBuiltIn)
            .name,
        'Offline mode',
      );

      await AppOverridesController.instance.setName(
        BuiltInEntry.offlineMode.key,
        'Nachtuhr',
      );
      expect(
        LauncherEntriesController.instance.entries
            .singleWhere((entry) => entry.isBuiltIn)
            .name,
        'Nachtuhr',
      );
      await LocaleController.instance.update(AppLanguage.de);
    });
  });

  group('the offline mode screen', () {
    testWidgets('is black, with the clock and nothing else on it', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: OfflineModeScreen()));

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, Colors.black);
      // The close button only exists once the screen has been tapped.
      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('shows the close button on a tap and hides it again', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: OfflineModeScreen()));

      await tester.tap(find.byType(OfflineModeScreen));
      await tester.pump();
      expect(find.byIcon(Icons.close), findsOneWidget);

      // Left alone, the screen goes back to being just the clock.
      await tester.pump(const Duration(seconds: 5));
      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('draws the clock in the chosen color', (tester) async {
      await OfflineModeController.instance.update(
        const OfflineModeSettings(colorIndex: 6),
      );
      await tester.pumpWidget(const MaterialApp(home: OfflineModeScreen()));

      final time = tester.widget<Text>(
        find.byWidgetPredicate(
          (widget) => widget is Text && widget.data?.contains(':') == true,
        ),
      );
      expect(time.style?.color, appListColorPalette[6]);
    });

    testWidgets('draws the time heavier than the home screen clock does', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: OfflineModeScreen()));

      final time = tester.widget<Text>(
        find.byWidgetPredicate(
          (widget) => widget is Text && widget.data?.contains(':') == true,
        ),
      );
      expect(time.style?.fontWeight, offlineDigitalWeight);
      expect(offlineDigitalWeight.value, greaterThan(FontWeight.w300.value));
    });

    testWidgets('leaves the date off - only the time is shown', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: OfflineModeScreen()));

      // The digital face draws the date as "dd.mm.yyyy" under the time.
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              RegExp(r'^\d{2}\.\d{2}\.\d{4}$').hasMatch(widget.data ?? ''),
        ),
        findsNothing,
      );
    });
  });
}
