import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Starts apps, and is the one place that knows *where on screen* a start
/// came from.
///
/// The plugin's `InstalledApps.startApp` fires a bare launch intent, which
/// leaves Android to open the app with its own default cross-fade from
/// nowhere. Handing over the rectangle of the icon that was tapped instead
/// makes the window grow out of that icon - the single most visible
/// difference between a launcher that was assembled and one that was built,
/// and the reason a stock home screen feels attached to the apps on it.
///
/// It also owns the pair: two apps opened side by side in split screen, one
/// entry on the home screen. See `MainActivity.launchPair` for why the
/// second one goes up on a delay.
class AppLauncher {
  AppLauncher._();

  static const _channel = MethodChannel('hanneslauncher/launch');

  /// Set once by the app so a home button press can be answered - see
  /// [onHomePressed].
  static VoidCallback? _homeHandler;

  static bool _listening = false;

  /// Called when the home button is pressed while the launcher is already in
  /// front. Android delivers that as a new intent rather than as a restart,
  /// so it is not something Flutter notices on its own.
  static set onHomePressed(VoidCallback? handler) {
    _homeHandler = handler;
    if (_listening) return;
    _listening = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'homePressed') _homeHandler?.call();
      return null;
    });
  }

  /// The rectangle a widget occupies on screen, for [launch] to grow the app
  /// out of. Null when the widget is gone or was never laid out, which the
  /// launch below treats as "no animation" rather than as a failure.
  static Rect? boundsOf(BuildContext? context) {
    if (context == null) return null;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    final origin = box.localToGlobal(Offset.zero);
    final ratio = View.of(context).devicePixelRatio;
    // Android wants physical pixels; Flutter measures in logical ones.
    return Rect.fromLTWH(
      origin.dx * ratio,
      origin.dy * ratio,
      box.size.width * ratio,
      box.size.height * ratio,
    );
  }

  /// Starts [package], growing it out of [from] when one is given.
  ///
  /// False means the app could not be started at all - uninstalled, or with
  /// no launchable activity. A missing or refused animation is not a
  /// failure: the app still opens, just the way it used to.
  static Future<bool> launch(String package, {Rect? from}) async {
    try {
      final ok = await _channel.invokeMethod<bool>('launch', {
        'package': package,
        ..._rect(from),
      });
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens two apps beside each other.
  ///
  /// On a phone too old for split screen this opens [first] alone, which is
  /// what the entry promises to do and better than refusing.
  static Future<bool> launchPair(
    String first,
    String second, {
    Rect? from,
  }) async {
    try {
      final ok = await _channel.invokeMethod<bool>('launchPair', {
        'first': first,
        'second': second,
        ..._rect(from),
      });
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Whether this phone can put two apps on screen at once. Asked once by
  /// the settings screen, so a pair is never offered where it cannot work.
  static Future<bool> supportsSplitScreen() async {
    try {
      return await _channel.invokeMethod<bool>('supportsSplitScreen') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Map<String, Object?> _rect(Rect? from) => from == null
      ? const {}
      : {
          'left': from.left,
          'top': from.top,
          'width': from.width,
          'height': from.height,
        };
}
