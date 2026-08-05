import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How a wallpaper file gets on screen. Still pictures and animated GIFs are
/// both drawn by `Image.file` - it plays GIFs by itself - while everything
/// else needs the video player.
enum WallpaperKind { image, video }

/// The containers the gallery picker can hand over as a video. Anything not
/// listed here is treated as a picture, which is the harmless way round: a
/// picture that won't decode shows nothing, a video fed to `Image.file`
/// would throw on every frame.
const _videoExtensions = {
  '.mp4', '.m4v', '.mov', '.webm', '.mkv', '.3gp', '.avi', '.ts', '.mpeg',
};

/// The chosen background together with what it is, so every place that draws
/// it knows which of the two paths to take.
@immutable
class Wallpaper {
  const Wallpaper(this.file, this.kind);

  /// Reads the kind off the file's extension - the picker keeps it when the
  /// file is copied, and it's all that's persisted.
  Wallpaper.of(File file)
    : this(
        file,
        _videoExtensions.contains(p.extension(file.path).toLowerCase())
            ? WallpaperKind.video
            : WallpaperKind.image,
      );

  final File file;
  final WallpaperKind kind;

  bool get isVideo => kind == WallpaperKind.video;
}

/// Holds the currently selected home screen wallpaper and keeps it in sync
/// across the app. The chosen file is copied into the app's own documents
/// directory so it keeps working even if the original gallery file is moved
/// or deleted, and its path is persisted so it survives app restarts.
class WallpaperController extends ValueNotifier<Wallpaper?> {
  WallpaperController._() : super(null);

  static final WallpaperController instance = WallpaperController._();

  // Named after pictures because that's all it held first; kept as it is so
  // a wallpaper set by an older version is still found after an update.
  static const _prefsKey = 'wallpaper_image_path';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_prefsKey);
    if (path != null && File(path).existsSync()) {
      value = Wallpaper.of(File(path));
    }
  }

  /// Opens the gallery for a picture *or* a video and makes the pick the new
  /// wallpaper.
  Future<void> pickAndSet() async {
    final picked = await ImagePicker().pickMedia();
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
    value = Wallpaper.of(savedFile);
    if (previous != null && previous.file.path != savedFile.path) {
      await _discard(previous);
    }
  }

  Future<void> clear() async {
    final current = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    value = null;
    if (current != null) {
      await _discard(current);
    }
  }

  Future<void> _discard(Wallpaper wallpaper) async {
    // Videos aren't in the image cache; a still that stayed there would be
    // redrawn from memory even after its file is gone.
    if (!wallpaper.isVideo) {
      await FileImage(wallpaper.file).evict();
    }
    if (wallpaper.file.existsSync()) {
      await wallpaper.file.delete();
    }
  }
}
