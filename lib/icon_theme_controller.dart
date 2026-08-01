import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_list_settings_controller.dart' show appListColorPalette;

class IconThemeSettings {
  const IconThemeSettings({this.enabled = false, this.colorIndex = 3});

  /// While off, every icon is drawn exactly as it comes - turning the theme
  /// off restores the original icons, nothing is overwritten.
  final bool enabled;

  /// Index into [appListColorPalette], same palette as everywhere else.
  final int colorIndex;

  Color get color => appListColorPalette[colorIndex];

  IconThemeSettings copyWith({bool? enabled, int? colorIndex}) {
    return IconThemeSettings(
      enabled: enabled ?? this.enabled,
      colorIndex: colorIndex ?? this.colorIndex,
    );
  }
}

/// One color for all app icons at once: each icon is reduced to its
/// brightness and re-tinted, so a mixed pile of logos reads as one set
/// instead of a wall of different brand colors.
class IconThemeController extends ValueNotifier<IconThemeSettings> {
  IconThemeController._() : super(const IconThemeSettings());

  static final IconThemeController instance = IconThemeController._();

  static const _enabledKey = 'icon_theme_enabled';
  static const _colorKey = 'icon_theme_color';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    value = IconThemeSettings(
      enabled: prefs.getBool(_enabledKey) ?? false,
      colorIndex: prefs.getInt(_colorKey) ?? 3,
    );
  }

  Future<void> update(IconThemeSettings newValue) async {
    value = newValue;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, newValue.enabled);
    await prefs.setInt(_colorKey, newValue.colorIndex);
  }
}
