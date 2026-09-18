import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanneslauncher/installed_packages_watch.dart';

/// The app list stopped reloading itself every time the launcher came back
/// to the foreground, and now leans on Android saying when the installed
/// apps changed. That trade is only safe while the "nobody answered" case is
/// told apart from "listening, nothing missed" - these hold that apart.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('hanneslauncher/packages');

  void answer(Future<Object?> Function(MethodCall call)? handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, handler);
  }

  tearDown(() => answer(null));

  test('a platform that never answers reports null, not false', () async {
    // No handler at all is what an older build, or a phone that refused the
    // receiver registration, looks like from here.
    answer(null);
    expect(await InstalledPackagesWatch.instance.start(), isNull);
  });

  test('a burst of changes becomes one reload', () async {
    final watch = InstalledPackagesWatch.instance;
    var fired = 0;
    final subscription = watch.changes.listen((_) => fired++);

    // Installing one app fires removed, added and replaced; a system update
    // fires one per package.
    watch.debugNotify();
    watch.debugNotify();
    watch.debugNotify();
    expect(fired, 0, reason: 'nothing until the burst settles');

    watch.debugFlush();
    await Future<void>.delayed(Duration.zero);
    expect(fired, 1);

    await subscription.cancel();
  });
}
