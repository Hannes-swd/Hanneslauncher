import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'design_tokens.dart';
import 'gesture_action.dart';
import 'gesture_shortcuts_controller.dart';
import 'gesture_stroke.dart';
import 'gesture_stroke_view.dart';
import 'haptics.dart';
import 'locale_controller.dart';

/// Drawing a shape straight onto the home screen.
///
/// The hard part is not the recognising - it is that the home screen already
/// answers a finger: dragging anywhere on it pulls the settings panel down.
/// Two gesture recognizers cannot both have the same touch, so this is the
/// one place that decides which of the two a finger meant, and it decides it
/// from the first [_decideDistance] pixels of the stroke:
///
///   * A straight pull up or down is the panel, as it always was.
///   * Anything else - sideways, diagonal, curved - is a drawing.
///
/// Which means a shape that starts with a straight vertical line opens the
/// panel instead of being drawn. That is said plainly in the settings, and
/// it is the price of not having a button to press first: the panel is used
/// constantly, and it may not become unreliable to save a stroke.
///
/// While there is no shape saved (or drawing is switched off) none of this
/// is in the tree at all and the home screen behaves exactly as it did.

/// How far the finger travels before the choice above is made. Short enough
/// not to be felt on the panel, long enough that the direction is the
/// finger's intent rather than its jitter.
const double _decideDistance = 30;

/// And how much slop the panel's own drag is given while drawing is on, so
/// it cannot win the touch before that choice has been made. Above
/// [_decideDistance] on purpose - a few pixels of margin, and the panel's
/// drag then starts from wherever the finger is by then, so it still follows
/// the finger exactly.
const double _panelSlopWhileDrawing = 38;

/// How straight and how upright a stroke has to be to count as a pull at the
/// panel rather than as the start of a shape. 0.94 is close to a ruler; the
/// sideways allowance is generous because a pull down with the thumb curves
/// noticeably.
const double _panelStraightness = 0.94;
const double _panelSideways = 0.45;

/// The layer that takes the touch. Sits under everything the home screen
/// draws (translucent, so taps on the icons above it still land) and inside
/// the alphabet bar's edge, which has scrub gestures of its own.
class HomeGestureLayer extends StatelessWidget {
  const HomeGestureLayer({
    super.key,
    required this.drawingActive,
    required this.showTrail,
    required this.trail,
    required this.onStrokeFinished,
    this.onPanelDragStart,
    this.onPanelDragUpdate,
    this.onPanelDragEnd,
  });

  /// False while there is nothing to recognise (no shape saved, the setting
  /// off) and while the app list is being used (the alphabet is up, the
  /// search is open) - in both cases the panel gets every drag, exactly as
  /// before.
  final bool drawingActive;

  /// Whether the stroke is drawn under the finger. With it off nothing is
  /// ever put into [trail] in the first place - the shape is still
  /// recognised and still fires, it just leaves no mark on the screen.
  final bool showTrail;

  /// The line as it is being drawn, shared with [HomeGestureTrail] which
  /// paints it on top of everything else.
  final ValueNotifier<List<Offset>> trail;

  final ValueChanged<List<Offset>> onStrokeFinished;

  final GestureDragStartCallback? onPanelDragStart;
  final GestureDragUpdateCallback? onPanelDragUpdate;
  final GestureDragEndCallback? onPanelDragEnd;

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: <Type, GestureRecognizerFactory>{
        // First in the map so it also gets each touch first, and can make
        // its call before the panel's drag has a chance to claim one.
        if (drawingActive)
          _ShapeStrokeRecognizer:
              GestureRecognizerFactoryWithHandlers<_ShapeStrokeRecognizer>(
                () => _ShapeStrokeRecognizer(debugOwner: this),
                (recognizer) {
                  recognizer
                    // Left unset when the line is not to be shown, so a
                    // stroke that nobody watches costs nothing to follow.
                    ..onPoints = showTrail
                        ? (points) {
                            trail.value = points;
                          }
                        : null
                    ..onFinished = (points) {
                      // Emptied rather than left standing: that is what
                      // starts the trail fading out, see [HomeGestureTrail].
                      trail.value = const [];
                      onStrokeFinished(points);
                    }
                    ..onCancelled = () {
                      trail.value = const [];
                    };
                },
              ),
        VerticalDragGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<
              VerticalDragGestureRecognizer
            >(
              () => VerticalDragGestureRecognizer(debugOwner: this),
              (recognizer) {
                recognizer
                  ..onStart = onPanelDragStart
                  ..onUpdate = onPanelDragUpdate
                  ..onEnd = onPanelDragEnd
                  // Left at the phone's own slop whenever drawing is off, so
                  // the panel is never made even slightly harder to pull by
                  // a feature that isn't running.
                  ..gestureSettings = drawingActive
                      ? const DeviceGestureSettings(
                          touchSlop: _panelSlopWhileDrawing,
                        )
                      : MediaQuery.maybeGestureSettingsOf(context);
              },
            ),
      },
    );
  }
}

