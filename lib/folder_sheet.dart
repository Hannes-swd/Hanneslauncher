import 'package:flutter/material.dart';

import 'app_icon.dart';
import 'app_strings.dart';
import 'folders_controller.dart';
import 'folders_settings_screen.dart' show FolderContentsPicker;
import 'launcher_entries_controller.dart';
import 'launcher_entry.dart';
import 'locale_controller.dart';
import 'text_prompt_dialog.dart';

/// Opens a folder's window: its apps, web apps and subfolders. Tapping an
/// app launches it and closes the window; tapping a subfolder opens that one
/// on top, so nested folders can be browsed and backed out of one by one.
Future<void> showFolderSheet(BuildContext context, LauncherFolder folder) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (context) => _FolderSheet(folderId: folder.id),
  );
}

class _FolderSheet extends StatelessWidget {
  const _FolderSheet({required this.folderId});

  // Held by id, not by value, so renaming or refilling the folder while the
  // window is open is picked up instead of showing a stale copy.
  final String folderId;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LocaleController.instance,
      builder: (context, language, child) {
        final s = AppStrings(language);
        return ListenableBuilder(
          listenable: LauncherEntriesController.instance,
          builder: (context, child) {
            final folder = FoldersController.instance.byId(folderId);
            // Deleted while open.
            if (folder == null) return const SizedBox.shrink();
            final items = LauncherEntriesController.instance.resolve(
              folder.itemKeys,
            );

            final onColor = folder.color.computeLuminance() > 0.5
                ? Colors.black87
                : Colors.white;

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(24),
              child: Container(
                decoration: BoxDecoration(
                  color: folder.color,
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            folder.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: onColor,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.add, color: onColor),
                          tooltip: s.addToFolder,
                          onPressed: () => _addToFolder(context, folder, s),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          s.emptyFolder,
                          style: TextStyle(color: onColor),
                        ),
                      )
                    else
                      Flexible(
                        child: GridView.builder(
                          shrinkWrap: true,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 4,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 0.8,
                              ),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            return _FolderItem(
                              entry: items[index],
                              labelColor: onColor,
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// The + in the folder's header: either pick existing entries, or create a
/// subfolder right here without a detour through the settings.
Future<void> _addToFolder(
  BuildContext context,
  LauncherFolder folder,
  AppStrings s,
) async {
  final choice = await showDialog<String>(
    context: context,
    builder: (context) {
      return SimpleDialog(
        title: Text(s.addToFolder),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop('apps'),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.apps),
              title: Text(s.addApps),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop('folder'),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.create_new_folder_outlined),
              title: Text(s.newSubfolder),
            ),
          ),
        ],
      );
    },
  );
  if (choice == null || !context.mounted) return;

  if (choice == 'apps') {
    // Pushed over the open folder window, which picks the additions up on
    // its own once this is popped again.
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FolderContentsPicker(folderId: folder.id),
      ),
    );
    return;
  }

  final name = await showDialog<String>(
    context: context,
    builder: (context) => TextPromptDialog(
      title: s.newSubfolder,
      label: s.folderName,
      initialValue: '',
      s: s,
    ),
  );
  if (name == null || !context.mounted) return;
  if (name.trim().isEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(s.nameRequired)));
    return;
  }
  final created = await FoldersController.instance.add(name);
  await FoldersController.instance.addItem(
    folder.id,
    FoldersController.keyFor(created.id),
  );
}

class _FolderItem extends StatelessWidget {
  const _FolderItem({required this.entry, required this.labelColor});

  final LauncherEntry entry;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (entry.isFolder) {
          showFolderSheet(context, entry.folder!);
        } else {
          // The window has done its job once something is launched.
          Navigator.of(context).pop();
          entry.launch();
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(entry: entry, size: 48),
          const SizedBox(height: 6),
          Text(
            entry.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(color: labelColor, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
