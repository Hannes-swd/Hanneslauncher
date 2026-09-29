import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// What the terminal screen draws: lines of styled text, filled by writing
/// raw program output into it - escape codes and all.
///
/// Programs colour their output with ANSI escape sequences (`ls --color`,
/// `grep --color`, anything from wttr.in), so this is a small interpreter
/// for the part of them that makes sense in a scrolling log: colours and
/// text attributes, carriage return (progress bars redraw their line with
/// it), backspace, tab and "clear the screen". Cursor movement is dropped -
/// there is no full-screen mode for it to move around in.

/// Ubuntu's own terminal palette, so `ls` looks the way it does there.
const List<Color> terminalPalette = [
  Color(0xFF171421), // black
  Color(0xFFC01C28), // red
  Color(0xFF26A269), // green
  Color(0xFFA2734C), // yellow
  Color(0xFF3A7BD5), // blue - a touch lighter than Ubuntu's, which is hard
  //                    to read on a phone in daylight
  Color(0xFFA347BA), // magenta
  Color(0xFF2AA1B3), // cyan
  Color(0xFFD0CFCC), // white
  Color(0xFF5E5C64), // bright black
  Color(0xFFF66151), // bright red
  Color(0xFF33D17A), // bright green
  Color(0xFFE9AD0C), // bright yellow
  Color(0xFF2A7BDE), // bright blue
  Color(0xFFC061CB), // bright magenta
  Color(0xFF33C7DE), // bright cyan
  Color(0xFFFFFFFF), // bright white
];

/// The classic Ubuntu aubergine.
const Color terminalBackground = Color(0xFF300A24);
const Color terminalForeground = Color(0xFFEEEEEC);

/// The 256-colour table programs pick from with `38;5;n`.
Color xtermColor(int index) {
  if (index < 16) return terminalPalette[index];
  if (index < 232) {
    final i = index - 16;
    int level(int v) => v == 0 ? 0 : 55 + v * 40;
    return Color.fromARGB(
      255,
      level(i ~/ 36),
      level((i ~/ 6) % 6),
      level(i % 6),
    );
  }
  final grey = 8 + (index - 232) * 10;
  return Color.fromARGB(255, grey, grey, grey);
}

@immutable
class TermStyle {
  const TermStyle({
    this.fg,
    this.bg,
    this.bold = false,
    this.dim = false,
    this.italic = false,
    this.underline = false,
    this.inverse = false,
  });

  static const plain = TermStyle();

  /// A palette index 0-7 (brightened when bold, the way terminals do), or
  /// null for the default colour.
  final int? fg;
  final int? bg;

  final bool bold;
  final bool dim;
  final bool italic;
  final bool underline;
  final bool inverse;

  // Separate from [fg]/[bg] so that a bold 256-colour or true-colour value is
  // not brightened: only the 8 basic colours are.
  static const _rgbFlag = 1 << 30;

  TermStyle copyWith({
    Object? fg = _keep,
    Object? bg = _keep,
    bool? bold,
    bool? dim,
    bool? italic,
    bool? underline,
    bool? inverse,
  }) {
    return TermStyle(
      fg: identical(fg, _keep) ? this.fg : fg as int?,
      bg: identical(bg, _keep) ? this.bg : bg as int?,
      bold: bold ?? this.bold,
      dim: dim ?? this.dim,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
      inverse: inverse ?? this.inverse,
    );
  }

  Color? _resolve(int? value, {required bool brighten}) {
    if (value == null) return null;
    if (value & _rgbFlag != 0) return Color(0xFF000000 | (value & 0xFFFFFF));
    if (brighten && value < 8) return terminalPalette[value + 8];
    return xtermColor(value);
  }

  Color? get foregroundColor => _resolve(fg, brighten: bold);
  Color? get backgroundColor => _resolve(bg, brighten: false);

