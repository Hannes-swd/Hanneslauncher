import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Everything the badges need from Android goes over one method channel, and
/// a method the Kotlin side does not answer fails in the quietest way there
/// is: `notImplemented` comes back as a `MissingPluginException`, the Dart
/// side catches it the way it catches a missing permission, and the result
/// is a launcher with no badges and no complaint anywhere.
///
/// That is exactly the failure this whole feature already spent a round on,
/// so the two sides are checked against each other here rather than left to
/// whoever remembers to rename both.
void main() {
  final dart = File('lib/notification_badges_controller.dart').readAsStringSync();
  final kotlin = File(
    'android/app/src/main/kotlin/com/example/hanneslauncher/MainActivity.kt',
  ).readAsStringSync();

  /// The method names the controller asks the channel for.
  List<String> invokedMethods() {
    return [
      for (final match in RegExp(
        r"_channel\.invoke(?:Map)?Method<[^>]*>\('([^']+)'\)",
      ).allMatches(dart))
        match.group(1)!,
    ];
  }

  /// The body of the `when (call.method)` that serves the notifications
  /// channel in MainActivity.
  String handlerBody() {
    final channel = kotlin.lastIndexOf('notificationsChannelName,');
    expect(
      channel,
      isNot(-1),
      reason: 'the notifications MethodChannel moved or was renamed',
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

  test('every method the badges ask for is answered on the Android side', () {
    final methods = invokedMethods();
    // A guard that guards nothing would pass just as quietly as the bug.
    expect(methods, isNotEmpty);
    expect(methods, contains('counts'));

    final body = handlerBody();
    for (final method in methods) {
      expect(
        body.contains('"$method" ->'),
        isTrue,
        reason:
            'NotificationCounts calls "$method" on hanneslauncher/notifications, '
            'but MainActivity.kt does not answer it - badges would silently '
            'stay empty',
      );
    }
  });

  test('the Android side answers nothing the badges never ask for', () {
    final methods = invokedMethods().toSet();
    final answered = [
      for (final match in RegExp(r'"([^"]+)" ->').allMatches(handlerBody()))
        match.group(1)!,
    ];

    expect(answered, isNotEmpty);
    expect(
      answered.toSet().difference(methods),
      isEmpty,
      reason:
          'left over on the Kotlin side after a rename - dead code that reads '
          'like the channel still works',
    );
  });
}
