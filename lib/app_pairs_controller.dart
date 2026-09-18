import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pinned_apps_controller.dart';

/// Two apps that open side by side, as one thing to tap.
///
/// Android has had split screen for years and every launcher makes you
/// assemble it by hand each time - open one app, go to recents, drag the
/// second one in. The intent flag that does it in one step
/// (`FLAG_ACTIVITY_LAUNCH_ADJACENT`) is available to any app and almost
/// nobody offers it, so a combination used every day is four gestures every
/// day.
///
/// Here it is an entry like any other: it sits in the app list under its own
/// letter, goes into folders, can be pinned to the home screen and wired to
/// a drawn shape.
@immutable
class AppPair {
  const AppPair({
    required this.id,
    required this.name,
    required this.first,
    required this.second,
  });

  /// `DateTime.microsecondsSinceEpoch` as a string, like web apps and
  /// folders - which is also what sorts it under "newest first".
  final String id;

  /// What it is called. Given by the user, because "WhatsApp + Notizen" is
  /// something only they can name usefully; deriving it from the two apps
  /// produces a label too long for an icon every time.
  final String name;

  /// The package that goes up first and keeps the side it was opened on.
  final String first;

  /// The one asked for beside it. Android decides which half each ends up
  /// in, and there is no way to ask - so "first" means first in time, not
  /// left or top.
  final String second;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'first': first,
    'second': second,
  };

  static AppPair? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final id = json['id'];
    final name = json['name'];
    final first = json['first'];
    final second = json['second'];
    if (id is! String || name is! String) return null;
    if (first is! String || second is! String) return null;
    if (first.isEmpty || second.isEmpty) return null;
    return AppPair(id: id, name: name, first: first, second: second);
  }
}

class AppPairsController extends ValueNotifier<List<AppPair>> {
  AppPairsController._() : super(const []);

  static final AppPairsController instance = AppPairsController._();

  static const _prefsKey = 'app_pairs';

  /// The prefix that keeps a pair's key from ever colliding with a package
  /// name, the same way web apps and folders do it.
  static String pinKeyFor(String id) => 'pair:$id';

  static String? idFromKey(String key) =>
      key.startsWith('pair:') ? key.substring('pair:'.length) : null;

  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      value = [
        for (final entry in decoded) ?AppPair.fromJson(entry),
      ];
    } catch (_) {
      // An unreadable list costs the pairs, not the launcher.
    }
  }

  AppPair? byId(String id) {
    for (final pair in value) {
      if (pair.id == id) return pair;
    }
    return null;
  }

  Future<void> add(String name, String first, String second) async {
    final pair = AppPair(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim(),
      first: first,
      second: second,
    );
    await _save([...value, pair]);
  }

  Future<void> update(AppPair pair) async {
    await _save([
      for (final existing in value)
        if (existing.id == pair.id) pair else existing,
    ]);
  }

  /// Deletes a pair, unpinning it so it cannot keep occupying a slot on the
  /// home screen invisibly - the same care [WebAppsController.remove] takes.
  Future<void> remove(String id) async {
    await PinnedAppsController.instance.remove(pinKeyFor(id));
    await _save([
      for (final pair in value)
        if (pair.id != id) pair,
    ]);
  }

  Future<void> replaceAll(List<AppPair> pairs) async {
    _loaded = true;
    await _save(pairs);
  }

  Future<void> _save(List<AppPair> pairs) async {
    value = pairs;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode([for (final pair in pairs) pair.toJson()]),
    );
  }
}
