import 'package:flutter/material.dart';

import 'app_icon.dart';
import 'app_strings.dart';
import 'color_swatch_picker.dart';
import 'design_tokens.dart';
import 'design_widgets.dart';
import 'launcher_entries_controller.dart';
import 'launcher_entry.dart';
import 'locale_controller.dart';
import 'notification_badges_controller.dart';
import 'pinned_apps_controller.dart';

class PinnedAppsSettingsScreen extends StatelessWidget {
  const PinnedAppsSettingsScreen({super.key});

  /// Folders, web apps and the launcher's own screens first: there are only
  /// a handful of them and they'd be tedious to find among hundreds of
  /// packages otherwise.
  List<LauncherEntry> _entries() {
    final all = LauncherEntriesController.instance.entries;
    return [
      for (final entry in all)
        if (entry.isFolder) entry,
      for (final entry in all)
        if (entry.isWebApp) entry,
      for (final entry in all)
        if (entry.isBuiltIn) entry,
      for (final entry in all)
        if (!entry.isFolder && !entry.isWebApp && !entry.isBuiltIn) entry,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LocaleController.instance,
      builder: (context, language, child) {
        final s = AppStrings(language);
        return ValueListenableBuilder<List<String>>(
          valueListenable: PinnedAppsController.instance,
          builder: (context, pinned, child) {
            return ListenableBuilder(
              listenable: LauncherEntriesController.instance,
              builder: (context, child) {
                final entries = _entries();
                return Scaffold(
                  appBar: AppBar(
                    title: Text(s.pinnedApps),
                    bottom: PreferredSize(
                      preferredSize: const Size.fromHeight(28),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          s.pinnedAppsSubtitle(
                            pinned.length,
                            PinnedAppsController.maxPinned,
                          ),
                          style: TextStyle(
                            fontSize: context.design.typeLabel,
                            color: context.design.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  body: !LauncherEntriesController.instance.isLoaded
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          // The settings for the row of icons on top, then
                          // the app picker - +1 for them, offset by 1 in
                          // itemBuilder below.
                          itemCount: entries.length + 1,
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _LeftMarginSlider(s: s),
                                  _BadgeSection(s: s),
                                  const Divider(height: 32),
                                ],
                              );
                            }
                            final entry = entries[index - 1];
                            final isPinned = pinned.contains(entry.key);
                            return CheckboxListTile(
                              value: isPinned,
                              // Greyed out once the limit is hit, except for
                              // the ones already pinned so they stay
                              // removable.
                              onChanged:
                                  !isPinned &&
                                      PinnedAppsController.instance.isFull
                                  ? null
                                  : (_) async {
                                      final ok = await PinnedAppsController
                                          .instance
                                          .toggle(entry.key);
                                      if (!ok && context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(s.pinnedAppsFull),
                                          ),
                                        );
                                      }
                                    },
                              secondary: AppIcon(entry: entry, size: 36),
                              title: Text(entry.name),
                              subtitle: entry.isWebApp
                                  ? Text(
                                      entry.webApp!.url,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                  : null,
                            );
                          },
                        ),
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Controls how far the pinned apps sit from the left edge of the screen -
/// no longer tied to the clock's own width.
class _LeftMarginSlider extends StatelessWidget {
  const _LeftMarginSlider({required this.s});

  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: PinnedAppsLayoutController.instance,
      builder: (context, margin, child) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.pinnedAppsLeftMargin(margin.round()),
                style: TextStyle(
                  fontSize: context.design.typeLabel,
                  fontWeight: FontWeight.bold,
                  color: context.design.textSecondary,
                ),
              ),
              Slider(
                value: margin,
                min: 0,
                max: 200,
                divisions: 40,
                onChanged: (value) =>
                    PinnedAppsLayoutController.instance.setLeftMargin(value),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Picks what a pinned app shows while notifications wait in it, and - once
/// that is anything other than "nothing" - offers the way to the permission
/// it needs.
class _BadgeSection extends StatefulWidget {
  const _BadgeSection({required this.s});

  final AppStrings s;

  @override
  State<_BadgeSection> createState() => _BadgeSectionState();
}

class _BadgeSectionState extends State<_BadgeSection>
    with WidgetsBindingObserver {
  bool _granted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    PinnedBadgeController.instance.load();
    _refreshPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Notification access is granted in Android's own settings, so coming
  /// back from there is the only moment this answer can have changed.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshPermission();
  }

  Future<void> _refreshPermission() async {
    final granted = await NotificationCounts.hasPermission();
    if (!mounted || granted == _granted) return;
    setState(() => _granted = granted);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return ValueListenableBuilder<PinnedBadgeSettings>(
      valueListenable: PinnedBadgeController.instance,
      builder: (context, badge, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettingsHeading(s.pinnedBadges),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                s.pinnedBadgesHint,
                style: TextStyle(color: context.design.textSecondary),
              ),
            ),
            RadioGroup<PinnedBadgeStyle>(
              groupValue: badge.style,
              onChanged: (value) {
                if (value != null) {
                  PinnedBadgeController.instance.update(
                    badge.copyWith(style: value),
                  );
                }
              },
              child: Column(
                children: [
                  RadioListTile<PinnedBadgeStyle>(
                    value: PinnedBadgeStyle.none,
                    title: Text(s.pinnedBadgesOff),
                    subtitle: Text(s.pinnedBadgesOffHint),
                  ),
                  RadioListTile<PinnedBadgeStyle>(
                    value: PinnedBadgeStyle.dot,
                    title: Text(s.pinnedBadgesDot),
                    subtitle: Text(s.pinnedBadgesDotHint),
                    secondary: _BadgePreview(color: badge.color, label: null),
                  ),
                  RadioListTile<PinnedBadgeStyle>(
                    value: PinnedBadgeStyle.count,
                    title: Text(s.pinnedBadgesCount),
                    subtitle: Text(s.pinnedBadgesCountHint),
                    secondary: _BadgePreview(color: badge.color, label: '3'),
                  ),
                ],
              ),
            ),
            // Nothing to color while nothing is drawn - and the two previews
            // above follow the pick, so the choice is visible where it
            // matters rather than only on the swatch.
            if (badge.style != PinnedBadgeStyle.none)
              Padding(
                padding: context.design.pagePadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FieldLabel(s.pinnedBadgesColor),
                    ColorSwatchPicker(
                      s: s,
                      selectedIndex: badge.colorIndex,
                      onSelected: (index) =>
                          PinnedBadgeController.instance.update(
                            badge.copyWith(colorIndex: index),
                          ),
                    ),
                  ],
                ),
              ),
            // Only once a badge is actually wanted: before that the
            // permission has nothing to do with anything on screen.
            if (badge.style != PinnedBadgeStyle.none)
              ListTile(
                leading: Icon(
                  _granted ? Icons.check_circle_outline : Icons.lock_outline,
                ),
                title: Text(
                  _granted
                      ? s.pinnedBadgesPermissionGranted
                      : s.pinnedBadgesPermission,
                ),
                subtitle: _granted
                    ? null
                    : Text(s.pinnedBadgesPermissionHint),
                trailing: _granted ? null : const Icon(Icons.open_in_new),
                onTap: _granted ? null : NotificationCounts.requestPermission,
              ),
          ],
        );
      },
    );
  }
}

/// The badge itself, next to the option that picks it - a dot or a number,
/// so the two are told apart by looking rather than by reading.
class _BadgePreview extends StatelessWidget {
  const _BadgePreview({required this.color, required this.label});

  final Color color;

  /// Null draws the plain dot.
  final String? label;

  @override
  Widget build(BuildContext context) {
    if (label == null) {
      return Container(
        width: 14,
        height: 14,
        margin: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
    }
    return Container(
      width: 20,
      height: 20,
      margin: const EdgeInsets.symmetric(vertical: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label!,
        style: TextStyle(
          color: DesignTokens.inkOn(color),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          height: 1,
        ),
      ),
    );
  }
}
