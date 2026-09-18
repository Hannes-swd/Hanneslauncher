import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

/// One shape drawn in a single go, and everything needed to decide later
/// which of the saved ones a new drawing is.
///
/// The comparison is the $1 unistroke recognizer (Wobbrock, Wilson, Li,
/// 2007): every stroke - saved or just drawn - is boiled down to the same
/// [sampleCount] evenly spaced points, turned so it points the same way,
/// blown up to the same size and moved onto the same spot. What is left of
/// two strokes after that can be compared point by point, and how far apart
/// they are is how unlike each other they are.
///
/// That is what makes a shape drawn small in the corner the same shape as
/// one drawn big in the middle: position and size are normalised away before
/// anything is compared, and are never part of the answer.

/// How many points every stroke is reduced to. 64 is what the paper uses:
/// enough to keep a heart's dip and a house's roof apart, few enough that
/// matching a drawing against a handful of saved shapes is instant.
const int sampleCount = 64;

/// The square every stroke is scaled into before comparing. Only its ratio
/// to [_maxDistance] matters, so the number itself is arbitrary - it is the
/// paper's.
const double _normalSize = 250.0;

/// The worst two normalised strokes can possibly score against each other:
/// the diagonal of that square, halved. A distance of this much is a score
/// of 0, a distance of 0 is a score of 1.
final double _maxDistance = 0.5 * math.sqrt(2 * _normalSize * _normalSize);

/// How far the recognizer turns a drawing looking for a better fit. The
/// stroke is already rotated so its start points the same way as the saved
/// one's ("indicative angle"), so this is only the fine adjustment on top -
/// which is why a heart drawn slightly crooked still matches, while one
/// drawn upside down does not.
const double _angleRange = math.pi / 4;
const double _anglePrecision = math.pi / 90;

/// A stroke thinner than this is treated as a line rather than a shape, and
/// is scaled up keeping its proportions instead of being stretched into the
/// square. Without it every straight line is stretched into the same square
/// of finger wobble, and they all match each other.
const double _thinRatio = 0.25;

/// A drawn shape, as the points it was drawn with - already thinned down to
/// [sampleCount] of them, but still in the size and the place it was drawn
/// in, so a saved one can be drawn back on screen the way it was made.
class GestureStroke {
  GestureStroke(this.points);

  final List<Offset> points;

  /// Takes what a finger actually produced (hundreds of points, unevenly
  /// spaced, at whatever size the finger happened to draw) and keeps the
  /// [sampleCount] that matter. Returns null when there is not enough of a
  /// stroke to be a shape at all.
  static GestureStroke? fromDrawing(List<Offset> raw) {
    final cleaned = _dropDuplicates(raw);
    if (cleaned.length < 4) return null;
    if (_pathLength(cleaned) <= 0) return null;
    return GestureStroke(_resample(cleaned, sampleCount));
  }

  /// The box the shape was drawn in.
  Rect get bounds => _boundsOf(points);

  /// How long the drawn line is, following it end to end, in the units it
  /// was drawn in. Used to tell a deliberate shape from a stray flick - see
  /// [isDeliberateShape].
  double get pathLength => _pathLength(points);

  /// The comparable form: turned, scaled and centred. Built once and kept,
  /// since every saved shape is compared against every drawing.
  late final List<Offset> normalized = _normalize(points);

  /// Stored flat - `[x0, y0, x1, y1, ...]` - rather than as a list of
  /// objects: it is the same numbers either way, and a backup file full of
  /// `{"x":..,"y":..}` for 64 points per shape would be several times the
  /// size for nothing.
  List<double> toJson() => [
    for (final point in points) ...[_round(point.dx), _round(point.dy)],
  ];

  /// Reads one back. Returns null rather than throwing on anything that
  /// isn't a list of pairs of numbers, so one unreadable shape in a backup
  /// costs only that shape.
  static GestureStroke? fromJson(Object? json) {
    if (json is! List) return null;
    if (json.length < 8 || json.length.isOdd) return null;
    final points = <Offset>[];
    for (var i = 0; i < json.length; i += 2) {
      final x = json[i];
      final y = json[i + 1];
      if (x is! num || y is! num) return null;
      points.add(Offset(x.toDouble(), y.toDouble()));
    }
    return GestureStroke(points);
  }

