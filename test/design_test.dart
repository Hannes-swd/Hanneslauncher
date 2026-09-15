import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanneslauncher/design_controller.dart';
import 'package:hanneslauncher/design_tokens.dart';
import 'package:hanneslauncher/settings_backup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A design that differs from the default in every single field, so a round
/// trip through the backup can't pass by accident.
final _distinctive = DesignSettings(
  preset: DesignThemePreset.dark,
  fieldStyle: InputFieldStyle.plain,
  overrides: {
    DesignColorRole.accent: const Color(0xFF00FF88),
    DesignColorRole.border: const Color(0xFF445566),
  },
  radius: 8,
  shadow: 0.9,
  spacing: 1.4,
  cardSize: 1.3,
  font: 1.2,
  opacity: 0.55,
  motion: 1.4,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('the scale holds at every setting', () {
    test('the three radii keep their order and never collapse', () {
      // The whole point of deriving the smaller two: whatever the slider is
      // set to, a hero surface stays rounder than a normal one, and a normal
      // one rounder than a compact one. Without that the tiers stop meaning
      // anything at the ends of the track.
      for (final radius in [
        radiusRange.min,
        8.0,
        radiusRange.initial,
        radiusRange.max,
      ]) {
        final t = DesignTokens(DesignSettings(radius: radius));
        expect(t.radiusLarge, greaterThan(t.radiusMedium), reason: '$radius');
        expect(t.radiusMedium, greaterThan(t.radiusSmall), reason: '$radius');
        expect(t.radiusSmall, greaterThan(0), reason: '$radius');
      }
    });

    test('each radius is a golden step down from the one above', () {
      // Not three numbers that looked right: the relation between them is the
      // same one the type and the spacing use, which is what stops the
      // design reading as approximate.
      final t = DesignTokens(DesignSettings());
      expect(t.radiusLarge, 24);
      expect(t.radiusLarge / t.radiusMedium, closeTo(phi, 0.001));
      expect(t.radiusMedium / t.radiusSmall, closeTo(phi, 0.001));
    });

    test('the type ramp climbs by a golden half-step', () {
      final t = DesignTokens(DesignSettings());
      final ramp = [
        t.typeCaption,
        t.typeBody,
        t.typeTitle,
        t.typeHero,
        t.typeDisplay,
      ];
      for (var i = 1; i < ramp.length; i++) {
        expect(ramp[i], greaterThan(ramp[i - 1]), reason: 'step $i');
      }
      // Two half-steps make the whole ratio.
      expect(t.typeHero / t.typeBody, closeTo(phi, 0.001));
      expect(t.typeDisplay / t.typeTitle, closeTo(phi, 0.001));
    });

    test('the spacing ramp closes on the golden ratio as it grows', () {
      // Each rung is the sum of the two before it, so the ratio between
      // neighbours converges - the same rhythm as the type, in whole pixels.
      for (var i = 2; i < spaceRamp.length - 1; i++) {
        expect(
          spaceRamp[i + 1],
          closeTo(spaceRamp[i] + spaceRamp[i - 1], 0.001),
          reason: 'rung $i',
        );
      }
      expect(
        spaceRamp.last / spaceRamp[spaceRamp.length - 2],
        closeTo(phi, 0.03),
      );
    });

    test('large text is set lighter and tighter than small text', () {
      // The part that makes type look bought rather than typed: tracking runs
      // from tight at the top of the ramp to open at the bottom, and weight
      // runs the other way.
      final t = DesignTokens(DesignSettings());
      final display = t.textStyle(TypeRole.display);
      final body = t.textStyle(TypeRole.body);
      final overline = t.textStyle(TypeRole.overline);

      expect(display.letterSpacing!, lessThan(0));
      expect(body.letterSpacing, 0);
      expect(overline.letterSpacing!, greaterThan(body.letterSpacing!));

      expect(display.fontWeight!.value, lessThan(body.fontWeight!.value));
      expect(overline.fontWeight!.value, greaterThan(body.fontWeight!.value));

      // Every role states a line height; leaving one to Material's default is
      // how one paragraph ends up set on a different rhythm from the next.
      for (final role in TypeRole.values) {
        expect(t.textStyle(role).height, isNotNull, reason: '$role');
      }
    });

    test('tracking scales with the text, so it stays a proportion', () {
      final small = DesignTokens(DesignSettings(font: fontRange.min));
      final large = DesignTokens(DesignSettings(font: fontRange.max));
      expect(
        large.textStyle(TypeRole.overline).letterSpacing!,
        greaterThan(small.textStyle(TypeRole.overline).letterSpacing!),
      );
    });

    test('shadows keep their depth order, and switch off completely', () {
      final off = DesignTokens(DesignSettings(shadow: 0));
      for (final level in SurfaceLevel.values) {
        expect(off.shadow(level), isEmpty, reason: '$level');
      }

      double reach(List<BoxShadow> layers) =>
          layers.map((l) => l.blurRadius).reduce((a, b) => a > b ? a : b);

      for (final strength in [0.2, shadowRange.initial, shadowRange.max]) {
        final t = DesignTokens(DesignSettings(shadow: strength));
        final hero = t.shadow(SurfaceLevel.hero);
        final normal = t.shadow(SurfaceLevel.normal);
        final compact = t.shadow(SurfaceLevel.compact);
        expect(reach(hero), greaterThan(reach(normal)));
        expect(reach(normal), greaterThan(reach(compact)));
      }
    });

    test('a shadow is three layers, not one soft blur', () {
      // One blur is the same grey everywhere, so nothing has a near edge.
      // Real light leaves a contact line, a short throw and a wide haze, and
      // the three are separated here.
      final t = DesignTokens(DesignSettings());
      final hero = t.shadow(SurfaceLevel.hero);
      expect(hero.length, 3);

      final blurs = hero.map((l) => l.blurRadius).toList()..sort();
      // Spread right across the range rather than three near-identical
      // blurs, which would just be one shadow drawn three times.
      expect(blurs.last / blurs.first, greaterThan(8));

      // The tightest layer is the darkest: that is the one that says the card
      // is resting on something.
      final tightest = hero.reduce(
        (a, b) => a.blurRadius < b.blurRadius ? a : b,
      );
      final widest = hero.reduce((a, b) => a.blurRadius > b.blurRadius ? a : b);
      expect(tightest.color.a, greaterThan(widest.color.a));

      // Every layer is thrown downwards or not at all - never upwards, which
      // would put the light source under the phone.
      for (final layer in hero) {
        expect(layer.offset.dy, greaterThanOrEqualTo(0));
      }
    });

    test('a chosen card is lit by the accent rather than merely ringed', () {
      final t = DesignTokens(DesignSettings());
      final glow = t.accentGlow(SurfaceLevel.normal);
      expect(glow, isNotEmpty);
      for (final layer in glow) {
        expect(layer.color.r, closeTo(t.accent.r, 0.001));
        expect(layer.color.b, closeTo(t.accent.b, 0.001));
      }
      // Present even with shadows turned all the way down: this one is not
      // depth, it is the colour having weight.
      expect(
        DesignTokens(
          DesignSettings(shadow: 0),
        ).accentGlow(SurfaceLevel.normal),
        isNotEmpty,
      );
    });

    test('motion has a floor where it is on at all', () {
      // Under about 150ms a movement reads as a flicker rather than as a
      // movement, so the slider either switches it off or gives it room.
      final t = DesignTokens(DesignSettings());
      expect(t.motionFast.inMilliseconds, greaterThanOrEqualTo(150));
      expect(t.motionNormal, greaterThan(t.motionFast));
      expect(t.motionSlow, greaterThan(t.motionNormal));
      expect(t.motionless, isFalse);

      final still = DesignTokens(DesignSettings(motion: 0));
      expect(still.motionless, isTrue);
      expect(still.motionFast, Duration.zero);
    });

    test('a theme change travels through the colours in between', () {
      // What makes picking a theme a crossfade instead of a cut. Without a
      // real lerp the extension snapped at the halfway mark and the whole
      // app changed in one frame.
      final grey = DesignTokens(DesignSettings());
      final dark = DesignTokens(
        DesignSettings(preset: DesignThemePreset.dark),
      );
      final half = grey.lerp(dark, 0.5);
      expect(half.background, isNot(grey.background));
      expect(half.background, isNot(dark.background));
      expect(
        half.background.computeLuminance(),
        lessThan(grey.background.computeLuminance()),
      );
      expect(
        half.background.computeLuminance(),
        greaterThan(dark.background.computeLuminance()),
      );
      // The ends are still exactly the two themes.
      expect(grey.lerp(dark, 0).background, grey.background);
      expect(grey.lerp(dark, 1).background, dark.background);
    });

    test('surfaces keep their size order whatever the card slider says', () {
      for (final size in [cardSizeRange.min, 1.0, cardSizeRange.max]) {
        final t = DesignTokens(DesignSettings(cardSize: size));
        expect(
          t.surfaceStyle(SurfaceLevel.hero).minHeight,
          greaterThan(t.surfaceStyle(SurfaceLevel.normal).minHeight),
        );
        expect(
          t.surfaceStyle(SurfaceLevel.normal).minHeight,
          greaterThan(t.surfaceStyle(SurfaceLevel.compact).minHeight),
        );
      }
    });

    test('type keeps its order whatever the font slider says', () {
      for (final font in [fontRange.min, 1.0, fontRange.max]) {
        final t = DesignTokens(DesignSettings(font: font));
        expect(t.typeHero, greaterThan(t.typeTitle));
        expect(t.typeTitle, greaterThan(t.typeBody));
        expect(t.typeBody, greaterThan(t.typeLabel));
        expect(t.typeLabel, greaterThan(t.typeCaption));
        expect(t.typeCaption, greaterThan(8));
      }
    });

    test('a value outside the range is pulled back into it', () {
      // The clamp lives on the settings rather than on the sliders, so a
      // number arriving from a backup file gets the same treatment as one
      // dragged by hand.
      final wild = DesignSettings(
        radius: 900,
        shadow: -4,
        spacing: 0,
        cardSize: 99,
        font: 0,
        opacity: 12,
      );
      expect(wild.radius, radiusRange.max);
      expect(wild.shadow, shadowRange.min);
      expect(wild.spacing, spacingRange.min);
      expect(wild.cardSize, cardSizeRange.max);
      expect(wild.font, fontRange.min);
      expect(wild.opacity, opacityRange.max);
    });
  });

  group('colors', () {
    test('every preset says something about every role', () {
      for (final preset in DesignThemePreset.values) {
        for (final role in DesignColorRole.values) {
          expect(
            () => presetColor(preset, role),
            returnsNormally,
            reason: '$preset has no $role',
          );
        }
      }
    });

    test('text is readable on its own background in every preset', () {
      // Not a full contrast check - just the one mistake that makes a theme
      // unusable rather than ugly: text and ground landing on the same side
      // of the brightness line.
      for (final preset in DesignThemePreset.values) {
        final t = DesignTokens(DesignSettings(preset: preset));
        final gap =
            (t.textPrimary.computeLuminance() -
                    t.background.computeLuminance())
                .abs();
        expect(gap, greaterThan(0.5), reason: '$preset');
      }
    });

    test('the dark preset is recognised as dark', () {
      expect(
        DesignTokens(DesignSettings(preset: DesignThemePreset.dark)).isDark,
        isTrue,
      );
      for (final preset in DesignThemePreset.values) {
        if (preset == DesignThemePreset.dark) continue;
        expect(
          DesignTokens(DesignSettings(preset: preset)).isDark,
          isFalse,
          reason: '$preset',
        );
      }
    });

    test('a preset is left exactly as it is', () {
      // The legibility floor below must be a floor, not a filter: nothing it
      // does may show up on a theme that was already fine, or the five
      // presets would not be the colors this file says they are.
      for (final preset in DesignThemePreset.values) {
        final t = DesignTokens(DesignSettings(preset: preset));
        for (final role in DesignColorRole.values) {
          final drawn = switch (role) {
            DesignColorRole.background => t.background,
            DesignColorRole.surface => t.surface,
            DesignColorRole.textPrimary => t.textPrimary,
            DesignColorRole.textSecondary => t.textSecondary,
            DesignColorRole.accent => t.accent,
            DesignColorRole.border => t.border,
          };
          expect(drawn, presetColor(preset, role), reason: '$preset $role');
        }
      }
    });

    test('darkening only the ground brings the text with it', () {
      // The combination that is easy to walk into: the ground is set dark by
      // hand and the text is left where the light theme had it. Before the
      // floor, that was near-black on near-black.
      final t = DesignTokens(
        DesignSettings(
          overrides: {DesignColorRole.background: const Color(0xFF151515)},
        ),
      );
      expect(
        DesignTokens.contrastBetween(t.textPrimary, t.background),
        greaterThan(4.5),
      );
      expect(
        DesignTokens.contrastBetween(t.textSecondary, t.background),
        greaterThan(3),
      );
      // Lifted, not swapped for plain white: the color keeps its own hue.
      expect(t.textPrimary, isNot(Colors.white));
    });

    test('a card cannot sit on the other side of the line from the ground', () {
      // A pale card on a dark ground leaves no text color that can be read on
      // both, so the card is carried back over - keeping the hue it was given.
      final t = DesignTokens(
        DesignSettings(
          preset: DesignThemePreset.dark,
          overrides: {DesignColorRole.surface: const Color(0xFFFFF0E0)},
        ),
      );
      expect(t.surface.computeLuminance(), lessThan(0.4));
      // Still lighter than the ground it stands on, which is what a card
      // asked to be pale was asking for.
      expect(
        t.surface.computeLuminance(),
        greaterThan(t.background.computeLuminance()),
      );
      expect(
        DesignTokens.contrastBetween(t.textPrimary, t.surface),
        greaterThan(4.5),
      );
    });

    test('a hand-picked dark ground gets the dark treatment too', () {
      // Read off the background rather than off the preset's name, so the
      // Material widgets flip without the preset having to be "Dark".
      final t = DesignTokens(
        DesignSettings(
          overrides: {DesignColorRole.background: const Color(0xFF101010)},
        ),
      );
      expect(t.isDark, isTrue);
      expect(buildAppTheme(t.settings).brightness, Brightness.dark);
    });

    test('picking a theme drops the colors picked by hand', () {
      final custom = DesignSettings(
        overrides: {DesignColorRole.accent: const Color(0xFFABCDEF)},
        radius: 10,
        fieldStyle: InputFieldStyle.box,
      );
      final swapped = custom.withPreset(DesignThemePreset.rose);
      expect(swapped.overrides, isEmpty);
      expect(
        swapped.color(DesignColorRole.accent),
        presetColor(DesignThemePreset.rose, DesignColorRole.accent),
      );
      // Only the colors: shape, spacing and how a field is framed are not
      // what a color theme is.
      expect(swapped.radius, 10);
      expect(swapped.fieldStyle, InputFieldStyle.box);
    });

    test('one color can be put back without touching the others', () {
      final custom = DesignSettings(
        overrides: {
          DesignColorRole.accent: const Color(0xFFABCDEF),
          DesignColorRole.surface: const Color(0xFF123456),
        },
      );
      final back = custom.withColor(DesignColorRole.accent, null);
      expect(
        back.color(DesignColorRole.accent),
        presetColor(DesignThemePreset.grey, DesignColorRole.accent),
      );
      expect(back.color(DesignColorRole.surface), const Color(0xFF123456));
    });

    test('text on the accent follows the accent, not a fixed white', () {
      final pale = DesignTokens(
        DesignSettings(
          overrides: {DesignColorRole.accent: const Color(0xFFFFE066)},
        ),
      );
      expect(pale.onAccent.computeLuminance(), lessThan(0.2));
      final deep = DesignTokens(
        DesignSettings(
          overrides: {DesignColorRole.accent: const Color(0xFF203080)},
        ),
      );
      expect(deep.onAccent.computeLuminance(), greaterThan(0.8));
    });
  });

  group('persistence', () {
    test('the design survives a restart', () async {
      await DesignController.instance.update(_distinctive);
      // A fresh read of the same store is what the next launch does.
      await DesignController.instance.update(DesignSettings());
      await DesignController.instance.update(_distinctive);
      await DesignController.instance.load();
      expect(DesignController.instance.value, _distinctive);
    });

    test('a color put back is gone from the store, not stored as null',
        () async {
      await DesignController.instance.update(_distinctive);
      await DesignController.instance.update(
        _distinctive.withColor(DesignColorRole.accent, null),
      );
      await DesignController.instance.load();
      final loaded = DesignController.instance.value;
      expect(loaded.overrides.containsKey(DesignColorRole.accent), isFalse);
      expect(
        loaded.color(DesignColorRole.accent),
        presetColor(DesignThemePreset.dark, DesignColorRole.accent),
      );
    });

    test('a store with nothing in it gives the designed default', () async {
      await DesignController.instance.load();
      expect(DesignController.instance.value, DesignSettings());
      expect(DesignController.instance.value.preset, DesignThemePreset.grey);
    });

    test('resetting goes back to the default', () async {
      await DesignController.instance.update(_distinctive);
      await DesignController.instance.reset();
      expect(DesignController.instance.value, DesignSettings());
    });
  });

  group('backup', () {
    test('the design comes back out of an export exactly as it went in',
        () async {
      await DesignController.instance.update(_distinctive);
      final exported = SettingsBackupService.exportJson();

      await DesignController.instance.update(DesignSettings());
      await SettingsBackupService.apply(exported);

      // Compared whole rather than field by field: a field added later and
      // then forgotten on one side of the backup fails here, which is the
      // point.
      expect(DesignController.instance.value, _distinctive);
    });

    test('an out-of-range value in a file is clamped, not obeyed', () async {
      await SettingsBackupService.apply(
        '{"formatVersion": 1, "design": {"radius": 999, "font": 0.01}}',
      );
      final restored = DesignController.instance.value;
      expect(restored.radius, radiusRange.max);
      expect(restored.font, fontRange.min);
    });

    test('a backup from before the design existed leaves it alone', () async {
      await DesignController.instance.update(_distinctive);
      await SettingsBackupService.apply('{"formatVersion": 1}');
      expect(DesignController.instance.value, _distinctive);
    });
  });

  /// Guards the one way this can quietly rot: a field added to
  /// [DesignSettings] and persisted, but never written into the backup - the
  /// setting then survives a restart and disappears on a restore, which is
  /// exactly when it is most missed.
  ///
  /// Reads the source as text. It is meant to fail when a field is added; the
  /// failure is the reminder to carry it through the controller and the
  /// backup, not an accusation that it wasn't.
  test('every stored design field is carried by the backup', () {
    final source = File('lib/design_tokens.dart').readAsStringSync();
    final start = source.indexOf('class DesignSettings {');
    final end = source.indexOf('\n}', start);
    expect(
      start,
      isNonNegative,
      reason: 'DesignSettings moved out of this file',
    );

    final fields = RegExp(r'^  final [\w<>, ]+ (\w+);', multiLine: true)
        .allMatches(source.substring(start, end))
        .map((m) => m.group(1)!)
        .toSet();

    // What each field is called in the backup document.
    const jsonKeys = {
      'preset': 'preset',
      'fieldStyle': 'fieldStyle',
      'overrides': 'colors',
      'radius': 'radius',
      'shadow': 'shadow',
      'spacing': 'spacing',
      'cardSize': 'cardSize',
      'font': 'font',
      'opacity': 'opacity',
      'motion': 'motion',
    };

    expect(
      fields,
      jsonKeys.keys.toSet(),
      reason:
          'DesignSettings gained or lost a field. Carry it through '
          'DesignController.load/update and both halves of '
          'SettingsBackupService, then name it here.',
    );

    final exported =
        SettingsBackupService.build()['design'] as Map<String, dynamic>;
    expect(exported.keys.toSet(), jsonKeys.values.toSet());
  });
}
