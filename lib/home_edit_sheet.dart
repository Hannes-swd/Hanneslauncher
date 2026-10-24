import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_dialogs.dart';
import 'app_icon.dart';
import 'app_strings.dart';
import 'clock_settings_screen.dart';
import 'design_tokens.dart';
import 'entry_search_field.dart';
import 'fluid_motion.dart';
import 'haptics.dart';
import 'intro_tutorial_controller.dart';
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
/// order, making a web app, the clock, the wallpaper. The settings pages are
/// all still there - this is the short way to the parts that are asked for
/// most.
///
/// Laid out the way the home screen itself is: the pinned apps are a row of
/// round icons, in the order they stand in, with a "+" at the end of it -
/// rather than a settings list of rows that took up half the sheet to say
/// the same thing. Held, an icon lifts and can be carried to another place;
/// the small minus on it unpins it. The sheet is as tall as what is in it.
Future<void> showHomeEditSheet(BuildContext context) async {
  // The one confirmation the press gets: the sheet has not drawn yet, so
  // without this the only sign that the press was long enough comes a
  // frame later.
  Haptics.fire(HapticEvent.grab);
  IntroTutorialController.instance.noteHomeEditOpened();
  await showAppBottomSheet<void>(
    context: context,
    // Lets the sheet size itself to its contents instead of the fixed share
    // of the screen a sheet gets otherwise.
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const _HomeEditSheet(),
  );
  IntroTutorialController.instance.noteHomeEditClosed();
}

class _HomeEditSheet extends StatelessWidget {
  const _HomeEditSheet();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LocaleController.instance,
      builder: (context, language, child) {
        final s = AppStrings(language);
        final design = context.design;
        final gap = SizedBox(width: design.spaceSm);
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              design.spaceLg,
              0,
              design.spaceLg,
              design.spaceMd,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(s: s),
                SizedBox(height: design.spaceMd),
                _PinnedStrip(s: s),
                SizedBox(height: design.spaceLg),
                // The four things asked for most, as tiles: one tap each,
                // and readable at a glance rather than row by row.
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _ShortcutTile(
                          icon: Icons.access_time,
                          label: s.homeEditClock,
                          onTap: () =>
                              _push(context, const ClockSettingsScreen()),
                        ),
                      ),
                      gap,
                      Expanded(
                        child: _ShortcutTile(
                          icon: Icons.wallpaper,
                          label: s.homeEditWallpaper,
                          onTap: () =>
                              _push(context, const WallpaperSettingsScreen()),
                        ),
                      ),
                      gap,
                      Expanded(
                        child: ListenableBuilder(
                          listenable: PinnedAppsController.instance,
                          builder: (context, child) => _ShortcutTile(
                            icon: Icons.language,
                            // Short, so all four tiles keep one line.
                            label: s.homeEditWebApp,
                            // It lands on the home screen, so it needs a free
                            // place there.
                            onTap: PinnedAppsController.instance.isFull
                                ? null
                                : () => _newWebApp(context, s),
                          ),
                        ),
                      ),
                      gap,
                      Expanded(
                        child: _ShortcutTile(
                          icon: Icons.settings_outlined,
                          label: s.settings,
                          onTap: () => _push(context, const SettingsScreen()),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: design.spaceSm),
                // The finer settings for the row - its margin, the badges -
                // are wanted far less often, so they stay one step further
                // in.
                TextButton.icon(
                  icon: const Icon(Icons.tune, size: 18),
                  label: Text(s.homeEditMore),
                  onPressed: () =>
                      _push(context, const PinnedAppsSettingsScreen()),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The title, how many places are taken, and what can be done with the row
/// below it.
class _Header extends StatelessWidget {
  const _Header({required this.s});

  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    return ListenableBuilder(
      listenable: PinnedAppsController.instance,
      builder: (context, child) {
        final count = PinnedAppsController.instance.value.length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    s.editHome,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                // A count rather than a heading: the one number worth
                // knowing here is how many places are left.
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: design.spaceSm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: design.accentWash,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '$count/${PinnedAppsController.maxPinned}',
                    style: TextStyle(
                      color: design.accent,
                      fontSize: design.typeCaption,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              count == 0 ? s.noPinnedYet : s.homeEditReorderHint,
              style: TextStyle(
                color: design.textSecondary,
                fontSize: design.typeCaption,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The pinned apps as they stand on the home screen, side by side, with the
/// "+" for another one at the end.
class _PinnedStrip extends StatelessWidget {
  const _PinnedStrip({required this.s});

  final AppStrings s;

  @override
  Widget build(BuildContext context) {
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
        // Every place plus the "+" side by side on any phone, without the
        // row ever having to scroll: the icons give up a little size on a
        // narrow screen rather than some of them going off its edge.
        return LayoutBuilder(
          builder: (context, constraints) {
            final slot = math.min(
              _Bubble.maxSlot,
              constraints.maxWidth / (PinnedAppsController.maxPinned + 1),
            );
            return _strip(context, pinned, keys, full, slot);
          },
        );
      },
    );
  }

  Widget _strip(
    BuildContext context,
    List<LauncherEntry> pinned,
    List<String> keys,
    bool full,
    double slot,
  ) {
    return SizedBox(
      height: _Bubble.heightFor(slot),
      child: Row(
        children: [
          Flexible(
            child: ReorderableListView(
              scrollDirection: Axis.horizontal,
              shrinkWrap: true,
              buildDefaultDragHandles: false,
              // Lifted rather than shadowed: the icon in the hand grows
              // a little, the way the icons on the home screen give
              // under a finger.
              proxyDecorator: (child, index, animation) => Material(
                type: MaterialType.transparency,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 1, end: 1.12).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutBack,
                    ),
                  ),
                  child: child,
                ),
              ),
              onReorderStart: (_) => Haptics.fire(HapticEvent.grab),
              onReorderEnd: (_) => Haptics.fire(HapticEvent.snap),
              onReorderItem: (oldIndex, newIndex) {
                final order = [...pinned];
                order.insert(newIndex, order.removeAt(oldIndex));
                // Pins that no longer resolve (an uninstalled app) are
                // not shown, so they ride along at the end rather than
                // being dropped by a reorder.
                PinnedAppsController.instance.restore([
                  for (final entry in order) entry.key,
                  for (final key in keys)
                    if (!order.any((entry) => entry.key == key)) key,
                ]);
              },
              children: [
                for (var i = 0; i < pinned.length; i++)
                  ReorderableDelayedDragStartListener(
                    key: ValueKey(pinned[i].key),
                    index: i,
                    child: _PinnedBubble(
                      entry: pinned[i],
                      s: s,
                      slot: slot,
                    ),
                  ),
              ],
            ),
          ),
          _Bubble(
            label: s.homeEditAdd,
            slot: slot,
            tooltip: full ? s.pinnedAppsFull : s.addAppSubtitle,
            onTap: full ? null : () => _pickApps(context, s),
            accent: true,
            child: Icon(Icons.add, color: context.design.accent),
          ),
        ],
      ),
    );
  }
}

/// One pinned entry: tap to change it, hold to move it, minus to unpin.
class _PinnedBubble extends StatelessWidget {
  const _PinnedBubble({
    required this.entry,
    required this.s,
    required this.slot,
  });

  final LauncherEntry entry;
  final AppStrings s;
  final double slot;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final circle = _Bubble.circleFor(slot);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Builder(
          builder: (context) => _Bubble(
            label: entry.name,
            slot: slot,
            // A web app has a name, an address and a browser to change;
            // anything else only has its icon (or a folder its color).
            onTap: () => entry.isWebApp
                ? WebAppsSettingsScreen.openOptions(context, s, entry.webApp!)
                : showPinnedQuickActions(context, entry),
            child: AppIcon(entry: entry, size: circle * 0.6),
          ),
        ),
        // On the circle's upper right, wherever the circle ends up.
        Positioned(
          top: 0,
          right: (slot - circle) / 2 - 10,
          child: Tooltip(
            message: s.removeFromHome,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Haptics.fire(HapticEvent.selection);
                PinnedAppsController.instance.toggle(entry.key);
              },
              // A bigger target than the dot that is drawn: a 20 px circle
              // is a hard thing to hit with a thumb.
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: design.textPrimary,
                    shape: BoxShape.circle,
                    border: Border.all(color: design.surface, width: 2),
                  ),
                  child: Icon(Icons.remove, size: 12, color: design.surface),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A round icon with its name under it - a pinned app, or the "+".
class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.label,
    required this.slot,
    required this.child,
    this.onTap,
    this.tooltip,
    this.accent = false,
  });

