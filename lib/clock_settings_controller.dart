import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_list_settings_controller.dart' show appListColorPalette;

enum ClockStyle { digital, word, roman, bars, dotMatrix }

/// Horizontal position on the home screen. Always anchored to the top -
/// there's no bottom option, only how far down from the top it sits.
enum ClockAlignment { left, center, right }

class ClockSettings {
  const ClockSettings({
    this.enabled = true,
    this.style = ClockStyle.digital,
    this.wordBgColorIndex = 0,
    this.wordBgOpacity = 0.6,
    this.wordActiveColorIndex = 1,
    this.wordInactiveColorIndex = 0,
    this.digitalColorIndex = 0,
    this.romanColorIndex = 0,
    this.dotColorIndex = 0,
    this.barsFilledColorIndex = 0,
    this.barsUnfilledColorIndex = 0,
    this.barsUnfilledOpacity = 0.12,
    this.barsTextColorIndex = 0,
    this.alignment = ClockAlignment.center,
    this.topPadding = 0,
    this.sidePadding = 16,
  });

  final bool enabled;
  final ClockStyle style;

  // Where the clock sits: always top-anchored, but movable left/right and
  // further down from the top.
  final ClockAlignment alignment;
  final double topPadding;
  // Only used when not centered - the gap to whichever edge it's pushed
  // against.
  final double sidePadding;

  // Word clock appearance, independent of the wallpaper/app list colors so
  // choosing a theme elsewhere doesn't force the clock into the same color.
  final int wordBgColorIndex;
  final double wordBgOpacity;
  final int wordActiveColorIndex;
  final int wordInactiveColorIndex;

  // Digital, Roman and Dot Matrix clock: the one text/dot color each draws
  // with.
  final int digitalColorIndex;
  final int romanColorIndex;
  final int dotColorIndex;

  // Bars clock: filled part, empty track (plus its own opacity, since a
  // fully solid track would hide the bars sitting on the wallpaper) and the
  // h/m/s numbers underneath.
  final int barsFilledColorIndex;
  final int barsUnfilledColorIndex;
  final double barsUnfilledOpacity;
  final int barsTextColorIndex;

  Color get wordBgColor => appListColorPalette[wordBgColorIndex];
  Color get wordActiveColor => appListColorPalette[wordActiveColorIndex];
  Color get wordInactiveColor => appListColorPalette[wordInactiveColorIndex];

  Color get digitalColor => appListColorPalette[digitalColorIndex];
  Color get romanColor => appListColorPalette[romanColorIndex];
  Color get dotColor => appListColorPalette[dotColorIndex];

  Color get barsFilledColor => appListColorPalette[barsFilledColorIndex];
  Color get barsUnfilledColor =>
      appListColorPalette[barsUnfilledColorIndex].withValues(
        alpha: barsUnfilledOpacity,
      );
  Color get barsTextColor => appListColorPalette[barsTextColorIndex];

