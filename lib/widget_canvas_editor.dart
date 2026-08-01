import 'package:flutter/material.dart';

import 'panel_blocks_controller.dart';
import 'widget_card_view.dart';
import 'widget_element.dart';

/// The card as it will look, with its elements draggable. Tapping one opens
/// it for editing, dragging moves it - the position is only written once the
/// finger lifts, so a drag doesn't hit storage on every frame.
///
/// While dragging, the element snaps to the ones already placed: to their
/// line, to the card's edges and middle, and to the gap two elements already
/// have between them, so a third lands evenly spaced without measuring.
class WidgetCanvasEditor extends StatefulWidget {
  const WidgetCanvasEditor({
    super.key,
    required this.block,
    required this.onTapElement,
  });

  final PanelBlock block;
  final ValueChanged<WidgetElement> onTapElement;

  @override
  State<WidgetCanvasEditor> createState() => _WidgetCanvasEditorState();
}

class _WidgetCanvasEditorState extends State<WidgetCanvasEditor> {
  // How close a position has to be before it is pulled onto a line, in
  // logical pixels - small enough that a deliberate offset still survives.
  static const double _snapDistance = 10;

  // While a drag is running the position lives here, so the card follows the
  // finger without a save per frame.
  String? _draggingId;

  // Where the finger actually is, kept apart from the snapped position
  // below. Adding the movement to the snapped value instead would swallow
  // every step small enough to be pulled back onto the line, and the element
  // could never leave it again.
  double _rawX = 0;
  double _rawY = 0;

  // What is drawn and eventually saved: the finger's position, pulled onto a
  // line when it is close enough to one.
  double _x = 0;
  double _y = 0;

  // The lines currently being snapped to, drawn so it's visible why the
  // element stopped where it did.
  double? _guideX;
  double? _guideY;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      height: widget.block.cardHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return Stack(
            children: [
              for (final element in widget.block.elements)
                Align(
                  alignment: _alignmentOf(element),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => widget.onTapElement(element),
                    onPanStart: (_) => setState(() {
                      _draggingId = element.id;
                      _rawX = element.x;
                      _rawY = element.y;
                      _x = element.x;
                      _y = element.y;
                    }),
                    onPanUpdate: (details) =>
                        _drag(element, details.delta, size),
                    onPanEnd: (_) => _commit(element),
                    onPanCancel: () => setState(_clearDrag),
                    child: WidgetElementView(
                      element: element,
                      cardWidth: size.width,
                    ),
                  ),
                ),
              if (_guideX != null)
                Positioned(
                  left: _guideX! * size.width,
                  top: 0,
                  bottom: 0,
                  child: const _Guide(vertical: true),
                ),
              if (_guideY != null)
                Positioned(
                  top: _guideY! * size.height,
                  left: 0,
                  right: 0,
                  child: const _Guide(vertical: false),
                ),
            ],
          );
        },
      ),
    );
  }

  void _drag(WidgetElement dragged, Offset delta, Size size) {
    final rawX = (_rawX + delta.dx / size.width).clamp(0.0, 1.0);
    final rawY = (_rawY + delta.dy / size.height).clamp(0.0, 1.0);

    final others = [
      for (final element in widget.block.elements)
        if (element.id != dragged.id) element,
    ];
    final snappedX = _snap(
      rawX,
      _candidates(others.map((e) => e.x)),
      _snapDistance / size.width,
    );
    final snappedY = _snap(
      rawY,
      _candidates(others.map((e) => e.y)),
      _snapDistance / size.height,
    );

    setState(() {
      _rawX = rawX;
      _rawY = rawY;
      _x = snappedX ?? rawX;
      _y = snappedY ?? rawY;
      _guideX = snappedX;
      _guideY = snappedY;
    });
  }

  /// Everything worth snapping to on one axis: the card's edges and middle,
  /// every other element's line, and - for each pair that already shares a
  /// gap - the next position continuing that same gap.
  List<double> _candidates(Iterable<double> positions) {
    final lines = positions.toList()..sort();
    final candidates = <double>[0, 0.5, 1, ...lines];
    for (var i = 0; i < lines.length; i++) {
      for (var j = i + 1; j < lines.length; j++) {
        final gap = lines[j] - lines[i];
        // Two elements on the same line say nothing about spacing.
        if (gap < 0.02) continue;
        candidates.add(lines[j] + gap);
        candidates.add(lines[i] - gap);
      }
    }
    return [
      for (final candidate in candidates)
        if (candidate >= 0 && candidate <= 1) candidate,
    ];
  }

  /// The nearest candidate within [threshold], or null when the finger is
  /// nowhere near one.
  double? _snap(double raw, List<double> candidates, double threshold) {
    double? best;
    var bestDistance = threshold;
    for (final candidate in candidates) {
      final distance = (candidate - raw).abs();
      if (distance <= bestDistance) {
        bestDistance = distance;
        best = candidate;
      }
    }
    return best;
  }

  Alignment _alignmentOf(WidgetElement element) {
    if (element.id != _draggingId) return element.stackAlignment;
    return Alignment(_x * 2 - 1, _y * 2 - 1);
  }

  void _clearDrag() {
    _draggingId = null;
    _guideX = null;
    _guideY = null;
  }

  Future<void> _commit(WidgetElement element) async {
    final x = _x;
    final y = _y;
    setState(_clearDrag);
    await PanelBlocksController.instance.update(
      widget.block.copyWith(
        elements: [
          for (final e in widget.block.elements)
            if (e.id == element.id) e.copyWith(x: x, y: y) else e,
        ],
      ),
    );
  }
}

class _Guide extends StatelessWidget {
  const _Guide({required this.vertical});

  final bool vertical;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: vertical ? 1 : null,
        height: vertical ? null : 1,
        color: Colors.blueAccent.withValues(alpha: 0.8),
      ),
    );
  }
}
