import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'terminal_commands.dart';
import 'terminal_output.dart';
import 'terminal_shell.dart';
import 'update_controller.dart';

Future<void> openTerminal(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (context) => const TerminalScreen()),
  );
}

const _mono = 'monospace';

/// A terminal in Ubuntu's colours, running the phone's own shell plus the
/// launcher's commands (see [TerminalShell] and `terminal_commands.dart`).
class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen>
    implements TerminalHost {
  final _out = TermBuffer();
  late final TerminalShell _shell = TerminalShell(out: _out, host: this);
  final _input = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();

  /// Kept for as long as the launcher runs, so reopening the terminal does
  /// not undo a pinch.
  static double _fontSize = 13;

  // Pinch and tap are read off raw pointers rather than gesture detectors,
  // which would compete with the list's scrolling and the text selection
  // for the same touches.
  final Map<int, Offset> _pointers = {};
  double? _pinchStartDistance;
  double _pinchStartSize = 13;
  Offset? _tapDown;
  DateTime? _tapDownAt;

  bool _ready = false;
  int? _historyIndex;
  String _draft = '';
  int _columns = 40;
  int _rows = 24;

  @override
  void initState() {
    super.initState();
    _shell.busy.addListener(_busyChanged);
    _start();
  }

  Future<void> _start() async {
    await _shell.init();
    await _motd();
    if (!mounted) return;
    setState(() => _ready = true);
    _focus.requestFocus();
  }

  Future<void> _motd() async {
    final info = (await _shell.captureOutput(
      'getprop ro.build.version.release; uname -r; uname -m',
    )).trim().split('\n');
    if (UpdateController.instance.value.installedVersion.isEmpty) {
      await UpdateController.instance.load();
    }
    final version = UpdateController.instance.value.installedVersion;
    final android = info.isNotEmpty ? info[0] : '?';
    final kernel = info.length > 1 ? info[1] : '?';
    final arch = info.length > 2 ? info[2] : '';
    _out.writeln('Welcome to hanneslauncher $version '
        '(Android $android, Linux $kernel $arch)');
    _out.writeln();
    _out.writeln(' * Help:      help, man <command>');
    _out.writeln(' * Info:      fastfetch, hl info');
    _out.writeln(' * Apps:      apps, open <app>, apt');
    if (!await terminalHasStorageAccess()) {
      _out.writeln(' * Storage:   setup-storage   (to reach /sdcard)');
    }
    _out.writeln();

    final lastLogin = File('${_shell.home}/.lastlogin');
    try {
      final previous = DateTime.parse(await lastLogin.readAsString());
      _out.writeln('Last login: ${_ubuntuDate(previous)}');
    } catch (_) {
      // First time.
    }
    try {
      await lastLogin.writeAsString(DateTime.now().toIso8601String());
    } catch (_) {}
  }

  static String _ubuntuDate(DateTime t) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    String two(int v) => v.toString().padLeft(2, '0');
    return '${days[t.weekday - 1]} ${months[t.month - 1]} '
        '${t.day.toString().padLeft(2)} ${two(t.hour)}:${two(t.minute)}:'
        '${two(t.second)} ${t.year}';
  }

  void _busyChanged() {
    if (!mounted) return;
    setState(() {});
    if (!_shell.busy.value) _focus.requestFocus();
  }

  @override
  void dispose() {
    _shell.busy.removeListener(_busyChanged);
    _shell.dispose();
    _out.dispose();
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------- TerminalHost

  @override
  int get columns => _columns;

  @override
  int get rows => _rows;

  @override
  void closeTerminal() {
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Future<void> openEditor(File file) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => TerminalEditorScreen(file: file)),
    );
  }

  @override
  Future<void> showMatrix() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        pageBuilder: (_, _, _) => const _MatrixRain(),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  // ----------------------------------------------------------------- input

  void _submit(String text) {
    _input.clear();
    _historyIndex = null;
    _draft = '';
    if (_scroll.hasClients) _scroll.jumpTo(0);
    if (_shell.busy.value) {
      _shell.sendInput(text);
    } else {
      _shell.submit(text);
    }
    _focus.requestFocus();
  }

  void _historyStep(int direction) {
    final history = _shell.history;
    if (history.isEmpty || _shell.busy.value) return;
    var index = _historyIndex ?? history.length;
    if (_historyIndex == null) _draft = _input.text;
    index = (index + direction).clamp(0, history.length);
    _historyIndex = index;
    _setInput(index == history.length ? _draft : history[index]);
  }

  void _setInput(String text, {int? cursor}) {
    _input.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: cursor ?? text.length),
    );
  }

  Future<void> _tab() async {
    if (_shell.busy.value) return;
    final value = _input.value;
    final cursor = value.selection.isValid
        ? value.selection.baseOffset
        : value.text.length;
    final before = value.text.substring(0, cursor);
    final after = value.text.substring(cursor);
    final (completed, options) = await _shell.complete(before);
    if (options.isNotEmpty) {
      if (!_out.atLineStart) _out.write('\n');
      _out.write(_shell.prompt);
      _out.writeln(value.text);
      _out.writeln(_columnsOf(options));
    }
    _setInput(completed + after, cursor: completed.length);
  }

  String _columnsOf(List<String> items) {
    final width = items.fold(0, (w, i) => math.max(w, i.length)) + 2;
    final perLine = math.max(1, _columns ~/ width);
    final buffer = StringBuffer();
    for (var i = 0; i < items.length; i++) {
      buffer.write(items[i].padRight(width));
      if ((i + 1) % perLine == 0 && i != items.length - 1) buffer.write('\n');
    }
    return buffer.toString().trimRight();
  }

  void _insert(String text) {
    final value = _input.value;
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    final newText = value.text.replaceRange(
      selection.start,
      selection.end,
      text,
    );
    _setInput(newText, cursor: selection.start + text.length);
  }

  void _moveCursor(int delta) {
    final value = _input.value;
    final offset = (value.selection.isValid
            ? value.selection.baseOffset
            : value.text.length) +
        delta;
    _setInput(value.text, cursor: offset.clamp(0, value.text.length));
  }

  void _interrupt() {
    if (_shell.busy.value) {
      _shell.interrupt();
    } else {
      // Like bash: ^C on a half-typed line throws it away.
      if (!_out.atLineStart) _out.write('\n');
      _out.write(_shell.prompt);
      _out.writeln('${_input.text}^C');
      _input.clear();
      _historyIndex = null;
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final ctrl = HardwareKeyboard.instance.isControlPressed;
    if (ctrl && key == LogicalKeyboardKey.keyC) {
      _interrupt();
      return KeyEventResult.handled;
    }
    if (ctrl && key == LogicalKeyboardKey.keyL) {
      _out.clear();
      return KeyEventResult.handled;
    }
    if (ctrl && key == LogicalKeyboardKey.keyD) {
      if (_shell.busy.value) {
        _shell.sendEof();
      } else if (_input.text.isEmpty) {
        closeTerminal();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.tab) {
      _tab();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _historyStep(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _historyStep(1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ----------------------------------------------------------------- build

  TextStyle get _baseStyle => TextStyle(
    fontFamily: _mono,
    fontSize: _fontSize,
    height: 1.25,
    color: terminalForeground,
  );

  void _measure(double width, double height) {
    final painter = TextPainter(
      text: TextSpan(text: 'MMMMMMMMMM', style: _baseStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final charWidth = painter.width / 10;
    final lineHeight = painter.height;
    painter.dispose();
    _columns = math.max(20, (width / charWidth).floor());
    _rows = math.max(5, (height / lineHeight).floor());
  }

  void _pointerDown(PointerDownEvent event) {
    _pointers[event.pointer] = event.position;
    if (_pointers.length == 1) {
      _tapDown = event.position;
      _tapDownAt = DateTime.now();
    } else {
      _tapDown = null;
      if (_pointers.length == 2) {
        final points = _pointers.values.toList();
        _pinchStartDistance = (points[0] - points[1]).distance;
        _pinchStartSize = _fontSize;
      }
    }
  }

  void _pointerMove(PointerMoveEvent event) {
    _pointers[event.pointer] = event.position;
    final start = _pinchStartDistance;
    if (start == null || _pointers.length != 2 || start < 1) return;
    final points = _pointers.values.toList();
    final scale = (points[0] - points[1]).distance / start;
    setState(() => _fontSize = (_pinchStartSize * scale).clamp(7.0, 28.0));
  }

  void _pointerUp(PointerUpEvent event) {
    _pointers.remove(event.pointer);
    if (_pointers.length < 2) _pinchStartDistance = null;
    final down = _tapDown;
    final at = _tapDownAt;
    _tapDown = null;
    if (down == null || at == null) return;
    final short = DateTime.now().difference(at).inMilliseconds < 400;
    if (short && (event.position - down).distance < 20) {
      // A plain tap anywhere brings the keyboard back, like in Termux.
      // After the tap's own handling, so the text selection - which takes
      // the focus for itself on a tap - cannot take it back again.
      Future.microtask(() {
        if (!mounted) return;
        _focus.requestFocus();
        SystemChannels.textInput.invokeMethod<void>('TextInput.show');
      });
    }
  }

  Widget _line(List<TermSpan> spans) {
    if (spans.isEmpty) return Text(' ', style: _baseStyle);
    return Text.rich(
      TextSpan(
        children: [
          for (final span in spans)
            TextSpan(text: span.text, style: span.style.toTextStyle()),
        ],
      ),
      style: _baseStyle,
    );
  }

  Widget _inputRow() {
    final field = Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: TextField(
        controller: _input,
        focusNode: _focus,
        enabled: _ready,
        style: _baseStyle,
        cursorColor: terminalForeground,
        cursorWidth: math.max(2, _fontSize * 0.55),
        autocorrect: false,
        enableSuggestions: false,
        smartDashesType: SmartDashesType.disabled,
        smartQuotesType: SmartQuotesType.disabled,
        keyboardType: TextInputType.visiblePassword,
        textInputAction: TextInputAction.send,
        // Every border spelled out: the launcher's theme draws a focused
        // underline in the accent colour, and .collapsed() only clears the
        // plain one.
        decoration: const InputDecoration(
          isCollapsed: true,
          filled: false,
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
        ),
        onSubmitted: _submit,
        onEditingComplete: () {}, // keep the keyboard up
      ),
    );
    if (_shell.busy.value || !_ready) return field;
    final parsed = TermBuffer()..write(_shell.prompt);
    final prompt = _line(parsed.lines.first);
    final length = TermBuffer.textOf(parsed.lines.first).length;
    parsed.dispose();
    // Typing starts right after the `$`, as in a real terminal. Only a
    // prompt too long for that (deep in a folder) gets a line of its own,
    // instead of being squeezed into a narrow column beside the input.
    if (length + 12 <= _columns) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [prompt, Expanded(child: field)],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [prompt, field],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        systemNavigationBarColor: terminalBackground,
      ),
      child: Scaffold(
        backgroundColor: terminalBackground,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _measure(constraints.maxWidth - 16, constraints.maxHeight);
                    return Listener(
                      // The whole area, not just the lines: below short
                      // output there is nothing else to catch a tap.
                      behavior: HitTestBehavior.translucent,
                      onPointerDown: _pointerDown,
                      onPointerMove: _pointerMove,
                      onPointerUp: _pointerUp,
                      onPointerCancel: (event) {
                        _pointers.remove(event.pointer);
                        _pinchStartDistance = null;
                      },
                      child: SelectionArea(
                        child: ListenableBuilder(
                          listenable: _out,
                          builder: (context, _) {
                            final lines = _out.lines;
                            final shown = lines.last.isEmpty
                                ? lines.length - 1
                                : lines.length;
                            // Reversed so new output stays in view at
                            // the bottom, shrink-wrapped and pinned to the
                            // top so a fresh terminal starts up there
                            // rather than at the bottom of an empty screen.
                            return Align(
                              alignment: Alignment.topCenter,
                              child: ListView.builder(
                                controller: _scroll,
                                reverse: true,
                                shrinkWrap: true,
                                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                                itemCount: shown + 1,
                                itemBuilder: (context, index) {
                                  if (index == 0) return _inputRow();
                                  return _line(lines[shown - index]);
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
              _ExtraKeys(
                onTab: _tab,
                onInterrupt: _interrupt,
                onUp: () => _historyStep(-1),
                onDown: () => _historyStep(1),
                onLeft: () => _moveCursor(-1),
                onRight: () => _moveCursor(1),
                onInsert: _insert,
                onClear: _out.clear,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The keys a phone keyboard does not have, in a row above it - the same
/// idea as Termux's extra keys.
class _ExtraKeys extends StatelessWidget {
  const _ExtraKeys({
    required this.onTab,
    required this.onInterrupt,
    required this.onUp,
    required this.onDown,
    required this.onLeft,
    required this.onRight,
    required this.onInsert,
    required this.onClear,
  });

  final VoidCallback onTab;
  final VoidCallback onInterrupt;
  final VoidCallback onUp;
  final VoidCallback onDown;
  final VoidCallback onLeft;
  final VoidCallback onRight;
  final ValueChanged<String> onInsert;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    Widget key(String label, VoidCallback onTap, {bool repeat = false}) {
      return _RepeatKey(label: label, onTap: onTap, repeat: repeat);
    }

    return Container(
      color: const Color(0xFF1E0617),
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        children: [
          key('TAB', onTab),
          key('^C', onInterrupt),
          key('↑', onUp, repeat: true),
          key('↓', onDown, repeat: true),
          key('←', onLeft, repeat: true),
          key('→', onRight, repeat: true),
          for (final symbol in const ['|', '/', '-', '~', '>', r'$', '&', '*'])
            key(symbol, () => onInsert(symbol)),
          key('^L', onClear),
        ],
      ),
    );
  }
}

class _RepeatKey extends StatefulWidget {
  const _RepeatKey({
    required this.label,
    required this.onTap,
    required this.repeat,
  });

  final String label;
  final VoidCallback onTap;
  final bool repeat;

  @override
  State<_RepeatKey> createState() => _RepeatKeyState();
}

class _RepeatKeyState extends State<_RepeatKey> {
  Timer? _timer;

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      onLongPressStart: widget.repeat
          ? (_) {
              _timer = Timer.periodic(
                const Duration(milliseconds: 80),
                (_) => widget.onTap(),
              );
            }
          : null,
      onLongPressEnd: widget.repeat ? (_) => _stop() : null,
      child: Container(
        constraints: const BoxConstraints(minWidth: 40),
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0x22FFFFFF),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          widget.label,
          style: const TextStyle(
            fontFamily: _mono,
            color: terminalForeground,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// What `nano`, `vi` and `vim` open: the file in a plain text field. A real
/// full-screen editor needs a terminal that can place a cursor anywhere on
/// the screen, which a pipe to `sh` cannot give it.
class TerminalEditorScreen extends StatefulWidget {
  const TerminalEditorScreen({super.key, required this.file});

  final File file;

  @override
  State<TerminalEditorScreen> createState() => _TerminalEditorScreenState();
}

class _TerminalEditorScreenState extends State<TerminalEditorScreen> {
  final _text = TextEditingController();
  String _saved = '';
  bool _loaded = false;
  bool _isNew = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      if (await widget.file.exists()) {
        _saved = await widget.file.readAsString();
      } else {
        _isNew = true;
      }
    } catch (error) {
      _status = "Can't read this file as text: $error";
    }
    _text.text = _saved;
    if (mounted) setState(() => _loaded = true);
  }

  bool get _dirty => _text.text != _saved;

  Future<bool> _save() async {
    try {
      await widget.file.parent.create(recursive: true);
      await widget.file.writeAsString(_text.text);
      final lines = '\n'.allMatches(_text.text).length +
          (_text.text.isEmpty || _text.text.endsWith('\n') ? 0 : 1);
      setState(() {
        _saved = _text.text;
        _isNew = false;
        _status = '[ Wrote $lines line${lines == 1 ? '' : 's'} ]';
      });
      return true;
    } catch (error) {
      setState(() => _status = '[ Error writing: $error ]');
      return false;
    }
  }

  Future<void> _exit() async {
    if (!_dirty) {
      Navigator.of(context).pop();
      return;
    }
    final answer = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save modified buffer?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'no'),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'yes'),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    if (!mounted || answer == null || answer == 'cancel') return;
    if (answer == 'yes' && !await _save()) return;
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bar = Color(0xFFD0CFCC);
    const barText = TextStyle(
      fontFamily: _mono,
      color: terminalBackground,
      fontSize: 13,
    );
    final name = widget.file.uri.pathSegments.last;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exit();
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyS, control: true): _save,
          const SingleActivator(LogicalKeyboardKey.keyO, control: true): _save,
          const SingleActivator(LogicalKeyboardKey.keyX, control: true): _exit,
        },
        child: Scaffold(
          backgroundColor: terminalBackground,
          body: SafeArea(
            child: Column(
              children: [
                Container(
                  color: bar,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      const Text('GNU nano 7.2', style: barText),
                      Expanded(
                        child: Text(
                          name + (_dirty ? ' *' : ''),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: barText.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(_isNew ? 'New File' : '', style: barText),
                    ],
                  ),
                ),
                Expanded(
                  child: _loaded
                      ? TextField(
                          controller: _text,
                          maxLines: null,
                          expands: true,
                          autofocus: true,
                          autocorrect: false,
                          enableSuggestions: false,
                          keyboardType: TextInputType.multiline,
                          textAlignVertical: TextAlignVertical.top,
                          cursorColor: terminalForeground,
                          style: const TextStyle(
                            fontFamily: _mono,
                            fontSize: 13,
                            color: terminalForeground,
                            height: 1.3,
                          ),
                          decoration: const InputDecoration(
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.all(8),
                          ),
                          onChanged: (_) => setState(() => _status = null),
                        )
                      : const SizedBox.shrink(),
                ),
                if (_status != null)
                  Container(
                    width: double.infinity,
                    color: bar,
                    padding: const EdgeInsets.all(2),
                    child: Text(
                      _status!,
                      textAlign: TextAlign.center,
                      style: barText,
                    ),
                  ),
                Container(
                  color: const Color(0xFF1E0617),
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      _nanoKey('^S', 'Save', _save),
                      _nanoKey('^X', 'Exit', _exit),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _nanoKey(String key, String label, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: key,
                  style: const TextStyle(
                    backgroundColor: Color(0xFFD0CFCC),
                    color: terminalBackground,
                  ),
                ),
                TextSpan(text: ' $label'),
              ],
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: _mono,
              color: terminalForeground,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

/// `cmatrix`: green characters raining down until the screen is tapped.
class _MatrixRain extends StatefulWidget {
  const _MatrixRain();

  @override
  State<_MatrixRain> createState() => _MatrixRainState();
}

class _MatrixRainState extends State<_MatrixRain>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick)..start();
  final _random = math.Random();
  final _frame = ValueNotifier(0);
  late final _painter = _MatrixPainter(_frame);
  Duration _last = Duration.zero;

  void _tick(Duration elapsed) {
    if (elapsed - _last < const Duration(milliseconds: 60)) return;
    _last = elapsed;
    _painter.step(_random);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: ColoredBox(
        color: Colors.black,
        child: SizedBox.expand(child: CustomPaint(painter: _painter)),
      ),
    );
  }
}

class _MatrixPainter extends CustomPainter {
  _MatrixPainter(this._frame) : super(repaint: _frame);

  final ValueNotifier<int> _frame;
  static const _cell = 14.0;
  static const _chars =
      'ｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ0123456789';

  List<double> _heads = [];
  List<double> _speeds = [];
  List<List<String>> _glyphs = [];
  Size _size = Size.zero;

  void step(math.Random random) {
    if (_heads.isEmpty) return;
    for (var i = 0; i < _heads.length; i++) {
      _heads[i] += _speeds[i];
      final rows = _glyphs[i].length;
      if (_heads[i] - 20 > rows) {
        _heads[i] = -random.nextDouble() * 20;
        _speeds[i] = 0.4 + random.nextDouble() * 0.8;
      }
      if (random.nextDouble() < 0.3) {
        _glyphs[i][random.nextInt(rows)] =
            _chars[random.nextInt(_chars.length)];
      }
    }
    _frame.value++;
  }

  void _setup(Size size) {
    _size = size;
    final random = math.Random();
    final columns = (size.width / _cell).ceil();
    final rows = (size.height / _cell).ceil();
    _heads = List.generate(columns, (_) => -random.nextDouble() * rows);
    _speeds = List.generate(columns, (_) => 0.4 + random.nextDouble() * 0.8);
    _glyphs = List.generate(
      columns,
      (_) => List.generate(rows, (_) => _chars[random.nextInt(_chars.length)]),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size != _size) _setup(size);
    for (var x = 0; x < _heads.length; x++) {
      final head = _heads[x].floor();
      for (var y = math.max(0, head - 18); y <= head; y++) {
        if (y >= _glyphs[x].length) break;
        final age = head - y;
        final color = age == 0
            ? const Color(0xFFE8FFE8)
            : Color.fromARGB(
                (255 * (1 - age / 19)).round().clamp(0, 255),
                0,
                255,
                70,
              );
        final painter = TextPainter(
          text: TextSpan(
            text: _glyphs[x][y],
            style: TextStyle(fontFamily: _mono, fontSize: 13, color: color),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        painter.paint(canvas, Offset(x * _cell, y * _cell));
        painter.dispose();
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
