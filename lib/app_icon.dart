import 'dart:io';

import 'package:flutter/material.dart';

import 'builtin_entries.dart';
import 'icon_pack_controller.dart';
import 'icon_theme_controller.dart';
import 'launcher_entry.dart';

/// Shows an entry's icon, and is the one place that decides where it comes
/// from. In order:
///
/// 1. A folder draws its own glyph in its own color.
/// 2. A picture the user picked for this one entry. It is the most specific
///    answer there is, so nothing global touches it: an icon pack skips it
///    and the color leaves it alone. Removing it in the customize screen is
///    what hands the entry back to the styles below.
/// 3. Whatever [IconThemeController] is set to - the app's own icon, the
///    chosen icon pack's, or the app's own re-tinted to one color.
///
/// Nothing is ever written back onto an app, so every step is undone by
/// undoing the setting that caused it.
class AppIcon extends StatelessWidget {
  const AppIcon({
    super.key,
    required this.entry,
    required this.size,
    this.styleOverride,
  });

  final LauncherEntry entry;
  final double size;

  /// Draws as if this style were the chosen one, without changing anything.
  /// Only the settings screen sets it, so its three tiles show the real
  /// treatment on a real icon instead of a mock-up that could drift from what
  /// the app list then does.
  final IconStyle? styleOverride;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<IconThemeSettings>(
      valueListenable: IconThemeController.instance,
      builder: (context, iconTheme, child) {
        final folder = entry.folder;
        if (folder != null) {
          // Folders keep the color picked for them individually - it's an
          // explicit choice, not something the icon style should overrule.
          // Just the glyph on nothing, so it sits on the wallpaper the same
          // way the app icons do instead of inside a colored tile.
          return Icon(Icons.folder, size: size, color: folder.color);
        }

        final customIcon = entry.customIcon;
        if (customIcon != null) return _picture(customIcon);

        switch (styleOverride ?? iconTheme.style) {
          case IconStyle.system:
            return _rawIcon();
          case IconStyle.color:
            return _tinted(_rawIcon(), iconTheme.color);
          case IconStyle.pack:
            return _packIcon();
        }
      },
    );
  }

  /// The chosen pack's icon, redrawn as the pack finishes rendering. An app
  /// the pack has nothing for - and a web app, folder or built-in screen,
  /// which no pack has ever heard of - keeps its own icon rather than
  /// disappearing while a set is half applied.
  Widget _packIcon() {
    return ListenableBuilder(
      listenable: IconPacksController.instance,
      builder: (context, child) {
        final app = entry.app;
        final packIcon = app == null
            ? null
            : IconPacksController.instance.iconFor(app.packageName);
        return packIcon == null ? _rawIcon() : _picture(packIcon);
      },
    );
  }

  /// A picture from a file - a picked one or a pack's rendered PNG. Clipped
  /// to a square and cropped to fill it: a picked one is an arbitrary photo,
  /// and stretching it would be worse than losing its edges.
  ///
  /// A file that is gone or unreadable falls back to the app's own icon
  /// rather than to a hole. That is not a corner case: a pack's icons live in
  /// the cache directory, which Android empties whenever it is short of
  /// space, and it can do so between two frames.
  ///
  /// [onError] overrides that fallback, and the one caller that passes it is
  /// [_rawIcon] drawing a shortcut's own picture: falling back to itself is
  /// where it would otherwise end up, and that loops forever.
  Widget _picture(File file, [Widget? onError]) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: Image.file(
        file,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => onError ?? _rawIcon(),
      ),
    );
  }

  Widget _rawIcon() {
    final systemIcon = entry.systemIcon;
    if (systemIcon != null) {
      return Image.memory(systemIcon, width: size, height: size);
    }
    // A saved shortcut's own picture, the one Android drew for it. Below the
    // picked picture above and above the fallback glyph below, which is the
    // same order everything else in here follows.
    final shortcutIcon = entry.shortcutIcon;
    if (shortcutIcon != null) return _picture(shortcutIcon, _fallbackGlyph());
    final builtIn = entry.builtIn;
    if (builtIn != null) return Icon(builtIn.icon, size: size);
    return _fallbackGlyph();
  }

  Widget _fallbackGlyph() {
    if (entry.isWebApp) return Icon(Icons.public, size: size);
    // Shortcuts without a picture are rare but allowed, and an arrow says
    // "this goes somewhere inside an app" better than a grid of squares.
    if (entry.isShortcut) return Icon(Icons.arrow_outward, size: size);
    return Icon(Icons.apps, size: size);
  }

  /// Strips an icon down to its brightness and multiplies the chosen color
  /// back in. Multiplying (rather than painting a flat silhouette) keeps the
  /// shape readable: bright parts take the color, dark parts stay dark, so a
  /// full-bleed square icon doesn't turn into a solid block.
  Widget _tinted(Widget icon, Color color) {
    return ColorFiltered(
      colorFilter: ColorFilter.mode(color, BlendMode.modulate),
      child: ColorFiltered(
        colorFilter: const ColorFilter.matrix(_grayscale),
        child: icon,
      ),
    );
  }

  // Luminance weights on every output channel, alpha untouched.
  static const List<double> _grayscale = [
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0, //
  ];
}
