import 'package:flutter/material.dart';

import 'app_icon.dart';
import 'app_strings.dart';
import 'launcher_entry.dart';
import 'locale_controller.dart';
import 'text_prompt_dialog.dart';
import 'web_apps_controller.dart';

/// Manages the websites saved to the launcher. Anything added here shows up
/// in the app list under its letter and can be pinned to the home screen,
/// just like an installed app.
class WebAppsSettingsScreen extends StatelessWidget {
  const WebAppsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LocaleController.instance,
      builder: (context, language, child) {
        final s = AppStrings(language);
        return ValueListenableBuilder<List<WebApp>>(
          valueListenable: WebAppsController.instance,
          builder: (context, webApps, child) {
            return Scaffold(
              appBar: AppBar(title: Text(s.webApps)),
              floatingActionButton: FloatingActionButton.extended(
                onPressed: () => _addWebApp(context, s),
                icon: const Icon(Icons.add),
                label: Text(s.addWebApp),
              ),
              body: webApps.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        s.noWebApps,
                        style: const TextStyle(color: Colors.black54),
                      ),
                    )
                  : ListView.builder(
                      // Room at the bottom so the last row isn't hidden
                      // behind the floating button.
                      padding: const EdgeInsets.only(bottom: 88),
                      itemCount: webApps.length,
                      itemBuilder: (context, index) {
                        final webApp = webApps[index];
                        return ListTile(
                          leading: AppIcon(
                            entry: LauncherEntry.web(webApp),
                            size: 36,
                          ),
                          title: Text(webApp.name),
                          subtitle: Text(
                            webApp.url,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _openOptions(context, s, webApp),
                        );
                      },
                    ),
            );
          },
        );
      },
    );
  }

  Future<void> _addWebApp(BuildContext context, AppStrings s) async {
    final result = await _promptNameAndUrl(context, s);
    if (result == null) return;
    await WebAppsController.instance.add(
      name: result.name,
      url: result.url,
    );
  }

  Future<void> _openOptions(
    BuildContext context,
    AppStrings s,
    WebApp webApp,
  ) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: Text(webApp.name),
          children: [
            _option(context, Icons.image_outlined, s.changeIcon, 'icon'),
            _option(context, Icons.edit_outlined, s.changeName, 'name'),
            _option(context, Icons.link, s.changeUrl, 'url'),
            _option(context, Icons.delete_outline, s.remove, 'remove'),
          ],
        );
      },
    );

    if (choice == null || !context.mounted) return;
    final controller = WebAppsController.instance;
    switch (choice) {
      case 'icon':
        await controller.pickIcon(webApp.id);
      case 'name':
        final name = await _promptText(
          context,
          title: s.changeName,
          label: s.nameLabel,
          initialValue: webApp.name,
          s: s,
        );
        if (name != null && name.trim().isNotEmpty) {
          await controller.rename(webApp.id, name);
        }
      case 'url':
        final url = await _promptText(
          context,
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

  Future<({String name, String url})?> _promptNameAndUrl(
    BuildContext context,
    AppStrings s,
  ) async {
    final result = await showDialog<({String name, String url})>(
      context: context,
      builder: (context) => _NameAndUrlDialog(s: s),
    );
    if (result == null) return null;
    if (result.name.trim().isEmpty || result.url.trim().isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s.nameAndUrlRequired)));
      }
      return null;
    }
    return result;
  }

  Future<String?> _promptText(
    BuildContext context, {
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
}

/// Asks for a name and an address at once when adding a web app.
///
/// Stateful so it owns its text controllers: disposing them from the caller
/// right after `showDialog` returns would tear them down while the dialog is
/// still playing its exit animation, which then rebuilds the fields.
class _NameAndUrlDialog extends StatefulWidget {
  const _NameAndUrlDialog({required this.s});

  final AppStrings s;

  @override
  State<_NameAndUrlDialog> createState() => _NameAndUrlDialogState();
}

class _NameAndUrlDialogState extends State<_NameAndUrlDialog> {
  final _nameField = TextEditingController();
  final _urlField = TextEditingController();

  @override
  void dispose() {
    _nameField.dispose();
    _urlField.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return AlertDialog(
      title: Text(s.addWebApp),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameField,
            autofocus: true,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(labelText: s.nameLabel),
          ),
          TextField(
            controller: _urlField,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: s.urlLabel,
              hintText: 'example.com',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop((
            name: _nameField.text,
            url: _urlField.text,
          )),
          child: Text(s.save),
        ),
      ],
    );
  }
}

