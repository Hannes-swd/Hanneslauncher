import 'package:flutter/material.dart';

import 'app_icon.dart';
import 'app_strings.dart';
import 'clock_settings_screen.dart';
import 'design_tokens.dart';
import 'design_widgets.dart';
import 'entry_search_field.dart';
import 'haptics.dart';
import 'launcher_entries_controller.dart';
import 'launcher_entry.dart';
import 'locale_controller.dart';
import 'pinned_apps_controller.dart';
import 'pinned_apps_settings_screen.dart';
import 'pinned_quick_actions.dart';
import 'settings_screen.dart';
import 'wallpaper_settings_screen.dart';
import 'web_apps_controller.dart';
import 'web_apps_settings_screen.dart';

/// Holding the home screen anywhere that is not an icon.
///
/// Everything the home screen is made of can be changed from here without
/// knowing which settings page it lives on: which apps are pinned and in what
/// order, making or changing a web app, the clock, the wallpaper. The settings
/// pages are all still there - this is the short way to the parts that are
/// asked for most.
Future<void> showHomeEditSheet(BuildContext context) {
  // The one confirmation the press gets: the sheet has not drawn yet, so
  // without this the only sign that the press was long enough comes a
  // frame later.
  Haptics.fire(HapticEvent.grab);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) =>
          _HomeEditSheet(scrollController: scrollController),
    ),
  );
}

class _HomeEditSheet extends StatelessWidget {
  const _HomeEditSheet({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LocaleController.instance,
      builder: (context, language, child) {
        final s = AppStrings(language);
        return ListenableBuilder(
          listenable: Listenable.merge([
            PinnedAppsController.instance,
            LauncherEntriesController.instance,
          ]),
          builder: (context, child) {
            final keys = PinnedAppsController.instance.value;
            final pinned = [
              for (final key in keys)
                if (LauncherEntriesController.instance.byKey(key) != null)
                  LauncherEntriesController.instance.byKey(key)!,
            ];
            final full = PinnedAppsController.instance.isFull;
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    s.editHome,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                SettingsHeading(
                  '${s.pinnedApps} (${pinned.length}/'
                  '${PinnedAppsController.maxPinned})',
                ),
                if (pinned.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      s.noPinnedYet,
                      style: TextStyle(color: context.design.textSecondary),
                    ),
                  )
                else
                  ReorderableListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    onReorderItem: (oldIndex, newIndex) {
                      final order = [...pinned];
                      order.insert(newIndex, order.removeAt(oldIndex));
                      // Pins that no longer resolve (an uninstalled app)
                      // are not shown, so they ride along at the end rather
                      // than being dropped by a reorder.
                      PinnedAppsController.instance.restore([
                        for (final entry in order) entry.key,
                        for (final key in keys)
                          if (!order.any((entry) => entry.key == key)) key,
                      ]);
                    },
                    children: [
                      for (var i = 0; i < pinned.length; i++)
                        _PinnedRow(
                          key: ValueKey(pinned[i].key),
                          entry: pinned[i],
                          index: i,
                          s: s,
                        ),
                    ],
                  ),
                ListTile(
                  leading: const Icon(Icons.add),
                  title: Text(s.addApp),
                  subtitle: Text(full ? s.pinnedAppsFull : s.addAppSubtitle),
                  enabled: !full,
                  onTap: () => _pickApps(context, s),
                ),
                ListTile(
                  leading: const Icon(Icons.language),
                  title: Text(s.newWebAppAndPin),
                  enabled: !full,
                  onTap: () => _newWebApp(context, s),
                ),
                const Divider(height: 32),
                ListTile(
                  leading: const Icon(Icons.access_time),
                  title: Text(s.homeEditClock),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _push(context, const ClockSettingsScreen()),
                ),
                ListTile(
                  leading: const Icon(Icons.wallpaper),
                  title: Text(s.homeEditWallpaper),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _push(context, const WallpaperSettingsScreen()),
                ),
                ListTile(
                  leading: const Icon(Icons.tune),
                  title: Text(s.homeEditMore),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      _push(context, const PinnedAppsSettingsScreen()),
                ),
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: Text(s.allSettings),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _push(context, const SettingsScreen()),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Pushed over the sheet rather than replacing it, so backing out of a
  /// settings page lands where the user left off.
  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => page));
  }

