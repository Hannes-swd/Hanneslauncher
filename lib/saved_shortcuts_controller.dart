import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_shortcuts.dart';
import 'picked_image_store.dart';
import 'pinned_apps_controller.dart';

/// An app shortcut the user kept: it behaves like an installed app from
/// there on - it shows up in the app list under its letter, goes into
/// folders, can be pinned to the home screen and can be drawn as a gesture.
///
/// The label and the icon are a snapshot taken when it was saved, refreshed
/// from Android whenever it answers. That is not a cache for speed: a
/// shortcut only exists while its app is installed and Android is handing
/// them out, and an entry that disappears from the home screen because the
/// phone was just unlocked would be worse than a slightly old name.
class SavedShortcut {
  const SavedShortcut({
    required this.id,
    required this.package,
    required this.shortcutId,
    required this.name,
    this.iconPath,
  });

  /// Stable id, also used as the pin key (prefixed, see [shortcutKeyPrefix]).
  /// The creation time, like a web app's, so "newest first" can sort it.
  final String id;

  /// The app that published the shortcut.
  final String package;

  /// That app's own id for it. Together with [package] this is what Android
  /// is asked to start.
  final String shortcutId;

  final String name;

  /// Android's rendered icon, copied into the app's own documents directory
  /// - the cache file it came from is one Android may delete at any time.
  final String? iconPath;

  File? get iconFile {
    final path = iconPath;
    if (path == null) return null;
    final file = File(path);
    return file.existsSync() ? file : null;
  }

  SavedShortcut copyWith({String? name, String? iconPath}) => SavedShortcut(
    id: id,
    package: package,
    shortcutId: shortcutId,
    name: name ?? this.name,
    iconPath: iconPath ?? this.iconPath,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'package': package,
    'shortcutId': shortcutId,
    'name': name,
    if (iconPath != null) 'iconPath': iconPath,
  };

  static SavedShortcut fromJson(Map<String, dynamic> json) => SavedShortcut(
    id: json['id'] as String,
    package: json['package'] as String,
    shortcutId: json['shortcutId'] as String,
    name: json['name'] as String,
    iconPath: json['iconPath'] as String?,
  );
}

/// Marks a pinned entry as a saved shortcut rather than a package name, so
/// it can live in the same pinned list as everything else.
const String shortcutKeyPrefix = 'shortcut:';

/// The shortcuts the user kept, persisted across restarts.
///
/// Every change also tells Android which of an app's shortcuts this launcher
/// still wants: a dynamic shortcut (the four most recent chats) drops off as
/// soon as the app publishes a newer one, and a saved chat would quietly
/// stop working a day later. [AppShortcuts.pin] takes the full set per
/// package, which is why saving and removing both end in [_syncPins].
class SavedShortcutsController extends ValueNotifier<List<SavedShortcut>> {
  SavedShortcutsController._() : super(const []);

  static final SavedShortcutsController instance = SavedShortcutsController._();

  static const _key = 'saved_shortcuts';

  bool _loaded = false;

