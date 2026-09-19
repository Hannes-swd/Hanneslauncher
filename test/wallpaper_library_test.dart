import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hanneslauncher/wallpaper_library.dart';

/// Two things that are only true as long as nobody looks away.
///
/// The built-in wallpapers have no list in the code on purpose - the folder
/// is the list. That is only pleasant while the folder is actually declared
/// in `pubspec.yaml` and holds nothing the app can't draw: an undeclared
/// folder ships an app with an empty library and no error anywhere, and a
/// `.heic` dropped in beside the others would become a tile that shows
/// nothing when tapped. Both are found here instead of on a phone.
///
/// The lock screen half goes over a method channel, where a renamed method
/// comes back as `notImplemented` and is caught as "this phone can't do it" -
/// which is exactly what a phone that can't do it looks like. So the two
/// sides are checked against each other, the same way
/// `app_shortcuts_channel_guard_test.dart` does it.
void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final folder = Directory('assets/wallpapers');

  group('the built-in library', () {
    test('its folder is declared as an asset', () {
      expect(
        pubspec.contains('- $wallpaperAssetFolder'),
        isTrue,
        reason:
            'pubspec.yaml must declare "- $wallpaperAssetFolder" under '
            'flutter/assets, or none of the wallpapers are in the build and '
            'the picker is empty on every phone.',
      );
    });

    test('it ships at least one wallpaper', () {
      expect(folder.existsSync(), isTrue, reason: '${folder.path} is missing');
      // A declared folder with nothing in it fails the build itself, and a
      // library with nothing in it is the feature switched off.
      expect(_wallpaperFiles(folder), isNotEmpty);
    });

    test('every file in it is a format the app can draw', () {
      final wrong = [
        for (final file in _wallpaperFiles(folder))
          if (!wallpaperAssetExtensions.contains(_extensionOf(file)))
            _nameOf(file),
      ]..sort();

      expect(
        wrong,
        isEmpty,
        reason:
            'These sit in ${folder.path} but are not one of '
            '${wallpaperAssetExtensions.join(', ')}. A tile would be built '
            'for each and show nothing: ${wrong.join(', ')}',
      );
    });

    test('a file name becomes the name shown on the tile', () {
      expect(wallpaperAssetName('aurora.png'), 'Aurora');
      expect(wallpaperAssetName('sakura-night.jpg'), 'Sakura night');
      expect(wallpaperAssetName('deep_ocean.webp'), 'Deep ocean');
    });
  });

  group('the lock screen channel', () {
    final dart = File('lib/lock_wallpaper_controller.dart').readAsStringSync();
    final kotlin = File(
      'android/app/src/main/kotlin/com/example/hanneslauncher/MainActivity.kt',
    ).readAsStringSync();

    test('both sides use the same channel name', () {
      final name = RegExp(
        r"MethodChannel\('([^']+)'\)",
      ).firstMatch(dart)?.group(1);
      expect(name, isNotNull);
      expect(
        kotlin.contains('wallpaperChannelName = "$name"'),
        isTrue,
        reason: 'MainActivity.kt serves a different channel than $name',
      );
    });

    test('every method the lock screen asks for is answered', () {
      final methods = [
        for (final match in RegExp(
          r"_channel\.invokeMethod<[^>]*>\(\s*'([^']+)'",
        ).allMatches(dart))
          match.group(1)!,
      ];
      // A guard that guards nothing would pass just as quietly as the bug.
      expect(methods, isNotEmpty);
      expect(
        methods,
        containsAll(<String>[
          'supportsLockScreen',
          'setLockScreen',
          'clearLockScreen',
        ]),
      );

      final handler = _handlerBody(kotlin, 'wallpaperChannelName)');
      for (final method in methods) {
        expect(
          handler.contains('"$method"'),
          isTrue,
          reason: 'MainActivity.kt does not answer "$method"',
        );
      }
    });

    test('the manifest asks for the permission it needs', () {
      // Setting a wallpaper without it throws a SecurityException, which is
      // caught and turned into "Android would not take that picture" - a
      // wrong answer that looks like a right one.
      expect(
        File('android/app/src/main/AndroidManifest.xml')
            .readAsStringSync()
            .contains('android.permission.SET_WALLPAPER'),
        isTrue,
      );
    });
  });
}

List<File> _wallpaperFiles(Directory folder) => [
  if (folder.existsSync())
    for (final entity in folder.listSync())
      if (entity is File) entity,
];

String _nameOf(File file) => file.uri.pathSegments.last;

String _extensionOf(File file) {
  final name = _nameOf(file);
  final dot = name.lastIndexOf('.');
  return dot <= 0 ? '' : name.substring(dot).toLowerCase();
}

/// The body of the `when (call.method)` that serves [channel] in
/// MainActivity.
String _handlerBody(String kotlin, String channel) {
  final at = kotlin.lastIndexOf(channel);
  expect(at, isNot(-1), reason: 'the $channel MethodChannel moved or was renamed');
  final start = kotlin.indexOf('when (call.method) {', at);
  expect(start, isNot(-1), reason: 'no method handler after the channel');
  var depth = 0;
  for (var i = kotlin.indexOf('{', start); i < kotlin.length; i++) {
    if (kotlin[i] == '{') depth++;
    if (kotlin[i] == '}') {
      depth--;
      if (depth == 0) return kotlin.substring(start, i);
    }
  }
  fail('the method handler is never closed');
}
