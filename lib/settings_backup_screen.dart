import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'auto_backup_service.dart';
import 'backup_file_bridge.dart';
import 'design_tokens.dart';
import 'design_widgets.dart';
import 'haptics.dart';
import 'locale_controller.dart';
import 'settings_backup_service.dart';

/// Every setting (colors, positions, widgets, calendar/app blocks, pinned
/// apps, folders, web apps, data sources, clock style, language, and the
/// pictures) as one JSON file, and back in again - so a reinstall or a new
/// phone doesn't mean rebuilding everything by hand.
///
/// The screen is in two halves, and the order is the point. At the top is
/// what the app does by itself: a list of the snapshots it has already
/// written, which is the answer to "is there a backup" that used to depend
/// on having remembered to make one. Underneath is the manual export and
/// import, for getting a copy off this phone and onto another.
class SettingsBackupScreen extends StatefulWidget {
  const SettingsBackupScreen({super.key});

  @override
  State<SettingsBackupScreen> createState() => _SettingsBackupScreenState();
}

class _SettingsBackupScreenState extends State<SettingsBackupScreen> {
  bool _busy = false;
  List<BackupSnapshot>? _snapshots;

  @override
  void initState() {
    super.initState();
    _loadSnapshots();
  }

  Future<void> _loadSnapshots() async {
    final snapshots = await AutoBackupService.instance.list();
    if (!mounted) return;
    setState(() => _snapshots = snapshots);
  }

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
    final json = await SettingsBackupService.exportJsonWithFiles();
    final ok = await BackupFileBridge.export(json);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      _notify(s.backupExportFailed);
    }
  }

  /// Writes a snapshot to the phone right now, without a share sheet.
  ///
  /// The button that was missing: the export above hands the file to another
  /// app and is done, so "make me a backup, here, now, before I touch this"
  /// had no answer that did not involve choosing a destination first.
  Future<void> _saveNow(AppStrings s) async {
    setState(() => _busy = true);
    final name = await AutoBackupService.instance.write(BackupReason.manual);
    await _loadSnapshots();
    if (!mounted) return;
    setState(() => _busy = false);
    Haptics.fire(name == null ? HapticEvent.reject : HapticEvent.confirm);
    _notify(name == null ? s.backupExportFailed : s.backupSavedTo(name));
  }

  Future<void> _restore(AppStrings s, BackupSnapshot snapshot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.backupRestore),
        content: Text(
          s.backupRestoreConfirm(_when(s, snapshot.modifiedAt)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(s.backupRestore),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await AutoBackupService.instance.restore(snapshot);
      if (!mounted) return;
      setState(() => _busy = false);
      _notify(s.backupImportSuccess);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _notify(s.backupImportFailed);
    }
  }

  Future<void> _share(AppStrings s, BackupSnapshot snapshot) async {
    setState(() => _busy = true);
    final ok = await AutoBackupService.instance.share(snapshot);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) _notify(s.backupExportFailed);
  }

  Future<void> _delete(AppStrings s, BackupSnapshot snapshot) async {
    setState(() => _busy = true);
    await AutoBackupService.instance.delete(snapshot);
    await _loadSnapshots();
    if (!mounted) return;
    setState(() => _busy = false);
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
      // Said before the success message, not instead of it: the settings did
      // come back, and the one thing that didn't is worth naming rather than
      // leaving to be noticed later on the home screen.
      final oversized = SettingsBackupService.oversizedPicturesIn(text);
      if (!mounted) return;
      setState(() => _busy = false);
      _notify(
        oversized.isEmpty
            ? s.backupImportSuccess
            : s.backupImportSuccessWithoutPictures(oversized.length),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _notify(s.backupImportFailed);
    }
  }

  /// "Today 14:32", "Yesterday 09:07", "18.09. 14:32". A date on its own
  /// makes the reader work out whether it is recent; these three do not.
  String _when(AppStrings s, DateTime at) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(at.year, at.month, at.day);
    final time =
        '${at.hour.toString().padLeft(2, '0')}:'
        '${at.minute.toString().padLeft(2, '0')}';
    final difference = today.difference(day).inDays;
    if (difference == 0) return '${s.backupToday} $time';
    if (difference == 1) return '${s.backupYesterday} $time';
    return '${at.day.toString().padLeft(2, '0')}.'
        '${at.month.toString().padLeft(2, '0')}. $time';
  }

  String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _reason(AppStrings s, BackupSnapshot snapshot) =>
      switch (snapshot.reason) {
        'daily' => s.backupReasonDaily,
        'update' => s.backupReasonUpdate,
        _ => s.backupReasonManual,
      };

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LocaleController.instance,
      builder: (context, language, child) {
        final s = AppStrings(language);
        final design = context.design;
        final snapshots = _snapshots;
        return Scaffold(
          appBar: AppBar(title: Text(s.backup)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                s.backupHint,
                style: TextStyle(color: design.textSecondary),
              ),
              SizedBox(height: design.spaceLg),

              SettingsHeading(s.backupAutomatic),
              Text(
                s.backupAutomaticHint,
                style: design.textStyle(TypeRole.caption),
              ),
              SizedBox(height: design.spaceMd),
              FilledButton.icon(
                onPressed: _busy ? null : () => _saveNow(s),
                icon: const Icon(Icons.save_outlined),
                label: Text(s.backupSaveNow),
              ),
              SizedBox(height: design.spaceMd),
              if (snapshots == null)
                const Center(child: CircularProgressIndicator())
              else if (snapshots.isEmpty)
                Text(
                  s.backupNoneYet,
                  style: design.textStyle(TypeRole.caption),
                )
              else
                for (final snapshot in snapshots)
                  _SnapshotRow(
                    title: _when(s, snapshot.modifiedAt),
                    subtitle:
                        '${_reason(s, snapshot)} · ${_size(snapshot.bytes)}',
                    busy: _busy,
                    onRestore: () => _restore(s, snapshot),
                    onShare: () => _share(s, snapshot),
                    onDelete: () => _delete(s, snapshot),
                    s: s,
                  ),

              SizedBox(height: design.spaceLg),
              SettingsHeading(s.backupManual),
              Text(
                s.backupManualHint,
                style: design.textStyle(TypeRole.caption),
              ),
              SizedBox(height: design.spaceMd),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _export(s),
                icon: const Icon(Icons.upload_outlined),
                label: Text(s.backupExport),
              ),
              SizedBox(height: design.spaceSm),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _import(s),
                icon: const Icon(Icons.download_outlined),
                label: Text(s.backupImport),
              ),
              if (_busy) ...[
                SizedBox(height: design.spaceLg),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// One snapshot: when it was written, why, how big, and the three things
/// that can be done with it.
///
/// Restoring is the tap on the row itself rather than a fourth icon, because
/// it is the only reason to be looking at the list at all; sharing and
/// deleting sit to the side where they cannot be hit by accident.
class _SnapshotRow extends StatelessWidget {
  const _SnapshotRow({
    required this.title,
    required this.subtitle,
    required this.busy,
    required this.onRestore,
    required this.onShare,
    required this.onDelete,
    required this.s,
  });

  final String title;
  final String subtitle;
  final bool busy;
  final VoidCallback onRestore;
  final VoidCallback onShare;
  final VoidCallback onDelete;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final style = design.surfaceStyle(SurfaceLevel.compact);
    return Padding(
      padding: EdgeInsets.only(bottom: style.gap),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: design.surface,
          borderRadius: style.borderRadius,
          boxShadow: style.shadow,
          border: Border.all(color: design.border),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: style.padding),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: busy ? null : onRestore,
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: design.spaceSm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: design.textStyle(TypeRole.body)),
                        Text(
                          subtitle,
                          style: design.textStyle(TypeRole.caption),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: s.backupShare,
                onPressed: busy ? null : onShare,
                icon: const Icon(Icons.ios_share),
              ),
              IconButton(
                tooltip: s.deleteBlock,
                onPressed: busy ? null : onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
