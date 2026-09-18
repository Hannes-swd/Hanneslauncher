import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings_backup_service.dart';

/// One snapshot sitting in the Downloads folder.
@immutable
class BackupSnapshot {
  const BackupSnapshot({
    required this.name,
    required this.bytes,
    required this.modifiedAt,
  });

  /// File name, which is also its identity - see [AutoBackupService] for how
  /// the names are chosen and rotated.
  final String name;
  final int bytes;
  final DateTime modifiedAt;

  /// Whether this one was written by the app rather than asked for by hand.
  bool get isAutomatic => name.startsWith(AutoBackupService.automaticPrefix);

  /// The reason the app wrote it, taken out of the file name: 'daily',
  /// 'update', or empty for one the user asked for.
  String get reason {
    if (!isAutomatic) return '';
    final rest = name.substring(AutoBackupService.automaticPrefix.length);
    final underscore = rest.indexOf('_');
    return underscore < 0 ? '' : rest.substring(0, underscore);
  }
}

/// Why a snapshot is being written. Each reason keeps its own small rotation,
/// so a week of quiet daily snapshots can never push out the one taken right
/// before an install.
enum BackupReason {
  /// Once a day, the first time the panel is pulled down.
  daily,

  /// Right before an APK is handed to the installer. The important one: an
  /// APK signed with another key cannot install over the old app, and going
  /// around that by uninstalling first takes every setting with it.
  update,

  /// The user pressed the button.
  manual,
}

/// Writes settings snapshots to the phone by itself, and reads them back.
///
/// The export that existed before this was a share sheet: it produced a
/// perfectly good backup, and only ever when someone remembered to ask for
/// one. The moment a backup is worth having - a failed install, a phone
/// being reset - is not a moment anyone thinks about exporting first, which
/// made "there is a backup" a question of discipline rather than of the app
/// working properly.
///
/// So the app now keeps its own, in the shared Downloads folder (see
/// `MainActivity.saveToDownloads` for why there and nowhere else), and the
/// share sheet stays for the times a copy should leave the phone.
///
/// Deliberately small: a handful of files, no scheduler, no background work.
/// It writes when the app is already awake and already doing something -
/// opening the panel, starting an update - because a launcher that wakes
/// itself up to write a file nobody asked for is a worse trade than a backup
/// that is occasionally a day old.
class AutoBackupService {
  AutoBackupService._();

  static final AutoBackupService instance = AutoBackupService._();

  static const _channel = MethodChannel('hanneslauncher/backup');

  static const _lastRunKey = 'auto_backup_at';

  /// What marks a file as one the app wrote. Anything else in the folder is
  /// left alone by the rotation, so a copy kept deliberately stays kept.
  static const automaticPrefix = 'auto_';

  /// How many of each reason to hold on to.
  ///
  /// Three days back is enough to notice "something went wrong yesterday"
  /// and still have the day before; more would be a longer list to read
  /// through for no more safety. The pre-update ones are kept deeper because
  /// they are tied to a version, and the reason to reach for one is usually
  /// "the version after this broke something".
  static const Map<BackupReason, int> _keep = {
    BackupReason.daily: 3,
    BackupReason.update: 5,
    BackupReason.manual: 10,
  };

  /// Swapped in by tests, which have no platform channel to answer.
  @visibleForTesting
  static Future<Object?> Function(String method, Map<String, Object?> args)?
  debugChannelOverride;

  static Future<T?> _invoke<T>(String method, [Map<String, Object?>? args]) {
    final override = debugChannelOverride;
    if (override != null) {
      return override(method, args ?? const {}).then((value) => value as T?);
    }
    return _channel.invokeMethod<T>(method, args).catchError((_) => null);
  }

