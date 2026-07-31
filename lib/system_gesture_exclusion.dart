import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// Tells Android to not intercept the given screen region for its own edge
/// gestures (e.g. swipe-from-edge-to-go-back), so a custom drag gesture
/// placed right at the screen edge (like the alphabet bar) gets first dibs
/// on touches there instead of losing the first attempt to the system.
class SystemGestureExclusion {
  static const _channel = MethodChannel('hanneslouncher/system_gestures');

  static Future<void> excludeRightEdge({
    required double barWidth,
    required double top,
    required double bottom,
  }) async {
    final view = ui.PlatformDispatcher.instance.views.first;
    final dpr = view.devicePixelRatio;
    final screenWidthLogical = view.physicalSize.width / dpr;

    try {
      await _channel.invokeMethod('setExclusionRect', {
        'left': (screenWidthLogical - barWidth) * dpr,
        'top': top * dpr,
        'right': screenWidthLogical * dpr,
        'bottom': bottom * dpr,
      });
    } catch (_) {
      // Best-effort only (e.g. unsupported on older Android or non-Android).
    }
  }
}
