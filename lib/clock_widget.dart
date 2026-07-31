import 'dart:async';

import 'package:flutter/material.dart';

import 'clock_settings_controller.dart';
import 'locale_controller.dart';

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
        return Align(
          alignment: Alignment.topCenter,
          child: settings.style == ClockStyle.digital
              ? const DigitalClock()
              : const WordClock(),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$hh:$mm',
          style: TextStyle(
            fontSize: widget.fontSize,
            fontWeight: FontWeight.w300,
            color: Colors.black,
          ),
        ),
        Text(
          '${_now.day.toString().padLeft(2, '0')}.'
          '${_now.month.toString().padLeft(2, '0')}.'
          '${_now.year}',
          style: TextStyle(
            fontSize: widget.fontSize * 0.28,
            color: Colors.black54,
          ),
        ),
      ],
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
