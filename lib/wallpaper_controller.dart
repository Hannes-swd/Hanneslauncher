import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
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
    // A fresh name per pick. Image.file keys its decoded-bitmap cache on the
    // file path alone, so one fixed name meant that choosing a second image
    // with the same extension kept redrawing the first one straight out of
    // the cache - the new file was on disk but never shown.
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final savedPath = p.join(appDir.path, 'wallpaper_$stamp$extension');

    final savedFile = await File(picked.path).copy(savedPath);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, savedFile.path);

    // Only once the new one is showing, so nothing ever paints a file that
    // has just been deleted. Covers the old fixed-name file too.
    final previous = value;
    value = savedFile;
    if (previous != null && previous.path != savedFile.path) {
      await FileImage(previous).evict();
      if (previous.existsSync()) await previous.delete();
    }
  }

  Future<void> clear() async {
    final current = value;
    if (current != null) {
      await FileImage(current).evict();
      if (current.existsSync()) await current.delete();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    value = null;
  }
}
