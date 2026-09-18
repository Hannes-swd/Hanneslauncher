import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hanneslauncher/auto_backup_service.dart';
import 'package:hanneslauncher/design_controller.dart';
import 'package:hanneslauncher/design_tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A stand-in for the Downloads folder: the same four operations
/// `MainActivity` answers, over a map instead of MediaStore.
class _FakeDownloads {
  final Map<String, String> files = {};
  final Map<String, int> written = {};
  int clock = 0;

  Future<Object?> call(String method, Map<String, Object?> args) async {
    switch (method) {
      case 'saveToDownloads':
        final name = args['name'] as String;
        files[name] = args['json'] as String;
        written[name] = clock++;
        return 'content://fake/$name';
      case 'listDownloads':
        final names = files.keys.toList()
          ..sort((a, b) => written[b]!.compareTo(written[a]!));
        return [
          for (final name in names)
            {
              'name': name,
              'bytes': files[name]!.length,
              'modifiedAt': 1700000000000 + written[name]! * 1000,
            },
        ];
      case 'readDownload':
        return files[args['name'] as String];
      case 'deleteDownload':
        return files.remove(args['name'] as String) != null;
      default:
        return null;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeDownloads downloads;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    downloads = _FakeDownloads();
    AutoBackupService.debugChannelOverride = downloads.call;
    await DesignController.instance.load();
  });

  tearDown(() {
    AutoBackupService.debugChannelOverride = null;
  });

  test('a snapshot is a backup document, not just a file', () async {
    await DesignController.instance.update(
      DesignSettings(preset: DesignThemePreset.dark, radius: 8),
    );

    final name = await AutoBackupService.instance.write(BackupReason.manual);

    expect(name, isNotNull);
    final document = jsonDecode(downloads.files[name]!) as Map<String, dynamic>;
    expect(document['formatVersion'], isNotNull);
    expect((document['design'] as Map)['preset'], 'dark');
  });

  test('the daily one is written once a day, not once per panel', () async {
    await AutoBackupService.instance.ensureDaily();
    expect(downloads.files, hasLength(1));

    // Same day: nothing more to do.
    await AutoBackupService.instance.ensureDaily();
    await AutoBackupService.instance.ensureDaily();
    expect(downloads.files, hasLength(1));
  });

  test('a new day writes again', () async {
    await AutoBackupService.instance.ensureDaily();
    final firstWrite = downloads.clock;
    expect(downloads.files, hasLength(1));

    // Pretend the last run was yesterday.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      'auto_backup_at',
      DateTime.now()
          .subtract(const Duration(days: 1))
          .millisecondsSinceEpoch,
    );

    await AutoBackupService.instance.ensureDaily();
    expect(
      downloads.clock,
      greaterThan(firstWrite),
      reason: 'The day changed, so a snapshot should have been written.',
    );
    // Still one file: a daily snapshot is named after its day, so writing
    // one twice in a day replaces it rather than piling up copies of the
    // same afternoon.
    expect(downloads.files, hasLength(1));
  });

  test('each reason rotates on its own', () async {
    // Ten by hand, which is exactly the limit, plus one more.
    for (var i = 0; i < 11; i++) {
      // The manual name carries the minute, so they are written directly
      // rather than through the clock to keep them distinct.
      await downloads.call('saveToDownloads', {
        'name': 'backup_2026-09-${(i + 1).toString().padLeft(2, '0')}-1200.json',
        'json': '{"formatVersion": 2}',
      });
    }
    expect(downloads.files, hasLength(11));

    await AutoBackupService.instance.write(BackupReason.update);

    // The update snapshot arrived, and it did not push out any of the
    // manual ones - a rotation shared between reasons would have.
    final manual = downloads.files.keys.where((n) => n.startsWith('backup_'));
    expect(manual, hasLength(11));
    expect(
      downloads.files.keys.where((n) => n.startsWith('auto_update_')),
      hasLength(1),
    );
  });

  test('daily snapshots are kept three deep', () async {
    for (final day in ['15', '16', '17', '18', '19']) {
      await downloads.call('saveToDownloads', {
        'name': 'auto_daily_2026-09-$day.json',
        'json': '{"formatVersion": 2}',
      });
    }
    // One more through the service, which is what triggers the rotation.
    await AutoBackupService.instance.write(BackupReason.daily);

    final daily =
        downloads.files.keys.where((n) => n.startsWith('auto_daily_')).toList()
          ..sort();
    expect(daily, hasLength(3));
    // The three newest by name, which for ISO dates is the three newest.
    expect(daily.first.compareTo('auto_daily_2026-09-17.json'), isNonNegative);
  });

  test('a snapshot reads back as what it was written from', () async {
    await DesignController.instance.update(
      DesignSettings(preset: DesignThemePreset.green, radius: 30, haptics: 0),
    );
    await AutoBackupService.instance.write(BackupReason.manual);

    // Move everything somewhere else, the way a restore finds it.
    await DesignController.instance.update(
      DesignSettings(preset: DesignThemePreset.rose, radius: 4, haptics: 2),
    );

    final snapshots = await AutoBackupService.instance.list();
    expect(snapshots, hasLength(1));
    await AutoBackupService.instance.restore(snapshots.single);

    final restored = DesignController.instance.value;
    expect(restored.preset, DesignThemePreset.green);
    expect(restored.radius, 30);
    expect(restored.haptics, 0);
  });

  test('a snapshot says why it was taken', () async {
    await AutoBackupService.instance.write(BackupReason.update);
    final snapshot = (await AutoBackupService.instance.list()).single;
    expect(snapshot.isAutomatic, isTrue);
    expect(snapshot.reason, 'update');
  });

  test('one saved by hand is not treated as automatic', () async {
    await AutoBackupService.instance.write(BackupReason.manual);
    final snapshot = (await AutoBackupService.instance.list()).single;
    expect(snapshot.isAutomatic, isFalse);
    expect(snapshot.reason, isEmpty);
  });

  test('a phone that refuses the write says so instead of pretending', () async {
    AutoBackupService.debugChannelOverride = (method, args) async => null;
    expect(await AutoBackupService.instance.write(BackupReason.manual), isNull);
  });

  test('a failed daily write is retried, not marked done', () async {
    AutoBackupService.debugChannelOverride = (method, args) async => null;
    await AutoBackupService.instance.ensureDaily();

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getInt('auto_backup_at'),
      isNull,
      reason:
          'Writing down "today is done" after a write that failed would skip '
          'the day entirely - the one behaviour that turns a missing backup '
          'into a silent one.',
    );
  });
}