  /// One decimal is a tenth of a pixel - far past what a finger can aim at,
  /// and it keeps the stored numbers short.
  static double _round(double value) => (value * 10).roundToDouble() / 10;
}

/// What a drawing turned out to be.
enum StrokeVerdict {
  /// Not a drawing at all: too short, too small, or a straight flick.
  /// Nothing happens and nothing is said - this is the swipe that was never
  /// meant to be a shape.
  notAShape,

  /// A real attempt at a shape, but nothing saved comes close. Worth saying
  /// so, because something was clearly meant by it.
  unknown,

  /// Close to more than one saved shape, and not clearly closer to either.
  /// Deliberately not a match: running the wrong shortcut is worse than
  /// running none.
  ambiguous,

  /// One saved shape, clearly.
  match,
}

/// The answer for one drawing: what it was, and how sure that is.
class StrokeRecognition {
  const StrokeRecognition({
    required this.verdict,
    this.id,
    this.score = 0,
    this.runnerUpScore = 0,
  });

  final StrokeVerdict verdict;

  /// The saved shape's id - set only when [verdict] is [StrokeVerdict.match].
  final String? id;

  /// How well the best saved shape fits, from 0 (nothing alike) to 1
  /// (identical). Kept for the other verdicts too, so a screen showing what
  /// happened can say how close it came.
  final double score;

  /// The second best - the difference between "clearly this one" and "could
  /// be either".
  final double runnerUpScore;
}

/// A saved shape, ready to be compared against.
class StrokeTemplate {
  const StrokeTemplate({required this.id, required this.stroke});

  final String id;
  final GestureStroke stroke;
}

/// How well a drawing has to fit the best saved shape before it counts.
///
/// Higher than the paper's own 0.8, and measured rather than guessed (see
/// gesture_recognition_test.dart, which is where these numbers come from): a
/// shape redrawn by hand, wobble and all, lands between 0.92 and 0.98 of the
/// saved one, while two genuinely different closed shapes - a circle against
/// a square, the worst pair there is, since both are a loop filling the same
/// box - sit at 0.87. The line goes in the gap, nearer the wrong side of it,
/// because opening the wrong app is worse than having to draw again.
const double minMatchScore = 0.88;

/// And the line at which two saved shapes are close enough to be worth
/// warning about when one is being saved. Deliberately below
/// [minMatchScore]: the pair to warn about is not only the one that would
/// fire each other today, but the one that a sloppier drawing tomorrow
/// would.
const double similarShapeScore = 0.85;

/// And how far ahead of the second best it has to be. Two saved shapes that
/// really do look alike (a circle and an oval) land within a hair of each
/// other on every drawing, and firing whichever won by 0.002 would be a coin
/// toss with an app launch riding on it.
const double minMatchMargin = 0.05;

/// Shorter than this - measured along the line, in logical pixels - and it
/// was a swipe, not a drawing.
const double _minPathLength = 110;

/// And it has to cover some ground: a long scribble inside a postage stamp
/// is not a shape either.
const double _minExtent = 40;

/// A shape has to bend somewhere. A straight line has almost none of this
/// (its ends are as far apart as the line is long); anything drawn as a
/// picture has plenty.
const double _maxStraightness = 0.92;

