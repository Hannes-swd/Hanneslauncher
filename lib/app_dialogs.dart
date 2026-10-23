import 'package:flutter/material.dart';

import 'design_controller.dart';

/// Every dialog and every bottom sheet in the app opens through here.
///
/// Flutter's own dialog comes up as a flat 150 ms fade, and nothing in the
/// theme reaches it - so dialogs were the one thing left in the app that
/// still appeared rather than arrived, at a speed of their own and deaf to
/// the motion slider. Through here a dialog fades in on the design's timing
/// and grows the last stretch into place with a hint of give, out of the
/// spot it was opened from when that is known - the icon that was held, the
/// folder that was tapped - and shrinks back into it on the way out.
///
/// Sheets get the design's timing and the same out-fast-settle-slow curve as
/// everything else that rises into place.
///
/// One place rather than a setting at every call: a dialog added later comes
/// up the same way without anyone having to remember to ask for it, and
/// `test/motion_guard_test.dart` fails while anything in lib/ still calls
/// Flutter's own `showDialog` or `showModalBottomSheet` directly.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  Rect? from,
}) {
  final origin = _originOf(context, from);
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor,
    animationStyle: _style(enter: 260, exit: 260),
    // The caller's builder, run in the same context it always was; the
    // entrance only wraps what it returns.
    builder: (context) =>
        _DialogEntrance(origin: origin, child: builder(context)),
  );
}

/// [showModalBottomSheet] on the design's timing - see [showAppDialog].
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool? showDragHandle,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    showDragHandle: showDragHandle,
    sheetAnimationStyle: _style(enter: 320, exit: 220),
    builder: builder,
  );
}

/// The durations scaled by the motion slider, as everywhere else. Off is no
/// animation at all rather than a zero-length one.
AnimationStyle _style({required int enter, required int exit}) {
  final motion = DesignController.instance.value.motion;
  if (motion <= 0) return AnimationStyle.noAnimation;
  return AnimationStyle(
    duration: Duration(milliseconds: (enter * motion).round()),
    reverseDuration: Duration(milliseconds: (exit * motion).round()),
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
}

/// Where in the dialog's area [from] sits, as the point to grow out of.
///
/// [from] comes in the physical pixels an app launch takes (see
/// `AppLauncher.boundsOf`), so one rectangle serves both. The dialog is laid
/// out inside the safe area, so that is the box measured against.
Alignment? _originOf(BuildContext context, Rect? from) {
  if (from == null) return null;
  final screen = MediaQuery.sizeOf(context);
  final padding = MediaQuery.paddingOf(context);
  final width = screen.width - padding.horizontal;
  final height = screen.height - padding.vertical;
  if (width <= 0 || height <= 0) return null;
  final ratio = View.of(context).devicePixelRatio;
  final center = from.center / ratio;
  return Alignment(
    ((center.dx - padding.left) / width * 2 - 1).clamp(-1.0, 1.0),
    ((center.dy - padding.top) / height * 2 - 1).clamp(-1.0, 1.0),
  );
}

/// The grow that rides on the dialog route's own fade.
///
/// From the middle it only grows the last few per cent: enough to be seen
/// arriving, not so much that a question asked in a hurry makes anyone wait
/// for it. Out of an icon it starts much smaller, because there the growing
/// is the point - it says where the dialog came from.
class _DialogEntrance extends StatefulWidget {
  const _DialogEntrance({required this.origin, required this.child});

  final Alignment? origin;
  final Widget child;

  @override
  State<_DialogEntrance> createState() => _DialogEntranceState();
}

class _DialogEntranceState extends State<_DialogEntrance> {
  CurvedAnimation? _curved;
  Animation<double>? _scale;

  // A touch past full size on the way in, then settling back: the give that
  // makes it land rather than stop. Plain on the way out.
  static const _arrive = Cubic(0.3, 1.25, 0.6, 1);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || animation == _curved?.parent) return;
    _curved?.dispose();
    final curved = CurvedAnimation(
      parent: animation,
      curve: _arrive,
      reverseCurve: Curves.easeInCubic,
    );
    _curved = curved;
    _scale = Tween<double>(
      begin: widget.origin == null ? 0.92 : 0.4,
      end: 1,
    ).animate(curved);
  }

  @override
  void dispose() {
    _curved?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = _scale;
    if (scale == null) return widget.child;
    return ScaleTransition(
      alignment: widget.origin ?? Alignment.center,
      scale: scale,
      child: widget.child,
    );
  }
}