  /// Writes one now. Returns the snapshot's file name, or null if the phone
  /// would not take it.
  ///
  /// Failure is quiet on purpose for the automatic reasons: the two places
  /// that call it are in the middle of doing something else the user is
  /// watching, and a dialog about a backup nobody asked for, interrupting an
  /// update they did ask for, is how a safety net becomes the thing that
  /// gets switched off.
  Future<String?> write(BackupReason reason) async {
    final String json;
    try {
      json = await SettingsBackupService.exportJsonWithFiles();
    } catch (_) {
      return null;
    }

    final name = _nameFor(reason, DateTime.now());
    final written = await _invoke<String>('saveToDownloads', {
      'name': name,
      'json': json,
    });
    if (written == null) return null;

    await _rotate(reason);
    if (reason == BackupReason.daily) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastRunKey, DateTime.now().millisecondsSinceEpoch);
    }
    return name;
  }

  /// Writes today's snapshot unless one already exists. Called when the
  /// panel opens, next to the other things that are only refreshed then.
  ///
  /// Compares calendar days rather than "24 hours ago": a phone opened every
  /// morning at eight would otherwise drift an hour later each day until it
  /// skipped one entirely.
  Future<void> ensureDaily() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_lastRunKey);
    if (last != null) {
      final then = DateTime.fromMillisecondsSinceEpoch(last);
      final now = DateTime.now();
      final sameDay =
          then.year == now.year && then.month == now.month && then.day == now.day;
      if (sameDay) return;
    }
    await write(BackupReason.daily);
  }

  /// Everything currently in the folder, newest first.
  Future<List<BackupSnapshot>> list() async {
    final rows = await _invoke<List<Object?>>('listDownloads');
    if (rows == null) return const [];
    final snapshots = <BackupSnapshot>[];
    for (final row in rows) {
      if (row is! Map) continue;
      final name = row['name'];
      if (name is! String) continue;
      snapshots.add(
        BackupSnapshot(
          name: name,
          bytes: (row['bytes'] as num?)?.toInt() ?? 0,
          modifiedAt: DateTime.fromMillisecondsSinceEpoch(
            (row['modifiedAt'] as num?)?.toInt() ?? 0,
          ),
        ),
      );
    }
    return snapshots;
  }

  /// Reads one back and applies it. Throws whatever
  /// [SettingsBackupService.apply] throws, so a bad file says the same thing
  /// here as one picked by hand does.
  Future<void> restore(BackupSnapshot snapshot) async {
    final json = await _invoke<String>('readDownload', {'name': snapshot.name});
    if (json == null) {
      throw const FormatException('Backup file could not be read');
    }
    await SettingsBackupService.apply(json);
  }

  Future<bool> delete(BackupSnapshot snapshot) async =>
      await _invoke<bool>('deleteDownload', {'name': snapshot.name}) ?? false;

  /// Hands one to the share sheet, which is how a copy gets off the phone -
  /// to a cloud drive, a mail to yourself, a cable.
  Future<bool> share(BackupSnapshot snapshot) async {
    final json = await _invoke<String>('readDownload', {'name': snapshot.name});
    if (json == null) return false;
    return await BackupFileChannel.exportNamed(snapshot.name, json);
  }

  /// `auto_daily_2026-09-18.json`, `auto_update_2026-09-18-1432.json`,
  /// `backup_2026-09-18-1432.json`.
  ///
  /// The date is in the name rather than only in the file's timestamp so the
  /// folder reads correctly in any file manager, and so a daily snapshot
  /// taken twice in one day overwrites itself instead of adding a second
  /// copy of the same thing. The pre-update ones carry the time too, because
  /// two updates in one day is an ordinary afternoon here.
  static String _nameFor(BackupReason reason, DateTime at) {
    final day =
        '${at.year}-${_two(at.month)}-${_two(at.day)}';
    final time = '${_two(at.hour)}${_two(at.minute)}';
    return switch (reason) {
      BackupReason.daily => '${automaticPrefix}daily_$day.json',
      BackupReason.update => '${automaticPrefix}update_$day-$time.json',
      BackupReason.manual => 'backup_$day-$time.json',
    };
  }

  static String _two(int value) => value.toString().padLeft(2, '0');

  /// Drops the oldest snapshots of one reason past its limit.
  ///
  /// Sorted by name, not by date: the names begin with a fixed prefix
  /// followed by an ISO date, so they sort the same way either round, and a
  /// name cannot be wrong about itself the way a file timestamp can after a
  /// copy between folders.
  Future<void> _rotate(BackupReason reason) async {
    final limit = _keep[reason]!;
    final prefix = switch (reason) {
      BackupReason.daily => '${automaticPrefix}daily_',
      BackupReason.update => '${automaticPrefix}update_',
      BackupReason.manual => 'backup_',
    };
    final mine =
        (await list()).where((s) => s.name.startsWith(prefix)).toList()
          ..sort((a, b) => b.name.compareTo(a.name));
    for (final old in mine.skip(limit)) {
      await delete(old);
    }
  }
}

/// The share sheet, reached with a file name of our choosing.
///
/// [BackupFileBridge] already does this for the ad-hoc export, but always
/// under the same fixed name; a snapshot shared out of the list should
/// arrive wherever it is sent called what it is called here.
class BackupFileChannel {
  BackupFileChannel._();

  static const _channel = MethodChannel('hanneslauncher/backup');

  static Future<bool> exportNamed(String name, String json) async {
    try {
      // Written back into Downloads first (which is a no-op when it is
      // already there under that name) so the share sheet has a real file to
      // hand over rather than a string.
      final path = await _channel.invokeMethod<String>('saveToDownloads', {
        'name': name,
        'json': json,
      });
      if (path == null) return false;
      return await _channel.invokeMethod<bool>('shareFile', {'path': path}) ??
          false;
    } catch (_) {
      return false;
    }
  }
}

/// Pretty-prints the JSON the same way the manual export does, so a snapshot
/// opened in a text editor reads like one.
String prettyBackupJson(Map<String, dynamic> document) =>
    const JsonEncoder.withIndent('  ').convert(document);
