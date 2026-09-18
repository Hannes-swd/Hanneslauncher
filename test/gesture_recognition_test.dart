import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:hanneslauncher/gesture_stroke.dart';

/// The shapes the tests draw with. Each is built from the same handful of
/// points a finger would leave, so what is being checked is the recogniser's
/// own behaviour rather than a fixture that happens to have been recorded on
/// a good day.
List<Offset> circle({
  Offset centre = const Offset(0, 0),
  double radius = 60,
  int points = 48,
}) {
  return [
    for (var i = 0; i < points; i++)
      Offset(
        centre.dx + radius * math.cos(2 * math.pi * i / (points - 1)),
        centre.dy + radius * math.sin(2 * math.pi * i / (points - 1)),
      ),
  ];
}

/// Walks the corners in order, dropping a point every few pixels along each
/// side - which is what a finger does.
List<Offset> polyline(List<Offset> corners, {double step = 4}) {
  final out = <Offset>[corners.first];
  for (var i = 1; i < corners.length; i++) {
    final from = corners[i - 1];
    final to = corners[i];
    final length = (to - from).distance;
    final count = math.max((length / step).round(), 1);
    for (var n = 1; n <= count; n++) {
      out.add(Offset.lerp(from, to, n / count)!);
    }
  }
  return out;
}

List<Offset> triangle({Offset at = const Offset(0, 0), double size = 120}) {
  return polyline([
    at + Offset(size / 2, 0),
    at + Offset(size, size),
    at + Offset(0, size),
    at + Offset(size / 2, 0),
  ]);
}

/// A square drawn from the top left, clockwise.
List<Offset> square({Offset at = const Offset(0, 0), double size = 120}) {
  return polyline([
    at,
    at + Offset(size, 0),
    at + Offset(size, size),
    at + Offset(0, size),
    at,
  ]);
}

/// The tick a check mark is: down to the left, then up and out to the right.
List<Offset> checkMark({Offset at = const Offset(0, 0), double size = 120}) {
  return polyline([
    at + Offset(0, size * 0.5),
    at + Offset(size * 0.35, size),
    at + Offset(size, 0),
  ]);
}

List<Offset> moved(List<Offset> points, Offset by) => [
  for (final point in points) point + by,
];

List<Offset> scaled(List<Offset> points, double by) => [
  for (final point in points) point * by,
];

StrokeTemplate template(String id, List<Offset> points) =>
    StrokeTemplate(id: id, stroke: GestureStroke.fromDrawing(points)!);

