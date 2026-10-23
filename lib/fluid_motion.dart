import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import 'design_controller.dart';

/// The movement everything settles on once a finger has let go of it: the
/// panel after a drag, the home screen after a swipe up that did not go far
/// enough, an icon after it was pressed.
///
/// A curve with a fixed duration starts from standstill. A panel flicked shut
/// at speed therefore stopped dead the moment the finger left the glass and
/// then set off again on its own, a beat slower - the one frame where a
/// launcher stops feeling like a thing in the hand. A spring is handed the
/// speed the finger let go with and carries it on, so there is no seam
/// between the drag and what comes after it.
///
/// Critically damped: it arrives without swinging past. The panel hangs from
/// the top edge, and a bounce past its end would open a gap above it.
///
/// The stiffness follows the design's motion scalar the way every duration
/// does - see `DesignTokens.duration` - so "calm" settles visibly slower and
/// "brisk" quicker, from the same slider. Read from [DesignController]
/// directly for the same reason `Haptics` does: every caller sits inside a
/// gesture callback, and there is exactly one design.
SpringDescription settleSpring({double damping = 1}) {
  final motion = DesignController.instance.value.motion;
  // 24 rad/s at the default: from rest, within two per cent of the target
  // after a quarter of a second, which is where motionNormal lands as well.
  // Clamped so the slowest setting still arrives, and the fastest one still
  // moves rather than teleporting.
  final omega = 24 / motion.clamp(0.4, 1.6);
  return SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: omega * omega,
    ratio: damping,
  );
}

/// Moves [controller] to [target] on [settleSpring], starting out at
/// [velocity] - in the controller's own units per second, so a drag measured
/// in pixels is divided by the distance that makes up one whole unit first.
///
/// With motion switched off it jumps, which is what "off" means everywhere
/// else in the app too.
TickerFuture settle(
  AnimationController controller,
  double target, {
  double velocity = 0,
  double damping = 1,
}) {
  if (DesignController.instance.value.motion <= 0) {
    controller.value = target;
    return TickerFuture.complete();
  }
  return controller.animateWith(
    SpringSimulation(
      settleSpring(damping: damping),
      controller.value,
      target,
      velocity,
      // Lands on the target exactly. Without it the spring stops a fraction
      // short, and a panel resting at 0.0004 still counts as open: the back
      // button stays caught and the home screen thinks it is covered.
      snapToEnd: true,
    ),
  );
}

