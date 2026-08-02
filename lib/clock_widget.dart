import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'clock_settings_controller.dart';
import 'locale_controller.dart';
import 'system_app_launcher.dart';

/// Shows the configured clock (digital or word-style), or nothing if the
/// clock is turned off in settings.
class ClockDisplay extends StatelessWidget {
  const ClockDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ClockSettings>(
      valueListenable: ClockSettingsController.instance,
      builder: (context, settings, child) {
        if (!settings.enabled) return const SizedBox.shrink();
        // scaleDown keeps the clock at its natural size when there's room
        // and shrinks it to fit on shorter screens instead of overflowing.
        // It also sizes itself to its content rather than filling the space,
        // which lets the caller lay out other widgets directly beneath it.
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: SystemAppLauncher.openClock,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topCenter,
            child: switch (settings.style) {
              ClockStyle.digital => const DigitalClock(),
              ClockStyle.word => const WordClock(),
              ClockStyle.roman => const RomanClock(),
              ClockStyle.bars => const BarsClock(),
              ClockStyle.dotMatrix => const DotMatrixClock(),
              ClockStyle.splitFlap => const SplitFlapClock(),
              ClockStyle.orbit => const OrbitClock(),
              ClockStyle.vertical => const VerticalClock(),
            },
          ),
        );
      },
    );
  }
}

class DigitalClock extends StatefulWidget {
  const DigitalClock({super.key, this.fontSize = 56});

  final double fontSize;

  @override
  State<DigitalClock> createState() => _DigitalClockState();
}

class _DigitalClockState extends State<DigitalClock> {
  late DateTime _now = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      Future.microtask(() {
        if (!mounted) return;
        setState(() => _now = DateTime.now());
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hh = _now.hour.toString().padLeft(2, '0');
    final mm = _now.minute.toString().padLeft(2, '0');
    return ValueListenableBuilder<ClockSettings>(
      valueListenable: ClockSettingsController.instance,
      builder: (context, settings, child) {
        final color = settings.digitalColor;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$hh:$mm',
              style: TextStyle(
                fontSize: widget.fontSize,
                fontWeight: FontWeight.w300,
                color: color,
              ),
            ),
            Text(
              '${_now.day.toString().padLeft(2, '0')}.'
              '${_now.month.toString().padLeft(2, '0')}.'
              '${_now.year}',
              style: TextStyle(
                fontSize: widget.fontSize * 0.28,
                color: color.withValues(alpha: 0.6),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Hour and minute spelled out in Roman numerals (e.g. "XII:V"), with the
/// date underneath in the usual digits. Minutes aren't zero-padded - Roman
/// numerals have no notion of it - and zero itself has none at all, so it
/// falls back to "0".
class RomanClock extends StatefulWidget {
  const RomanClock({super.key, this.fontSize = 56});

  final double fontSize;

  @override
  State<RomanClock> createState() => _RomanClockState();
}

class _RomanClockState extends State<RomanClock> {
  late DateTime _now = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      Future.microtask(() {
        if (!mounted) return;
        setState(() => _now = DateTime.now());
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var hour = _now.hour % 12;
    if (hour == 0) hour = 12;
    return ValueListenableBuilder<ClockSettings>(
      valueListenable: ClockSettingsController.instance,
      builder: (context, settings, child) {
        final color = settings.romanColor;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${_toRoman(hour)}:${_toRoman(_now.minute)}',
              style: TextStyle(
                fontSize: widget.fontSize,
                fontWeight: FontWeight.w300,
                color: color,
              ),
            ),
            Text(
              '${_now.day.toString().padLeft(2, '0')}.'
              '${_now.month.toString().padLeft(2, '0')}.'
              '${_now.year}',
              style: TextStyle(
                fontSize: widget.fontSize * 0.28,
                color: color.withValues(alpha: 0.6),
              ),
            ),
          ],
        );
      },
    );
  }
}

const List<int> _romanValues = [
  1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1,
];
const List<String> _romanSymbols = [
  'M', 'CM', 'D', 'CD', 'C', 'XC', 'L', 'XL', 'X', 'IX', 'V', 'IV', 'I',
];

String _toRoman(int number) {
  if (number <= 0) return '0';
  var remaining = number;
  final buffer = StringBuffer();
  for (var i = 0; i < _romanValues.length; i++) {
    while (remaining >= _romanValues[i]) {
      buffer.write(_romanSymbols[i]);
      remaining -= _romanValues[i];
    }
  }
  return buffer.toString();
}

/// Three bars - hour, minute, second - each filled from the bottom up in
/// proportion to how far its unit has gotten through its own cycle, moving
/// again every second.
class BarsClock extends StatefulWidget {
  const BarsClock({super.key, this.barHeight = 120, this.barWidth = 28});

  final double barHeight;
  final double barWidth;

  @override
  State<BarsClock> createState() => _BarsClockState();
}

class _BarsClockState extends State<BarsClock> {
  late DateTime _now = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      Future.microtask(() {
        if (!mounted) return;
        setState(() => _now = DateTime.now());
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ClockSettings>(
      valueListenable: ClockSettingsController.instance,
      builder: (context, settings, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _Bar(
              fraction: _now.hour / 24,
              label: '${_now.hour}',
              height: widget.barHeight,
              width: widget.barWidth,
              settings: settings,
            ),
            const SizedBox(width: 14),
            _Bar(
              fraction: _now.minute / 60,
              label: '${_now.minute}',
              height: widget.barHeight,
              width: widget.barWidth,
              settings: settings,
            ),
            const SizedBox(width: 14),
            _Bar(
              fraction: _now.second / 60,
              label: '${_now.second}',
              height: widget.barHeight,
              width: widget.barWidth,
              settings: settings,
            ),
          ],
        );
      },
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.fraction,
    required this.label,
    required this.height,
    required this.width,
    required this.settings,
  });

  final double fraction;
  final String label;
  final double height;
  final double width;
  final ClockSettings settings;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: width,
          height: height,
          alignment: Alignment.bottomCenter,
          decoration: BoxDecoration(
            color: settings.barsUnfilledColor,
            borderRadius: BorderRadius.circular(width / 2),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
            width: width,
            height: height * fraction.clamp(0.0, 1.0),
            decoration: BoxDecoration(
              color: settings.barsFilledColor,
              borderRadius: BorderRadius.circular(width / 2),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: settings.barsTextColor,
          ),
        ),
      ],
    );
  }
}