void main() {
  group('a shape is the same shape wherever and however big it is drawn', () {
    final saved = [template('circle', circle()), template('tick', checkMark())];

    test('drawn again in the same spot', () {
      final result = recognizeStroke(circle(), saved);
      expect(result.verdict, StrokeVerdict.match);
      expect(result.id, 'circle');
    });

    test('drawn in the far corner of the screen', () {
      final result = recognizeStroke(
        moved(circle(), const Offset(640, 1200)),
        saved,
      );
      expect(result.verdict, StrokeVerdict.match);
      expect(result.id, 'circle');
    });

    test('drawn with two fingers worth of space', () {
      final result = recognizeStroke(scaled(circle(), 0.35), saved);
      expect(result.verdict, StrokeVerdict.match);
      expect(result.id, 'circle');
    });

    test('drawn across the whole screen', () {
      final result = recognizeStroke(
        moved(scaled(circle(), 5), const Offset(500, 900)),
        saved,
      );
      expect(result.verdict, StrokeVerdict.match);
      expect(result.id, 'circle');
    });

    test('drawn crooked', () {
      final wobbly = [
        for (var i = 0; i < circle().length; i++)
          circle()[i] + Offset(i.isEven ? 3 : -3, i % 3 == 0 ? 2 : -2),
      ];
      final result = recognizeStroke(wobbly, saved);
      expect(result.verdict, StrokeVerdict.match);
      expect(result.id, 'circle');
    });
  });

  group('shapes that are not the same shape are kept apart', () {
    final saved = [
      template('circle', circle()),
      template('triangle', triangle()),
      template('tick', checkMark()),
    ];

    test('a triangle is not the circle', () {
      final result = recognizeStroke(triangle(at: const Offset(300, 400)), saved);
      expect(result.verdict, StrokeVerdict.match);
      expect(result.id, 'triangle');
    });

    test('a tick is not the triangle', () {
      final result = recognizeStroke(checkMark(size: 200), saved);
      expect(result.verdict, StrokeVerdict.match);
      expect(result.id, 'tick');
    });

    test('a square is none of them', () {
      final result = recognizeStroke(square(), saved);
      expect(result.verdict, StrokeVerdict.unknown);
    });
  });

  group('what was never a shape is answered with silence', () {
    final saved = [template('circle', circle())];

    test('a flick to open the panel', () {
      final result = recognizeStroke(
        polyline([const Offset(200, 100), const Offset(210, 500)]),
        saved,
      );
      expect(result.verdict, StrokeVerdict.notAShape);
    });

    test('a tap that slid a little', () {
      final result = recognizeStroke(
        polyline([const Offset(200, 100), const Offset(206, 112)]),
        saved,
      );
      expect(result.verdict, StrokeVerdict.notAShape);
    });

    test('a long scribble inside a postage stamp', () {
      final result = recognizeStroke(scaled(circle(radius: 8), 1), saved);
      expect(result.verdict, StrokeVerdict.notAShape);
    });

    test('with nothing saved, even a real shape is left alone', () {
      expect(recognizeStroke(circle(), const []).verdict,
          StrokeVerdict.notAShape);
    });
  });

  test('two saved shapes that look alike fire neither', () {
    // A circle and a circle drawn a touch wider - exactly the pair the
    // editor warns about, and the reason the margin rule exists: guessing
    // between them would be a coin toss with an app launch on it.
    final saved = [
      template('circle', circle()),
      template('oval', [
        for (final point in circle()) Offset(point.dx * 1.12, point.dy),
      ]),
    ];
    final result = recognizeStroke(circle(), saved);
    expect(result.verdict, StrokeVerdict.ambiguous);
    expect(result.score - result.runnerUpScore, lessThan(minMatchMargin));
  });

  test('a shape scores against itself as high as it can', () {
    final stroke = GestureStroke.fromDrawing(triangle())!;
    expect(strokeScore(stroke, stroke), greaterThan(0.99));
  });

  test('a shape is worth less drawn backwards', () {
    // Which end a shape starts at is part of what it is - said outright in
    // the settings, and this is what says it in code.
    final forwards = GestureStroke.fromDrawing(checkMark())!;
    final backwards = GestureStroke.fromDrawing(
      checkMark().reversed.toList(),
    )!;
    expect(strokeScore(forwards, backwards), lessThan(minMatchScore));
  });

  group('storing a shape keeps it the same shape', () {
    test('there and back through JSON', () {
      final original = GestureStroke.fromDrawing(triangle())!;
      final restored = GestureStroke.fromJson(original.toJson())!;
      expect(restored.points.length, sampleCount);
      expect(strokeScore(original, restored), greaterThan(0.99));
    });

    test('anything else reads back as nothing rather than throwing', () {
      expect(GestureStroke.fromJson(null), isNull);
      expect(GestureStroke.fromJson('herz'), isNull);
      expect(GestureStroke.fromJson([1, 2]), isNull);
      // An odd number of values is half a point short.
      expect(GestureStroke.fromJson([1, 2, 3, 4, 5, 6, 7, 8, 9]), isNull);
      expect(GestureStroke.fromJson([1, 2, 3, 4, 'x', 6, 7, 8]), isNull);
    });
  });

  test('every stroke is thinned to the same number of points', () {
    // Three points or three hundred, drawn fast or slow: what is compared is
    // always the same 64 steps along the line.
    expect(GestureStroke.fromDrawing(circle(points: 300))!.points.length,
        sampleCount);
    expect(GestureStroke.fromDrawing(circle(points: 6))!.points.length,
        sampleCount);
  });

  test('a stroke too short to be anything is not a stroke', () {
    expect(GestureStroke.fromDrawing(const []), isNull);
    expect(
      GestureStroke.fromDrawing(const [Offset(1, 1), Offset(1, 1)]),
      isNull,
    );
  });
}