/// Decides what a freshly drawn stroke was.
///
/// [templates] is everything currently saved. With none saved the answer is
/// always [StrokeVerdict.notAShape] - there is nothing it could be.
StrokeRecognition recognizeStroke(
  List<Offset> drawn,
  List<StrokeTemplate> templates,
) {
  final stroke = GestureStroke.fromDrawing(drawn);
  if (stroke == null || !isDeliberateShape(stroke)) {
    return const StrokeRecognition(verdict: StrokeVerdict.notAShape);
  }
  if (templates.isEmpty) {
    return const StrokeRecognition(verdict: StrokeVerdict.notAShape);
  }

  var bestId = templates.first.id;
  var best = 0.0;
  var runnerUp = 0.0;
  for (final template in templates) {
    final score = strokeScore(stroke, template.stroke);
    if (score > best) {
      runnerUp = best;
      best = score;
      bestId = template.id;
    } else if (score > runnerUp) {
      runnerUp = score;
    }
  }

  if (best < minMatchScore) {
    return StrokeRecognition(
      verdict: StrokeVerdict.unknown,
      score: best,
      runnerUpScore: runnerUp,
    );
  }
  if (best - runnerUp < minMatchMargin) {
    return StrokeRecognition(
      verdict: StrokeVerdict.ambiguous,
      score: best,
      runnerUpScore: runnerUp,
    );
  }
  return StrokeRecognition(
    verdict: StrokeVerdict.match,
    id: bestId,
    score: best,
    runnerUpScore: runnerUp,
  );
}

/// Whether a stroke is big enough, long enough and bent enough to have been
/// meant as a shape. Everything the home screen ignores in silence fails
/// here: a flick, a tap that slid a little, a finger dragged across to
/// scroll.
bool isDeliberateShape(GestureStroke stroke) {
  final bounds = stroke.bounds;
  final length = stroke.pathLength;
  if (length < _minPathLength) return false;
  if (math.max(bounds.width, bounds.height) < _minExtent) return false;
  // How much of the drawn line went into getting from the start to the end -
  // 1 for a ruler-straight stroke, well under it for anything with a corner
  // or a curve in it.
  final straightness =
      (stroke.points.first - stroke.points.last).distance / length;
  return straightness < _maxStraightness;
}

/// How alike two strokes are, from 0 to 1. Public so the settings screen can
/// warn that a new shape looks like one that already exists - the same
/// number, computed the same way, as the home screen uses.
double strokeScore(GestureStroke a, GestureStroke b) {
  final distance = _distanceAtBestAngle(a.normalized, b.normalized);
  final score = 1.0 - distance / _maxDistance;
  return score.clamp(0.0, 1.0);
}

// --- the $1 pipeline -------------------------------------------------------

List<Offset> _normalize(List<Offset> points) {
  var work = _resample(points, sampleCount);
  work = _rotateToZero(work);
  work = _scaleToSquare(work);
  return _translateToOrigin(work);
}

/// Consecutive points on the exact same spot carry no direction, which the
/// resampling below would divide by.
List<Offset> _dropDuplicates(List<Offset> points) {
  final out = <Offset>[];
  for (final point in points) {
    if (out.isEmpty || (point - out.last).distance > 0.01) out.add(point);
  }
  return out;
}

/// Walks the drawn line and drops a point every equal step along it. This is
/// what makes speed irrelevant: a corner drawn slowly (dozens of points) and
/// one drawn fast (three) come out as the same corner.
List<Offset> _resample(List<Offset> points, int count) {
  final step = _pathLength(points) / (count - 1);
  final source = [...points];
  final out = <Offset>[source.first];
  var travelled = 0.0;
  for (var i = 1; i < source.length; i++) {
    final segment = (source[i] - source[i - 1]).distance;
    if (travelled + segment >= step) {
      final t = segment == 0 ? 0.0 : (step - travelled) / segment;
      final point = Offset(
        source[i - 1].dx + t * (source[i].dx - source[i - 1].dx),
        source[i - 1].dy + t * (source[i].dy - source[i - 1].dy),
      );
      out.add(point);
      // The new point becomes the next segment's start, so what is left of
      // this segment is not skipped.
      source.insert(i, point);
      travelled = 0;
    } else {
      travelled += segment;
    }
  }
  // Rounding along the way can leave the last step just short.
  while (out.length < count) {
    out.add(source.last);
  }
  return out;
}

/// Turns the stroke so the line from its middle to its first point lies
/// flat. Two drawings of the same shape then start from the same direction,
/// however the phone was held.
List<Offset> _rotateToZero(List<Offset> points) {
  final centroid = _centroidOf(points);
  final angle = math.atan2(
    centroid.dy - points.first.dy,
    centroid.dx - points.first.dx,
  );
  return _rotateBy(points, -angle, centroid);
}

