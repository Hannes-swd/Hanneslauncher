import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'picked_image_store.dart';

/// A user-supplied replacement for an app's name and/or icon. Either field
/// may be null, meaning "keep whatever the system reports for this app".
class AppOverride {
  const AppOverride({this.name, this.iconPath});

  final String? name;
  final String? iconPath;

  bool get isEmpty => name == null && iconPath == null;

  /// The picked icon as a file, or null if none was set (or it went missing).
  File? get iconFile {
    final path = iconPath;
    if (path == null) return null;
    final file = File(path);
    return file.existsSync() ? file : null;
  }

  Map<String, dynamic> toJson() => {
    if (name != null) 'name': name,
    if (iconPath != null) 'iconPath': iconPath,
  };

  static AppOverride fromJson(Map<String, dynamic> json) => AppOverride(
    name: json['name'] as String?,
    iconPath: json['iconPath'] as String?,
  );
}

/// Per-app customizations (renamed apps, replaced icons), keyed by package
/// name and persisted across restarts. Replacement icons are copied into the
/// app's own documents directory, so they keep working even if the original
/// gallery file is moved or deleted.
class AppOverridesController extends ValueNotifier<Map<String, AppOverride>> {
  AppOverridesController._() : super(const {});

  static final AppOverridesController instance = AppOverridesController._();

  static const _key = 'app_overrides';

  bool _loaded = false;

  /// Reads the stored customizations once. Later calls do nothing: what's in
  /// memory is by then the newer state, and re-reading would throw away
  /// renames made since.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      value = {
        for (final entry in decoded.entries)
          entry.key: AppOverride.fromJson(
            entry.value as Map<String, dynamic>,
          ),
      };
    } catch (_) {
      // Unreadable - leave whatever is in memory alone rather than wiping
      // it, since the next save would make that permanent.
    }
  }

  AppOverride? forPackage(String packageName) => value[packageName];

  /// The name to display for an app: the user's own if set, else the
  /// system one.
  String nameFor(String packageName, String systemName) {
    final custom = value[packageName]?.name;
    return (custom == null || custom.isEmpty) ? systemName : custom;
  }

  Future<void> setName(String packageName, String? name) async {
    final trimmed = name?.trim();
    await _write(
      packageName,
      AppOverride(
        name: (trimmed == null || trimmed.isEmpty) ? null : trimmed,
        iconPath: value[packageName]?.iconPath,
      ),
    );
  }

  /// Lets the user pick an image and uses it as [packageName]'s icon.
  /// Returns false if the picker was dismissed without a selection.
  Future<bool> pickIcon(String packageName) async {
    final savedFile = await pickImageInto('app_icons', packageName);
    if (savedFile == null) return false;

    await deleteStoredImage(value[packageName]?.iconPath);
    await _write(
      packageName,
      AppOverride(name: value[packageName]?.name, iconPath: savedFile.path),
    );
    return true;
  }

  Future<void> clearIcon(String packageName) async {
    await deleteStoredImage(value[packageName]?.iconPath);
    await _write(packageName, AppOverride(name: value[packageName]?.name));
  }

  /// Drops both the custom name and the custom icon for an app.
  Future<void> reset(String packageName) async {
    await deleteStoredImage(value[packageName]?.iconPath);
    await _write(packageName, const AppOverride());
  }

  Future<void> _write(String packageName, AppOverride override) async {
    final updated = Map<String, AppOverride>.from(value);
    if (override.isEmpty) {
      updated.remove(packageName);
    } else {
      updated[packageName] = override;
    }
    value = updated;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        for (final entry in updated.entries) entry.key: entry.value.toJson(),
      }),
    );
  }
}