  /// Reads the stored shortcuts once. Later calls do nothing: what's in
  /// memory is by then the newer state, and re-reading would throw away
  /// shortcuts saved since.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key);
    if (raw == null) return;
    final loaded = <SavedShortcut>[];
    for (final entry in raw) {
      try {
        loaded.add(
          SavedShortcut.fromJson(jsonDecode(entry) as Map<String, dynamic>),
        );
      } catch (_) {
        // Skip just the unreadable one. Dropping the whole list here would
        // be permanent: the next save would write the shortened list back.
      }
    }
    value = loaded;
  }

  @visibleForTesting
  void debugResetLoadedForTest() => _loaded = false;

  SavedShortcut? byId(String id) {
    for (final shortcut in value) {
      if (shortcut.id == id) return shortcut;
    }
    return null;
  }

  /// The saved copy of one of an app's shortcuts, if there is one. What the
  /// long-press menu checks to show "saved" instead of offering it again.
  SavedShortcut? bySource(String package, String shortcutId) {
    for (final shortcut in value) {
      if (shortcut.package == package && shortcut.shortcutId == shortcutId) {
        return shortcut;
      }
    }
    return null;
  }

  /// The pin key for a saved shortcut, distinguishable from a package name.
  static String pinKeyFor(String id) => '$shortcutKeyPrefix$id';

  /// Keeps [shortcut], copying its icon somewhere permanent and asking
  /// Android to hold the shortcut itself open. Answers with the saved entry,
  /// or the existing one when it was already kept.
  Future<SavedShortcut> add(AppShortcut shortcut) async {
    final existing = bySource(shortcut.package, shortcut.id);
    if (existing != null) return existing;

    final id = _newId();
    final source = shortcut.iconFile;
    final stored = source == null
        ? null
        : await copyImageInto('shortcut_icons', id, source);

    final saved = SavedShortcut(
      id: id,
      package: shortcut.package,
      shortcutId: shortcut.id,
      name: shortcut.label,
      iconPath: stored?.path,
    );
    await _save([...value, saved]);
    await _syncPins(shortcut.package);
    return saved;
  }

  /// Ids are the creation time. If the clock hasn't advanced since the last
  /// one, two shortcuts would share an id and then be edited and deleted
  /// together. Step past anything already taken.
  String _newId() {
    var stamp = DateTime.now().microsecondsSinceEpoch;
    while (byId(stamp.toString()) != null) {
      stamp++;
    }
    return stamp.toString();
  }

  /// Drops a saved shortcut, unpinning it so it doesn't keep occupying one
  /// of the home screen's slots invisibly, and letting Android drop the
  /// shortcut itself again. Folders holding it skip it on their own.
  Future<void> remove(String id) async {
    final shortcut = byId(id);
    if (shortcut == null) return;
    await deleteStoredImage(shortcut.iconPath);
    await PinnedAppsController.instance.remove(pinKeyFor(id));
    await _save([
      for (final entry in value)
        if (entry.id != id) entry,
    ]);
    await _syncPins(shortcut.package);
  }

  /// Picks up renames and new pictures from the apps themselves - a contact
  /// shortcut follows the contact's name and photo.
  ///
  /// Only ever updates. A shortcut Android doesn't answer for is left
  /// exactly as it was, because the overwhelmingly common reason for no
  /// answer is not "it is gone" but "this launcher isn't the home app at
  /// this moment", and acting on that would empty the home screen.
  Future<void> refresh() async {
    if (value.isEmpty) return;
    if (!await AppShortcuts.available()) return;

    var changed = false;
    final updated = <SavedShortcut>[];
    for (final shortcut in value) {
      final label = await AppShortcuts.label(shortcut.package, shortcut.shortcutId);
      if (label == null) {
        updated.add(shortcut);
        continue;
      }
      final freshIcon = await AppShortcuts.icon(
        shortcut.package,
        shortcut.shortcutId,
      );
      String? storedPath = shortcut.iconPath;
      // Only when the picture actually differs. A stored file carries a
      // timestamp in its name (Image.file caches by path, so overwriting one
      // would keep showing the old picture), which means copying
      // unconditionally would write a new file and drop the old one on every
      // single launch, for a picture that changes maybe once a year.
      if (freshIcon != null && !await _sameBytes(freshIcon, storedPath)) {
        final copied = await copyImageInto(
          'shortcut_icons',
          shortcut.id,
          File(freshIcon),
        );
        if (copied != null) {
          await deleteStoredImage(shortcut.iconPath);
          storedPath = copied.path;
        }
      }
      if (label == shortcut.name && storedPath == shortcut.iconPath) {
        updated.add(shortcut);
        continue;
      }
      changed = true;
      updated.add(shortcut.copyWith(name: label, iconPath: storedPath));
    }
    if (changed) await _save(updated);
  }

  /// Whether the freshly rendered icon is the picture already stored. These
  /// are a few kilobytes each, so comparing them outright is cheaper than
  /// being wrong: a length check alone would eventually call two different
  /// contact photos the same and leave one stale forever.
  Future<bool> _sameBytes(String freshPath, String? storedPath) async {
    if (storedPath == null) return false;
    try {
      final fresh = File(freshPath);
      final stored = File(storedPath);
      if (!fresh.existsSync() || !stored.existsSync()) return false;
      if (await fresh.length() != await stored.length()) return false;
      final a = await fresh.readAsBytes();
      final b = await stored.readAsBytes();
      for (var i = 0; i < a.length; i++) {
        if (a[i] != b[i]) return false;
      }
      return true;
    } catch (_) {
      // Unreadable either way: treat it as different, which at worst copies
      // a file that didn't need copying.
      return false;
    }
  }

  /// Replaces every saved shortcut wholesale - used to restore a settings
  /// backup. Re-pins each package, so a restored shortcut is held open by
  /// Android again rather than surviving only until the app publishes its
  /// next one.
  Future<void> replaceAll(List<SavedShortcut> shortcuts) async {
    await _save(shortcuts);
    for (final package in {for (final entry in shortcuts) entry.package}) {
      await _syncPins(package);
    }
  }

  /// Hands Android the full set of [package]'s shortcuts this launcher still
  /// holds. Always the whole set, never a delta: the call replaces whatever
  /// was pinned before, so leaving one out is how it gets released.
  Future<void> _syncPins(String package) async {
    await AppShortcuts.pin(package, [
      for (final shortcut in value)
        if (shortcut.package == package) shortcut.shortcutId,
    ]);
  }

  Future<void> _save(List<SavedShortcut> shortcuts) async {
    value = shortcuts;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      [for (final shortcut in shortcuts) jsonEncode(shortcut.toJson())],
    );
  }
}
