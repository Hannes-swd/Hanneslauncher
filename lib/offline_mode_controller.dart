import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'clock_settings_controller.dart';

/// How thick the digital face draws in this mode. Heavier than the home
/// screen's: filling a screen, the light weight the home clock uses thins
/// out into hairlines you can't read from the other side of a room.
const FontWeight offlineDigitalWeight = FontWeight.w600;

/// What the offline mode looks like: which clock face it draws, in which
/// color, and whether it shows what's currently playing.
///
/// Deliberately its own settings rather than the home screen clock's: the
/// two are looked at in completely different situations - one on a
/// wallpaper in the hand, the other across a room on a charging phone - so
/// a style that works for one rarely works for the other.
class OfflineModeSettings {
  const OfflineModeSettings({
    this.style = ClockStyle.digital,
    this.colorIndex = 1,
    this.showMedia = false,
  });

  final ClockStyle style;

  /// Index into `appListColorPalette`, like every other color in the app.
  /// Defaults to 1 (white) - the only color that reads on black from a
  /// distance without further thought.
  final int colorIndex;

  /// Whether the currently playing track and its skip buttons are drawn
  /// under the clock. Off until the user turns it on, because it needs a
  /// permission they have to grant by hand first.
  final bool showMedia;

  OfflineModeSettings copyWith({
    ClockStyle? style,
    int? colorIndex,
    bool? showMedia,
  }) {
    return OfflineModeSettings(
      style: style ?? this.style,
      colorIndex: colorIndex ?? this.colorIndex,
      showMedia: showMedia ?? this.showMedia,
    );
  }

  /// The clock settings a face is drawn with in this mode: the chosen style,
  /// and every color slot set to the one chosen color. Built off the
  /// defaults rather than the home screen's own settings, so a background
  /// or opacity tuned for a wallpaper can't leak onto the black screen.
  ClockSettings toClockSettings() {
    return ClockSettings(
      style: style,
      digitalColorIndex: colorIndex,
      romanColorIndex: colorIndex,
      dotColorIndex: colorIndex,
      orbitColorIndex: colorIndex,
      verticalColorIndex: colorIndex,
      barsFilledColorIndex: colorIndex,
      barsUnfilledColorIndex: colorIndex,
      barsTextColorIndex: colorIndex,
      wordActiveColorIndex: colorIndex,
      // The two backgrounds stay black: the screen behind them already is,
      // and a card drawn in the clock's own color would swallow its digits.
      wordInactiveColorIndex: colorIndex,
      wordBgColorIndex: 0,
      wordBgOpacity: 0,
      splitFlapTextColorIndex: colorIndex,
      splitFlapBgColorIndex: 0,
      splitFlapBgOpacity: 0.85,
    );
  }
}

/// The offline mode's settings, persisted across app restarts.
class OfflineModeController extends ValueNotifier<OfflineModeSettings> {
  OfflineModeController._() : super(const OfflineModeSettings());

  static final OfflineModeController instance = OfflineModeController._();

  static const _styleKey = 'offline_style';
  static const _colorKey = 'offline_color';
  static const _showMediaKey = 'offline_show_media';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final styleName = prefs.getString(_styleKey);
    value = OfflineModeSettings(
      style: ClockStyle.values.firstWhere(
        (style) => style.name == styleName,
        orElse: () => ClockStyle.digital,
      ),
      colorIndex: prefs.getInt(_colorKey) ?? 1,
      showMedia: prefs.getBool(_showMediaKey) ?? false,
    );
  }

  Future<void> update(OfflineModeSettings settings) async {
    value = settings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_styleKey, settings.style.name);
    await prefs.setInt(_colorKey, settings.colorIndex);
    await prefs.setBool(_showMediaKey, settings.showMedia);
  }
}
