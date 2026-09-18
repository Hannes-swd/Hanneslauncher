import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'design_tokens.dart';
import 'gesture_stroke.dart';
import 'gesture_stroke_view.dart';
import 'locale_controller.dart';

/// Opens the blank screen a shape is drawn on. Comes back with the stroke,
/// or null if it was left without one.
Future<GestureStroke?> drawGestureStroke(
  BuildContext context, {
  GestureStroke? initial,
}) {
  return Navigator.of(context).push<GestureStroke>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) => GestureDrawScreen(initial: initial),
    ),
  );
}

/// An empty sheet and a finger. The whole screen is the canvas: no grid, no
/// shapes to pick from, nothing to aim at - whatever gets drawn is the shape,
/// and it is compared to later drawings by what it looks like rather than by
/// where on the screen it was made.
class GestureDrawScreen extends StatefulWidget {
  const GestureDrawScreen({super.key, this.initial});

  /// The shape being replaced, drawn faintly behind until the first new
  /// stroke starts - redrawing a shape from memory alone is a lot harder
  /// than redrawing one you can see.
  final GestureStroke? initial;

  @override
  State<GestureDrawScreen> createState() => _GestureDrawScreenState();
}

class _GestureDrawScreenState extends State<GestureDrawScreen> {
  /// The stroke as it is being drawn. Its own notifier so that the line
  /// following the finger repaints on its own, rather than rebuilding the
  /// whole screen sixty times a second.
  final ValueNotifier<List<Offset>> _points = ValueNotifier(const []);

  /// True from the first finger-down until the stroke is thrown away again.
  bool _hasStroke = false;

  /// Set once a second stroke was started, which replaced the first: the one
  /// rule this screen has is that a shape is drawn without lifting the
  /// finger, so this says why the earlier line vanished.
  bool _restarted = false;

  @override
  void dispose() {
    _points.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    final replacing = _hasStroke;
    _points.value = [details.localPosition];
    if (!_hasStroke || _restarted != replacing) {
      setState(() {
        _hasStroke = true;
        _restarted = replacing;
      });
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    // A new list rather than adding to the old one: the notifier only tells
    // the painter something changed when the value itself is a different
    // object.
    _points.value = [..._points.value, details.localPosition];
  }

  void _clear() {
    _points.value = const [];
    setState(() {
      _hasStroke = false;
      _restarted = false;
    });
  }

  void _save(AppStrings s) {
    final stroke = GestureStroke.fromDrawing(_points.value);
    if (stroke == null || !isDeliberateShape(stroke)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.gestureTooSmall)),
      );
      return;
    }
    Navigator.of(context).pop(stroke);
  }

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final s = AppStrings(LocaleController.instance.value);
    // Deliberately not the app's own surface colour: this screen is a sheet
    // of paper, and the point of it is that nothing else is on it. In a dark
    // theme that sheet is black paper rather than a white flash in the dark.
    final paper = design.isDark ? const Color(0xFF0D0D0D) : Colors.white;
    final ink = design.isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: paper,
      appBar: AppBar(
        backgroundColor: paper,
        surfaceTintColor: Colors.transparent,
        foregroundColor: ink,
        title: Text(s.gestureDrawTitle),
        actions: [
          if (_hasStroke)
            TextButton(
              onPressed: _clear,
              child: Text(s.gestureDrawAgain),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              design.spaceMd,
              0,
              design.spaceMd,
              design.spaceSm,
            ),
            child: Text(
              _restarted ? s.gestureOneStrokeOnly : s.gestureDrawHint,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: design.typeLabel,
                color: ink.withValues(alpha: _restarted ? 0.85 : 0.55),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              // No end handler: lifting the finger is simply the end of the
              // stroke. Whether what was drawn is usable is decided when it
              // is saved, so a drawing that came out too small can still be
              // looked at before being drawn again.
              child: Stack(
                children: [
                  // The shape being replaced, until the first new stroke
                  // starts.
                  if (widget.initial != null && !_hasStroke)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: StrokePainter(
                            points: widget.initial!.points,
                            color: ink.withValues(alpha: 0.12),
                            width: 6,
                            showStart: false,
                          ),
                        ),
                      ),
                    ),
                  Positioned.fill(
                    child: ValueListenableBuilder<List<Offset>>(
                      valueListenable: _points,
                      builder: (context, points, child) => CustomPaint(
                        painter: StrokePainter(
                          points: points,
                          color: design.accent,
                          width: 6,
                          fit: false,
                          showStart: false,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.all(design.spaceMd),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(s.cancel),
                    ),
                  ),
                  SizedBox(width: design.spaceSm),
                  Expanded(
                    child: FilledButton(
                      onPressed: _hasStroke ? () => _save(s) : null,
                      child: Text(s.gestureUseShape),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
