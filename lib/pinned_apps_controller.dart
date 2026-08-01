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

  bool _loaded = false;

  /// Reads the stored pins once. Later calls do nothing: what's in memory is
  /// by then the newer state, and re-reading would throw away pins made
  /// since.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
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

  /// Replaces the whole pinned list wholesale - used to restore a settings
  /// backup. Capped at [maxPinned] the same way [toggle] enforces it live.
  Future<void> restore(List<String> keys) async {
    value = keys.take(maxPinned).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, value);
  }
}

/// How far the pinned apps sit from the left edge of the screen. Kept
/// separate from the clock's own width so the icons no longer land under
/// whatever the clock's left edge happens to be - which shifted around
/// depending on the clock style and looked arbitrary - but at a spot the
/// user picks directly.
class PinnedAppsLayoutController extends ValueNotifier<double> {
  PinnedAppsLayoutController._() : super(16);

  static final PinnedAppsLayoutController instance =
      PinnedAppsLayoutController._();

  static const _key = 'pinned_apps_left_margin';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    value = prefs.getDouble(_key) ?? 16;
  }

  Future<void> setLeftMargin(double margin) async {
    value = margin;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_key, margin);
  }
}
