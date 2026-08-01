import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';

import 'app_icon.dart';
import 'app_overrides_controller.dart';
import 'app_strings.dart';
import 'locale_controller.dart';

/// Lists every installed app; tapping one offers to replace its icon or
/// rename it. Changes are stored per package and used everywhere the app
/// shows up (app list and pinned apps).
class AppCustomizeScreen extends StatefulWidget {
  const AppCustomizeScreen({super.key});

  @override
  State<AppCustomizeScreen> createState() => _AppCustomizeScreenState();
}

class _AppCustomizeScreenState extends State<AppCustomizeScreen> {
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

  Future<void> _openOptions(AppInfo app, AppStrings s) async {
    final controller = AppOverridesController.instance;
    final hasOverride = controller.forPackage(app.packageName) != null;

    final choice = await showDialog<String>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: Text(controller.nameFor(app.packageName, app.name)),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop('icon'),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.image_outlined),
                title: Text(s.changeIcon),
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop('name'),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.edit_outlined),
                title: Text(s.changeName),
              ),
            ),
            if (hasOverride)
              SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop('reset'),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.restore),
                  title: Text(s.resetApp),
                ),
              ),
          ],
        );
      },
    );

    if (!mounted || choice == null) return;
    switch (choice) {
      case 'icon':
        await controller.pickIcon(app.packageName);
      case 'name':
        await _renameApp(app, s);
      case 'reset':
        await controller.reset(app.packageName);
    }
  }

  Future<void> _renameApp(AppInfo app, AppStrings s) async {
    final controller = AppOverridesController.instance;
    final field = TextEditingController(
      text: controller.nameFor(app.packageName, app.name),
    );

    final newName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(s.changeName),
          content: TextField(
            controller: field,
            autofocus: true,
            decoration: InputDecoration(labelText: s.nameLabel),
            onSubmitted: (value) => Navigator.of(context).pop(value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(s.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(field.text),
              child: Text(s.save),
            ),
          ],
        );
      },
    );
    field.dispose();

    if (newName == null) return;
    // An empty field means "use the system name again".
    await controller.setName(
      app.packageName,
      newName.trim() == app.name ? null : newName,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LocaleController.instance,
      builder: (context, language, child) {
        final s = AppStrings(language);
        return Scaffold(
          appBar: AppBar(title: Text(s.customizeApps)),
          body: !_loaded
              ? const Center(child: CircularProgressIndicator())
              : ValueListenableBuilder<Map<String, AppOverride>>(
                  valueListenable: AppOverridesController.instance,
                  builder: (context, overrides, child) {
                    return ListView.builder(
                      itemCount: _apps.length,
                      itemBuilder: (context, index) {
                        final app = _apps[index];
                        final override = overrides[app.packageName];
                        final name = AppOverridesController.instance.nameFor(
                          app.packageName,
                          app.name,
                        );
                        return ListTile(
                          leading: AppIcon(app: app, size: 36),
                          title: Text(name),
                          // Only shown once something was customized, so the
                          // original name stays findable after a rename.
                          subtitle: override == null || name == app.name
                              ? null
                              : Text(app.name),
                          onTap: () => _openOptions(app, s),
                        );
                      },
                    );
                  },
                ),
        );
      },
    );
  }
}
