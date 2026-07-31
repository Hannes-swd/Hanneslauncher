import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_list_settings_controller.dart' show appListColorPalette;

enum ClockStyle { digital, word }

class ClockSettings {
  const ClockSettings({
    this.enabled = true,
    this.style = ClockStyle.digital,
    this.wordBgColorIndex = 0,
    this.wordBgOpacity = 0.6,
    this.wordActiveColorIndex = 1,
    this.wordInactiveColorIndex = 0,
  });

  final bool enabled;
  final ClockStyle style;

  // Word clock appearance, independent of the wallpaper/app list colors so
  // choosing a theme elsewhere doesn't force the clock into the same color.
  final int wordBgColorIndex;
  final double wordBgOpacity;
  final int wordActiveColorIndex;
  final int wordInactiveColorIndex;

  Color get wordBgColor => appListColorPalette[wordBgColorIndex];
  Color get wordActiveColor => appListColorPalette[wordActiveColorIndex];
  Color get wordInactiveColor => appListColorPalette[wordInactiveColorIndex];

  ClockSettings copyWith({
    bool? enabled,
    ClockStyle? style,
    int? wordBgColorIndex,
    double? wordBgOpacity,
    int? wordActiveColorIndex,
    int? wordInactiveColorIndex,
  }) {
    return ClockSettings(
      enabled: enabled ?? this.enabled,
      style: style ?? this.style,
      wordBgColorIndex: wordBgColorIndex ?? this.wordBgColorIndex,
      wordBgOpacity: wordBgOpacity ?? this.wordBgOpacity,
      wordActiveColorIndex: wordActiveColorIndex ?? this.wordActiveColorIndex,
      wordInactiveColorIndex:
          wordInactiveColorIndex ?? this.wordInactiveColorIndex,
    );
  }
}

/// Holds whether the home screen clock is shown, and which style it uses,
/// persisted across app restarts.
class ClockSettingsController extends ValueNotifier<ClockSettings> {
  ClockSettingsController._() : super(const ClockSettings());

  static final ClockSettingsController instance = ClockSettingsController._();

  static const _enabledKey = 'clock_enabled';
  static const _styleKey = 'clock_style';
  static const _wordBgColorKey = 'clock_word_bg_color';
  static const _wordBgOpacityKey = 'clock_word_bg_opacity';
  static const _wordActiveColorKey = 'clock_word_active_color';
  static const _wordInactiveColorKey = 'clock_word_inactive_color';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    value = ClockSettings(
      enabled: prefs.getBool(_enabledKey) ?? true,
      style: ClockStyle.values[prefs.getInt(_styleKey) ?? 0],
      wordBgColorIndex: prefs.getInt(_wordBgColorKey) ?? 0,
      wordBgOpacity: prefs.getDouble(_wordBgOpacityKey) ?? 0.6,
      wordActiveColorIndex: prefs.getInt(_wordActiveColorKey) ?? 1,
      wordInactiveColorIndex: prefs.getInt(_wordInactiveColorKey) ?? 0,
    );
  }

  Future<void> update(ClockSettings newValue) async {
    value = newValue;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, newValue.enabled);
    await prefs.setInt(_styleKey, newValue.style.index);
    await prefs.setInt(_wordBgColorKey, newValue.wordBgColorIndex);
    await prefs.setDouble(_wordBgOpacityKey, newValue.wordBgOpacity);
    await prefs.setInt(_wordActiveColorKey, newValue.wordActiveColorIndex);
    await prefs.setInt(
      _wordInactiveColorKey,
      newValue.wordInactiveColorIndex,
    );
  }
}