/// Hour and minute rendered as a classic LED-style 3x5 dot matrix. One
/// accent color throughout - a digit's dots are either lit or dimmed, never
/// a different color.
class DotMatrixClock extends StatefulWidget {
  const DotMatrixClock({super.key, this.dotSize = 8});

  final double dotSize;

  @override
  State<DotMatrixClock> createState() => _DotMatrixClockState();
}

class _DotMatrixClockState extends State<DotMatrixClock> {
  late DateTime _now = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      Future.microtask(() {
        if (!mounted) return;
        setState(() => _now = DateTime.now());
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hh = _now.hour.toString().padLeft(2, '0');
    final mm = _now.minute.toString().padLeft(2, '0');
    return ValueListenableBuilder<ClockSettings>(
      valueListenable: ClockSettingsController.instance,
      builder: (context, settings, child) {
        final color = settings.dotColor;
        final digitGap = widget.dotSize * 0.7;
        final groupGap = widget.dotSize * 1.1;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _DotDigit(
                  digit: int.parse(hh[0]),
                  color: color,
                  dotSize: widget.dotSize,
                ),
                SizedBox(width: digitGap),
                _DotDigit(
                  digit: int.parse(hh[1]),
                  color: color,
                  dotSize: widget.dotSize,
                ),
                SizedBox(width: groupGap),
                _DotColon(color: color, dotSize: widget.dotSize),
                SizedBox(width: groupGap),
                _DotDigit(
                  digit: int.parse(mm[0]),
                  color: color,
                  dotSize: widget.dotSize,
                ),
                SizedBox(width: digitGap),
                _DotDigit(
                  digit: int.parse(mm[1]),
                  color: color,
                  dotSize: widget.dotSize,
                ),
              ],
            ),
            SizedBox(height: widget.dotSize),
            Text(
              '${_now.day.toString().padLeft(2, '0')}.'
              '${_now.month.toString().padLeft(2, '0')}.'
              '${_now.year}',
              style: TextStyle(
                fontSize: widget.dotSize * 1.4,
                color: color.withValues(alpha: 0.6),
              ),
            ),
          ],
        );
      },
    );
  }
}

