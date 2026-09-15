import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanneslauncher/design_controller.dart';
import 'package:hanneslauncher/design_settings_screen.dart';
import 'package:hanneslauncher/design_tokens.dart';
import 'package:hanneslauncher/design_widgets.dart';
import 'package:hanneslauncher/locale_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The design is meant to hold together at every setting, not only at the
/// default - so these actually draw it at the ends of every slider and at
/// every preset, on a narrow screen, and fail on any overflow.
///
/// A range check in `design_test.dart` proves the numbers stay in order; only
/// putting them on a screen proves a row of them still fits.
Widget _app(DesignSettings settings, Widget child) => MaterialApp(
  theme: buildAppTheme(settings),
  home: child,
);

/// The combinations worth drawing: each preset once, and each scalar at both
/// ends of its track.
Iterable<(String, DesignSettings)> _cases() sync* {
  for (final preset in DesignThemePreset.values) {
    yield (preset.name, DesignSettings(preset: preset));
  }
  yield ('tightest', DesignSettings(
    radius: radiusRange.min,
    shadow: shadowRange.min,
    spacing: spacingRange.min,
    cardSize: cardSizeRange.min,
    font: fontRange.min,
    opacity: opacityRange.min,
  ));
  yield ('loosest', DesignSettings(
    radius: radiusRange.max,
    shadow: shadowRange.max,
    spacing: spacingRange.max,
    cardSize: cardSizeRange.max,
    font: fontRange.max,
    opacity: opacityRange.max,
  ));
}


void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // A narrow phone rather than the test default: whatever overflows, does
    // so here first.
    LocaleController.instance.value = AppLanguage.de;
  });

  testWidgets('the design settings draw at every preset and extreme', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    for (final (name, settings) in _cases()) {
      await DesignController.instance.update(settings);
      // Torn down between cases: the same screen rebuilt in place would keep
      // the scroll position the last case left at the bottom of the page.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_app(settings, const DesignSettingsScreen()));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: name);

      // A list only builds what is on screen, so everything further down -
      // the theme tiles, the sliders - would never be drawn at all without
      // walking to the bottom, and being drawn is the whole point here.
      var sawTiles = find.byType(OptionTile).evaluate().isNotEmpty;
      final list = find.byType(ListView);
      for (var i = 0; i < 10; i++) {
        await tester.drag(list, const Offset(0, -500));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '$name, scrolled $i');
        sawTiles |= find.byType(OptionTile).evaluate().isNotEmpty;
      }
      // The page is really there, not an error box standing in for it.
      expect(sawTiles, isTrue, reason: name);
      expect(find.byType(Slider), findsWidgets, reason: name);
    }
  });

  testWidgets('the shared settings shapes draw at every extreme', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    for (final (name, settings) in _cases()) {
      await tester.pumpWidget(
        _app(
          settings,
          Scaffold(
            body: ListView(
              children: [
                const SettingsHeading('Aussehen'),
                const FieldLabel('Farbe'),
                for (final level in SurfaceLevel.values)
                  SizedBox(
                    height: 140,
                    child: OptionTile(
                      title: 'Ein ziemlich langer Name für eine Kachel',
                      selected: level == SurfaceLevel.normal,
                      level: level,
                      preview: const Icon(Icons.access_time, size: 40),
                      onTap: () {},
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: name);
    }
  });

  /// The complaint this exists for: text in a field that could not be read,
  /// on a dark theme in particular.
  ///
  /// The field's tint is a wash of the text color over whatever is behind it,
  /// so this holds for hand-mixed colors too - it is not a check that the
  /// five presets happen to work out.
  testWidgets('what is typed into a field can be read, in every combination', (
    tester,
  ) async {
    final grounds = <String, DesignSettings>{
      for (final preset in DesignThemePreset.values)
        preset.name: DesignSettings(preset: preset),
      // The mix that is easiest to stumble into and hardest to spot: a dark
      // ground picked by hand while the cards stay as the light theme left
      // them.
      'dark ground, pale cards': DesignSettings(
        overrides: {DesignColorRole.background: const Color(0xFF151515)},
      ),
    };

    for (final entry in grounds.entries) {
      for (final field in InputFieldStyle.values) {
        final settings = entry.value.copyWith(fieldStyle: field);
        final t = DesignTokens(settings);
        final reason = '${entry.key} / ${field.name}';

        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          _app(
            settings,
            const Scaffold(
              body: TextField(decoration: InputDecoration(hintText: 'hint')),
            ),
          ),
        );
        await tester.pump();

        // What the field is actually drawn on: its own tint where it has one,
        // otherwise the page underneath.
        final ground = field == InputFieldStyle.plain
            ? Color.alphaBlend(t.fillSubtle, t.background)
            : t.background;

        final typed = tester
            .widget<EditableText>(find.byType(EditableText))
            .style
            .color!;
        expect(
          DesignTokens.contrastBetween(typed, ground),
          greaterThan(4.5),
          reason: reason,
        );

        final hint = tester.widget<Text>(find.text('hint')).style!.color!;
        expect(
          DesignTokens.contrastBetween(hint, ground),
          greaterThan(3),
          reason: reason,
        );
      }
    }
  });
}
