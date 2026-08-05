import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hanneslauncher/wallpaper_controller.dart';

void main() {
  WallpaperKind kindOf(String path) => Wallpaper.of(File(path)).kind;

  group('what a wallpaper file is', () {
    test('videos go to the player', () {
      for (final path in [
        '/data/wallpaper_1.mp4',
        '/data/wallpaper_1.MP4',
        '/data/wallpaper_1.mov',
        '/data/wallpaper_1.webm',
        '/data/wallpaper_1.mkv',
        '/data/wallpaper_1.3gp',
      ]) {
        expect(kindOf(path), WallpaperKind.video, reason: path);
      }
    });

    test('an animated GIF is a picture - Image plays it by itself', () {
      expect(kindOf('/data/wallpaper_1.gif'), WallpaperKind.image);
    });

    test('stills are pictures', () {
      for (final path in [
        '/data/wallpaper_1.jpg',
        '/data/wallpaper_1.jpeg',
        '/data/wallpaper_1.png',
        '/data/wallpaper_1.webp',
      ]) {
        expect(kindOf(path), WallpaperKind.image, reason: path);
      }
    });

    test('anything unknown falls back to a picture', () {
      // The harmless way round: a picture that won't decode paints nothing,
      // while a video handed to Image.file would throw on every frame.
      expect(kindOf('/data/wallpaper_1'), WallpaperKind.image);
      expect(kindOf('/data/wallpaper_1.bin'), WallpaperKind.image);
    });

    test('a path with a dot in the folder name is read at the file', () {
      expect(kindOf('/data/my.videos/wallpaper_1.png'), WallpaperKind.image);
    });
  });
}