/// Gives a little under the finger, and springs back when the finger leaves.
///
/// A tap that changes nothing on screen until the app it starts is up reads
/// as a tap that may not have landed. An icon that dips under the finger
/// answers on the very frame the touch arrives, long before anything it
/// opens can.
///
/// It only listens - it never joins the gesture arena - so it cannot take a
/// tap, a long press or a drag away from whatever it wraps. A finger that
/// sets off to scroll or drag lets the icon go again straight away.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.pressedScale = 0.9});

  final Widget child;

  /// How small the child gets while held.
  final double pressedScale;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale>
    with SingleTickerProviderStateMixin {
  // 0 at rest, 1 pressed. Unbounded so the spring on the way back may swing a
  // hair past rest - a press that pops back reads as something elastic, one
  // that merely stops reads as a picture being resized.
  late final AnimationController _press = AnimationController.unbounded(
    vsync: this,
  );

  late final Animation<double> _scale = _press.drive(
    Tween<double>(begin: 1, end: widget.pressedScale),
  );

  Offset? _downAt;

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  void _onDown(PointerDownEvent event) {
    _downAt = event.position;
    if (DesignController.instance.value.motion <= 0) {
      _press.value = 1;
      return;
    }
    // In quickly and plainly: the finger is what is doing it.
    _press.animateTo(
      1,
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOut,
    );
  }

  void _onMove(PointerMoveEvent event) {
    final downAt = _downAt;
    if (downAt == null) return;
    if ((event.position - downAt).distance > kTouchSlop) _release();
  }

  void _release() {
    if (_downAt == null) return;
    _downAt = null;
    settle(_press, 0, damping: 0.55);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onDown,
      onPointerMove: _onMove,
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _release(),
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

/// Fades its child in while sliding it the last few pixels into place - once
/// when it is first built, and again every time [trigger] changes.
///
/// For content that is swapped rather than moved: the apps under the next
/// letter, the search opening. A cut from one set of rows to the next reads
/// as a flicker at scrubbing speed; the same swap arriving from the side the
/// finger is on reads as the list following it.
///
/// Short on purpose. It must never be the reason something cannot be read
/// yet, so the rows are legible well before it ends.
class EntranceMotion extends StatefulWidget {
  const EntranceMotion({
    super.key,
    required this.child,
    this.trigger,
    this.from = const Offset(0, 16),
  });

  final Widget child;

  /// Plays the entrance again whenever this changes - the letter on show,
  /// say. The child's own state is kept throughout, so a list inside keeps
  /// its scroll position and its controller.
  final Object? trigger;

  /// Where the child starts from, in pixels, relative to where it ends up.
  final Offset from;

  @override
  State<EntranceMotion> createState() => _EntranceMotionState();
}

class _EntranceMotionState extends State<EntranceMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: _duration,
  );

  late final Animation<double> _curved = CurvedAnimation(
    parent: _entrance,
    curve: Curves.easeOutCubic,
  );

  static Duration get _duration => Duration(
    milliseconds: (170 * DesignController.instance.value.motion).round(),
  );

  @override
  void initState() {
    super.initState();
    _play();
  }

  @override
  void didUpdateWidget(EntranceMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trigger != widget.trigger) _play();
  }

  void _play() {
    final duration = _duration;
    if (duration == Duration.zero) {
      _entrance.value = 1;
      return;
    }
    _entrance
      ..duration = duration
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curved,
      child: widget.child,
      // The same two wrappers at rest as in motion: swapping them out once
      // the entrance is over would hand the child a new parent, and with it
      // a new state - a list inside would lose its scroll position.
      // At full opacity and no offset neither of them costs anything.
      builder: (context, child) {
        final t = _curved.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: widget.from * (1 - t),
            child: child,
          ),
        );
      },
    );
  }
}

/// One item of something that has just opened - an icon in a folder - which
/// pops into place a beat after the one before it, riding on the opening
/// route's own animation.
///
/// A grid that appears all at once is a picture; one that fills in from the
/// first item on is seen to be the contents of the thing that opened. The
/// beats are short and stop growing after a handful of items, so a full
/// folder is never waited on - and closing runs it all backwards, together.
class RouteStagger extends StatefulWidget {
  const RouteStagger({super.key, required this.index, required this.child});

  /// Position in the order things arrive in.
  final int index;
  final Widget child;

  @override
  State<RouteStagger> createState() => _RouteStaggerState();
}

class _RouteStaggerState extends State<RouteStagger> {
  CurvedAnimation? _fade;
  CurvedAnimation? _pop;
  Animation<double>? _scale;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || animation == _fade?.parent) return;
    _fade?.dispose();
    _pop?.dispose();
    // Each item starts a little after the one before, up to a point; all of
    // them finish together with the route.
    final start = math.min(widget.index * 0.05, 0.35) + 0.15;
    _fade = CurvedAnimation(
      parent: animation,
      curve: Interval(
        start,
        math.min(start + 0.3, 1.0),
        curve: Curves.easeOut,
      ),
      reverseCurve: Curves.easeIn,
    );
    _pop = CurvedAnimation(
      parent: animation,
      // A touch past full size and back: popped in, not slid.
      curve: Interval(start, 1, curve: Curves.easeOutBack),
      reverseCurve: Curves.easeIn,
    );
    _scale = Tween<double>(begin: 0.6, end: 1).animate(_pop!);
  }

  @override
  void dispose() {
    _fade?.dispose();
    _pop?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fade = _fade;
    final scale = _scale;
    if (fade == null || scale == null) return widget.child;
    return FadeTransition(
      opacity: fade,
      child: ScaleTransition(scale: scale, child: widget.child),
    );
  }
}