const Map<int, List<String>> _dotDigitPatterns = {
  0: ['111', '101', '101', '101', '111'],
  1: ['010', '110', '010', '010', '111'],
  2: ['111', '001', '111', '100', '111'],
  3: ['111', '001', '111', '001', '111'],
  4: ['101', '101', '111', '001', '001'],
  5: ['111', '100', '111', '001', '111'],
  6: ['111', '100', '111', '101', '111'],
  7: ['111', '001', '010', '010', '010'],
  8: ['111', '101', '111', '101', '111'],
  9: ['111', '101', '111', '001', '111'],
};

class _DotDigit extends StatelessWidget {
  const _DotDigit({
    required this.digit,
    required this.color,
    required this.dotSize,
  });

  final int digit;
  final Color color;
  final double dotSize;

  @override
  Widget build(BuildContext context) {
    final pattern = _dotDigitPatterns[digit]!;
    final gap = dotSize * 0.35;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var r = 0; r < pattern.length; r++) ...[
          if (r > 0) SizedBox(height: gap),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var c = 0; c < pattern[r].length; c++) ...[
                if (c > 0) SizedBox(width: gap),
                _MatrixDot(
                  lit: pattern[r][c] == '1',
                  color: color,
                  size: dotSize,
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

/// The two dots between hour and minute, vertically centered to the same
/// height as a digit so the whole row lines up.
class _DotColon extends StatelessWidget {
  const _DotColon({required this.color, required this.dotSize});

  final Color color;
  final double dotSize;

  @override
  Widget build(BuildContext context) {
    final gap = dotSize * 0.35;
    final digitHeight = dotSize * 5 + gap * 4;
    return SizedBox(
      height: digitHeight,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _MatrixDot(lit: true, color: color, size: dotSize),
          SizedBox(height: gap * 2 + dotSize),
          _MatrixDot(lit: true, color: color, size: dotSize),
        ],
      ),
    );
  }
}

class _MatrixDot extends StatelessWidget {
  const _MatrixDot({
    required this.lit,
    required this.color,
    required this.size,
  });

  final bool lit;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: lit ? 1 : 0.12),
      ),
    );
  }
}

/// A mechanical split-flap ("Solari board") clock: each digit is a card
/// that flips over whenever its value changes. One accent color throughout
/// - card background and digit/seam-line color, no hue shifts.
class SplitFlapClock extends StatefulWidget {
  const SplitFlapClock({
    super.key,
    this.digitWidth = 44,
    this.digitHeight = 64,
    this.fontSize = 40,
  });

  final double digitWidth;
  final double digitHeight;
  final double fontSize;

  @override
  State<SplitFlapClock> createState() => _SplitFlapClockState();
}

