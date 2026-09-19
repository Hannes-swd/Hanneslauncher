/// The wallpapers that ship inside the app, read straight out of the asset
/// manifest.
///
/// There is deliberately no list of them in the code. `pubspec.yaml` declares
/// the whole `assets/wallpapers/` folder, so the folder *is* the list: a
/// picture dropped in there shows up in the settings after the next build,
/// and one deleted disappears, without a second place that has to be told
/// about it. `test/wallpaper_library_test.dart` is what keeps that promise -
/// it fails while the folder is undeclared, empty, or holds a file in a
/// format none of this can draw.
library;

import 'package:flutter/services.dart';

/// The folder inside the bundle. Also the prefix an entry is recognised by,
/// so nothing else in the manifest (fonts, a package's own assets) can end
/// up in the picker.
const wallpaperAssetFolder = 'assets/wallpapers/';

/// What a bundled wallpaper may be. Stills and animated GIFs are drawn by
/// `Image`, the video containers by the video player - the same split
/// `wallpaper_controller.dart` makes, which is why a file's extension is
/// carried through to the copy on disk untouched.
const wallpaperAssetExtensions = {
  '.png', '.jpg', '.jpeg', '.webp', '.gif',
  '.mp4', '.m4v', '.mov', '.webm',
};

/// One entry in the built-in library.
class WallpaperAsset {
  const WallpaperAsset(this.key, this.name);

  /// The full asset path, e.g. `assets/wallpapers/aurora.png`. Also what is
  /// persisted, so the settings can show which tile the current wallpaper
  /// came from.
  final String key;

  /// What the tile is labelled with, read off the file name.
  final String name;
}

/// Every bundled wallpaper, sorted by name.
///
/// Empty rather than throwing when the manifest can't be read: a launcher
/// whose library is missing is a settings screen with one section fewer, not
/// a launcher that won't start.
Future<List<WallpaperAsset>> loadWallpaperAssets() async {
  final List<String> keys;
  try {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    keys = manifest.listAssets();
  } catch (_) {
    return const [];
  }

  final assets = <WallpaperAsset>[];
  for (final key in keys) {
    if (!key.startsWith(wallpaperAssetFolder)) continue;
    final name = key.substring(wallpaperAssetFolder.length);
    // Resolution variants ("2.0x/aurora.png") are listed next to the picture
    // they belong to; they are the same wallpaper and must not become a
    // second tile. Flutter picks the right variant for the screen by itself.
    if (name.contains('/')) continue;
    if (!wallpaperAssetExtensions.contains(_extensionOf(name))) continue;
    assets.add(WallpaperAsset(key, wallpaperAssetName(name)));
  }
  assets.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return assets;
}

/// The label for a file name: `sakura-night.png` becomes `Sakura night`.
/// Keeps the picker's names in the file names, so naming a new wallpaper is
/// the same act as adding it.
String wallpaperAssetName(String fileName) {
  final stem = fileName.substring(
    0,
    fileName.length - _extensionOf(fileName).length,
  );
  final words = stem.replaceAll(RegExp(r'[_-]+'), ' ').trim();
  if (words.isEmpty) return fileName;
  return words[0].toUpperCase() + words.substring(1);
}

String _extensionOf(String name) {
  final dot = name.lastIndexOf('.');
  if (dot <= 0) return '';
  return name.substring(dot).toLowerCase();
}
