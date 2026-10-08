import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_list_settings_controller.dart';
import 'app_overrides_controller.dart';
import 'app_pairs_controller.dart';
import 'charging_animation_controller.dart';
import 'clock_settings_controller.dart';
import 'code_widget_store.dart';
import 'custom_colors_controller.dart';
import 'data_packages_controller.dart';
import 'data_sources_controller.dart';
import 'design_controller.dart';
import 'folders_controller.dart';
import 'gesture_shortcuts_controller.dart';
import 'icon_theme_controller.dart';
import 'notification_badges_controller.dart';
import 'offline_mode_controller.dart';
import 'panel_blocks_controller.dart';
import 'pinned_apps_controller.dart';
import 'saved_shortcuts_controller.dart';
import 'settings_keys.dart';
import 'wallpaper_controller.dart';
import 'web_apps_controller.dart';

/// The user every install starts with, and the one that cannot be deleted.
/// Shown as "Standard" or "Main" until it is given a name of its own.
const String mainUserId = 'main';

/// One user: a whole home screen of its own - wallpaper, design, clock,
/// pinned apps, folders, the panel and its widgets.
@immutable
class LauncherUser {
  const LauncherUser({required this.id, this.name = '', this.icon = ''});

  final String id;

  /// What it was called. Empty for the main user until it is renamed, which
  /// is what lets its name follow the language.
  final String name;

  /// Which of the user icons (users_settings_screen.dart) it is shown with,
  /// by name. Empty for none: it is then shown with its initial.
  final String icon;

  bool get isMain => id == mainUserId;

  LauncherUser copyWith({String? name, String? icon}) =>
      LauncherUser(id: id, name: name ?? this.name, icon: icon ?? this.icon);

  Map<String, dynamic> toJson() => {
    'id': id,
    if (name.isNotEmpty) 'name': name,
    if (icon.isNotEmpty) 'icon': icon,
  };

  static LauncherUser? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    if (id is! String || id.isEmpty) return null;
    final name = json['name'];
    final icon = json['icon'];
    return LauncherUser(
      id: id,
      name: name is String ? name : '',
      icon: icon is String ? icon : '',
    );
  }
}

@immutable
class UsersState {
  const UsersState({
    this.users = const [LauncherUser(id: mainUserId)],
    this.activeId = mainUserId,
  });

  /// Always starts with the main user.
  final List<LauncherUser> users;
  final String activeId;

  LauncherUser get active => users.firstWhere(
    (user) => user.id == activeId,
    orElse: () => users.first,
  );
}

/// More than one home screen on the same phone.
///
/// A user is not an account and has nothing to log into: it is "how
/// everything is set up", kept apart from another way of setting it all up.
/// The controllers know nothing about it. They keep reading and writing
/// their own keys exactly as before, and those keys always hold the active
/// user. Every other user is parked under one key of its own
/// (`users_stash_<id>`) as a plain copy of their keys, and a switch is three
/// steps: park the active user, put the other one's keys in place, have
/// every controller read again.
///
/// Which keys move is not decided here but in settings_keys.dart
/// ([isUserKey]) - everything the backup carries, minus the few things that
/// are about the phone rather than the home screen. So a setting added later
/// follows the user without anyone having to remember this file, as long as
/// it is registered there, which test/settings_keys_test.dart already makes
/// impossible to skip.
///
/// A new user is simply one with nothing parked: switching to it clears the
/// keys and every controller falls back to what a fresh install shows.
///
/// The active user never has anything parked. If one does, a switch was cut
/// off half way (the phone died, the app was killed), and that parked copy
/// is the complete one - so [load] finishes the switch from it.
class UsersController extends ValueNotifier<UsersState> {
  UsersController._() : super(const UsersState());

  static final UsersController instance = UsersController._();

  static const _listKey = 'users_list';
  static const _activeKey = 'users_active';
  static const _stashPrefix = 'users_stash_';

  static String _stashKey(String id) => '$_stashPrefix$id';

  /// Every controller holding something [isUserKey] covers, in the order
  /// they read again. The custom colours first: every `colorIndex` the
  /// others restore points into them. `test/users_test.dart` checks that
  /// every file owning such a key is imported here.
  static final List<Future<void> Function()> _reloaders = [
    CustomColorsController.instance.reload,
    DesignController.instance.load,
    WallpaperController.instance.reload,
    ClockSettingsController.instance.load,
    OfflineModeController.instance.load,
    ChargingAnimationController.instance.load,
    AppListSettingsController.instance.load,
    IconThemeController.instance.load,
    AppOverridesController.instance.reload,
    WebAppsController.instance.reload,
    AppPairsController.instance.reload,
    SavedShortcutsController.instance.reload,
    FoldersController.instance.reload,
    PinnedAppsController.instance.reload,
    PinnedAppsLayoutController.instance.load,
    PinnedBadgeController.instance.reload,
    GestureShortcutsController.instance.reload,
    GestureDrawingController.instance.reload,
    PanelBlocksController.instance.reload,
    DataSourcesController.instance.reload,
    DeviceDataController.instance.reload,
  ];

