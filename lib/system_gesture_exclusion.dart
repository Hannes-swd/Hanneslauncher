import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// Tells Android to not intercept the given screen region for its own edge
/// gestures (e.g. swipe-from-edge-to-go-back), so a custom drag gesture
/// placed right at the screen edge (like the alphabet bar) gets first dibs
/// on touches there instead of losing the first attempt to the system.
class SystemGestureExclusion {
  static const _channel = MethodChannel('hanneslauncher/system_gestures');

  /// Excludes the strip the alphabet bar occupies - on the left edge in the
  /// left-handed layout, on the right one otherwise.
  static Future<void> excludeBarEdge({
    required double barWidth,
    required double top,
    required double bottom,
    required bool leftEdge,
  }) async {
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
}
