import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'design_tokens.dart';
import 'gesture_stroke.dart';

/// Draws a stroke. The one painter for all three places a shape is ever
/// shown - the thumbnail in the list, the big preview in the editor, and the
/// line following the finger on the home screen - so a shape looks the same
/// everywhere it appears.
class StrokePainter extends CustomPainter {
  const StrokePainter({
    required this.points,
    required this.color,
    this.width = 3,
    this.fit = true,
    this.showStart = true,
  });

  final List<Offset> points;
  final Color color;
  final double width;

  /// Whether to scale the stroke into the box it is painted in. On for a
  /// saved shape, which was drawn at whatever size on whatever screen; off
  /// for the line following the finger, which belongs exactly where the
  /// finger is.
  final bool fit;

  /// The dot marking where the stroke begins. Which end a shape starts at is
  /// part of what it is - the same circle drawn from the bottom is a
  /// different shape to the recognizer - so a saved one says where to start.
  final bool showStart;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final drawn = fit ? _fitted(size) : points;

    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()..moveTo(drawn.first.dx, drawn.first.dy);
    for (var i = 1; i < drawn.length; i++) {
      path.lineTo(drawn[i].dx, drawn[i].dy);
    }
    canvas.drawPath(path, paint);

    if (showStart) {
      canvas.drawCircle(
        drawn.first,
        width * 0.9,
        Paint()..color = color,
      );
    }
  }

  /// Scales the shape into [size] keeping its proportions, so a heart drawn
  /// tall stays tall instead of being squashed into whatever box it is being
  /// shown in.
  List<Offset> _fitted(Size size) {
    final bounds = _bounds();
    final inset = width * 2;
    final boxWidth = math.max(size.width - inset * 2, 1.0);
    final boxHeight = math.max(size.height - inset * 2, 1.0);
    // A shape that is all in one direction (a line, a check mark) has no
    // extent at all on the other axis - scaling by that would be a division
    // by zero, and its own scale is the only sensible one left.
    final scaleX = bounds.width <= 0.01
        ? double.infinity
        : boxWidth / bounds.width;
    final scaleY = bounds.height <= 0.01
        ? double.infinity
        : boxHeight / bounds.height;
    var scale = math.min(scaleX, scaleY);
    if (!scale.isFinite) scale = 1;

    final offsetX = (size.width - bounds.width * scale) / 2;
    final offsetY = (size.height - bounds.height * scale) / 2;
    return [
      for (final point in points)
        Offset(
          (point.dx - bounds.left) * scale + offsetX,
          (point.dy - bounds.top) * scale + offsetY,
        ),
    ];
  }

  Rect _bounds() {
    var left = points.first.dx;
    var right = points.first.dx;
    var top = points.first.dy;
    var bottom = points.first.dy;
    for (final point in points) {
      left = math.min(left, point.dx);
      right = math.max(right, point.dx);
      top = math.min(top, point.dy);
      bottom = math.max(bottom, point.dy);
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

  @override
  bool shouldRepaint(StrokePainter old) =>
      old.points != points ||
      old.points.length != points.length ||
      old.color != color ||
      old.width != width ||
      old.fit != fit;
}

/// A saved shape at list-row size, on its own little card so it reads as a
/// picture of something rather than as an icon.
class GestureStrokeThumbnail extends StatelessWidget {
  const GestureStrokeThumbnail({
    super.key,
    required this.stroke,
    this.size = 48,
    this.dimmed = false,
  });

  final GestureStroke stroke;
  final double size;

  /// Drawn faint for a shortcut that is switched off, so the list shows at a
  /// glance which shapes are actually being watched for.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: design.fillSubtle,
        borderRadius: BorderRadius.circular(design.radiusSmall),
      ),
      child: CustomPaint(
        painter: StrokePainter(
          points: stroke.points,
          color: dimmed
              ? design.textSecondary.withValues(alpha: 0.5)
              : design.accent,
          width: size / 18,
        ),
      ),
    );
  }
}