/// The line following the finger. A separate widget from the layer above
/// because the touch has to be taken underneath everything the home screen
/// draws while the line has to be painted on top of it - same box, opposite
/// ends of the stack.
class HomeGestureTrail extends StatefulWidget {
  const HomeGestureTrail({super.key, required this.trail});

  final ValueNotifier<List<Offset>> trail;

  @override
  State<HomeGestureTrail> createState() => _HomeGestureTrailState();
}

class _HomeGestureTrailState extends State<HomeGestureTrail>
    with SingleTickerProviderStateMixin {
  /// The stroke keeps being drawn for a moment after the finger is lifted
  /// and fades out from there. A line that simply disappears the instant the
  /// finger leaves the glass reads as a glitch; one that fades reads as
  /// having been received.
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1,
  );

  /// What is painted: the live stroke, or the last one while it fades.
  List<Offset> _points = const [];

  @override
  void initState() {
    super.initState();
    widget.trail.addListener(_onTrailChanged);
    _fade.addStatusListener(_onFadeDone);
  }

  @override
  void dispose() {
    widget.trail.removeListener(_onTrailChanged);
    _fade.dispose();
    super.dispose();
  }

  void _onTrailChanged() {
    final points = widget.trail.value;
    if (points.isEmpty) {
      // Emptied means the stroke is over - keep the last one on screen and
      // fade it out, rather than dropping it mid-air.
      if (_points.isEmpty) return;
      _fade.reverse(from: 1);
      return;
    }
    setState(() {
      _points = points;
      _fade.value = 1;
    });
  }

  /// Faded away is gone: held on to any longer and a new stroke starting
  /// within the fade would flash the old one back up for a frame.
  void _onFadeDone(AnimationStatus status) {
    if (status != AnimationStatus.dismissed || _points.isEmpty) return;
    setState(() => _points = const []);
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _fade,
        builder: (context, child) {
          if (_points.length < 2 || _fade.value <= 0) {
            return const SizedBox.expand();
          }
          // The picked colour, or the design's accent while none is picked -
          // read here rather than stored, so the line follows a theme change
          // the same way the rest of the app does.
          final colour =
              GestureDrawingController.instance.value.fixedColor ??
              context.design.accent;
          return CustomPaint(
            size: Size.infinite,
            painter: StrokePainter(
              points: _points,
              color: colour.withValues(alpha: _fade.value * colour.a),
              width: 6,
              fit: false,
              showStart: false,
            ),
          );
        },
      ),
    );
  }
}

/// What to do with a finished stroke: work out which saved shape it was, and
/// either run it or say why nothing happened.
///
/// A stroke that was never meant as a shape says nothing at all - most of
/// what a finger does on a home screen is not a drawing, and a launcher that
/// commented on every swipe would be unusable.
Future<void> handleHomeStroke(
  BuildContext context,
  List<Offset> points, {
  required VoidCallback onOpenSettings,
}) async {
  final s = AppStrings(LocaleController.instance.value);
  final controller = GestureShortcutsController.instance;
  final result = recognizeStroke(points, controller.templates);

  switch (result.verdict) {
    case StrokeVerdict.notAShape:
      return;
    case StrokeVerdict.unknown:
      Haptics.fire(HapticEvent.reject);
      _flash(context, s.gestureNotRecognized);
      return;
    case StrokeVerdict.ambiguous:
      Haptics.fire(HapticEvent.reject);
      _flash(context, s.gestureAmbiguous);
      return;
    case StrokeVerdict.match:
      final shortcut = controller.byId(result.id!);
      if (shortcut == null) return;
      // Before the action runs, not after: a drawing that opens an app has
      // the launcher leaving the screen as its next event, and a buzz that
      // lands after the app is up reads as the app's, not the shape's.
      Haptics.fire(HapticEvent.confirm);
      final outcome = await runGestureAction(
        context,
        shortcut.action,
        onOpenSettings: onOpenSettings,
      );
      final message = outcome.message;
      if (message != null && context.mounted) _flash(context, message);
  }
}