List<Offset> _rotateBy(List<Offset> points, double angle, Offset around) {
  final cos = math.cos(angle);
  final sin = math.sin(angle);
  return [
    for (final point in points)
      Offset(
        (point.dx - around.dx) * cos - (point.dy - around.dy) * sin + around.dx,
        (point.dx - around.dx) * sin + (point.dy - around.dy) * cos + around.dy,
      ),
  ];
}

/// Blows the stroke up to a fixed square, which is what makes a shape drawn
/// in two fingers' worth of space the same shape as one drawn across the
/// whole screen.
///
/// Wide and tall strokes are stretched to fill the square in both directions
/// (the paper's version - it forgives a heart drawn squashed). A stroke that
/// runs almost entirely in one direction is scaled evenly instead, because
/// stretching the thin side of a line out to full width turns finger wobble
/// into the shape itself.
List<Offset> _scaleToSquare(List<Offset> points) {
  final bounds = _boundsOf(points);
  final width = bounds.width;
  final height = bounds.height;
  final longest = math.max(width, height);
  if (longest <= 0) return points;
  final thin = math.min(width, height) / longest < _thinRatio;
  final scaleX = thin
      ? _normalSize / longest
      : (width <= 0 ? 1.0 : _normalSize / width);
  final scaleY = thin
      ? _normalSize / longest
      : (height <= 0 ? 1.0 : _normalSize / height);
  return [
    for (final point in points)
      Offset(
        (point.dx - bounds.left) * scaleX,
        (point.dy - bounds.top) * scaleY,
      ),
  ];
}

/// And finally onto the same spot, so where on the screen it was drawn stops
/// mattering.
List<Offset> _translateToOrigin(List<Offset> points) {
  final centroid = _centroidOf(points);
  return [for (final point in points) point - centroid];
}

/// The best fit within [_angleRange] either way, found by golden section
/// search: the distance as a function of the angle has one dip in that
/// range, so the search only ever needs a handful of tries instead of
/// stepping through every degree.
double _distanceAtBestAngle(List<Offset> points, List<Offset> template) {
  const phi = 0.6180339887498949; // 1 / golden ratio
  var low = -_angleRange;
  var high = _angleRange;
  var x1 = phi * low + (1 - phi) * high;
  var f1 = _distanceAtAngle(points, template, x1);
  var x2 = (1 - phi) * low + phi * high;
  var f2 = _distanceAtAngle(points, template, x2);
  while ((high - low).abs() > _anglePrecision) {
    if (f1 < f2) {
      high = x2;
      x2 = x1;
      f2 = f1;
      x1 = phi * low + (1 - phi) * high;
      f1 = _distanceAtAngle(points, template, x1);
    } else {
      low = x1;
      x1 = x2;
      f1 = f2;
      x2 = (1 - phi) * low + phi * high;
      f2 = _distanceAtAngle(points, template, x2);
    }
  }
  return math.min(f1, f2);
}

double _distanceAtAngle(
  List<Offset> points,
  List<Offset> template,
  double angle,
) {
  return _pathDistance(_rotateBy(points, angle, Offset.zero), template);
}

/// Average distance between the two strokes' matching points - the whole
/// answer, once everything else has been normalised away.
double _pathDistance(List<Offset> a, List<Offset> b) {
  final count = math.min(a.length, b.length);
  if (count == 0) return double.infinity;
  var sum = 0.0;
  for (var i = 0; i < count; i++) {
    sum += (a[i] - b[i]).distance;
  }
  return sum / count;
}

double _pathLength(List<Offset> points) {
  var sum = 0.0;
  for (var i = 1; i < points.length; i++) {
    sum += (points[i] - points[i - 1]).distance;
  }
  return sum;
}

Offset _centroidOf(List<Offset> points) {
  var x = 0.0;
  var y = 0.0;
  for (final point in points) {
    x += point.dx;
    y += point.dy;
  }
  return Offset(x / points.length, y / points.length);
}

Rect _boundsOf(List<Offset> points) {
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