  TextStyle toTextStyle() {
    var fore = foregroundColor ?? terminalForeground;
    var back = backgroundColor;
    if (inverse) {
      final swapped = back ?? terminalBackground;
      back = fore;
      fore = swapped;
    }
    if (dim) fore = fore.withValues(alpha: 0.6);
    return TextStyle(
      color: fore,
      backgroundColor: back,
      fontWeight: bold ? FontWeight.bold : null,
      fontStyle: italic ? FontStyle.italic : null,
      decoration: underline ? TextDecoration.underline : null,
      decorationColor: fore,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TermStyle &&
      other.fg == fg &&
      other.bg == bg &&
      other.bold == bold &&
      other.dim == dim &&
      other.italic == italic &&
      other.underline == underline &&
      other.inverse == inverse;

  @override
  int get hashCode =>
      Object.hash(fg, bg, bold, dim, italic, underline, inverse);
}

const Object _keep = Object();

class TermSpan {
  TermSpan(this.text, this.style);

  String text;
  final TermStyle style;
}

/// Colour codes out of [text], for anything that goes into a file or a pipe
/// rather than onto the screen.
String stripAnsi(String text) => text.replaceAll(_escape, '');

final _escape = RegExp(r'\x1B(\[[0-9;?]*[ -/]*[@-~]|\][^\x07]*\x07|.)');

class TermBuffer extends ChangeNotifier {
  TermBuffer({this.maxLines = 4000});

  /// Older lines are dropped past this - a `yes` left running would
  /// otherwise eat the phone's memory.
  final int maxLines;

  final List<List<TermSpan>> lines = [[]];

  TermStyle _style = TermStyle.plain;

  /// An escape sequence split across two writes, kept until its end
  /// arrives.
  String _pending = '';

  /// A `\r` was seen: the next printable character starts the line over.
  bool _returned = false;

  /// Bumped on every change, so the screen can tell cheaply whether it has
  /// to rebuild.
  int revision = 0;

  bool _notifyScheduled = false;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void clear() {
    lines
      ..clear()
      ..add([]);
    _style = TermStyle.plain;
    _pending = '';
    _returned = false;
    _changed();
  }

  /// Writes raw output. [base] colours text that sets no colour itself -
  /// used for error messages and the echoed prompt.
  void write(String text, {TermStyle? base}) {
    if (text.isEmpty) return;
    final saved = _style;
    if (base != null) _style = base;
    var input = _pending + text;
    _pending = '';
    final plain = StringBuffer();

    void flush() {
      if (plain.isEmpty) return;
      _append(plain.toString());
      plain.clear();
    }

    var i = 0;
    while (i < input.length) {
      final char = input[i];
      if (char == '\x1B') {
        flush();
        final end = _escapeEnd(input, i);
        if (end == null) {
          // Incomplete - wait for the rest.
          _pending = input.substring(i);
          break;
        }
        _handleEscape(input.substring(i, end));
        i = end;
        continue;
      }
      switch (char) {
        case '\n':
          flush();
          _newLine();
        case '\r':
          flush();
          _returned = true;
        case '\b':
          flush();
          _backspace();
        case '\t':
          flush();
          final column = _lineLength(lines.last);
          plain.write(' ' * (8 - column % 8));
        case '\x07':
          break; // bell
        default:
          if (char.codeUnitAt(0) < 0x20) break;
          plain.write(char);
      }
      i++;
    }
    flush();
    if (base != null) _style = saved;
    _changed();
  }

  void writeln([String text = '', TermStyle? base]) =>
      write('$text\n', base: base);

  /// Plain text of one line, for copying and filtering.
  static String textOf(List<TermSpan> line) =>
      line.map((span) => span.text).join();

  String get allText => lines.map(textOf).join('\n');

  /// Whether the cursor sits at the start of an empty line - so the prompt
  /// can be put on a fresh one after output that did not end in a newline.
  bool get atLineStart => lines.last.isEmpty || _returned;

  void _append(String text) {
    final line = lines.last;
    if (_returned) {
      line.clear();
      _returned = false;
    }
    if (line.isNotEmpty && line.last.style == _style) {
      line.last.text += text;
    } else {
      line.add(TermSpan(text, _style));
    }
  }

  void _newLine() {
    _returned = false;
    lines.add([]);
    if (lines.length > maxLines) {
      lines.removeRange(0, lines.length - maxLines);
    }
  }

  void _backspace() {
    final line = lines.last;
    while (line.isNotEmpty && line.last.text.isEmpty) {
      line.removeLast();
    }
    if (line.isEmpty) return;
    final last = line.last;
    last.text = last.text.substring(0, last.text.length - 1);
    if (last.text.isEmpty) line.removeLast();
  }

  static int _lineLength(List<TermSpan> line) =>
      line.fold(0, (sum, span) => sum + span.text.length);

  /// Index just past the escape sequence starting at [start], or null when
  /// it is cut off.
  static int? _escapeEnd(String input, int start) {
    if (start + 1 >= input.length) return null;
    final kind = input[start + 1];
    if (kind == '[') {
      for (var i = start + 2; i < input.length; i++) {
        final code = input.codeUnitAt(i);
        if (code >= 0x40 && code <= 0x7E) return i + 1;
      }
      return null;
    }
    if (kind == ']') {
      // Operating system command (window title and the like): runs to a
      // bell or to ESC \.
      for (var i = start + 2; i < input.length; i++) {
        if (input[i] == '\x07') return i + 1;
        final next = i + 1 < input.length ? input[i + 1] : '';
        if (input[i] == '\x1B' && next == r'\') {
          return i + 2;
        }
      }
      return null;
    }
    if (kind == '(' || kind == ')') {
      return start + 3 <= input.length ? start + 3 : null;
    }
    return start + 2;
  }

  void _handleEscape(String sequence) {
    if (!sequence.startsWith('\x1B[')) return;
    final command = sequence[sequence.length - 1];
    final params = sequence.substring(2, sequence.length - 1);
    switch (command) {
      case 'm':
        _applySgr(params);
      case 'J':
        if (params == '2' || params == '3') {
          lines
            ..clear()
            ..add([]);
        }
      case 'K':
        // Erase to the end of the line: the cursor is always at the end
        // here, except right after a \r, where it means "blank this line".
        if (_returned && (params.isEmpty || params == '0' || params == '2')) {
          lines.last.clear();
        }
    }
  }

  void _applySgr(String params) {
    final codes = params.isEmpty
        ? [0]
        : params.split(';').map((p) => int.tryParse(p) ?? 0).toList();
    var style = _style;
    for (var i = 0; i < codes.length; i++) {
      final code = codes[i];
      switch (code) {
        case 0:
          style = TermStyle.plain;
        case 1:
          style = style.copyWith(bold: true);
        case 2:
          style = style.copyWith(dim: true);
        case 3:
          style = style.copyWith(italic: true);
        case 4:
          style = style.copyWith(underline: true);
        case 7:
          style = style.copyWith(inverse: true);
        case 21 || 22:
          style = style.copyWith(bold: false, dim: false);
        case 23:
          style = style.copyWith(italic: false);
        case 24:
          style = style.copyWith(underline: false);
        case 27:
          style = style.copyWith(inverse: false);
        case >= 30 && <= 37:
          style = style.copyWith(fg: code - 30);
        case 39:
          style = style.copyWith(fg: null);
        case >= 40 && <= 47:
          style = style.copyWith(bg: code - 40);
        case 49:
          style = style.copyWith(bg: null);
        case >= 90 && <= 97:
          style = style.copyWith(fg: code - 90 + 8);
        case >= 100 && <= 107:
          style = style.copyWith(bg: code - 100 + 8);
        case 38 || 48:
          int? value;
          if (i + 2 < codes.length && codes[i + 1] == 5) {
            // Stored as its RGB value, so bold does not brighten a colour
            // picked from the 256 table.
            final rgb = xtermColor(codes[i + 2].clamp(0, 255)).toARGB32();
            value = TermStyle._rgbFlag | (rgb & 0xFFFFFF);
            i += 2;
          } else if (i + 4 < codes.length && codes[i + 1] == 2) {
            value = TermStyle._rgbFlag |
                (codes[i + 2].clamp(0, 255) << 16) |
                (codes[i + 3].clamp(0, 255) << 8) |
                codes[i + 4].clamp(0, 255);
            i += 4;
          }
          if (value != null) {
            style = code == 38
                ? style.copyWith(fg: value)
                : style.copyWith(bg: value);
          }
      }
    }
    _style = style;
  }

  void _changed() {
    revision++;
    // Output can arrive in hundreds of small chunks a second; one repaint
    // per frame is all the screen can show anyway.
    if (_notifyScheduled || !hasListeners) return;
    _notifyScheduled = true;
    Future.delayed(const Duration(milliseconds: 16), () {
      _notifyScheduled = false;
      if (!_disposed) notifyListeners();
    });
  }
}