  ClockSettings copyWith({
    bool? enabled,
    ClockStyle? style,
    int? wordBgColorIndex,
    double? wordBgOpacity,
    int? wordActiveColorIndex,
    int? wordInactiveColorIndex,
    int? digitalColorIndex,
    int? romanColorIndex,
    int? dotColorIndex,
    int? barsFilledColorIndex,
    int? barsUnfilledColorIndex,
    double? barsUnfilledOpacity,
    int? barsTextColorIndex,
    ClockAlignment? alignment,
    double? topPadding,
    double? sidePadding,
  }) {
    return ClockSettings(
      enabled: enabled ?? this.enabled,
      style: style ?? this.style,
      wordBgColorIndex: wordBgColorIndex ?? this.wordBgColorIndex,
      wordBgOpacity: wordBgOpacity ?? this.wordBgOpacity,
      wordActiveColorIndex: wordActiveColorIndex ?? this.wordActiveColorIndex,
      wordInactiveColorIndex:
          wordInactiveColorIndex ?? this.wordInactiveColorIndex,
      digitalColorIndex: digitalColorIndex ?? this.digitalColorIndex,
      romanColorIndex: romanColorIndex ?? this.romanColorIndex,
      dotColorIndex: dotColorIndex ?? this.dotColorIndex,
      barsFilledColorIndex:
          barsFilledColorIndex ?? this.barsFilledColorIndex,
      barsUnfilledColorIndex:
          barsUnfilledColorIndex ?? this.barsUnfilledColorIndex,
      barsUnfilledOpacity: barsUnfilledOpacity ?? this.barsUnfilledOpacity,
      barsTextColorIndex: barsTextColorIndex ?? this.barsTextColorIndex,
      alignment: alignment ?? this.alignment,
      topPadding: topPadding ?? this.topPadding,
      sidePadding: sidePadding ?? this.sidePadding,
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
  static const _digitalColorKey = 'clock_digital_color';
  static const _romanColorKey = 'clock_roman_color';
  static const _dotColorKey = 'clock_dot_color';
  static const _barsFilledColorKey = 'clock_bars_filled_color';
  static const _barsUnfilledColorKey = 'clock_bars_unfilled_color';
  static const _barsUnfilledOpacityKey = 'clock_bars_unfilled_opacity';
  static const _barsTextColorKey = 'clock_bars_text_color';
  static const _alignmentKey = 'clock_alignment';
  static const _topPaddingKey = 'clock_top_padding';
  static const _sidePaddingKey = 'clock_side_padding';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    value = ClockSettings(
      enabled: prefs.getBool(_enabledKey) ?? true,
      style: ClockStyle.values[prefs.getInt(_styleKey) ?? 0],
      wordBgColorIndex: prefs.getInt(_wordBgColorKey) ?? 0,
      wordBgOpacity: prefs.getDouble(_wordBgOpacityKey) ?? 0.6,
      wordActiveColorIndex: prefs.getInt(_wordActiveColorKey) ?? 1,
      wordInactiveColorIndex: prefs.getInt(_wordInactiveColorKey) ?? 0,
      digitalColorIndex: prefs.getInt(_digitalColorKey) ?? 0,
      romanColorIndex: prefs.getInt(_romanColorKey) ?? 0,
      dotColorIndex: prefs.getInt(_dotColorKey) ?? 0,
      barsFilledColorIndex: prefs.getInt(_barsFilledColorKey) ?? 0,
      barsUnfilledColorIndex: prefs.getInt(_barsUnfilledColorKey) ?? 0,
      barsUnfilledOpacity: prefs.getDouble(_barsUnfilledOpacityKey) ?? 0.12,
      barsTextColorIndex: prefs.getInt(_barsTextColorKey) ?? 0,
      alignment: ClockAlignment.values[prefs.getInt(_alignmentKey) ?? 1],
      topPadding: prefs.getDouble(_topPaddingKey) ?? 0,
      sidePadding: prefs.getDouble(_sidePaddingKey) ?? 16,
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
    await prefs.setInt(_digitalColorKey, newValue.digitalColorIndex);
    await prefs.setInt(_romanColorKey, newValue.romanColorIndex);
    await prefs.setInt(_dotColorKey, newValue.dotColorIndex);
    await prefs.setInt(_barsFilledColorKey, newValue.barsFilledColorIndex);
    await prefs.setInt(
      _barsUnfilledColorKey,
      newValue.barsUnfilledColorIndex,
    );
    await prefs.setDouble(
      _barsUnfilledOpacityKey,
      newValue.barsUnfilledOpacity,
    );
    await prefs.setInt(_barsTextColorKey, newValue.barsTextColorIndex);
    await prefs.setInt(_alignmentKey, newValue.alignment.index);
    await prefs.setDouble(_topPaddingKey, newValue.topPadding);
    await prefs.setDouble(_sidePaddingKey, newValue.sidePadding);
  }
}
