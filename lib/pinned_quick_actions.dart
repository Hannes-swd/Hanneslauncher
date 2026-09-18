import 'package:flutter/material.dart';

import 'app_overrides_controller.dart';
import 'app_shortcuts.dart';
import 'app_strings.dart';
import 'color_swatch_picker.dart';
import 'folders_controller.dart';
import 'launcher_entry.dart';
import 'locale_controller.dart';
import 'saved_shortcuts_controller.dart';
import 'web_apps_controller.dart';

/// Long-pressing an entry - a pinned icon, a row in the search results, an
/// icon in a folder.
///
/// For an installed app this is also where the shortcuts it publishes about
/// itself show up: a chat, "new tab", a playlist. Tapping one starts it;
/// keeping one puts it in the launcher for good, from where it behaves like
/// any other entry. Everything else here is what it always was - change the
/// icon, or a folder's color.
Future<void> showPinnedQuickActions(
  BuildContext context,
  LauncherEntry entry,
) async {
  final s = AppStrings(LocaleController.instance.value);

  final action = await showDialog<_QuickAction>(
    context: context,
    builder: (context) => _QuickActionsDialog(entry: entry, s: s),
  );
  if (action == null || !context.mounted) return;

  switch (action) {
    // Deliberately run after the dialog is gone: both of these put another
    // window on top (the gallery picker, the color grid), and stacking them
    // over a dialog that is about to close reads as a glitch.
    case _QuickAction.changeIcon:
      if (entry.isFolder) {
        await _pickFolderColor(context, entry.folder!, s);
      } else if (entry.isWebApp) {
        await WebAppsController.instance.pickIcon(entry.webApp!.id);
      } else {
        // Built-ins and saved shortcuts have no package name, so they go
        // into the same override store under their own key - which is what
        // [LauncherEntry.customIcon] reads them back out of.
        await AppOverridesController.instance.pickIcon(entry.key);
      }
    case _QuickAction.removeShortcut:
      await SavedShortcutsController.instance.remove(entry.shortcut!.id);
  }
}

/// What the dialog hands back for the caller to run once it has closed.
enum _QuickAction { changeIcon, removeShortcut }

class _QuickActionsDialog extends StatefulWidget {
  const _QuickActionsDialog({required this.entry, required this.s});

  final LauncherEntry entry;
  final AppStrings s;

  @override
  State<_QuickActionsDialog> createState() => _QuickActionsDialogState();
}

class _QuickActionsDialogState extends State<_QuickActionsDialog> {
  /// Null while Android is still being asked. Told apart from "none": one is
  /// a spinner, the other is a sentence.
  List<AppShortcut>? _shortcuts;

  /// False when Android won't hand out shortcuts at all - on Android 7.0 and
  /// older, or while another app is the home app.
  bool _available = true;

  @override
  void initState() {
    super.initState();
    _loadShortcuts();
  }

  /// Only an installed app publishes shortcuts. A web app, a folder, one of
  /// the launcher's own screens and an already saved shortcut have none, so
  /// they never wait for an answer either.
  Future<void> _loadShortcuts() async {
    final package = widget.entry.app?.packageName;
    if (package == null) {
      setState(() => _shortcuts = const []);
      return;
    }
    final available = await AppShortcuts.available();
    final shortcuts = available
        ? await AppShortcuts.list(package)
        : const <AppShortcut>[];
    if (!mounted) return;
    setState(() {
      _available = available;
      _shortcuts = shortcuts;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final entry = widget.entry;
    final isFolder = entry.isFolder;

    return SimpleDialog(
      title: Text(entry.name),
      children: [
        ..._shortcutSection(),
        SimpleDialogOption(
          onPressed: () => Navigator.of(context).pop(_QuickAction.changeIcon),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              isFolder ? Icons.palette_outlined : Icons.image_outlined,
            ),
            title: Text(isFolder ? s.folderColor : s.changeIcon),
          ),
        ),
        // Only on the saved shortcut itself, not on the app it came from:
        // removing it there would be a different thing (unsaving something
        // you are not looking at) wearing the same words.
        if (entry.isShortcut)
          SimpleDialogOption(
            onPressed: () =>
                Navigator.of(context).pop(_QuickAction.removeShortcut),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.link_off),
              title: Text(s.removeAppShortcut),
            ),
          ),
      ],
    );
  }

  List<Widget> _shortcutSection() {
    final s = widget.s;
    final package = widget.entry.app?.packageName;
    if (package == null) return const [];

    final shortcuts = _shortcuts;
    if (shortcuts == null) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ];
    }

    // The two quiet cases. Both are a sentence rather than an empty gap,
    // because "nothing here" and "this launcher may not ask" look identical
    // otherwise, and only one of them is fixable.
    if (shortcuts.isEmpty) {
      return [
        _note(!_available ? s.appShortcutsNeedHomeApp : s.noAppShortcuts),
        const Divider(height: 1),
      ];
    }

    return [
      for (final shortcut in shortcuts)
        _ShortcutRow(
          shortcut: shortcut,
          s: s,
          onLaunch: () => _launch(shortcut),
          onKeep: () => _keep(shortcut),
        ),
      _note(s.appShortcutKeptHint),
      const Divider(height: 1),
    ];
  }

  Widget _note(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  /// Closes first and reports only a failure: the shortcut coming up in
  /// front speaks for itself, and a dialog left standing over the app that
  /// just opened would have to be dismissed by hand.
  Future<void> _launch(AppShortcut shortcut) async {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    final started = await AppShortcuts.launch(shortcut.package, shortcut.id);
    if (started) return;
    messenger.showSnackBar(
      SnackBar(content: Text(widget.s.appShortcutFailed)),
    );
  }

  /// Keeps the dialog open: an app's shortcuts are usually kept two or three
  /// at a time, and closing after each one would mean a long press per chat.
  Future<void> _keep(AppShortcut shortcut) async {
    final messenger = ScaffoldMessenger.of(context);
    await SavedShortcutsController.instance.add(shortcut);
    if (!mounted) return;
    // The row redraws as kept off the controller's own state, so this is
    // only about the confirmation.
    setState(() {});
    messenger.showSnackBar(
      SnackBar(content: Text(widget.s.appShortcutKept(shortcut.label))),
    );
  }
}

/// One shortcut: tap the row to start it, tap the button to keep it.
class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({
    required this.shortcut,
    required this.s,
    required this.onLaunch,
    required this.onKeep,
  });

  final AppShortcut shortcut;
  final AppStrings s;
  final VoidCallback onLaunch;
  final VoidCallback onKeep;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<SavedShortcut>>(
      valueListenable: SavedShortcutsController.instance,
      builder: (context, saved, child) {
        final kept =
            SavedShortcutsController.instance.bySource(
              shortcut.package,
              shortcut.id,
            ) !=
            null;
        return ListTile(
          leading: _icon(),
          title: Text(
            shortcut.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: onLaunch,
          trailing: IconButton(
            icon: Icon(kept ? Icons.bookmark : Icons.bookmark_border),
            tooltip: kept ? s.appShortcutAlreadyKept : s.keepAppShortcut,
            onPressed: kept ? null : onKeep,
          ),
        );
      },
    );
  }

  Widget _icon() {
    final file = shortcut.iconFile;
    if (file == null) return const Icon(Icons.arrow_outward, size: 32);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.file(
        file,
        width: 32,
        height: 32,
        fit: BoxFit.cover,
        // The file lives in the cache directory, which Android empties
        // whenever it is short of space - between two frames, if it likes.
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.arrow_outward, size: 32),
      ),
    );
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
