import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// The panel's block list, which can also move the panel itself.
///
/// Pushed up once it has nothing left to scroll, the list hands the rest of
/// the drag to the panel, which then follows the finger up and off the
/// screen exactly as it follows its header - and comes back down with the
/// finger if it turns round. Let go part way, and the panel settles on
/// whichever side the release points to, carrying the finger's speed.
///
/// What it replaces closed the panel outright once the list had overscrolled
/// by twelve pixels: nothing followed the finger, there was no changing one's
/// mind half way, and a hard scroll that reached the bottom of a long panel
/// could shut it a moment later all by itself.
///
/// Only a drag moves the panel. A fling of the list that runs into the end
/// on its own momentum stops there, as it always did.
class PanelScrollController extends ScrollController {
  PanelScrollController({
    required this.onPanelDrag,
    required this.onPanelRelease,
    required this.isPanelPulled,
  });

  /// Moves the panel by a finger movement of this many pixels, downwards
  /// positive - the same sign a vertical drag on the header reports.
  final ValueChanged<double> onPanelDrag;

  /// The finger let go of a panel this list had been moving, at this many
  /// pixels per second, downwards positive.
  final ValueChanged<double> onPanelRelease;

  /// Whether the panel is pulled up away from fully open right now. While it
  /// is, every movement belongs to the panel, whichever way it goes.
  final bool Function() isPanelPulled;

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return _PanelScrollPosition(
      owner: this,
      physics: physics,
      context: context,
      oldPosition: oldPosition,
      initialPixels: initialScrollOffset,
      keepScrollOffset: keepScrollOffset,
      debugLabel: debugLabel,
    );
  }
}

class _PanelScrollPosition extends ScrollPositionWithSingleContext {
  _PanelScrollPosition({
    required this.owner,
    required super.physics,
    required super.context,
    super.oldPosition,
    super.initialPixels,
    super.keepScrollOffset,
    super.debugLabel,
  });

  final PanelScrollController owner;

  /// Whether the drag going on right now has moved the panel at all. Only a
  /// drag that did gets its release handed over; one that only ever
  /// scrolled the list ends as a scroll.
  bool _movedPanel = false;

  @override
  Drag drag(DragStartDetails details, VoidCallback dragCancelCallback) {
    _movedPanel = false;
    return super.drag(details, dragCancelCallback);
  }

  @override
  void applyUserOffset(double delta) {
    // [delta] is the finger's movement along the list: positive downwards,
    // which scrolls back towards the top. Pushing up at the bottom is the
    // one movement the list has no use for.
    final atEnd = pixels >= maxScrollExtent - precisionErrorTolerance;
    if (owner.isPanelPulled() || (delta < 0 && atEnd)) {
      _movedPanel = true;
      owner.onPanelDrag(delta);
      return;
    }
    super.applyUserOffset(delta);
  }

  @override
  void goBallistic(double velocity) {
    if (!_movedPanel) {
      super.goBallistic(velocity);
      return;
    }
    _movedPanel = false;
    // Scroll velocity counts towards the end of the list, i.e. a flick
    // upwards is positive. The panel counts downwards.
    owner.onPanelRelease(-velocity);
    // The list itself stays where it is: the momentum went to the panel.
    super.goBallistic(0);
  }
}
