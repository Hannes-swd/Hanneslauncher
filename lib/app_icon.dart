import 'package:flutter/material.dart';

import 'builtin_entries.dart';
import 'icon_theme_controller.dart';
import 'launcher_entry.dart';

/// Shows an entry's icon: the user's own picture if one was set, otherwise
/// the icon Android reports for an installed app, otherwise a glyph (which
/// is what a web app without a picked picture falls back to).
///
/// When the icon theme is on, whatever came out of that is re-tinted to the
/// chosen color. Nothing is written back, so switching the theme off brings
/// the original icons straight back.
class AppIcon extends StatelessWidget {
  const AppIcon({super.key, required this.entry, required this.size});

  final LauncherEntry entry;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<IconThemeSettings>(
      valueListenable: IconThemeController.instance,
      builder: (context, iconTheme, child) {
        final folder = entry.folder;
        if (folder != null) {
          // Folders keep the color picked for them individually - it's an
          // explicit choice, not something the icon theme should overrule.
          // Just the glyph on nothing, so it sits on the wallpaper the same
          // way the app icons do instead of inside a colored tile.
          return Icon(Icons.folder, size: size, color: folder.color);
        }

        final icon = _rawIcon();
        return iconTheme.enabled ? _tinted(icon, iconTheme.color) : icon;
      },
    );
  }

  Widget _rawIcon() {
    final customIcon = entry.customIcon;
    if (customIcon != null) {
      // Custom pictures are arbitrary photos, so they're clipped to a square
      // and cropped to fill it instead of being stretched.
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: Image.file(
          customIcon,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }
    final systemIcon = entry.systemIcon;
    if (systemIcon != null) {
      return Image.memory(systemIcon, width: size, height: size);
    }
    final builtIn = entry.builtIn;
    if (builtIn != null) return Icon(builtIn.icon, size: size);
    return Icon(entry.isWebApp ? Icons.public : Icons.apps, size: size);
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