class _SplitFlapClockState extends State<SplitFlapClock> {
  late DateTime _now = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      Future.microtask(() {
        if (!mounted) return;
        setState(() => _now = DateTime.now());
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hh = _now.hour.toString().padLeft(2, '0');
    final mm = _now.minute.toString().padLeft(2, '0');
    return ValueListenableBuilder<ClockSettings>(
      valueListenable: ClockSettingsController.instance,
      builder: (context, settings, child) {
        final bgColor = settings.splitFlapBgColor;
        final textColor = settings.splitFlapTextColor;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _FlipDigit(
                  digit: int.parse(hh[0]),
                  bgColor: bgColor,
                  textColor: textColor,
                  width: widget.digitWidth,
                  height: widget.digitHeight,
                  fontSize: widget.fontSize,
                ),
                const SizedBox(width: 4),
                _FlipDigit(
                  digit: int.parse(hh[1]),
                  bgColor: bgColor,
                  textColor: textColor,
                  width: widget.digitWidth,
                  height: widget.digitHeight,
                  fontSize: widget.fontSize,
                ),
                SizedBox(
                  width: widget.digitWidth * 0.45,
                  child: Text(
                    ':',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: widget.fontSize,
                      fontWeight: FontWeight.w300,
                      color: textColor,
                    ),
                  ),
                ),
                _FlipDigit(
                  digit: int.parse(mm[0]),
                  bgColor: bgColor,
                  textColor: textColor,
                  width: widget.digitWidth,
                  height: widget.digitHeight,
                  fontSize: widget.fontSize,
                ),
                const SizedBox(width: 4),
                _FlipDigit(
                  digit: int.parse(mm[1]),
                  bgColor: bgColor,
                  textColor: textColor,
                  width: widget.digitWidth,
                  height: widget.digitHeight,
                  fontSize: widget.fontSize,
                ),
              ],
            ),
            SizedBox(height: widget.fontSize * 0.3),
            Text(
              '${_now.day.toString().padLeft(2, '0')}.'
              '${_now.month.toString().padLeft(2, '0')}.'
              '${_now.year}',
              style: TextStyle(
                fontSize: widget.fontSize * 0.28,
                color: textColor.withValues(alpha: 0.6),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// One flap card. Whenever [digit] changes from its previous build, it
/// plays a single 3D flip from the old value to the new one - the old
/// face rotates down to the edge, then the new face continues the turn
/// down to flat, so the text is never seen mirrored mid-flip.
class _FlipDigit extends StatefulWidget {
  const _FlipDigit({
    required this.digit,
    required this.bgColor,
    required this.textColor,
    required this.width,
    required this.height,
    required this.fontSize,
  });

  final int digit;
  final Color bgColor;
  final Color textColor;
  final double width;
  final double height;
  final double fontSize;

  @override
  State<_FlipDigit> createState() => _FlipDigitState();
}

class _FlipDigitState extends State<_FlipDigit>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );
  late int _previousDigit = widget.digit;

  @override
  void didUpdateWidget(covariant _FlipDigit oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.digit != widget.digit) {
      _previousDigit = oldWidget.digit;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final firstHalf = t < 0.5;
        final angle = firstHalf ? t * pi : (t - 0.5) * pi - pi / 2;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0016)
            ..rotateX(angle),
          child: _FlapCard(
            digit: firstHalf ? _previousDigit : widget.digit,
            bgColor: widget.bgColor,
            textColor: widget.textColor,
            width: widget.width,
            height: widget.height,
            fontSize: widget.fontSize,
          ),
        );
      },
    );
  }
}

class _FlapCard extends StatelessWidget {
  const _FlapCard({
    required this.digit,
    required this.bgColor,
    required this.textColor,
    required this.width,
    required this.height,
    required this.fontSize,
  });

  final int digit;
  final Color bgColor;
  final Color textColor;
  final double width;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            '$digit',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: textColor,
              height: 1,
            ),
          ),
          // The seam of the flap board - a hairline across the middle.
          Positioned(
            left: 0,
            right: 0,
            top: height / 2 - 0.5,
            child: Container(
              height: 1,
              color: textColor.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }
}

/// No hands, no numerals around a dial - a single dot orbits a thin ring
/// once per hour, its position marking the minute, with the hour as a
/// number resting in the center. A small "HH:MM" readout underneath keeps
/// the exact time legible even though the ring itself is abstract. One
/// accent color throughout.
class OrbitClock extends StatefulWidget {
  const OrbitClock({super.key, this.size = 140});

  final double size;

  @override
  State<OrbitClock> createState() => _OrbitClockState();
}

