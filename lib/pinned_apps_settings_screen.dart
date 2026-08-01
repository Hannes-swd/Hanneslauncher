import 'package:flutter/material.dart';

import 'app_icon.dart';
import 'app_strings.dart';
import 'launcher_entries_controller.dart';
import 'launcher_entry.dart';
import 'locale_controller.dart';
import 'pinned_apps_controller.dart';

class PinnedAppsSettingsScreen extends StatelessWidget {
  const PinnedAppsSettingsScreen({super.key});

  /// Folders and web apps first: there are only a handful of them and they'd
  /// be tedious to find among hundreds of packages otherwise.
  List<LauncherEntry> _entries() {
    final all = LauncherEntriesController.instance.entries;
    return [
      for (final entry in all)
        if (entry.isFolder) entry,
      for (final entry in all)
        if (entry.isWebApp) entry,
      for (final entry in all)
        if (!entry.isFolder && !entry.isWebApp) entry,
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
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    ),
                  ),
                  body: !LauncherEntriesController.instance.isLoaded
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          // The margin slider on top, then the app picker -
                          // +1 for it, offset by 1 in itemBuilder below.
                          itemCount: entries.length + 1,
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return _LeftMarginSlider(s: s);
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
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
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
