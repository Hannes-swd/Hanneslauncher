import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Hears from Android when an app is installed, removed or updated.
///
/// What this replaces: the home screen used to re-read every installed app
/// each time it came back to the foreground - which is after every single
/// app the user opens and closes. That read pulls each app's icon across the
/// platform channel as a bitmap, so on a phone with a couple of hundred apps
/// it is megabytes of decoding, several times an hour, virtually always to
/// conclude that nothing had changed.
///
/// Android knows when something changes and will say so. So the list is now
/// read once and then only when it is actually out of date, and coming back
/// from an app costs nothing.
///
/// See `MainActivity.registerPackageReceiver` for the Android half.
class InstalledPackagesWatch {
  InstalledPackagesWatch._();

  static final InstalledPackagesWatch instance = InstalledPackagesWatch._();

  static const _channel = MethodChannel('hanneslauncher/packages');

  /// Installing an app fires several of these - removed, added, replaced -
  /// and a system update fires one per package in a burst. Collapsing them
  /// into one reload is the difference between a single read and thirty.
  static const _debounce = Duration(milliseconds: 600);

  Timer? _pending;
  final _controller = StreamController<void>.broadcast();
  bool _started = false;

  /// Fires once per settled burst of changes. Carries nothing: which package
  /// changed is not enough to update the list correctly anyway - a rename,
  /// an icon change and a new launchable activity all arrive as "changed" -
  /// so the answer is always to re-read, just not constantly.
  Stream<void> get changes => _controller.stream;

  /// Begins listening. Safe to call more than once.
  ///
  /// Three answers, not two, and the distinction matters more than it looks:
  ///
  ///   true  - listening, and something changed before anyone was. The
  ///           caller's list was read before that and is already stale.
  ///   false - listening, nothing missed.
  ///   null  - the platform did not answer at all. The caller must keep
  ///           whatever fallback it had.
  ///
  /// That last one is the whole reason this returns a nullable. Folding it
  /// into `false` would read as "listening, nothing missed" on exactly the
  /// phones where nothing is being listened to - and the app list would then
  /// sit there stale forever, with the reload-on-resume that used to cover
  /// it switched off on the strength of a channel that never replied.
  Future<bool?> start() async {
    if (_started) return false;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'packagesChanged') _schedule();
      return null;
    });
    try {
      final missed = await _channel.invokeMethod<bool>('ready');
      if (missed == null) return null;
      _started = true;
      return missed;
    } catch (_) {
      return null;
    }
  }

  void _schedule() {
    _pending?.cancel();
    _pending = Timer(_debounce, () {
      _pending = null;
      if (!_controller.isClosed) _controller.add(null);
    });
  }

  /// Makes the next [changes] event arrive at once. For tests.
  @visibleForTesting
  void debugFlush() {
    _pending?.cancel();
    _pending = null;
    if (!_controller.isClosed) _controller.add(null);
  }

  /// Pretends Android reported a change. For tests.
  @visibleForTesting
  void debugNotify() => _schedule();
}
