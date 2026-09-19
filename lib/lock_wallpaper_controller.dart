import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The picture on Android's own lock screen.
///
/// This is the one wallpaper the launcher does not draw itself: the lock
/// screen belongs to the system, and the only thing an app can do with it is
/// hand Android a picture through `WallpaperManager` (see the
/// `hanneslauncher/wallpaper` channel in `MainActivity.kt`). So the home
/// screen background and this one are deliberately kept apart - setting one
/// never touches the other.
///
/// A copy of the chosen picture is kept here all the same, for two reasons:
/// Android will not hand a lock screen wallpaper back out again, so the copy
/// is the only way the settings can show what is on it, and it is what lets
/// a backup carry the picture like any other.
///
/// Stills only. A video or a GIF would be handed to Android as its first
/// frame or not at all, which is why the picker here asks for an image
/// rather than for media the way the home screen one does.
class LockWallpaperController extends ValueNotifier<File?> {
  LockWallpaperController._() : super(null);

  static final LockWallpaperController instance = LockWallpaperController._();

  static const _channel = MethodChannel('hanneslauncher/wallpaper');

  static const _prefsKey = 'lock_wallpaper_path';
  static const _assetPrefsKey = 'lock_wallpaper_asset';
  static const _folder = 'lock_wallpaper';

  /// Which built-in library entry the current picture came from, or null for
  /// one out of the gallery. Only the picker's tick reads this.
  String? get assetKey => _assetKey;
  String? _assetKey;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_prefsKey);
    if (path != null && File(path).existsSync()) {
      _assetKey = prefs.getString(_assetPrefsKey);
      value = File(path);
    }
  }

  /// Whether this phone lets an app set the lock screen at all.
  ///
  /// False on Android 6 and older, which has no separate lock screen
  /// wallpaper, and while a device policy has the wallpaper locked down. The
  /// settings screen asks before offering anything, so the buttons are
  /// simply not there rather than there and failing.
  static Future<bool> supported() async {
    try {
      return await _channel.invokeMethod<bool>('supportsLockScreen') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the gallery and puts the picked picture on the lock screen.
  ///
  /// Null when the picker was dismissed, true/false for whether Android took
  /// the picture - the caller says so on screen, because a lock screen that
  /// did not change is something the user would otherwise only find out
  /// about at the next unlock.
  Future<bool?> pickAndSet() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return null;
    return _apply(File(picked.path), p.extension(picked.path), null);
  }

  /// Puts one of the wallpapers that ship with the app on the lock screen.
  Future<bool> setAsset(String assetKey) async {
    final ByteData data;
    try {
      data = await rootBundle.load(assetKey);
    } catch (_) {
      return false;
    }
    final temporary = File(
      p.join(
        (await getTemporaryDirectory()).path,
        'lock_asset${p.extension(assetKey)}',
      ),
    );
    await temporary.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    try {
      return await _apply(temporary, p.extension(assetKey), assetKey);
    } finally {
      if (temporary.existsSync()) await temporary.delete();
    }
  }

  /// Puts a picture out of a backup back on the lock screen.
  ///
  /// A restore is meant to give back the phone that was backed up, and the
  /// lock screen is part of what the user set up - so it is applied, not
  /// just remembered. If Android refuses, the copy is still kept: the
  /// settings then show the picture with the same button to try again.
  Future<void> restoreFile(File file, {String? assetKey}) async {
    await _apply(file, p.extension(file.path), assetKey, keepOnFailure: true);
  }

  /// Takes the launcher's picture off the lock screen again, which puts
  /// Android back to showing the home screen wallpaper there.
  Future<void> clear() async {
    try {
      await _channel.invokeMethod<bool>('clearLockScreen');
    } catch (_) {
      // Nothing to undo - the stored copy still goes, so the settings and
      // the phone say the same thing either way.
    }
    final previous = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    await prefs.remove(_assetPrefsKey);
    _assetKey = null;
    value = null;
    await _discard(previous);
  }

  /// Hands [source] to Android and, if it took it, keeps a copy as the
  /// picture the settings show.
  Future<bool> _apply(
    File source,
    String extension,
    String? assetKey, {
    bool keepOnFailure = false,
  }) async {
    var ok = false;
    try {
      ok =
          await _channel.invokeMethod<bool>('setLockScreen', {
            'path': source.path,
          }) ??
          false;
    } catch (_) {
      // An older build of the app with no such channel answers with a
      // MissingPluginException. Same as Android saying no.
      ok = false;
    }
    if (!ok && !keepOnFailure) return false;

    try {
      // A fresh name per picture: Image.file keys its decoded-bitmap cache
      // on the path, so a fixed one would keep showing the previous lock
      // screen in the settings after the phone had already changed.
      final dir = Directory(
        p.join((await getApplicationDocumentsDirectory()).path, _folder),
      );
      if (!dir.existsSync()) await dir.create(recursive: true);
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final saved = await source.copy(
        p.join(dir.path, 'lock_$stamp$extension'),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, saved.path);
      if (assetKey == null) {
        await prefs.remove(_assetPrefsKey);
      } else {
        await prefs.setString(_assetPrefsKey, assetKey);
      }

      final previous = value;
      _assetKey = assetKey;
      value = saved;
      if (previous?.path != saved.path) await _discard(previous);
    } catch (_) {
      // The picture is on the lock screen either way - this was only the
      // copy the settings show it by. Better a section that says nothing is
      // set than a restore that stops half way through.
    }
    return ok;
  }

  Future<void> _discard(File? file) async {
    if (file == null) return;
    await FileImage(file).evict();
    if (file.existsSync()) await file.delete();
  }
}
