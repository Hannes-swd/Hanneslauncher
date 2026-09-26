import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// Tells Android to not intercept the given screen region for its own edge
/// gestures (e.g. swipe-from-edge-to-go-back), so a custom drag gesture
/// placed right at the screen edge (like the alphabet bar) gets first dibs
/// on touches there instead of losing the first attempt to the system.
///
/// The exclusion rect is set on the native window, which is shared by every
/// Flutter route (there is only one Activity) - so left applied while a
/// settings page is on top, it would also swallow the OS back-swipe there,
/// on whichever edge the alphabet bar happens to occupy. [setHomeTopmost]
/// is how the caller says the home screen isn't what's on top right now, so
/// the rect can be cleared until it is again.
class SystemGestureExclusion {
  static const _channel = MethodChannel('hanneslauncher/system_gestures');

  static double? _barWidth;
  static double? _top;
  static double? _bottom;
  static bool? _leftEdge;
  static bool _homeTopmost = true;

  /// Excludes the strip the alphabet bar occupies - on the left edge in the
  /// left-handed layout, on the right one otherwise. Remembered so it can be
  /// re-applied once the home screen is back on top after [setHomeTopmost].
  static Future<void> excludeBarEdge({
    required double barWidth,
    required double top,
    required double bottom,
    required bool leftEdge,
  }) async {
    _barWidth = barWidth;
    _top = top;
    _bottom = bottom;
    _leftEdge = leftEdge;
    if (_homeTopmost) await _apply();
  }

  /// Whether the home screen is the topmost route in the app. Anything
  /// pushed on top of it (settings pages, dialogs) gets the rect cleared for
  /// as long as it's showing, since none of them have an alphabet bar to
  /// protect and the OS back-swipe should work on both edges there.
  static Future<void> setHomeTopmost(bool topmost) async {
    if (_homeTopmost == topmost) return;
    _homeTopmost = topmost;
    if (topmost) {
      await _apply();
    } else {
      await _clear();
    }
  }

  static Future<void> _apply() async {
    final barWidth = _barWidth;
    final top = _top;
    final bottom = _bottom;
    final leftEdge = _leftEdge;
    if (barWidth == null || top == null || bottom == null || leftEdge == null) {
      return;
    }
    final view = ui.PlatformDispatcher.instance.views.first;
    final dpr = view.devicePixelRatio;
    final screenWidthLogical = view.physicalSize.width / dpr;
    final left = leftEdge ? 0.0 : screenWidthLogical - barWidth;

    try {
      await _channel.invokeMethod('setExclusionRect', {
        'left': left * dpr,
        'top': top * dpr,
        'right': (left + barWidth) * dpr,
        'bottom': bottom * dpr,
      });
    } catch (_) {
      // Best-effort only (e.g. unsupported on older Android or non-Android).
    }
  }

  static Future<void> _clear() async {
    try {
      await _channel.invokeMethod('setExclusionRect', {
        'left': 0.0,
        'top': 0.0,
        'right': 0.0,
        'bottom': 0.0,
      });
    } catch (_) {
      // Best-effort only (e.g. unsupported on older Android or non-Android).
    }
  }
}