  /// The widest a place in the row gets; narrower when the phone is.
  static const double maxSlot = 72;

  /// The circle in a place [slot] wide, leaving room for the next one.
  static double circleFor(double slot) => math.min(56, slot - 10);

  /// Circle, the space above and below it, and one line of name.
  static double heightFor(double slot) => circleFor(slot) + 34;

  final String label;

  /// How wide this place in the row is - see [maxSlot].
  final double slot;
  final Widget child;
  final VoidCallback? onTap;
  final String? tooltip;

  /// The "+": tinted with the accent, so it reads as the thing to press
  /// rather than as one more app.
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final enabled = onTap != null;
    final circle = circleFor(slot);
    Widget bubble = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: slot,
        child: Column(
          children: [
            const SizedBox(height: 8),
            PressScale(
              child: Container(
                width: circle,
                height: circle,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent ? design.accentWash : design.fillSubtle,
                  shape: BoxShape.circle,
                  border: accent
                      ? Border.all(
                          color: design.accent.withValues(alpha: 0.5),
                          width: 1.5,
                        )
                      : null,
                ),
                child: child,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: design.typeCaption,
                color: accent ? design.accent : design.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
    if (!enabled) bubble = Opacity(opacity: 0.4, child: bubble);
    if (tooltip != null) bubble = Tooltip(message: tooltip!, child: bubble);
    return bubble;
  }
}

/// One of the four shortcuts under the row: an icon and a word on a soft
/// tile, the whole tile the target.
class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  /// Two words may take two lines; a single long one - "Einstellungen" on a
  /// narrow tile - is set a little smaller instead of being broken in the
  /// middle.
  Widget _label(DesignTokens design) {
    final text = Text(
      label,
      maxLines: 2,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: design.typeCaption,
        color: design.textPrimary,
      ),
    );
    if (label.contains(' ')) return text;
    return FittedBox(fit: BoxFit.scaleDown, child: text);
  }

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final radius = BorderRadius.circular(design.radiusMedium);
    return Opacity(
      opacity: onTap == null ? 0.4 : 1,
      child: Material(
        color: design.fillSubtle,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 4,
              vertical: design.spaceMd,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: design.accent),
                const SizedBox(height: 6),
                _label(design),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pushed over the sheet rather than replacing it, so backing out of a
/// settings page lands where the user left off.
void _push(BuildContext context, Widget page) {
  Navigator.of(context).push(MaterialPageRoute(builder: (context) => page));
}

Future<void> _pickApps(BuildContext context, AppStrings s) {
  return showAppBottomSheet<void>(
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