  Future<void> _pickApps(BuildContext context, AppStrings s) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) =>
            _AppPicker(scrollController: scrollController, s: s),
      ),
    );
  }

  /// Makes the web app and pins it in one go: it was asked for from the home
  /// screen, so the home screen is where it is expected to show up.
  Future<void> _newWebApp(BuildContext context, AppStrings s) async {
    final messenger = ScaffoldMessenger.of(context);
    final webApp = await WebAppsSettingsScreen.addWebApp(context, s);
    if (webApp == null) return;
    final pinned = await PinnedAppsController.instance.toggle(
      '$webAppIdPrefix${webApp.id}',
    );
    if (pinned) {
      messenger.showSnackBar(SnackBar(content: Text(s.webAppPinnedNote)));
    }
  }
}

/// One pinned entry: tap to change it, handle to move it, cross to unpin.
class _PinnedRow extends StatelessWidget {
  const _PinnedRow({
    super.key,
    required this.entry,
    required this.index,
    required this.s,
  });

  final LauncherEntry entry;
  final int index;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: AppIcon(entry: entry, size: 36),
      title: Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: entry.isWebApp
          ? Text(entry.webApp!.url, maxLines: 1, overflow: TextOverflow.ellipsis)
          : null,
      // A web app has a name, an address and a browser to change; anything
      // else only has its icon (or a folder its color).
      onTap: () => entry.isWebApp
          ? WebAppsSettingsScreen.openOptions(context, s, entry.webApp!)
          : showPinnedQuickActions(context, entry),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: s.removeFromHome,
            onPressed: () => PinnedAppsController.instance.toggle(entry.key),
          ),
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.drag_handle),
            ),
          ),
        ],
      ),
    );
  }
}

/// Everything that can be pinned, searchable, a tick for what is pinned
/// already. Stays open so several can be picked in one go.
class _AppPicker extends StatefulWidget {
  const _AppPicker({required this.scrollController, required this.s});

  final ScrollController scrollController;
  final AppStrings s;

  @override
  State<_AppPicker> createState() => _AppPickerState();
}

class _AppPickerState extends State<_AppPicker> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Folders, web apps and the launcher's own screens first - there are few
  /// of them and they would be tedious to find among hundreds of packages.
  List<LauncherEntry> _entries() {
    final all = LauncherEntriesController.instance.entries;
    return filterByName([
      for (final entry in all)
        if (entry.isFolder) entry,
      for (final entry in all)
        if (entry.isWebApp) entry,
      for (final entry in all)
        if (entry.isBuiltIn) entry,
      for (final entry in all)
        if (!entry.isFolder && !entry.isWebApp && !entry.isBuiltIn) entry,
    ], _search.text, (entry) => entry.name);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return ListenableBuilder(
      listenable: Listenable.merge([
        PinnedAppsController.instance,
        LauncherEntriesController.instance,
      ]),
      builder: (context, child) {
        final entries = _entries();
        final pinned = PinnedAppsController.instance.value;
        return Column(
          children: [
            EntrySearchField(
              controller: _search,
              s: s,
              onChanged: (_) => setState(() {}),
            ),
            Expanded(
              child: ListView.builder(
                controller: widget.scrollController,
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  final isPinned = pinned.contains(entry.key);
                  return CheckboxListTile(
                    value: isPinned,
                    // Greyed out once the limit is hit, except for what is
                    // pinned already, so it stays removable.
                    onChanged:
                        !isPinned && PinnedAppsController.instance.isFull
                        ? null
                        : (_) =>
                              PinnedAppsController.instance.toggle(entry.key),
                    secondary: AppIcon(entry: entry, size: 36),
                    title: Text(entry.name),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
