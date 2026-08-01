import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';

import 'app_overrides_controller.dart';

/// Shows an app's icon: the user's own picture if one was set in the app
/// customization screen, otherwise the icon reported by the system.
class AppIcon extends StatelessWidget {
  const AppIcon({super.key, required this.app, required this.size});

  final AppInfo app;
  final double size;

  @override
  Widget build(BuildContext context) {
    final customIcon = AppOverridesController.instance
        .forPackage(app.packageName)
        ?.iconFile;
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
    if (app.icon != null) {
      return Image.memory(app.icon!, width: size, height: size);
    }
    return Icon(Icons.apps, size: size);
  }
}
