import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Everything the app shortcuts need from Android goes over one method
/// channel, and a method the Kotlin side does not answer fails in the
/// quietest way there is: `notImplemented` comes back as a
/// `MissingPluginException`, and `app_shortcuts.dart` catches every one of
/// those the same way it catches "this launcher isn't the home app" - by
/// answering "no shortcuts".
///
/// So a renamed method here doesn't break anything loudly. It produces a
/// launcher whose long-press menu is permanently empty, with an explanation
/// on screen for why that is perfectly normal. The two sides are checked
/// against each other here rather than left to whoever remembers to rename
/// both.
void main() {
  final dart = File('lib/app_shortcuts.dart').readAsStringSync();
  final kotlin = File(
    'android/app/src/main/kotlin/com/example/hanneslauncher/MainActivity.kt',
  ).readAsStringSync();

  /// The method names the Dart side asks the channel for.
  List<String> invokedMethods() {
    return [
      for (final match in RegExp(
        r"_channel\.invoke(?:List|Map)?Method<[^>]*>\(\s*'([^']+)'",
      ).allMatches(dart))
        match.group(1)!,
    ];
  }

  /// The body of the `when (call.method)` that serves the shortcuts channel
  /// in MainActivity.
  String handlerBody() {
    final channel = kotlin.lastIndexOf('appShortcutsChannelName)');
    expect(
      channel,
      isNot(-1),
      reason: 'the app shortcuts MethodChannel moved or was renamed',
    );
    final start = kotlin.indexOf('when (call.method) {', channel);
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

  test('every method the shortcuts ask for is answered on the Android side', () {
    final methods = invokedMethods();
    // A guard that guards nothing would pass just as quietly as the bug.
    expect(methods, isNotEmpty);
    expect(methods, containsAll(<String>['available', 'list', 'launch', 'pin']));

    final body = handlerBody();
    for (final method in methods) {
      expect(
        body,
        contains('"$method" ->'),
        reason:
            'lib/app_shortcuts.dart calls "$method", but MainActivity.kt does '
            'not answer it - the call would come back as a missing plugin and '
            'be swallowed as "no shortcuts"',
      );
    }
  });

  test('both sides name the same channel', () {
    final dartName = RegExp(
      r"MethodChannel\('([^']+)'\)",
    ).firstMatch(dart)?.group(1);
    final kotlinName = RegExp(
      r'appShortcutsChannelName = "([^"]+)"',
    ).firstMatch(kotlin)?.group(1);

    expect(dartName, isNotNull, reason: 'no MethodChannel in app_shortcuts.dart');
    expect(
      kotlinName,
      isNotNull,
      reason: 'appShortcutsChannelName is gone from MainActivity.kt',
    );
    expect(dartName, kotlinName);
  });

  test('the Kotlin side answers nothing the Dart side never asks for', () {
    final answered = [
      for (final match in RegExp(r'"([a-zA-Z]+)" ->').allMatches(handlerBody()))
        match.group(1)!,
    ];
    // The other direction of the same drift: a method left behind after the
    // Dart call that used it was renamed is dead weight that reads like a
    // working feature.
    expect(answered, isNotEmpty);
    for (final method in answered) {
      expect(
        invokedMethods(),
        contains(method),
        reason:
            'MainActivity.kt answers "$method", but nothing in '
            'lib/app_shortcuts.dart ever calls it',
      );
    }
  });
}