/// A word at the bottom of the screen, gone again in a moment. The only
/// thing the home screen ever says about a drawing.
void _flash(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1600),
      ),
    );
}

/// Watches a touch on the home screen and decides, once it has seen enough
/// of it, whether it is a shape being drawn or a pull at the settings panel.
///
/// Rejecting hands the touch to the panel's own drag, which is sitting in the
/// same arena waiting for exactly that; accepting takes it away from it for
/// good.
class _ShapeStrokeRecognizer extends OneSequenceGestureRecognizer {
  _ShapeStrokeRecognizer({super.debugOwner});

  /// The stroke so far, from the moment it is known to be a drawing. Sent
  /// whole rather than point by point: the points that came before the
  /// decision are part of the shape too, and the first call carries them.
  ValueChanged<List<Offset>>? onPoints;

  ValueChanged<List<Offset>>? onFinished;

  /// The stroke was taken away again (another recognizer won, the touch was
  /// cancelled by the system): whatever was drawn is dropped.
  VoidCallback? onCancelled;

  int? _pointer;
  final List<Offset> _points = [];
  double _travelled = 0;
  bool _decided = false;
  bool _drawing = false;

  @override
  String get debugDescription => 'home screen shape';

  @override
  void addAllowedPointer(PointerDownEvent event) {
    // One finger at a time. A second one landing mid-stroke is a pinch or a
    // pocket, not a second shape.
    if (_pointer != null) return;
    _pointer = event.pointer;
    _points
      ..clear()
      ..add(event.localPosition);
    _travelled = 0;
    _decided = false;
    _drawing = false;
    startTrackingPointer(event.pointer, event.transform);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event.pointer != _pointer) return;

    if (event is PointerMoveEvent) {
      _travelled += (event.localPosition - _points.last).distance;
      _points.add(event.localPosition);
      if (_drawing) {
        onPoints?.call(List<Offset>.of(_points));
      } else if (!_decided && _travelled >= _decideDistance) {
        _decide();
      }
      return;
    }

    if (event is PointerUpEvent) {
      if (_drawing) {
        onFinished?.call(List<Offset>.of(_points));
        _drawing = false;
      } else if (!_decided) {
        // Lifted before there was anything to judge: a tap, or a nudge too
        // short to be either gesture.
        resolve(GestureDisposition.rejected);
      }
      stopTrackingPointer(event.pointer);
      return;
    }

    if (event is PointerCancelEvent) {
      if (_drawing) onCancelled?.call();
      _drawing = false;
      resolve(GestureDisposition.rejected);
      stopTrackingPointer(event.pointer);
    }
  }

  void _decide() {
    _decided = true;
    final displacement = _points.last - _points.first;
    // How much of the travelled line went into getting from where the finger
    // started to where it is now: 1 for a ruler-straight drag, less for
    // anything that has already turned a corner.
    final straightness = _travelled <= 0
        ? 1.0
        : displacement.distance / _travelled;
    final upright =
        displacement.dx.abs() <= displacement.dy.abs() * _panelSideways;

    if (straightness > _panelStraightness && upright) {
      resolve(GestureDisposition.rejected);
      return;
    }

    resolve(GestureDisposition.accepted);
    _drawing = true;
    onPoints?.call(List<Offset>.of(_points));
  }

  @override
  void rejectGesture(int pointer) {
    // Lost the touch to something else after having claimed it - possible
    // when a longer-lived recognizer higher up wins. Whatever was drawn goes
    // with it.
    if (_drawing) {
      _drawing = false;
      onCancelled?.call();
    }
    super.rejectGesture(pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _pointer = null;
    _points.clear();
    _travelled = 0;
    _decided = false;
    _drawing = false;
  }
}
