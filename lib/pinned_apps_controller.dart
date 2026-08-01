import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Package names of the apps pinned to the home screen, in display order.
/// Only the package names are persisted; icons come from the already
/// loaded app list at render time.
class PinnedAppsController extends ValueNotifier<List<String>> {
  PinnedAppsController._() : super(const []);

  static final PinnedAppsController instance = PinnedAppsController._();

  static const maxPinned = 6;
  static const _key = 'pinned_app_packages';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    value = prefs.getStringList(_key) ?? const [];
  }

  bool isPinned(String packageName) => value.contains(packageName);

  bool get isFull => value.length >= maxPinned;

  /// Unpins an entry that no longer exists (a deleted web app or folder),
  /// so it doesn't keep occupying one of the [maxPinned] slots invisibly.
  Future<void> remove(String key) async {
    if (!value.contains(key)) return;
    value = [
      for (final entry in value)
        if (entry != key) entry,
    ];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, value);
  }

  /// Adds or removes a package. Returns false if it couldn't be added
  /// because the limit is already reached.
  Future<bool> toggle(String packageName) async {
    final current = List<String>.from(value);
    if (current.remove(packageName)) {
      value = current;
    } else {
      if (current.length >= maxPinned) return false;
      current.add(packageName);
      value = current;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, value);
    return true;
  }
}
