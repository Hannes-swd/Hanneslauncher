import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'design_tokens.dart';

/// Holds the look the whole app is drawn in - see `design_tokens.dart` for
/// what the values mean.
///
/// One notifier at the very top of the tree, the way every other area here
/// keeps its state. The app's [MaterialApp] listens to it and rebuilds its
/// theme, so a slider dragged in the design settings redraws the screen it
/// is being dragged on, with nothing in between to keep in step.
class DesignController extends ValueNotifier<DesignSettings> {
  DesignController._() : super(DesignSettings());

  static final DesignController instance = DesignController._();

  static const _presetKey = 'design_preset';
  static const _fieldStyleKey = 'design_field_style';
  static const _radiusKey = 'design_radius';
  static const _shadowKey = 'design_shadow';
  static const _spacingKey = 'design_spacing';
  static const _cardSizeKey = 'design_card_size';
  static const _fontKey = 'design_font';
  static const _opacityKey = 'design_opacity';
  static const _motionKey = 'design_motion';
  static const _hapticsKey = 'design_haptics';

  /// One key per role rather than one encoded blob, so a single color can be
  /// removed again (back to what the preset says) by deleting its key.
  static String _colorKey(DesignColorRole role) => 'design_color_${role.name}';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final overrides = <DesignColorRole, Color>{};
    for (final role in DesignColorRole.values) {
      final stored = prefs.getInt(_colorKey(role));
      if (stored != null) overrides[role] = Color(stored);
    }
    value = DesignSettings(
      preset: _presetFor(prefs.getString(_presetKey)),
      fieldStyle: _fieldStyleFor(prefs.getString(_fieldStyleKey)),
      overrides: overrides,
      radius: prefs.getDouble(_radiusKey),
      shadow: prefs.getDouble(_shadowKey),
      spacing: prefs.getDouble(_spacingKey),
      cardSize: prefs.getDouble(_cardSizeKey),
      font: prefs.getDouble(_fontKey),
      opacity: prefs.getDouble(_opacityKey),
      motion: prefs.getDouble(_motionKey),
      haptics: prefs.getDouble(_hapticsKey),
    );
  }

  Future<void> update(DesignSettings newValue) async {
    value = newValue;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_presetKey, newValue.preset.name);
    await prefs.setString(_fieldStyleKey, newValue.fieldStyle.name);
    await prefs.setDouble(_radiusKey, newValue.radius);
    await prefs.setDouble(_shadowKey, newValue.shadow);
    await prefs.setDouble(_spacingKey, newValue.spacing);
    await prefs.setDouble(_cardSizeKey, newValue.cardSize);
    await prefs.setDouble(_fontKey, newValue.font);
    await prefs.setDouble(_opacityKey, newValue.opacity);
    await prefs.setDouble(_motionKey, newValue.motion);
    await prefs.setDouble(_hapticsKey, newValue.haptics);
    for (final role in DesignColorRole.values) {
      final color = newValue.overrides[role];
      if (color == null) {
        await prefs.remove(_colorKey(role));
      } else {
        await prefs.setInt(_colorKey(role), color.toARGB32());
      }
    }
  }

  /// Back to the untouched default - the grey theme at every default scalar.
  /// Worth its own entry rather than "drag six sliders back": the whole point
  /// of the default being a designed look is that it is somewhere to return
  /// to after experimenting.
  Future<void> reset() => update(DesignSettings());

  static DesignThemePreset _presetFor(String? name) {
    for (final preset in DesignThemePreset.values) {
      if (preset.name == name) return preset;
    }
    return DesignThemePreset.grey;
  }

  static InputFieldStyle _fieldStyleFor(String? name) {
    for (final style in InputFieldStyle.values) {
      if (style.name == name) return style;
    }
    return InputFieldStyle.line;
  }
}
