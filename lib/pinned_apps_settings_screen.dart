import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';

import 'app_icon.dart';
import 'app_overrides_controller.dart';
import 'app_strings.dart';
import 'locale_controller.dart';
import 'pinned_apps_controller.dart';

class PinnedAppsSettingsScreen extends StatefulWidget {
  const PinnedAppsSettingsScreen({super.key});

  @override
  State<PinnedAppsSettingsScreen> createState() =>
      _PinnedAppsSettingsScreenState();
}

class _PinnedAppsSettingsScreenState extends State<PinnedAppsSettingsScreen> {
  List<AppInfo> _apps = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  Future<void> _loadApps() async {
    final apps = await InstalledApps.getInstalledApps(
      excludeSystemApps: false,
      excludeNonLaunchableApps: true,
      withIcon: true,
    );
    apps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (!mounted) return;
    setState(() {
      _apps = apps;
      _loaded = true;
    });
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
              body: !_loaded
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: _apps.length,
                      itemBuilder: (context, index) {
                        final app = _apps[index];
                        final isPinned = pinned.contains(app.packageName);
                        return CheckboxListTile(
                          value: isPinned,
                          // Greyed out once the limit is hit, except for the
                          // ones already pinned so they stay removable.
                          onChanged:
                              !isPinned && PinnedAppsController.instance.isFull
                              ? null
                              : (_) async {
                                  final ok = await PinnedAppsController.instance
                                      .toggle(app.packageName);
                                  if (!ok && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(s.pinnedAppsFull),
                                      ),
                                    );
                                  }
                                },
                          secondary: AppIcon(app: app, size: 36),
                          title: Text(
                            AppOverridesController.instance.nameFor(
                              app.packageName,
                              app.name,
                            ),
                          ),
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
