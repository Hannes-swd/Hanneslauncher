import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_list_settings_controller.dart' show appListColorPalette;
import 'pinned_apps_controller.dart';

/// A folder holding apps, web apps and other folders. It behaves like an
/// app everywhere: it shows up in the app list under its letter and can be
/// pinned to the home screen - only instead of launching something, opening
/// it shows a window with its contents.
class LauncherFolder {
  const LauncherFolder({
    required this.id,
    required this.name,
    this.colorIndex = 3,
    this.itemKeys = const [],
  });

  final String id;
  final String name;

  /// Index into [appListColorPalette], same palette as everywhere else.
  final int colorIndex;

  /// What's inside, in display order. Holds the same keys used for pinning:
  /// a package name, a `web:<id>` or a `folder:<id>`.
  final List<String> itemKeys;

  Color get color => appListColorPalette[colorIndex];

  LauncherFolder copyWith({
    String? name,
    int? colorIndex,
    List<String>? itemKeys,
  }) {
    return LauncherFolder(
      id: id,
      name: name ?? this.name,
      colorIndex: colorIndex ?? this.colorIndex,
      itemKeys: itemKeys ?? this.itemKeys,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'colorIndex': colorIndex,
    'itemKeys': itemKeys,
  };

  static LauncherFolder fromJson(Map<String, dynamic> json) => LauncherFolder(
    id: json['id'] as String,
    name: json['name'] as String,
    colorIndex: json['colorIndex'] as int? ?? 3,
    itemKeys: [
      for (final key in (json['itemKeys'] as List<dynamic>? ?? const []))
        key as String,
    ],
  );
}

/// Marks a key as a folder rather than a package name or a web app.
const String folderKeyPrefix = 'folder:';

/// The user's folders, persisted across restarts.
class FoldersController extends ValueNotifier<List<LauncherFolder>> {
  FoldersController._() : super(const []);

  static final FoldersController instance = FoldersController._();

  static const _key = 'folders';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key);
    if (raw == null) return;
    try {
      value = [
        for (final entry in raw)
          LauncherFolder.fromJson(jsonDecode(entry) as Map<String, dynamic>),
      ];
    } catch (_) {
      // Corrupted entry (e.g. from an older format): start over rather than
      // leaving the launcher unable to show its app list.
      value = const [];
    }
  }

  LauncherFolder? byId(String id) {
    for (final folder in value) {
      if (folder.id == id) return folder;
    }
    return null;
  }

  /// The key a folder is referenced by when pinned or nested.
  static String keyFor(String id) => '$folderKeyPrefix$id';

  /// The folder a key refers to, or null if it points at something else.
  LauncherFolder? byKey(String key) => key.startsWith(folderKeyPrefix)
      ? byId(key.substring(folderKeyPrefix.length))
      : null;

  Future<LauncherFolder> add(String name) async {
    final folder = LauncherFolder(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim(),
    );
    await _save([...value, folder]);
    return folder;
  }

  Future<void> rename(String id, String name) async {
    await _replace(id, (folder) => folder.copyWith(name: name.trim()));
  }

  Future<void> setColor(String id, int colorIndex) async {
    await _replace(id, (folder) => folder.copyWith(colorIndex: colorIndex));
  }

  Future<void> addItem(String folderId, String itemKey) async {
    final folder = byId(folderId);
    if (folder == null || folder.itemKeys.contains(itemKey)) return;
    if (!canContain(folderId, itemKey)) return;
    await _replace(
      folderId,
      (f) => f.copyWith(itemKeys: [...f.itemKeys, itemKey]),
    );
  }

  Future<void> removeItem(String folderId, String itemKey) async {
    await _replace(
      folderId,
      (f) => f.copyWith(
        itemKeys: [
          for (final key in f.itemKeys)
            if (key != itemKey) key,
        ],
      ),
    );
  }

  /// Deletes a folder and drops it from every other folder that held it,
  /// plus from the pinned apps.
  Future<void> remove(String id) async {
    final key = keyFor(id);
    await PinnedAppsController.instance.remove(key);
    await _save([
      for (final folder in value)
        if (folder.id != id)
          folder.copyWith(
            itemKeys: [
              for (final itemKey in folder.itemKeys)
                if (itemKey != key) itemKey,
            ],
          ),
    ]);
  }

  /// Whether [itemKey] may go into the folder [folderId] - false when that
  /// would put a folder inside itself, directly or through a chain of
  /// subfolders (which would make opening it loop forever).
  bool canContain(String folderId, String itemKey) {
    if (!itemKey.startsWith(folderKeyPrefix)) return true;
    final childId = itemKey.substring(folderKeyPrefix.length);
    if (childId == folderId) return false;
    // A cycle appears exactly when the folder we're adding into can already
    // be reached from the one being added.
    return !_reaches(childId, folderId);
  }

  bool _reaches(String fromId, String targetId, [Set<String>? seen]) {
    final visited = seen ?? <String>{};
    if (!visited.add(fromId)) return false;
    final folder = byId(fromId);
    if (folder == null) return false;
    for (final key in folder.itemKeys) {
      if (!key.startsWith(folderKeyPrefix)) continue;
      final nextId = key.substring(folderKeyPrefix.length);
      if (nextId == targetId) return true;
      if (_reaches(nextId, targetId, visited)) return true;
    }
    return false;
  }

  Future<void> _replace(
    String id,
    LauncherFolder Function(LauncherFolder) update,
  ) async {
    await _save([
      for (final folder in value)
        if (folder.id == id) update(folder) else folder,
    ]);
  }

  Future<void> _save(List<LauncherFolder> folders) async {
    value = folders;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      [for (final folder in folders) jsonEncode(folder.toJson())],
    );
  }
}
