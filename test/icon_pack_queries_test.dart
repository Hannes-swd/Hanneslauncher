import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// An icon pack is found by asking Android which apps declare one of a fixed
/// list of theme actions. On Android 11+ that question is answered with
/// nothing at all unless the manifest also declares the same action under
/// `<queries>` - no error, no warning, just an empty list and a settings
/// screen saying no pack is installed.
///
/// That makes adding an action to `IconPacks.kt` and forgetting the manifest a
/// silent failure that only shows up on a phone, with a pack installed, which
/// is the worst place to notice it. So the two are checked against each other
/// here instead of being left to memory.
void main() {
  final kotlin = File(
    'android/app/src/main/kotlin/com/example/hanneslauncher/IconPacks.kt',
  ).readAsStringSync();
  final manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();

  /// The string literals inside `supportedActions = listOf(...)`.
  List<String> supportedActions() {
    final start = kotlin.indexOf('supportedActions = listOf(');
    expect(start, isNot(-1), reason: 'supportedActions moved or was renamed');
    final end = kotlin.indexOf(')', start);
    final body = kotlin.substring(start, end);
    return [
      for (final match in RegExp('"([^"]+)"').allMatches(body))
        match.group(1)!,
    ];
  }

  test('every icon pack action is declared in the manifest', () {
    final actions = supportedActions();
    // A guard that guards nothing would pass just as quietly as the bug.
    expect(actions, isNotEmpty);

    for (final action in actions) {
      expect(
        manifest.contains('<action android:name="$action"/>'),
        isTrue,
        reason:
            'AndroidManifest.xml has no <queries> action entry for $action, '
            'so packs declaring it are invisible on Android 11+',
      );
      expect(
        manifest.contains('<category android:name="$action"/>'),
        isTrue,
        reason:
            'AndroidManifest.xml has no <queries> category entry for $action, '
            'so packs hanging it off MAIN are invisible on Android 11+',
      );
    }
  });
}
