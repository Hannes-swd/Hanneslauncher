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

/// How the app list's flat view (search, or the search icon tapped with no
/// query) orders its entries. The letter-scrub grid above it stays
/// alphabetical regardless - that's inherent to a letter index, sorting it
/// any other way would make the bar itself meaningless.
enum AppListSortMode { alphabetical, newestFirst }

/// How a letter's apps are arranged once there are more of them than fit on
/// screen at once.
///
/// [singleColumn] keeps every app on its own full-width row and scrolls the
/// group while the finger is dragged towards the top or bottom edge - with
/// many apps under one letter that stays readable, which is why it's the
/// default. [columns] is the older layout: apps spill into further columns
/// next to each other so the whole group is visible without scrolling, at
/// the cost of ever narrower columns.
enum AppListLayoutMode { singleColumn, columns }

/// Which side of the screen the alphabet bar sits on - and with it the whole
/// app list, mirrored. [right] is the default thumb-on-the-right layout,
/// [left] the left-handed one: alphabet on the left, apps to the right of it.
enum AppListHand { right, left }

class AppListSettings {
  const AppListSettings({
    this.colorIndex = 0,
    this.fontFamily = '',
    this.fontSize = 16,
    this.rowHeight = 72,
    this.sortMode = AppListSortMode.alphabetical,
    this.layoutMode = AppListLayoutMode.singleColumn,
    this.hand = AppListHand.right,
    this.hideAlphabet = false,
    this.backgroundBlur = 14,
    this.searchExtras = true,
    this.searchContacts = false,
    this.searchWebUrl = '',
  });

  final int colorIndex;
  final String fontFamily;
  final double fontSize;
  final double rowHeight;
  final AppListSortMode sortMode;
  final AppListLayoutMode layoutMode;
  final AppListHand hand;

  /// Keeps the alphabet bar invisible until a finger is actually on it: the
  /// letters fade in for the duration of the scrub and back out on release,
  /// so the home screen stays free of them without losing the gesture.
  final bool hideAlphabet;

  /// How strongly the wallpaper is blurred while the app list is in use - a
  /// scrub on the alphabet bar, or the search - in pixels of blur radius.
  /// 0 switches the blur off entirely and leaves the wallpaper alone.
  final double backgroundBlur;

  /// Whether the search answers sums and finds settings as well as apps.
  ///
  /// On by default, unlike the two below, because both are free: the
  /// calculator is arithmetic and the settings list is already in the app.
  /// Neither asks for a permission, sends anything anywhere, or costs a
  /// frame when it finds nothing.
  final bool searchExtras;

  /// Whether the search also looks through the contacts. Off until it is
  /// switched on: it needs a permission, and a launcher set up without it
  /// should never be asked for one.
  final bool searchContacts;

  /// Where to send whatever was typed when nothing here matched it. Empty
  /// leaves that row out entirely - the same address format the search
  /// widget uses, with `{{suche}}` where the words go.
  final String searchWebUrl;

  Color get color => appListColorPalette[colorIndex];

  /// True while the app list is mirrored for left-handed use.
  bool get leftHanded => hand == AppListHand.left;

  AppListSettings copyWith({
    int? colorIndex,
    String? fontFamily,
    double? fontSize,
    double? rowHeight,
    AppListSortMode? sortMode,
    AppListLayoutMode? layoutMode,
    AppListHand? hand,
    bool? hideAlphabet,
    double? backgroundBlur,
    bool? searchExtras,
    bool? searchContacts,
    String? searchWebUrl,
  }) {
    return AppListSettings(
      colorIndex: colorIndex ?? this.colorIndex,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      rowHeight: rowHeight ?? this.rowHeight,
      sortMode: sortMode ?? this.sortMode,
      layoutMode: layoutMode ?? this.layoutMode,
      hand: hand ?? this.hand,
      hideAlphabet: hideAlphabet ?? this.hideAlphabet,
      backgroundBlur: backgroundBlur ?? this.backgroundBlur,
      searchExtras: searchExtras ?? this.searchExtras,
      searchContacts: searchContacts ?? this.searchContacts,
      searchWebUrl: searchWebUrl ?? this.searchWebUrl,
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
  static const _sortModeKey = 'applist_sort_mode';
  static const _layoutModeKey = 'applist_layout_mode';
  static const _handKey = 'applist_hand';
  static const _hideAlphabetKey = 'applist_hide_alphabet';
  // Named for the search because that was all it applied to at first; kept
  // under the old key so a value already set survives the rename.
  static const _backgroundBlurKey = 'applist_search_blur';
  static const _searchExtrasKey = 'applist_search_extras';
  static const _searchContactsKey = 'applist_search_contacts';
  static const _searchWebUrlKey = 'applist_search_web_url';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    value = AppListSettings(
      colorIndex: prefs.getInt(_colorKey) ?? 0,
      fontFamily: prefs.getString(_fontFamilyKey) ?? '',
      fontSize: prefs.getDouble(_fontSizeKey) ?? 16,
      rowHeight: prefs.getDouble(_rowHeightKey) ?? 72,
      sortMode:
          AppListSortMode.values[prefs.getInt(_sortModeKey) ?? 0],
      layoutMode:
          AppListLayoutMode.values[prefs.getInt(_layoutModeKey) ?? 0],
      hand: AppListHand.values[prefs.getInt(_handKey) ?? 0],
      hideAlphabet: prefs.getBool(_hideAlphabetKey) ?? false,
      backgroundBlur: prefs.getDouble(_backgroundBlurKey) ?? 14,
      searchExtras: prefs.getBool(_searchExtrasKey) ?? true,
      searchContacts: prefs.getBool(_searchContactsKey) ?? false,
      searchWebUrl: prefs.getString(_searchWebUrlKey) ?? '',
    );
  }

  Future<void> update(AppListSettings newValue) async {
    value = newValue;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_colorKey, newValue.colorIndex);
    await prefs.setString(_fontFamilyKey, newValue.fontFamily);
    await prefs.setDouble(_fontSizeKey, newValue.fontSize);
    await prefs.setDouble(_rowHeightKey, newValue.rowHeight);
    await prefs.setInt(_sortModeKey, newValue.sortMode.index);
    await prefs.setInt(_layoutModeKey, newValue.layoutMode.index);
    await prefs.setInt(_handKey, newValue.hand.index);
    await prefs.setBool(_hideAlphabetKey, newValue.hideAlphabet);
    await prefs.setDouble(_backgroundBlurKey, newValue.backgroundBlur);
    await prefs.setBool(_searchExtrasKey, newValue.searchExtras);
    await prefs.setBool(_searchContactsKey, newValue.searchContacts);
    await prefs.setString(_searchWebUrlKey, newValue.searchWebUrl);
  }
}