  bool _loaded = false;

  /// The operation in progress. Switches, creations and deletions run one
  /// after the other: two switches overlapping would each park what the
  /// other just put in place.
  Future<void> _queue = Future.value();

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    final users = _parseList(prefs.getString(_listKey));
    final stored = prefs.getString(_activeKey) ?? mainUserId;
    final activeId = users.any((user) => user.id == stored)
        ? stored
        : mainUserId;
    value = UsersState(users: users, activeId: activeId);
    // An interrupted switch - see the class comment.
    if (prefs.containsKey(_stashKey(activeId))) {
      await _unpark(prefs, activeId);
      await _reloadAll();
    }
  }

  /// Lets a test pretend the app restarted: the users are read again, and
  /// so is every controller they move.
  @visibleForTesting
  Future<void> debugRestartForTest() async {
    _loaded = false;
    // A widget test's fake clock may have left the queue waiting on
    // something that will never run again; a real restart starts empty.
    _queue = Future.value();
    value = const UsersState();
    await _reloadAll();
    await load();
  }

  /// Adds a user with nothing set up. Does not switch to it.
  Future<LauncherUser> create(String name, {String icon = ''}) =>
      _serial(() async {
        await load();
        var stamp = DateTime.now().microsecondsSinceEpoch;
        while (value.users.any((user) => user.id == 'u$stamp')) {
          stamp++;
        }
        final user = LauncherUser(
          id: 'u$stamp',
          name: name.trim(),
          icon: icon,
        );
        await _saveList([...value.users, user]);
        return user;
      });

  /// Changes how a user is shown - name, icon or both. Nothing they have
  /// set up is touched.
  Future<void> edit(String id, {String? name, String? icon}) =>
      _serial(() async {
        await load();
        await _saveList([
          for (final user in value.users)
            if (user.id == id)
              user.copyWith(name: name?.trim(), icon: icon)
            else
              user,
        ]);
      });

  /// Makes [id] the active user: what is on screen becomes their home
  /// screen, and the one that was there waits, untouched, for the next
  /// switch back.
  Future<void> switchTo(String id) => _serial(() async {
    await load();
    await _switch(id);
  });

  Future<void> _switch(String id) async {
    if (id == value.activeId) return;
    if (!value.users.any((user) => user.id == id)) return;
    final prefs = await SharedPreferences.getInstance();
    // Parked first, so from here on the outgoing user exists complete in
    // one place whatever happens next.
    await _park(prefs, value.activeId);
    await _unpark(prefs, id);
    value = UsersState(users: value.users, activeId: id);
    await _reloadAll();
  }

  /// Deletes a user and everything only they used: their pictures and
  /// their code widgets' folders. The main user stays; deleting the active
  /// one switches to the main user first.
  Future<void> remove(String id) => _serial(() async {
    await load();
    if (id == mainUserId) return;
    if (!value.users.any((user) => user.id == id)) return;
    if (value.activeId == id) await _switch(mainUserId);
    final prefs = await SharedPreferences.getInstance();
    final parked = _readStash(prefs, id);
    await prefs.remove(_stashKey(id));
    await _saveList([
      for (final user in value.users)
        if (user.id != id) user,
    ]);
    if (parked != null) await _discardFilesOf([parked], prefs);
  });

  // --- backup ---

  /// Runs [action] with no switch, creation or deletion in between.
  ///
  /// For the backup, which reads the active user off the controllers and
  /// everyone else off their parked keys. A switch landing between the two
  /// would put one user in both places and the other in neither - and the
  /// daily backup is written the moment the panel opens, which is also
  /// where the quick switch is.
  Future<T> steady<T>(Future<T> Function() action) => _serial(() async {
    await load();
    return action();
  });

  /// Every user that is not the active one, as their parked keys - for
  /// settings_backup_service.dart, which carries the pictures and code
  /// widgets they point at alongside.
  ///
  /// A user with nothing parked is left out: it is one nobody has set up
  /// yet, and the list alone brings it back the same.
  Future<Map<String, Map<String, dynamic>>> parkedForBackup() async {
    await load();
    final prefs = await SharedPreferences.getInstance();
    return {
      for (final user in value.users)
        if (user.id != value.activeId) user.id: ?_readStash(prefs, user.id),
    };
  }

  /// Puts the users back as a backup had them. The active user's own keys
  /// were already restored the ordinary way by the rest of the backup, so
  /// this only replaces the list and the parked users - and throws away the
  /// files of the ones on this phone that the backup does not bring back.
  Future<void> restoreFromBackup({
    required List<LauncherUser> users,
    required String activeId,
    required Map<String, Map<String, dynamic>> parked,
  }) => _serial(() async {
    await load();
    final prefs = await SharedPreferences.getInstance();
    final list = _withMain(users);
    final active = list.any((user) => user.id == activeId)
        ? activeId
        : mainUserId;

    final replaced = <Map<String, dynamic>>[];
    for (final user in value.users) {
      final stash = _readStash(prefs, user.id);
      if (stash == null) continue;
      replaced.add(stash);
      await prefs.remove(_stashKey(user.id));
    }
    for (final user in list) {
      final stash = parked[user.id];
      if (user.id == active || stash == null) continue;
      await prefs.setString(_stashKey(user.id), jsonEncode(stash));
    }
    await prefs.setString(_activeKey, active);
    value = UsersState(users: value.users, activeId: active);
    await _saveList(list);
    await _discardFilesOf(replaced, prefs);
  });

  // --- the moving itself ---

  /// Copies every key of the active user into their parking spot.
  Future<void> _park(SharedPreferences prefs, String id) async {
    final entries = <String, dynamic>{};
    for (final key in prefs.getKeys()) {
      if (!isUserKey(key)) continue;
      final encoded = _encodeValue(prefs.get(key));
      if (encoded != null) entries[key] = encoded;
    }
    await prefs.setString(_stashKey(id), jsonEncode(entries));
  }

  /// Clears the active user's keys and writes [id]'s in their place - or
  /// nothing, for a user never set up. The parked copy goes last: until
  /// then it is the one complete version.
  Future<void> _unpark(SharedPreferences prefs, String id) async {
    final stash = _readStash(prefs, id) ?? const {};
    for (final key in prefs.getKeys().toList()) {
      if (isUserKey(key)) await prefs.remove(key);
    }
    for (final entry in stash.entries) {
      if (!isUserKey(entry.key)) continue;
      await _writeValue(prefs, entry.key, entry.value);
    }
    await prefs.setString(_activeKey, id);
    await prefs.remove(_stashKey(id));
  }

  Future<void> _reloadAll() async {
    for (final reload in _reloaders) {
      await reload();
    }
    // Their cached answers are already showing; anything past its interval
    // is fetched now, the way opening the panel would.
    unawaited(DataSourcesController.instance.refreshStale());
  }

  /// Deletes the files that only [dropped] pointed at.
  ///
  /// A user's pictures are files in the app's documents directory, named
  /// in their keys by full path; a code widget's files are a folder named
  /// after its block. Neither is ever shared between two users - each pick
  /// and each block makes a new one - but nothing is deleted that the active
  /// user or another parked one still names, so a mistake there costs disk
  /// space rather than a picture.
  Future<void> _discardFilesOf(
    List<Map<String, dynamic>> dropped,
    SharedPreferences prefs,
  ) async {
    if (dropped.isEmpty) return;
    final String root;
    try {
      root = (await getApplicationDocumentsDirectory()).path;
    } catch (_) {
      return;
    }

    final kept = <Map<String, dynamic>>[
      {
        for (final key in prefs.getKeys())
          if (isUserKey(key)) key: _encodeValue(prefs.get(key)),
      },
      for (final user in value.users) ?_readStash(prefs, user.id),
    ];
    final keptStrings = {for (final stash in kept) ...stringsIn(stash)};
    final keptBlocks = {for (final stash in kept) ...codeBlockIdsIn(stash)};

    for (final stash in dropped) {
      for (final path in stringsIn(stash)) {
        if (!path.startsWith(root) || keptStrings.contains(path)) continue;
        try {
          final file = File(path);
          if (file.existsSync()) await file.delete();
        } catch (_) {
          // A file that will not go stays - it is only space.
        }
      }
      for (final blockId in codeBlockIdsIn(stash)) {
        if (keptBlocks.contains(blockId)) continue;
        await CodeWidgetStore.instance.deleteFolder(blockId);
      }
    }
  }

  // --- reading parked keys ---

  Map<String, dynamic>? _readStash(SharedPreferences prefs, String id) {
    final raw = prefs.getString(_stashKey(id));
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // Unreadable - treated like nothing parked, which is a user that
      // starts over rather than a launcher that will not switch.
    }
    return null;
  }

  /// Every string in a parked user, including the ones inside the JSON
  /// that most lists are stored as - which is where picture paths live.
  static Set<String> stringsIn(Map<String, dynamic> stash) {
    final found = <String>{};
    void walk(Object? node) {
      switch (node) {
        case String text:
          found.add(text);
          final trimmed = text.trimLeft();
          if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
            try {
              walk(jsonDecode(text));
            } catch (_) {}
          }
        case Map map:
          map.values.forEach(walk);
        case List list:
          list.forEach(walk);
      }
    }

    walk(stash);
    return found;
  }

  /// The ids of a parked user's code widgets, whose files live in folders
  /// named after them.
  static Set<String> codeBlockIdsIn(Map<String, dynamic> stash) {
    final entry = stash['panel_blocks'];
    final list = entry is Map ? entry['list'] : null;
    if (list is! List) return const {};
    final ids = <String>{};
    for (final raw in list) {
      try {
        final block = PanelBlock.fromJson(
          jsonDecode(raw as String) as Map<String, dynamic>,
        );
        if (block.type == PanelBlockType.code) ids.add(block.id);
      } catch (_) {
        // Skip just the unreadable one.
      }
    }
    return ids;
  }

  /// [stash] with every path in [moved] replaced by where it is now - for a
  /// restore, which writes each picture to a new file of this install's own.
  static Map<String, dynamic> withMovedPaths(
    Map<String, dynamic> stash,
    Map<String, String> moved,
  ) {
    if (moved.isEmpty) return stash;
    String move(String text) {
      var result = text;
      for (final entry in moved.entries) {
        result = result.replaceAll(entry.key, entry.value);
        // Inside a JSON string a path is escaped; on Android that changes
        // nothing, but a backslash in it would be doubled.
        final escapedFrom = _escaped(entry.key);
        if (escapedFrom != entry.key) {
          result = result.replaceAll(escapedFrom, _escaped(entry.value));
        }
      }
      return result;
    }

    Object? walk(Object? node) => switch (node) {
      String text => move(text),
      Map map => {for (final e in map.entries) e.key as String: walk(e.value)},
      List list => [for (final item in list) walk(item)],
      _ => node,
    };

    return walk(stash) as Map<String, dynamic>;
  }

  static String _escaped(String text) {
    final encoded = jsonEncode(text);
    return encoded.substring(1, encoded.length - 1);
  }

  /// A preference value tagged with its type, because JSON alone cannot tell
  /// a double that happens to be whole from an int - and SharedPreferences
  /// refuses to read one as the other.
  static Map<String, dynamic>? _encodeValue(Object? value) => switch (value) {
    bool v => {'bool': v},
    int v => {'int': v},
    double v => {'double': v},
    String v => {'string': v},
    List v => {
      'list': [for (final item in v) '$item'],
    },
    _ => null,
  };

  static Future<void> _writeValue(
    SharedPreferences prefs,
    String key,
    Object? tagged,
  ) async {
    if (tagged is! Map || tagged.length != 1) return;
    final value = tagged.values.single;
    switch (tagged.keys.single) {
      case 'bool' when value is bool:
        await prefs.setBool(key, value);
      case 'int' when value is num:
        await prefs.setInt(key, value.toInt());
      case 'double' when value is num:
        await prefs.setDouble(key, value.toDouble());
      case 'string' when value is String:
        await prefs.setString(key, value);
      case 'list' when value is List:
        await prefs.setStringList(key, [for (final item in value) '$item']);
    }
  }

  // --- the list ---

  static List<LauncherUser> _parseList(String? raw) {
    if (raw == null) return const [LauncherUser(id: mainUserId)];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return _withMain([
          for (final entry in decoded) ?LauncherUser.fromJson(entry),
        ]);
      }
    } catch (_) {
      // Unreadable - the main user alone, whose keys are the live ones
      // anyway. The parked ones stay where they are.
    }
    return const [LauncherUser(id: mainUserId)];
  }

  /// [users] with the main user first and every id once.
  static List<LauncherUser> _withMain(List<LauncherUser> users) {
    final seen = <String>{};
    final main = users.firstWhere(
      (user) => user.isMain,
      orElse: () => const LauncherUser(id: mainUserId),
    );
    return [
      main,
      for (final user in users)
        if (!user.isMain && seen.add(user.id)) user,
    ];
  }

  Future<void> _saveList(List<LauncherUser> users) async {
    final list = _withMain(users);
    value = UsersState(users: list, activeId: value.activeId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _listKey,
      jsonEncode([for (final user in list) user.toJson()]),
    );
  }
}
