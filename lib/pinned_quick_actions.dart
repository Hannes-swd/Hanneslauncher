import 'package:flutter/material.dart';

import 'app_overrides_controller.dart';
import 'app_strings.dart';
import 'color_swatch_picker.dart';
import 'folders_controller.dart';
import 'launcher_entry.dart';
import 'locale_controller.dart';
import 'web_apps_controller.dart';

/// Long-pressing a pinned entry on the home screen: change its icon, or -
/// for a folder - its color, without going through the settings.
Future<void> showPinnedQuickActions(
  BuildContext context,
  LauncherEntry entry,
) async {
  final s = AppStrings(LocaleController.instance.value);
  final isFolder = entry.isFolder;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return SimpleDialog(
        title: Text(entry.name),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(true),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                isFolder ? Icons.palette_outlined : Icons.image_outlined,
              ),
              title: Text(isFolder ? s.folderColor : s.changeIcon),
            ),
          ),
        ],
      );
    },
  );
  if (confirmed != true || !context.mounted) return;

  if (isFolder) {
    await _pickFolderColor(context, entry.folder!, s);
  } else if (entry.isWebApp) {
    await WebAppsController.instance.pickIcon(entry.webApp!.id);
  } else {
    // Built-ins have no package name, so they go into the same override
    // store under their own key - which is what [LauncherEntry.customIcon]
    // reads them back out of.
    await AppOverridesController.instance.pickIcon(entry.key);
  }
}

Future<void> _pickFolderColor(
  BuildContext context,
  LauncherFolder folder,
  AppStrings s,
) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(s.folderColor),
        content: ColorSwatchPicker(
          s: s,
          swatchSize: 40,
          selectedIndex: folder.colorIndex,
          onSelected: (i) {
            FoldersController.instance.setColor(folder.id, i);
            Navigator.of(context).pop();
          },
        ),
      );
    },
  );
}