class _OrbitClockState extends State<OrbitClock> {
  late DateTime _now = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      Future.microtask(() {
        if (!mounted) return;
        setState(() => _now = DateTime.now());
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var hour = _now.hour % 12;
    if (hour == 0) hour = 12;
    // Includes seconds so the dot glides smoothly around the ring instead
    // of jumping once a minute.
    final minuteFraction = (_now.minute + _now.second / 60) / 60;
    final hh = _now.hour.toString().padLeft(2, '0');
    final mm = _now.minute.toString().padLeft(2, '0');
    return ValueListenableBuilder<ClockSettings>(
      valueListenable: ClockSettingsController.instance,
      builder: (context, settings, child) {
        final color = settings.orbitColor;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: widget.size,
              height: widget.size,
              child: CustomPaint(
                painter: _OrbitPainter(fraction: minuteFraction, color: color),
                child: Center(
                  child: Text(
                    '$hour',
                    style: TextStyle(
                      fontSize: widget.size * 0.32,
                      fontWeight: FontWeight.w300,
                      color: color,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: widget.size * 0.06),
            Text(
              '$hh:$mm',
              style: TextStyle(
                fontSize: widget.size * 0.15,
                color: color.withValues(alpha: 0.7),
              ),
            ),
            SizedBox(height: widget.size * 0.02),
            Text(
              '${_now.day.toString().padLeft(2, '0')}.'
              '${_now.month.toString().padLeft(2, '0')}.'
              '${_now.year}',
              style: TextStyle(
                fontSize: widget.size * 0.1,
                color: color.withValues(alpha: 0.45),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Draws the ring, four reference ticks at 12/3/6/9, and the orbiting dot.
/// [fraction] is how far through the hour we are (0 = top, clockwise).
class _OrbitPainter extends CustomPainter {
  _OrbitPainter({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;

    final ringPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, ringPaint);

    final tickPaint = Paint()
      ..color = color.withValues(alpha: 0.45)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i++) {
      final angle = i * pi / 2 - pi / 2;
      final direction = Offset(cos(angle), sin(angle));
      canvas.drawLine(
        center + direction * radius,
        center + direction * (radius - 6),
        tickPaint,
      );
    }

    final dotAngle = fraction * 2 * pi - pi / 2;
    final dotCenter =
        center + Offset(cos(dotAngle), sin(dotAngle)) * radius;
    canvas.drawCircle(dotCenter, 5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter oldDelegate) {
    return oldDelegate.fraction != fraction || oldDelegate.color != color;
  }
}

/// Hour and minute written top-to-bottom in a single column - every digit
/// stacked under the previous one, like traditional vertical (tategaki)
/// text, with a small dot between hour and minute instead of a colon. One
/// accent color throughout.
class VerticalClock extends StatefulWidget {
  const VerticalClock({super.key, this.fontSize = 38});

  final double fontSize;

  @override
  State<VerticalClock> createState() => _VerticalClockState();
}

class _VerticalClockState extends State<VerticalClock> {
  late DateTime _now = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      Future.microtask(() {
        if (!mounted) return;
        setState(() => _now = DateTime.now());
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hh = _now.hour.toString().padLeft(2, '0');
    final mm = _now.minute.toString().padLeft(2, '0');
    return ValueListenableBuilder<ClockSettings>(
      valueListenable: ClockSettingsController.instance,
      builder: (context, settings, child) {
        final color = settings.verticalColor;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final char in hh.split(''))
              Text(
                char,
                style: TextStyle(
                  fontSize: widget.fontSize,
                  fontWeight: FontWeight.w300,
                  color: color,
                  height: 1.05,
                ),
              ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: widget.fontSize * 0.18),
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.5),
                ),
              ),
            ),
            for (final char in mm.split(''))
              Text(
                char,
                style: TextStyle(
                  fontSize: widget.fontSize,
                  fontWeight: FontWeight.w300,
                  color: color,
                  height: 1.05,
                ),
              ),
            SizedBox(height: widget.fontSize * 0.3),
            Text(
              '${_now.day.toString().padLeft(2, '0')}.'
              '${_now.month.toString().padLeft(2, '0')}.'
              '${_now.year}',
              style: TextStyle(
                fontSize: widget.fontSize * 0.28,
                color: color.withValues(alpha: 0.6),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A German QLOCKTWO-style word clock: a fixed grid of letters where the
/// ones spelling out the current time (rounded to 5 minutes) are lit up.
class WordClock extends StatefulWidget {
  const WordClock({super.key});

  @override
  State<WordClock> createState() => _WordClockState();
}

class _WordClockState extends State<WordClock> {
  late DateTime _now = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      Future.microtask(() {
        if (!mounted) return;
        setState(() => _now = DateTime.now());
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final extraMinutes = _now.minute % 5;
    const cellSize = 22.0;

    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LocaleController.instance,
      builder: (context, language, child) {
        final grid = language == AppLanguage.en ? _gridEn : _gridDe;
        final active = language == AppLanguage.en
            ? _activeCellsEn(_now)
            : _activeCellsDe(_now);
        return ValueListenableBuilder<ClockSettings>(
          valueListenable: ClockSettingsController.instance,
          builder: (context, settings, child) {
            final activeColor = settings.wordActiveColor;
            final inactiveColor = settings.wordInactiveColor;
            return Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: settings.wordBgColor.withValues(
                  alpha: settings.wordBgOpacity,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var row = 0; row < grid.length; row++)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var col = 0; col < grid[row].length; col++)
                          SizedBox(
                            width: cellSize,
                            height: cellSize,
                            child: Center(
                              child: Text(
                                grid[row][col],
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: active.contains((row, col))
                                      ? activeColor
                                      : inactiveColor,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 1; i <= 4; i++)
                        _Dot(lit: extraMinutes >= i, color: activeColor),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.lit, required this.color});

  final bool lit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: lit ? color : color.withValues(alpha: 0.3),
      ),
    );
  }
}

class _Word {
  const _Word(this.row, this.cols);
  final int row;
  final List<int> cols;
}

// --- German grid (QLOCKTWO-style), 10x11 -----------------------------

const List<String> _gridDe = [
  'ESKISTAFÜNF',
  'ZEHNZWANZIG',
  'DREIVIERTEL',
  'VORFUNKNACH',
  'HALBAELFÜNF',
  'EINSXAMZWEI',
  'DREIPMJVIER',
  'SECHSNLACHT',
  'SIEBENZWÖLF',
  'ZEHNEUNKUHR',
];

const _deEs = _Word(0, [0, 1]);
const _deIst = _Word(0, [3, 4, 5]);
const _deFuenfMin = _Word(0, [7, 8, 9, 10]);
const _deZehnMin = _Word(1, [0, 1, 2, 3]);
const _deZwanzig = _Word(1, [4, 5, 6, 7, 8, 9, 10]);
const _deViertel = _Word(2, [4, 5, 6, 7, 8, 9, 10]);
const _deVor = _Word(3, [0, 1, 2]);
const _deNach = _Word(3, [7, 8, 9, 10]);
const _deHalb = _Word(4, [0, 1, 2, 3]);
const _deUhr = _Word(9, [8, 9, 10]);

const Map<int, _Word> _deHourWords = {
  1: _Word(5, [0, 1, 2, 3]), // EINS
  2: _Word(5, [7, 8, 9, 10]), // ZWEI
  3: _Word(6, [0, 1, 2, 3]), // DREI
  4: _Word(6, [7, 8, 9, 10]), // VIER
  5: _Word(4, [7, 8, 9, 10]), // FÜNF
  6: _Word(7, [0, 1, 2, 3, 4]), // SECHS
  7: _Word(8, [0, 1, 2, 3, 4, 5]), // SIEBEN
  8: _Word(7, [7, 8, 9, 10]), // ACHT
  9: _Word(9, [3, 4, 5, 6]), // NEUN
  10: _Word(9, [0, 1, 2, 3]), // ZEHN
  11: _Word(4, [5, 6, 7]), // ELF
  12: _Word(8, [6, 7, 8, 9, 10]), // ZWÖLF
};

Set<(int, int)> _activeCellsDe(DateTime time) {
  var hour = time.hour % 12;
  if (hour == 0) hour = 12;
  final minute = time.minute;
  final m5 = minute - (minute % 5);

  final words = <_Word>[_deEs, _deIst];
  // German "halb"/"vor"/"nach" phrases starting at :25 already refer to
  // the NEXT hour (e.g. 10:25 -> "fünf vor halb elf").
  var displayHour = hour;

  if (m5 == 0) {
    words.add(_deUhr);
  } else if (m5 == 5) {
    words.addAll([_deFuenfMin, _deNach]);
  } else if (m5 == 10) {
    words.addAll([_deZehnMin, _deNach]);
  } else if (m5 == 15) {
    words.addAll([_deViertel, _deNach]);
  } else if (m5 == 20) {
    words.addAll([_deZwanzig, _deNach]);
  } else if (m5 == 25) {
    words.addAll([_deFuenfMin, _deVor, _deHalb]);
    displayHour = hour % 12 + 1;
  } else if (m5 == 30) {
    words.add(_deHalb);
    displayHour = hour % 12 + 1;
  } else if (m5 == 35) {
    words.addAll([_deFuenfMin, _deNach, _deHalb]);
    displayHour = hour % 12 + 1;
  } else if (m5 == 40) {
    words.addAll([_deZwanzig, _deVor]);
    displayHour = hour % 12 + 1;
  } else if (m5 == 45) {
    words.addAll([_deViertel, _deVor]);
    displayHour = hour % 12 + 1;
  } else if (m5 == 50) {
    words.addAll([_deZehnMin, _deVor]);
    displayHour = hour % 12 + 1;
  } else if (m5 == 55) {
    words.addAll([_deFuenfMin, _deVor]);
    displayHour = hour % 12 + 1;
  }
  words.add(_deHourWords[displayHour]!);
  return _cellsOf(words);
}

// --- English grid, 12x11 ------------------------------------------------
// A self-built grid (not a specific commercial product's exact layout):
// "IT IS [FIVE/TEN/QUARTER/TWENTY/TWENTY FIVE/HALF] [PAST/TO] <hour>
// [O'CLOCK]". The letters between words are just filler with no meaning.

const List<String> _gridEn = [
  'ITKISAMTENR',
  'QUARTERDSTY',
  'TWENTYAFIVE',
  'HALFOPASTDY',
  'TOLYONESTWO',
  'THREEMFOURD',
  'FIVEYSIXPQR',
  'SEVENLEIGHT',
  'NINEOTENCLK',
  'ELEVENDPQRS',
  'TWELVEHJKLM',
  'OCLOCKABCDE',
];

const _enIt = _Word(0, [0, 1]);
const _enIs = _Word(0, [3, 4]);
const _enTenMin = _Word(0, [7, 8, 9]);
const _enQuarter = _Word(1, [0, 1, 2, 3, 4, 5, 6]);
const _enTwenty = _Word(2, [0, 1, 2, 3, 4, 5]);
const _enFiveMin = _Word(2, [7, 8, 9, 10]);
const _enHalf = _Word(3, [0, 1, 2, 3]);
const _enPast = _Word(3, [5, 6, 7, 8]);
const _enTo = _Word(4, [0, 1]);
const _enOclock = _Word(11, [0, 1, 2, 3, 4, 5]);

const Map<int, _Word> _enHourWords = {
  1: _Word(4, [4, 5, 6]), // ONE
  2: _Word(4, [8, 9, 10]), // TWO
  3: _Word(5, [0, 1, 2, 3, 4]), // THREE
  4: _Word(5, [6, 7, 8, 9]), // FOUR
  5: _Word(6, [0, 1, 2, 3]), // FIVE
  6: _Word(6, [5, 6, 7]), // SIX
  7: _Word(7, [0, 1, 2, 3, 4]), // SEVEN
  8: _Word(7, [6, 7, 8, 9, 10]), // EIGHT
  9: _Word(8, [0, 1, 2, 3]), // NINE
  10: _Word(8, [5, 6, 7]), // TEN
  11: _Word(9, [0, 1, 2, 3, 4, 5]), // ELEVEN
  12: _Word(10, [0, 1, 2, 3, 4, 5]), // TWELVE
};

Set<(int, int)> _activeCellsEn(DateTime time) {
  var hour = time.hour % 12;
  if (hour == 0) hour = 12;
  final minute = time.minute;
  final m5 = minute - (minute % 5);

  final words = <_Word>[_enIt, _enIs];
  // English "past" phrases (up to half past) use the CURRENT hour; only
  // from :35 onward ("to" phrases) does it refer to the NEXT hour.
  var displayHour = hour;

  if (m5 == 0) {
    words.add(_enOclock);
  } else if (m5 == 5) {
    words.addAll([_enFiveMin, _enPast]);
  } else if (m5 == 10) {
    words.addAll([_enTenMin, _enPast]);
  } else if (m5 == 15) {
    words.addAll([_enQuarter, _enPast]);
  } else if (m5 == 20) {
    words.addAll([_enTwenty, _enPast]);
  } else if (m5 == 25) {
    words.addAll([_enTwenty, _enFiveMin, _enPast]);
  } else if (m5 == 30) {
    words.addAll([_enHalf, _enPast]);
  } else if (m5 == 35) {
    words.addAll([_enTwenty, _enFiveMin, _enTo]);
    displayHour = hour % 12 + 1;
  } else if (m5 == 40) {
    words.addAll([_enTwenty, _enTo]);
    displayHour = hour % 12 + 1;
  } else if (m5 == 45) {
    words.addAll([_enQuarter, _enTo]);
    displayHour = hour % 12 + 1;
  } else if (m5 == 50) {
    words.addAll([_enTenMin, _enTo]);
    displayHour = hour % 12 + 1;
  } else if (m5 == 55) {
    words.addAll([_enFiveMin, _enTo]);
    displayHour = hour % 12 + 1;
  }
  words.add(_enHourWords[displayHour]!);
  return _cellsOf(words);
}

Set<(int, int)> _cellsOf(List<_Word> words) {
  final cells = <(int, int)>{};
  for (final word in words) {
    for (final col in word.cols) {
      cells.add((word.row, col));
    }
  }
  return cells;
}
