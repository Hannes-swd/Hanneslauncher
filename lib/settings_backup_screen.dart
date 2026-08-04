import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'backup_file_bridge.dart';
import 'locale_controller.dart';
import 'settings_backup_service.dart';

/// Exports every setting (colors, positions, widgets, calendar/app blocks,
/// pinned apps, folders, web apps, data sources, clock style, language) as
/// one JSON file, and restores one back in - so a reinstall or a new phone
/// doesn't mean rebuilding everything by hand.
class SettingsBackupScreen extends StatefulWidget {
  const SettingsBackupScreen({super.key});

  @override
  State<SettingsBackupScreen> createState() => _SettingsBackupScreenState();
}

class _SettingsBackupScreenState extends State<SettingsBackupScreen> {
  bool _busy = false;

  /// clearSnackBars (not hideCurrentSnackBar) removes any already showing
  /// one instantly - importing twice in a row would otherwise put two
  /// SnackBars with the same text in the tree while the first animates out,
  /// and the implicit Hero tag SnackBar derives from its content is then no
  /// longer unique, which crashes with "multiple heroes share tag". The
  /// _busy guard doesn't cover this: it is already false while the previous
  /// SnackBar is still on screen.
  void _notify(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _export(AppStrings s) async {
    setState(() => _busy = true);
    final json = SettingsBackupService.exportJson();
    final ok = await BackupFileBridge.export(json);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      _notify(s.backupExportFailed);
    }
  }

  Future<void> _import(AppStrings s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.backupImport),
        content: Text(s.backupImportConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(s.backupImport),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final text = await BackupFileBridge.import();
    if (text == null) {
      if (mounted) setState(() => _busy = false);
      return;
    }
    try {
      await SettingsBackupService.apply(text);
      if (!mounted) return;
      setState(() => _busy = false);
      _notify(s.backupImportSuccess);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _notify(s.backupImportFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LocaleController.instance,
      builder: (context, language, child) {
        final s = AppStrings(language);
        return Scaffold(
          appBar: AppBar(title: Text(s.backup)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(s.backupHint, style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _busy ? null : () => _export(s),
                icon: const Icon(Icons.upload_outlined),
                label: Text(s.backupExport),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _import(s),
                icon: const Icon(Icons.download_outlined),
                label: Text(s.backupImport),
              ),
              if (_busy) ...[
                const SizedBox(height: 24),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          ),
        );
      },
    );
  }
}
