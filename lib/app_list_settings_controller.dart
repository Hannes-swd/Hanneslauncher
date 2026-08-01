import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'custom_colors_controller.dart';

/// The fixed colors every color picker starts out with.
const List<Color> _baseColorPalette = [
  Colors.black,
  Colors.white,
  Color(0xFF37474F), // blue grey
  Color(0xFF1565C0), // blue
  Color(0xFF2E7D32), // green
  Color(0xFF6A1B9A), // purple
  Color(0xFFC62828), // red
];

/// Selectable colors everywhere in the app: the fixed base palette, plus
/// whatever the user has added themselves through a color picker's "+".
/// Stored as an index into this (rather than a raw ARGB value) to keep
/// persistence simple - which is also why colors are only ever appended,
/// never removed: removing one would shift every index after it.
List<Color> get appListColorPalette => [
  ..._baseColorPalette,
  ...CustomColorsController.instance.value,
];

class AppListSettings {
  const AppListSettings({
    this.colorIndex = 0,
    this.fontFamily = '',
    this.fontSize = 16,
    this.rowHeight = 72,
  });

  final int colorIndex;
  final String fontFamily;
  final double fontSize;
  final double rowHeight;

  Color get color => appListColorPalette[colorIndex];

  AppListSettings copyWith({
    int? colorIndex,
    String? fontFamily,
    double? fontSize,
    double? rowHeight,
  }) {
    return AppListSettings(
      colorIndex: colorIndex ?? this.colorIndex,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      rowHeight: rowHeight ?? this.rowHeight,
    );
  }
}

/// Holds the app list's appearance settings, persisted across app restarts.
class AppListSettingsController extends ValueNotifier<AppListSettings> {
  AppListSettingsController._() : super(const AppListSettings());

  static final AppListSettingsController instance =
      AppListSettingsController._();

  static const _colorKey = 'applist_color_index';
  static const _fontFamilyKey = 'applist_font_family';
  static const _fontSizeKey = 'applist_font_size';
  static const _rowHeightKey = 'applist_row_height';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    value = AppListSettings(
      colorIndex: prefs.getInt(_colorKey) ?? 0,
      fontFamily: prefs.getString(_fontFamilyKey) ?? '',
      fontSize: prefs.getDouble(_fontSizeKey) ?? 16,
      rowHeight: prefs.getDouble(_rowHeightKey) ?? 72,
    );
  }

  Future<void> update(AppListSettings newValue) async {
    value = newValue;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_colorKey, newValue.colorIndex);
    await prefs.setString(_fontFamilyKey, newValue.fontFamily);
    await prefs.setDouble(_fontSizeKey, newValue.fontSize);
    await prefs.setDouble(_rowHeightKey, newValue.rowHeight);
  }
}
