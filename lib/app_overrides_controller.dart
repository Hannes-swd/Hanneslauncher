import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Future<void> load() async {
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
      // Corrupted entry (e.g. from an older format): start over rather than
      // leaving the launcher unable to show its app list.
      value = const {};
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
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return false;

    final appDir = await getApplicationDocumentsDirectory();
    final iconDir = Directory(p.join(appDir.path, 'app_icons'));
    if (!iconDir.existsSync()) {
      await iconDir.create(recursive: true);
    }

    // The package name goes into the file name, so each app keeps its own
    // icon file. A timestamp is appended because Image.file caches by path -
    // reusing it would keep showing the previous picture.
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final safePackage = packageName.replaceAll(RegExp(r'[^\w.]'), '_');
    final savedPath = p.join(
      iconDir.path,
      '$safePackage.$stamp${p.extension(picked.path)}',
    );
    final savedFile = await File(picked.path).copy(savedPath);

    await _deleteIconFile(value[packageName]?.iconPath);
    await _write(
      packageName,
      AppOverride(name: value[packageName]?.name, iconPath: savedFile.path),
    );
    return true;
  }

  Future<void> clearIcon(String packageName) async {
    await _deleteIconFile(value[packageName]?.iconPath);
    await _write(packageName, AppOverride(name: value[packageName]?.name));
  }

  /// Drops both the custom name and the custom icon for an app.
  Future<void> reset(String packageName) async {
    await _deleteIconFile(value[packageName]?.iconPath);
    await _write(packageName, const AppOverride());
  }

  Future<void> _deleteIconFile(String? path) async {
    if (path == null) return;
    final file = File(path);
    if (file.existsSync()) {
      await file.delete();
    }
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
