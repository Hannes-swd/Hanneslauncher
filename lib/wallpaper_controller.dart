import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart' show rootBundle;
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

/// Whether the file (or asset) at [path] is one of the video containers,
/// read off its extension alone.
///
/// Public because the library picker has to answer the same question about
/// an asset it has no file for - and asking it in two places with two lists
/// is how one of them ends up drawing an mp4 with `Image`.
bool isVideoWallpaperPath(String path) =>
    _videoExtensions.contains(p.extension(path).toLowerCase());

/// The chosen background together with what it is, so every place that draws
/// it knows which of the two paths to take.
@immutable
class Wallpaper {
  const Wallpaper(this.file, this.kind, {this.assetKey});

  /// Reads the kind off the file's extension - the picker keeps it when the
  /// file is copied, and it's all that's persisted.
  Wallpaper.of(File file, {String? assetKey})
    : this(
        file,
        isVideoWallpaperPath(file.path)
            ? WallpaperKind.video
            : WallpaperKind.image,
        assetKey: assetKey,
      );

  final File file;
  final WallpaperKind kind;

  /// Which entry of the built-in library this came from, or null for a
  /// picture out of the gallery.
  ///
  /// The file on disk is a copy either way - that is what keeps drawing it,
  /// backing it up and deleting it one code path rather than two. This is
  /// only so the library can show which tile is the one currently on screen;
  /// nothing draws from it.
  final String? assetKey;

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

  /// Which built-in library entry the current file was copied from. Absent
  /// for a gallery pick, and for every wallpaper set before the library
  /// existed - both of which simply mean "no tile is the current one".
  static const _assetKey = 'wallpaper_asset';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_prefsKey);
    if (path != null && File(path).existsSync()) {
      value = Wallpaper.of(File(path), assetKey: prefs.getString(_assetKey));
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
    await _install(savedFile, null);
  }

  /// Makes one of the wallpapers that ship with the app the current one.
  ///
  /// Its bytes are written into the same documents directory a gallery pick
  /// lands in, under the same kind of name, so from here on there is no
  /// difference between the two: the same widget draws it, the same backup
  /// carries it, the same delete throws it away. Only [Wallpaper.assetKey]
  /// remembers where it came from, for the tick in the picker.
  ///
  /// Returns false if the asset could not be read - a wallpaper deleted from
  /// the folder while its key was still persisted, say.
  Future<bool> setAsset(String assetKey) async {
    final ByteData data;
    try {
      data = await rootBundle.load(assetKey);
    } catch (_) {
      return false;
    }

    final appDir = await getApplicationDocumentsDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final savedPath = p.join(
      appDir.path,
      'wallpaper_$stamp${p.extension(assetKey)}',
    );
    final savedFile = await File(savedPath).writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );

    await _install(savedFile, assetKey);
    return true;
  }

  /// The bookkeeping every way of setting a wallpaper ends with: persist the
  /// path and where it came from, swap the value, then throw the old file
  /// away.
  Future<void> _install(File file, String? assetKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, file.path);
    if (assetKey == null) {
      await prefs.remove(_assetKey);
    } else {
      await prefs.setString(_assetKey, assetKey);
    }

    // Only once the new one is showing, so nothing ever paints a file that
    // has just been deleted. Covers the old fixed-name file too.
    final previous = value;
    value = Wallpaper.of(file, assetKey: assetKey);
    if (previous != null && previous.file.path != file.path) {
      await _discard(previous);
    }
  }

  /// Makes an already-saved file the wallpaper, without a picker.
  ///
  /// What a restore needs: the backup carries the picture's bytes, the
  /// caller has written them somewhere durable, and all that is left is the
  /// same bookkeeping [pickAndSet] does afterwards - persist the path, swap
  /// the value, throw the old file away.
  Future<void> restoreFile(File file, {String? assetKey}) async {
    await _install(file, assetKey);
  }

  Future<void> clear() async {
    final current = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    await prefs.remove(_assetKey);
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
