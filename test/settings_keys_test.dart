import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hanneslauncher/settings_keys.dart';

/// The guard that makes "I added a setting and forgot the backup" impossible
/// to do quietly - see `lib/settings_keys.dart` for why it exists.
///
/// It reads the source rather than the running app on purpose. A test that
/// exercised the controllers could only ever check the keys it already knew
/// to ask about, which is the same blind spot it is supposed to close; the
/// source is where a new key actually appears, so the source is what gets
/// counted.
///
/// Same shape as `app_shortcuts_channel_guard_test.dart` and
/// `notification_channel_guard_test.dart`: two lists that have to agree,
/// checked in both directions.
void main() {
  late Set<String> found;

  setUpAll(() {
    found = _keysUsedInSource();
  });

  test('every preference key in lib/ is classified', () {
    final unclassified = found
        .where((key) => !_isClassified(key))
        .toList(growable: false)..sort();

    expect(
      unclassified,
      isEmpty,
      reason:
          'These keys are written to SharedPreferences but say nothing about '
          'what a backup does with them.\n\n'
          'Add each to settingsKeyRegistry in lib/settings_keys.dart:\n'
          '  KeyFate.backedUp   - and carry it in settings_backup_service.dart\n'
          '  KeyFate.deviceLocal - and give the reason in settingsKeyNotes\n\n'
          'Missing: ${unclassified.join(', ')}',
    );
  });

  test('the registry names nothing the app stopped writing', () {
    final stale = settingsKeyRegistry.keys
        .where((key) => !found.contains(key))
        .toList(growable: false)..sort();

    expect(
      stale,
      isEmpty,
      reason:
          'These are in the registry but no longer written anywhere in lib/. '
          'A registry that keeps dead keys is one nobody trusts to be the '
          'whole list, so drop them: ${stale.join(', ')}',
    );
  });

  test('every key left out of backups says why', () {
    final unexplained = [
      for (final entry in settingsKeyRegistry.entries)
        if (entry.value == KeyFate.deviceLocal &&
            (settingsKeyNotes[entry.key] ?? '').trim().isEmpty)
          entry.key,
    ]..sort();

    expect(
      unexplained,
      isEmpty,
      reason:
          'Leaving a setting out of the backup is a decision, and a decision '
          'with no reason written down is indistinguishable from an omission '
          'a year later. Add a line to settingsKeyNotes for: '
          '${unexplained.join(', ')}',
    );
  });

  test('settingsKeyNotes explains only keys that exist', () {
    final orphans = settingsKeyNotes.keys
        .where((key) => settingsKeyRegistry[key] != KeyFate.deviceLocal)
        .toList(growable: false)..sort();

    expect(
      orphans,
      isEmpty,
      reason:
          'A note for a key that is backed up (or gone) is a note that will '
          'be read as still true: ${orphans.join(', ')}',
    );
  });

  test('the registry is alphabetical', () {
    final keys = settingsKeyRegistry.keys.toList(growable: false);
    final sorted = [...keys]..sort();
    expect(
      keys,
      sorted,
      reason:
          'Kept in order so that a diff shows what changed rather than where '
          'it was inserted.',
    );
  });

  test('every backed-up key belongs to a controller the backup imports', () {
    // A weaker check than "the key is in the document" - the backup stores
    // `clock.style`, not `clock_style`, so the key itself never appears
    // there. What it can catch is a whole controller nobody wired in: the
    // file that owns the key has to be one settings_backup_service.dart
    // actually pulls in.
    final backupSource = File('lib/settings_backup_service.dart')
        .readAsStringSync();
    final missing = <String, String>{};

    for (final entry in _keyOwners().entries) {
      if (settingsKeyRegistry[entry.key] != KeyFate.backedUp) continue;
      final owner = entry.value;
      if (_ownersExemptFromImport.contains(owner)) continue;
      if (!backupSource.contains("import '$owner';")) {
        missing[entry.key] = owner;
      }
    }

    expect(
      missing,
      isEmpty,
      reason:
          'These keys are marked backedUp, but the file that writes them is '
          "not imported by settings_backup_service.dart - so there is nothing "
          'there that could be reading them:\n'
          '${missing.entries.map((e) => '  ${e.key} (${e.value})').join('\n')}',
    );
  });
}

/// Files that own a backed-up key without the backup importing them, each
/// for a reason that has been looked at.
const _ownersExemptFromImport = {
  // The wallpaper travels as a picture in the 'pictures' section, which
  // settings_backup_service.dart builds through PickedImageStore rather than
  // by asking the controller.
  'wallpaper_controller.dart',
  // Written per code-widget block by the store, which the backup reaches
  // through CodeWidgetStore.exportBlock.
  'code_widget_store.dart',
  // Only ever read by the auto backup itself.
  'auto_backup_service.dart',
};

/// Matches `static const _fooKey = 'bar'` and friends, which is how every
/// controller in this app names its keys.
final _keyDeclaration = RegExp(
  r"""const\s+_?[A-Za-z0-9_]*[Kk]ey\s*=\s*'([^']+)'""",
);

Set<String> _keysUsedInSource() {
  final keys = <String>{};
  for (final file in _libFiles()) {
    for (final match in _keyDeclaration.allMatches(file.readAsStringSync())) {
      keys.add(match.group(1)!);
    }
  }
  // The registry itself is full of key literals, but they are not
  // declarations, so it never contributes to this set - which is what keeps
  // the second test from passing just because the first one was satisfied by
  // copying names in.
  return keys;
}

/// Which file declares each key, for the import check.
Map<String, String> _keyOwners() {
  final owners = <String, String>{};
  for (final file in _libFiles()) {
    final name = file.uri.pathSegments.last;
    for (final match in _keyDeclaration.allMatches(file.readAsStringSync())) {
      owners[match.group(1)!] = name;
    }
  }
  return owners;
}

List<File> _libFiles() => Directory('lib')
    .listSync()
    .whereType<File>()
    .where((file) => file.path.endsWith('.dart'))
    .toList(growable: false);

bool _isClassified(String key) {
  if (settingsKeyRegistry.containsKey(key)) return true;
  return settingsKeyPrefixes.keys.any(key.startsWith);
}
