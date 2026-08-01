import 'package:flutter/material.dart';

import 'launcher_entry.dart';

/// Shows an entry's icon: the user's own picture if one was set, otherwise
/// the icon Android reports for an installed app, otherwise a glyph (which
/// is what a web app without a picked picture falls back to).
class AppIcon extends StatelessWidget {
  const AppIcon({super.key, required this.entry, required this.size});

  final LauncherEntry entry;
  final double size;

  @override
  Widget build(BuildContext context) {
    final folder = entry.folder;
    if (folder != null) {
      // Just the glyph in the folder's own color, on nothing - so it sits on
      // the wallpaper the same way the app icons do, instead of inside a
      // colored tile.
      return Icon(Icons.folder, size: size, color: folder.color);
    }

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
    return Icon(entry.isWebApp ? Icons.public : Icons.apps, size: size);
  }
}
