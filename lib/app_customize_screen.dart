import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';

import 'app_icon.dart';
import 'app_overrides_controller.dart';
import 'app_strings.dart';
import 'launcher_entries_controller.dart';
import 'launcher_entry.dart';
import 'locale_controller.dart';
import 'text_prompt_dialog.dart';
import 'web_apps_controller.dart';

/// Lists everything that appears in the app list - installed apps and saved
/// web apps - and lets each one be given its own icon and name, or an
/// installed app be uninstalled. Changes show up everywhere the entry is
/// used (app list and pinned apps).
class AppCustomizeScreen extends StatefulWidget {
  const AppCustomizeScreen({super.key});

  @override
  State<AppCustomizeScreen> createState() => _AppCustomizeScreenState();
}

class _AppCustomizeScreenState extends State<AppCustomizeScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // The system's own uninstall confirmation runs in front of this screen -
  // by the time the app is foregrounded again, whatever the user decided has
  // already happened, so this is the moment to find out whether the app is
  // still there.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      LauncherEntriesController.instance.load();
    }
  }
  /// Web apps first: there are only a handful of them and they'd be tedious
  /// to find among hundreds of packages otherwise. Folders are left out -
  /// they get their own screen, where their contents are editable too.
  List<LauncherEntry> _entries() {
    final all = LauncherEntriesController.instance.entries;
    return [
      for (final entry in all)
        if (entry.isWebApp) entry,
      for (final entry in all)
        if (entry.app != null) entry,
    ];
  }

  Future<void> _openOptions(LauncherEntry entry, AppStrings s) async {
    final hasOverride =
        entry.app != null &&
        AppOverridesController.instance.forPackage(entry.app!.packageName) !=
            null;

    final choice = await showDialog<String>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: Text(entry.name),
          children: [
            _option(context, Icons.image_outlined, s.changeIcon, 'icon'),
            _option(context, Icons.edit_outlined, s.changeName, 'name'),
            // A web app is defined by its address, so that's editable here
            // too; an installed app instead offers to drop its changes.
            if (entry.isWebApp)
              _option(context, Icons.link, s.changeUrl, 'url'),
            if (entry.isWebApp)
              _option(context, Icons.delete_outline, s.remove, 'remove'),
            if (hasOverride)
              _option(context, Icons.restore, s.resetApp, 'reset'),
            if (entry.app != null)
              _option(
                context,
                Icons.delete_forever_outlined,
                s.uninstallApp,
                'uninstall',
              ),
          ],
        );
      },
    );

    if (!mounted || choice == null) return;
    if (entry.isWebApp) {
      await _applyToWebApp(entry.webApp!, choice, s);
    } else {
      await _applyToApp(entry.app!, choice, s);
    }
  }

  Future<void> _applyToApp(AppInfo app, String choice, AppStrings s) async {
    final controller = AppOverridesController.instance;
    switch (choice) {
      case 'icon':
        await controller.pickIcon(app.packageName);
      case 'name':
        final newName = await _promptText(
          title: s.changeName,
          label: s.nameLabel,
          initialValue: controller.nameFor(app.packageName, app.name),
          s: s,
        );
        if (newName == null) return;
        // Clearing the field (or typing the original) means "use the system
        // name again".
        await controller.setName(
          app.packageName,
          newName.trim() == app.name ? null : newName,
        );
      case 'reset':
        await controller.reset(app.packageName);
      case 'uninstall':
        // Fires the system's own uninstall confirmation; whatever the user
        // decides there is picked up in didChangeAppLifecycleState once this
        // screen is foregrounded again, not here.
        final started = await InstalledApps.uninstallApp(app.packageName);
        if (started != true && mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(s.uninstallFailed)));
        }
    }
  }

  Future<void> _applyToWebApp(
    WebApp webApp,
    String choice,
    AppStrings s,
  ) async {
    final controller = WebAppsController.instance;
    switch (choice) {
      case 'icon':
        await controller.pickIcon(webApp.id);
      case 'name':
        final name = await _promptText(
          title: s.changeName,
          label: s.nameLabel,
          initialValue: webApp.name,
          s: s,
        );
        // A web app has no system name to fall back on, so an empty one is
        // simply ignored.
        if (name != null && name.trim().isNotEmpty) {
          await controller.rename(webApp.id, name);
        }
      case 'url':
        final url = await _promptText(
          title: s.changeUrl,
          label: s.urlLabel,
          initialValue: webApp.url,
          s: s,
        );
        if (url != null && url.trim().isNotEmpty) {
          await controller.setUrl(webApp.id, url);
        }
      case 'remove':
        await controller.remove(webApp.id);
    }
  }

  Widget _option(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return SimpleDialogOption(
      onPressed: () => Navigator.of(context).pop(value),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon),
        title: Text(label),
      ),
    );
  }

  Future<String?> _promptText({
    required String title,
    required String label,
    required String initialValue,
    required AppStrings s,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => TextPromptDialog(
        title: title,
        label: label,
        initialValue: initialValue,
        s: s,
      ),
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
          body: ListenableBuilder(
            listenable: LauncherEntriesController.instance,
            builder: (context, child) {
              if (!LauncherEntriesController.instance.isLoaded) {
                return const Center(child: CircularProgressIndicator());
              }
              final entries = _entries();
              return ListView.builder(
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return ListTile(
                    leading: AppIcon(entry: entry, size: 36),
                    title: Text(entry.name),
                    // Web apps show their address; renamed apps show the
                    // original name, so they stay findable.
                    subtitle: _subtitleFor(entry),
                    onTap: () => _openOptions(entry, s),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget? _subtitleFor(LauncherEntry entry) {
    final text = entry.isWebApp
        ? entry.webApp!.url
        : (entry.name == entry.app!.name ? null : entry.app!.name);
    if (text == null) return null;
    return Text(text, maxLines: 1, overflow: TextOverflow.ellipsis);
  }
}
