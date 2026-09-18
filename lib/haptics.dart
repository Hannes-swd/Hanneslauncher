import 'package:flutter/services.dart';

import 'design_controller.dart';

/// What a piece of feedback is *for*, not how strong it is. The strength
/// comes from the design's `haptics` scalar, the same way a duration comes
/// from `motion` - see [DesignTokens.duration].
///
/// Naming the occasion rather than the intensity is what keeps the whole app
/// feeling like one device: "the selection moved" is one sensation
/// everywhere it happens, and turning it up turns all of them up together.
enum HapticEvent {
  /// The selection moved one step: the next letter under the finger on the
  /// alphabet bar, the next row, the next value on a slider. The most
  /// frequent one by far, so it is the lightest - a tick, not a knock.
  selection,

  /// Something was picked up or let go: a long press opening quick actions,
  /// a block grabbed for reordering.
  grab,

  /// A movement hit an edge or snapped into place: the panel reaching open
  /// or shut, a drag refusing to go further.
  snap,

  /// Something was committed that cannot be taken back with the same finger:
  /// an app launched, a shape recognised, a setting applied.
  confirm,

  /// It did not work: an unrecognised shape, a wrong password, a failed
  /// fetch. The one event that is deliberately unlike the others.
  reject,
}

/// Fires the phone's haptics for [HapticEvent]s, scaled by the design's
/// `haptics` setting.
///
/// Reads [DesignController] directly instead of taking a [BuildContext].
/// Every caller is inside a gesture callback - a drag update running at
/// display rate, a long-press handler - where looking a token up through the
/// tree is both awkward and pointless: there is exactly one design, and it
/// is the same one `context.design` would find.
///
/// Every call is fire-and-forget. A phone with no vibrator, or one where the
/// user switched system haptics off, simply does nothing with it, and that
/// is the right outcome rather than something to check for first.
class Haptics {
  const Haptics._();

  /// Android's haptics come in fixed shapes - there is no "40% of a click" -
  /// so the scalar picks *which* shape rather than scaling one. Three tiers
  /// is what the hardware actually distinguishes; more would be a slider
  /// where two of the positions feel identical.
  static void fire(HapticEvent event) {
    final strength = DesignController.instance.value.haptics;
    if (strength <= 0) return;
    final firm = strength >= 1.5;
    final soft = strength < 0.75;

    switch (event) {
      case HapticEvent.selection:
        // Deliberately never louder than a light impact: this one fires
        // dozens of times while a finger runs down the alphabet, and a
        // medium knock repeated thirty times is a phone that feels broken.
        if (soft) {
          HapticFeedback.selectionClick();
        } else {
          firm ? HapticFeedback.lightImpact() : HapticFeedback.selectionClick();
        }
      case HapticEvent.grab:
        if (soft) {
          HapticFeedback.selectionClick();
        } else {
          firm ? HapticFeedback.heavyImpact() : HapticFeedback.mediumImpact();
        }
      case HapticEvent.snap:
        if (soft) {
          HapticFeedback.selectionClick();
        } else {
          firm ? HapticFeedback.mediumImpact() : HapticFeedback.lightImpact();
        }
      case HapticEvent.confirm:
        if (soft) {
          HapticFeedback.lightImpact();
        } else {
          firm ? HapticFeedback.heavyImpact() : HapticFeedback.mediumImpact();
        }
      case HapticEvent.reject:
        // Two knocks in a row rather than one bigger one. A single stronger
        // pulse is indistinguishable from a confirmation at arm's length;
        // a double is unmistakably "no" without being louder.
        HapticFeedback.mediumImpact();
        Future<void>.delayed(
          const Duration(milliseconds: 90),
          HapticFeedback.mediumImpact,
        );
    }
  }

  /// Convenience for the one case that reads better as a condition than as a
  /// branch at the call site: the letter under the finger changed.
  static void selectionChanged(Object? from, Object? to) {
    if (from != to) fire(HapticEvent.selection);
  }
}
