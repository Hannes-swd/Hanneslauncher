import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the currently selected home screen wallpaper and keeps it in sync
/// across the app. The chosen image is copied into the app's own documents
/// directory so it keeps working even if the original gallery file is moved
/// or deleted, and its path is persisted so it survives app restarts.
class WallpaperController extends ValueNotifier<File?> {
  WallpaperController._() : super(null);

  static final WallpaperController instance = WallpaperController._();

  static const _prefsKey = 'wallpaper_image_path';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_prefsKey);
    if (path != null && File(path).existsSync()) {
      value = File(path);
    }
  }

  Future<void> pickAndSetImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final appDir = await getApplicationDocumentsDirectory();
    final extension = p.extension(picked.path);
    final savedPath = p.join(appDir.path, 'wallpaper$extension');

    // Remove any previously saved wallpaper file first.
    final oldFile = File(savedPath);
    if (oldFile.existsSync()) {
      await oldFile.delete();
    }

    final savedFile = await File(picked.path).copy(savedPath);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, savedFile.path);

    value = savedFile;
  }

  Future<void> clear() async {
    final current = value;
    if (current != null && current.existsSync()) {
      await current.delete();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    value = null;
  }
}
