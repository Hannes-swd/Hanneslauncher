import 'package:flutter/material.dart';

import 'app_icon.dart';
import 'app_strings.dart';
import 'color_swatch_picker.dart';
import 'folders_controller.dart';
import 'launcher_entries_controller.dart';
import 'launcher_entry.dart';
import 'locale_controller.dart';
import 'text_prompt_dialog.dart';

/// Lists the user's folders and lets new ones be created.
class FoldersSettingsScreen extends StatelessWidget {
  const FoldersSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LocaleController.instance,
      builder: (context, language, child) {
        final s = AppStrings(language);
        return ValueListenableBuilder<List<LauncherFolder>>(
          valueListenable: FoldersController.instance,
          builder: (context, folders, child) {
            return Scaffold(
              appBar: AppBar(title: Text(s.folders)),
              floatingActionButton: FloatingActionButton.extended(
                onPressed: () => _addFolder(context, s),
                icon: const Icon(Icons.create_new_folder_outlined),
                label: Text(s.addFolder),
              ),
              body: folders.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        s.noFolders,
                        style: const TextStyle(color: Colors.black54),
                      ),
                    )
                  : ListView.builder(
                      // Room at the bottom so the last row isn't hidden
                      // behind the floating button.
                      padding: const EdgeInsets.only(bottom: 88),
                      itemCount: folders.length,
                      itemBuilder: (context, index) {
                        final folder = folders[index];
                        return ListTile(
                          leading: AppIcon(
                            entry: LauncherEntry.folder(folder),
                            size: 36,
                          ),
                          title: Text(folder.name),
                          subtitle: Text(
                            s.foldersSubtitle(folder.itemKeys.length),
                          ),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    FolderEditScreen(folderId: folder.id),
                              ),
                            );
                          },
                        );
                      },
                    ),
            );
          },
        );
      },
    );
  }

  Future<void> _addFolder(BuildContext context, AppStrings s) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => TextPromptDialog(
        title: s.addFolder,
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
    final folder = await FoldersController.instance.add(name);
    if (!context.mounted) return;
    // Straight into the folder, since a new one is empty and the next step
    // is always filling it.
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FolderEditScreen(folderId: folder.id),
      ),
    );
  }
}

/// Name, color and contents of a single folder.
class FolderEditScreen extends StatelessWidget {
  const FolderEditScreen({super.key, required this.folderId});

  final String folderId;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LocaleController.instance,
      builder: (context, language, child) {
        final s = AppStrings(language);
        return ValueListenableBuilder<List<LauncherFolder>>(
          valueListenable: FoldersController.instance,
          builder: (context, folders, child) {
            final folder = FoldersController.instance.byId(folderId);
            // Deleted from this very screen.
            if (folder == null) return const Scaffold();
            final items = LauncherEntriesController.instance.resolve(
              folder.itemKeys,
            );

            return Scaffold(
              appBar: AppBar(
                title: Text(folder.name),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: s.changeName,
                    onPressed: () => _rename(context, folder, s),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: s.deleteFolder,
                    onPressed: () async {
                      await FoldersController.instance.remove(folder.id);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
              floatingActionButton: FloatingActionButton.extended(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          FolderContentsPicker(folderId: folder.id),
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: Text(s.addToFolder),
              ),
              body: ListView(
                padding: const EdgeInsets.only(bottom: 88),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      s.folderColor,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ColorSwatchPicker(
                      s: s,
                      selectedIndex: folder.colorIndex,
                      onSelected: (i) =>
                          FoldersController.instance.setColor(folder.id, i),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: Text(
                      s.folderContents,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  if (items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        s.emptyFolder,
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ),
                  for (final entry in items)
                    ListTile(
                      leading: AppIcon(entry: entry, size: 36),
                      title: Text(entry.name),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () => FoldersController.instance.removeItem(
                          folder.id,
                          entry.key,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _rename(
    BuildContext context,
    LauncherFolder folder,
    AppStrings s,
  ) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => TextPromptDialog(
        title: s.changeName,
        label: s.folderName,
        initialValue: folder.name,
        s: s,
      ),
    );
    // A folder has no name to fall back on, so an empty one is ignored.
    if (name != null && name.trim().isNotEmpty) {
      await FoldersController.instance.rename(folder.id, name);
    }
  }
}

/// Picks what goes into a folder: apps, web apps and other folders.
class FolderContentsPicker extends StatelessWidget {
  const FolderContentsPicker({super.key, required this.folderId});

  final String folderId;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LocaleController.instance,
      builder: (context, language, child) {
        final s = AppStrings(language);
        return ValueListenableBuilder<List<LauncherFolder>>(
          valueListenable: FoldersController.instance,
          builder: (context, folders, child) {
            final folder = FoldersController.instance.byId(folderId);
            if (folder == null) return const Scaffold();

            // Folders first, then everything else - a folder is the thing
            // being looked for here and would be lost among the packages.
            final all = LauncherEntriesController.instance.entries;
            final entries = [
              for (final entry in all)
                if (entry.isFolder &&
                    FoldersController.instance.canContain(
                      folder.id,
                      entry.key,
                    ))
                  entry,
              for (final entry in all)
                if (!entry.isFolder) entry,
            ];

            return Scaffold(
              appBar: AppBar(title: Text(s.addToFolder)),
              body: ListView.builder(
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  final contained = folder.itemKeys.contains(entry.key);
                  return CheckboxListTile(
                    value: contained,
                    secondary: AppIcon(entry: entry, size: 36),
                    title: Text(entry.name),
                    onChanged: (_) {
                      if (contained) {
                        FoldersController.instance.removeItem(
                          folder.id,
                          entry.key,
                        );
                      } else {
                        FoldersController.instance.addItem(
                          folder.id,
                          entry.key,
                        );
                      }
                    },
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
