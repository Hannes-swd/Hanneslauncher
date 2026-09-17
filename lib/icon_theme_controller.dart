import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_list_settings_controller.dart' show appListColorPalette;

/// Where an app's icon comes from, for every app at once.
///
/// A picture picked by hand for one app is not in here on purpose: it is a
/// per-app answer, it always wins over whatever is chosen here, and removing
/// it in the customize screen is what hands that app back to this setting.
/// See [AppIcon], which is where the two meet.
enum IconStyle {
  /// The icon each app ships itself - how the launcher behaved before any of
  /// this existed, and still the default.
  system,

  /// An installed icon pack redraws every app it covers. Apps the pack does
  /// not cover keep their own icon (dressed in the pack's frame when it
  /// ships one).
  pack,

  /// Every icon reduced to its brightness and re-tinted to one color.
  color,
}

class IconThemeSettings {
  const IconThemeSettings({
    this.style = IconStyle.system,
    this.colorIndex = 3,
    this.packPackage,
  });

  final IconStyle style;

  /// Index into [appListColorPalette], same palette as everywhere else.
  final int colorIndex;

  /// The chosen icon pack's package name, or null while none is picked.
  /// Kept even while another style is on, so switching back to [IconStyle.pack]
  /// lands on the same pack instead of on nothing.
  final String? packPackage;

  /// Clamped rather than indexed straight: a backup from a phone with more
  /// hand-picked colors than this one has can name an index past the end.
  Color get color {
    final palette = appListColorPalette;
    return palette[colorIndex.clamp(0, palette.length - 1)];
  }

  /// Whether anything at all is being done to the icons. What the settings
  /// list shows a swatch next to.
  bool get changesIcons => style != IconStyle.system;

  IconThemeSettings copyWith({
    IconStyle? style,
    int? colorIndex,
    String? packPackage,
  }) {
    return IconThemeSettings(
      style: style ?? this.style,
      colorIndex: colorIndex ?? this.colorIndex,
      packPackage: packPackage ?? this.packPackage,
    );
  }
}

/// How the icons are drawn: as they come, from an icon pack, or all in one
/// color. Nothing is ever written back onto an app, so every one of these is
/// undone by picking another - the original icons are always a tap away.
class IconThemeController extends ValueNotifier<IconThemeSettings> {
  IconThemeController._() : super(const IconThemeSettings());

  static final IconThemeController instance = IconThemeController._();

  static const _styleKey = 'icon_theme_style';
  static const _colorKey = 'icon_theme_color';
  static const _packKey = 'icon_theme_pack';

  /// Only read, never written any more: before there were three styles this
  /// was the on/off switch for the color, and a launcher updated from that
  /// version has to keep the color it was set to.
  static const _legacyEnabledKey = 'icon_theme_enabled';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final storedStyle = prefs.getString(_styleKey);
    value = IconThemeSettings(
      style: storedStyle == null
          ? ((prefs.getBool(_legacyEnabledKey) ?? false)
                ? IconStyle.color
                : IconStyle.system)
          : styleFromName(storedStyle),
      colorIndex: prefs.getInt(_colorKey) ?? 3,
      packPackage: prefs.getString(_packKey),
    );
  }

  Future<void> update(IconThemeSettings newValue) async {
    value = newValue;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_styleKey, newValue.style.name);
    await prefs.setInt(_colorKey, newValue.colorIndex);
    final pack = newValue.packPackage;
    if (pack == null) {
      await prefs.remove(_packKey);
    } else {
      await prefs.setString(_packKey, pack);
    }
  }

  /// Anything unknown (an older or newer backup, a cleared setting) means
  /// "leave the icons alone", which is the one answer that always works.
  static IconStyle styleFromName(Object? name) {
    for (final style in IconStyle.values) {
      if (style.name == name) return style;
    }
    return IconStyle.system;
  }
}
