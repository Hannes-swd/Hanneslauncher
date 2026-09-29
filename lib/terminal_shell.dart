import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import 'secret_apps_controller.dart';
import 'terminal_commands.dart';
import 'terminal_output.dart';
import 'terminal_parser.dart';

/// What the shell needs from the screen it runs in.
abstract class TerminalHost {
  BuildContext get context;

  /// Characters that fit on one line at the current font size.
  int get columns;
  int get rows;

  void closeTerminal();
  Future<void> openEditor(File file);
  Future<void> showMatrix();
}

/// Everything a Dart-side command gets to work with.
class CommandContext {
  CommandContext._(
    this.shell,
    this.name,
    this.args,
    this.stdin,
    this._capture,
  );

  final TerminalShell shell;
  final String name;

  /// The arguments, without the command name.
  final List<String> args;

  /// What was piped in, or null when nothing was.
  final String? stdin;

  final StringBuffer? _capture;

  /// Output goes straight to the screen rather than into a pipe or a file -
  /// the one case where colour belongs in it.
  bool get isTty => _capture == null;

  TermBuffer get out => shell.out;
  TerminalHost get host => shell.host;

  void write(String text) {
    text = shell.withoutSecrets(text);
    final capture = _capture;
    if (capture != null) {
      capture.write(stripAnsi(text));
    } else {
      shell.out.write(text);
    }
  }

  void writeln([String text = '']) => write('$text\n');

  /// An error message: always on the screen, never into the pipe.
  void error(String message) =>
      shell.out.write('$name: $message\n', base: TerminalShell.errorStyle);

  String resolve(String path) => shell.resolvePath(path);

  bool get cancelled => shell._cancelled;

  /// Called once when the user hits Ctrl+C while this command runs.
  void onCancel(void Function() callback) =>
      shell._cancelHandlers.add(callback);
}

class TerminalCommand {
  const TerminalCommand(this.summary, this.run, {this.usage, this.group});

  final String summary;
  final String? usage;
  final String? group;
  final Future<int> Function(CommandContext context) run;
}

/// Runs command lines: the Dart-side commands itself, everything else
/// through the phone's `/system/bin/sh` as this app's user.
///
/// There is no pseudo-terminal behind it (Android does not let an app
/// allocate one without native code), so programs see a pipe rather than a
/// terminal. What that costs is hidden where it can be: `ls` gets its
/// columns and colours back, typed lines go to a running program's input,
/// and Ctrl+C stops it. Full-screen programs like `vi` or `top` in
/// interactive mode cannot work that way - `nano`/`vi` open the launcher's
/// own editor instead.
class TerminalShell {
  TerminalShell({required this.out, required this.host});

  final TermBuffer out;
  final TerminalHost host;

  static const errorStyle = TermStyle(fg: 9);

  late String home;
  late String cwd;
  String? _oldPwd;
  late String _tmp;
  final Map<String, String> vars = {};
  final Map<String, String> aliases = {};
  final List<String> history = [];
  int lastExit = 0;

  /// True while a command runs. The screen hides the prompt then and hands
  /// typed lines to [sendInput].
  final ValueNotifier<bool> busy = ValueNotifier(false);

  Process? _process;
  bool _cancelled = false;
  final List<void Function()> _cancelHandlers = [];

  /// Packages of the secret folder. Output lines naming one are dropped:
  /// the shell can ask Android things the launcher never would
  /// (`pm list packages`, `ls /sdcard/Android/data`), and the secret folder
  /// has to hold for those too.
  Set<String> _hidden = const {};

  static String get shellPath =>
      Platform.isAndroid ? '/system/bin/sh' : '/bin/sh';

  String get user => vars['USER'] ?? 'user';
  String get hostname => vars['HOSTNAME'] ?? 'hanneslauncher';

  File get _historyFile => File('$home/.bash_history');
  File get bashrc => File('$home/.bashrc');

  Future<void> init() async {
    final support = await getApplicationSupportDirectory();
    home = '${support.path}/home';
    await Directory(home).create(recursive: true);
    _tmp = (await getTemporaryDirectory()).path;
    cwd = home;
    vars.addAll({
      'HOME': home,
      'USER': 'hannes',
      'LOGNAME': 'hannes',
      'HOSTNAME': 'hanneslauncher',
      'SHELL': shellPath,
      'TERM': 'xterm-256color',
      'LANG': 'C.UTF-8',
      'TMPDIR': _tmp,
      'PATH':
          Platform.environment['PATH'] ??
          '/product/bin:/apex/com.android.runtime/bin:/system/bin:'
              '/system/xbin:/vendor/bin',
    });
    await _refreshHidden();

    try {
      final lines = await _historyFile.readAsLines();
      history.addAll(lines.where((line) => line.trim().isNotEmpty));
      if (history.length > _historyLimit) {
        history.removeRange(0, history.length - _historyLimit);
      }
    } catch (_) {
      // First start.
    }

    if (!await bashrc.exists()) await bashrc.writeAsString(defaultBashrc);
    await source(bashrc.path, quiet: true);
  }

  /// [text] without the lines that name a secret app. Applied to what the
  /// Dart commands print too: `tree` or `less` can walk into a folder named
  /// after a package just as `ls` can.
  String withoutSecrets(String text) {
    if (_hidden.isEmpty || !_hidesSecret(text, _hidden)) return text;
    return text
        .split('\n')
        .where((line) => !_hidesSecret(line, _hidden))
        .join('\n');
  }

  Future<void> _refreshHidden() async {
    _hidden = {...await SecretAppsController.instance.loadedKeys()};
  }

  static const _historyLimit = 2000;

  // ---------------------------------------------------------------- prompt

  String get displayCwd {
    if (cwd == home) return '~';
    if (cwd.startsWith('$home/')) return '~${cwd.substring(home.length)}';
    return cwd;
  }

  /// `user@host:~$ ` in Ubuntu's colours.
  String get prompt =>
      '\x1B[1;32m$user@$hostname\x1B[0m:\x1B[1;34m$displayCwd\x1B[0m\$ ';

  // ------------------------------------------------------------- execution

  /// A line typed at the prompt: echoed, remembered, run.
  Future<void> submit(String typed) async {
    if (!out.atLineStart) out.write('\n');
    out.write(prompt);
    out.write('$typed\n');

    var line = typed;
    if (line.trim().isEmpty) return;
    final expanded = _expandHistory(line);
    if (expanded == null) {
      out.write('${line.trim()}: event not found\n', base: errorStyle);
      return;
    }
    if (expanded != line) {
      out.write('$expanded\n');
      line = expanded;
    }
    _remember(line);

    busy.value = true;
    _cancelled = false;
    try {
      await _refreshHidden();
      await execute(line);
    } finally {
      _cancelHandlers.clear();
      _process = null;
      busy.value = false;
    }
  }

  /// Runs a whole command line and answers its exit status.
  Future<int> execute(String line) async {
    final expanded = expandAliases(line, aliases);
    if (needsRawShell(expanded)) {
      return lastExit = await _external(expanded, tty: true);
    }
    for (final item in splitCommandList(expanded)) {
      if (_cancelled) break;
      if (item.op == '&&' && lastExit != 0) continue;
      if (item.op == '||' && lastExit == 0) continue;
      try {
        lastExit = await _pipeline(item.text);
      } catch (error) {
        out.write('$error\n', base: errorStyle);
        lastExit = 1;
      }
    }
    return lastExit;
  }

  /// Runs every line of [path] as if typed - `source ~/.bashrc`.
  Future<int> source(String path, {bool quiet = false}) async {
    final file = File(resolvePath(path));
    if (!await file.exists()) {
      if (!quiet) out.write('source: $path: No such file\n', base: errorStyle);
      return 1;
    }
    // Continuation lines and multi-line constructs go to sh whole; the
    // rest line by line so aliases and exports stay in this shell.
    final text = await file.readAsString();
    var code = 0;
    for (final raw in const LineSplitter().convert(text)) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      code = await execute(line);
    }
    return code;
  }

  Future<int> _pipeline(String text) async {
    final stages = [for (final stage in splitPipeline(text)) _rewrite(stage)];

    if (stages.length == 1) {
      final words = tokenizeWords(
        stages.single,
        lookup: lookup,
        home: home,
      );
      if (words.isNotEmpty &&
          words.every((word) => !word.isOperator && isAssignment(word.text))) {
        for (final word in words) {
          final eq = word.text.indexOf('=');
          vars[word.text.substring(0, eq)] = word.text.substring(eq + 1);
        }
        return 0;
      }
    }

    final dart = [
      for (final stage in stages)
        terminalCommands.containsKey(firstWord(stage)),
    ];
    if (!dart.contains(true)) {
      return _external(stages.join(' | '), tty: true);
    }

    String? input;
    var code = 0;
    var i = 0;
    while (i < stages.length) {
      if (_cancelled) return 130;
      final last = i == stages.length - 1;
      if (dart[i]) {
        final result = await _runDart(stages[i], stdin: input, capture: !last);
        code = result.$1;
        input = result.$2;
        i++;
      } else {
        var j = i;
        while (j < stages.length && !dart[j]) {
          j++;
        }
        final chunk = stages.sublist(i, j).join(' | ');
        if (j == stages.length) {
          code = await _external(chunk, stdin: input, tty: true);
        } else {
          final result = await _capture(chunk, stdin: input);
          code = result.$1;
          input = result.$2;
        }
        i = j;
      }
    }
    return code;
  }

  /// Names that mean something else here than on stock Android.
  String _rewrite(String stage) {
    final word = firstWord(stage);
    // bash and zsh do not exist on the phone; sh understands nearly
    // everything written for them that a phone could run anyway.
    if (word == 'bash' || word == 'zsh') {
      return replaceFirstWord(stage, 'sh');
    }
    // `./script.sh`: app storage is mounted so nothing in it may be
    // executed directly (Android's W^X rule), so scripts are handed to sh
    // as a file to read instead.
    if (word.contains('/') && !terminalCommands.containsKey(word)) {
      final file = File(resolvePath(word));
      if (file.existsSync() && !_isElf(file)) {
        return 'sh ${stage.trimLeft()}';
      }
    }
    return stage;
  }

  static bool _isElf(File file) {
    try {
      final handle = file.openSync();
      final head = handle.readSync(4);
      handle.closeSync();
      return head.length == 4 &&
          head[0] == 0x7F &&
          head[1] == 0x45 &&
          head[2] == 0x4C &&
          head[3] == 0x46;
    } catch (_) {
      return false;
    }
  }

  Future<(int, String?)> _runDart(
    String stage, {
    String? stdin,
    required bool capture,
  }) async {
    final text = await _substituteCommands(stage);
    final words = tokenizeWords(text, lookup: lookup, home: home);

    String? outFile;
    var append = false;
    String? inFile;
    final args = <String>[];
    for (var i = 0; i < words.length; i++) {
      final word = words[i];
      if (!word.isOperator) {
        args.addAll(_glob(word));
        continue;
      }
      if (word.text == '2>&1' || word.text == '>&2' || word.text == '>&1') {
        continue;
      }
      final target = i + 1 < words.length ? words[++i].text : null;
      if (target == null) {
        out.write('syntax error near unexpected token `newline\'\n',
            base: errorStyle);
        return (2, null);
      }
      switch (word.text) {
        case '>' || '&>':
          outFile = target;
          append = false;
        case '>>':
          outFile = target;
          append = true;
        case '<':
          inFile = target;
        // 2> file: the Dart commands' errors always go to the screen.
      }
    }
    while (args.isNotEmpty && isAssignment(args.first)) {
      args.removeAt(0);
    }
    if (args.isEmpty) return (0, null);
    final name = args.removeAt(0);
    final command = terminalCommands[name]!;

    if (inFile != null) {
      try {
        stdin = await File(resolvePath(inFile)).readAsString();
      } catch (_) {
        out.write('$inFile: No such file or directory\n', base: errorStyle);
        return (1, null);
      }
    }

    final buffer = capture || outFile != null ? StringBuffer() : null;
    final context = CommandContext._(this, name, args, stdin, buffer);
    int code;
    try {
      code = await command.run(context);
    } catch (error) {
      context.error('$error');
      code = 1;
    }
    if (outFile != null) {
      try {
        await File(resolvePath(outFile)).writeAsString(
          buffer.toString(),
          mode: append ? FileMode.append : FileMode.write,
        );
      } catch (error) {
        out.write('$outFile: $error\n', base: errorStyle);
        return (1, null);
      }
      return (code, capture ? '' : null);
    }
    return (code, buffer?.toString());
  }

  /// `$(...)` and backticks in a Dart-side command, run by sh and pasted
  /// back in - `cd $(dirname $f)`.
  Future<String> _substituteCommands(String text) async {
    final found = findCommandSubstitutions(text);
    if (found.isEmpty) return text;
    var result = text;
    for (final sub in found.reversed) {
      final (_, output) = await _capture(sub.command);
      final value = (output ?? '').replaceFirst(RegExp(r'\n+$'), '');
      result = result.replaceRange(
        sub.start,
        sub.end,
        escapeForShell(value, quoted: sub.quoted),
      );
    }
    return result;
  }

  List<String> _glob(ShellWord word) {
    if (!word.glob) return [word.text];
    final text = word.text;
    final slash = text.lastIndexOf('/');
    final dirPart = slash == -1 ? '' : text.substring(0, slash + 1);
    final pattern = text.substring(slash + 1);
    if (RegExp(r'[*?\[]').hasMatch(dirPart)) return [text];
    final regex = _globRegex(pattern);
    if (regex == null) return [text];
    final dir = Directory(resolvePath(dirPart.isEmpty ? '.' : dirPart));
    try {
      final names = [
        for (final entity in dir.listSync())
          entity.uri.pathSegments.lastWhere((s) => s.isNotEmpty),
      ]..sort();
      final matches = [
        for (final name in names)
          if (regex.hasMatch(name) &&
              (!name.startsWith('.') || pattern.startsWith('.')))
            '$dirPart$name',
      ];
      return matches.isEmpty ? [text] : matches;
    } catch (_) {
      return [text];
    }
  }

  static RegExp? _globRegex(String pattern) {
    final out = StringBuffer('^');
    for (var i = 0; i < pattern.length; i++) {
      final c = pattern[i];
      if (c == '*') {
        out.write('.*');
      } else if (c == '?') {
        out.write('.');
      } else if (c == '[') {
        final close = pattern.indexOf(']', i + 1);
        if (close == -1) return null;
        var body = pattern.substring(i + 1, close);
        if (body.startsWith('!')) body = '^${body.substring(1)}';
        out.write('[$body]');
        i = close;
      } else {
        out.write(RegExp.escape(c));
      }
    }
    out.write(r'$');
    try {
      return RegExp(out.toString());
    } catch (_) {
      return null;
    }
  }

  String lookup(String name) {
    switch (name) {
      case '?':
        return '$lastExit';
      case r'$':
        return '$pid';
      case '0':
        return 'sh';
      case '#':
        return '0';
      case 'PWD':
        return cwd;
      case 'OLDPWD':
        return _oldPwd ?? '';
      case 'COLUMNS':
        return '${host.columns}';
      case 'LINES':
        return '${host.rows}';
      case 'RANDOM':
        return '${DateTime.now().microsecond % 32768}';
    }
    return vars[name] ?? Platform.environment[name] ?? '';
  }

  Map<String, String> get environment => {
    ...vars,
    'PWD': cwd,
    'OLDPWD': ?_oldPwd,
    'COLUMNS': '${host.columns}',
    'LINES': '${host.rows}',
  };

  /// Streams [command] run by sh onto the screen.
  Future<int> _external(
    String command, {
    String? stdin,
    bool tty = false,
  }) async {
    if (tty) command = _pretendTty(command);
    final Process process;
    try {
      process = await Process.start(
        shellPath,
        ['-c', command],
        workingDirectory: Directory(cwd).existsSync() ? cwd : home,
        environment: environment,
      );
    } catch (error) {
      out.write('sh: $error\n', base: errorStyle);
      return 127;
    }
    _process = process;
    if (stdin != null) {
      process.stdin.write(stdin);
      unawaited(process.stdin.close().catchError((_) {}));
    }
    final stdoutSink = _FilteredSink(out, _hidden);
    final stderrSink = _FilteredSink(out, _hidden, style: errorStyle);
    final done = Future.wait([
      process.stdout
          .transform(const Utf8Decoder(allowMalformed: true))
          .forEach(stdoutSink.add),
      process.stderr
          .transform(const Utf8Decoder(allowMalformed: true))
          .forEach(stderrSink.add),
    ]);
    final code = await process.exitCode;
    // A background child can hold the pipes open past the exit; it gets a
    // moment to finish writing, not the terminal.
    await done.timeout(const Duration(seconds: 1), onTimeout: () => []);
    stdoutSink.close();
    stderrSink.close();
    _process = null;
    return code;
  }

  /// What [command] prints, run by sh without anything reaching the
  /// screen but its errors.
  Future<String> captureOutput(String command) async =>
      (await _capture(command)).$2 ?? '';

  /// Runs [command] through sh and hands back what it printed - for a
  /// pipe into a Dart command, or `$(...)`.
  Future<(int, String?)> _capture(String command, {String? stdin}) async {
    try {
      final process = await Process.start(
        shellPath,
        ['-c', command],
        workingDirectory: Directory(cwd).existsSync() ? cwd : home,
        environment: environment,
      );
      _process = process;
      if (stdin != null) process.stdin.write(stdin);
      unawaited(process.stdin.close().catchError((_) {}));
      final errors = _FilteredSink(out, _hidden, style: errorStyle);
      final stderrDone = process.stderr
          .transform(const Utf8Decoder(allowMalformed: true))
          .forEach(errors.add);
      final output = await process.stdout
          .transform(const Utf8Decoder(allowMalformed: true))
          .join();
      await stderrDone;
      errors.close();
      final code = await process.exitCode;
      _process = null;
      final lines = output
          .split('\n')
          .where((line) => !_hidesSecret(line, _hidden))
          .join('\n');
      return (code, lines);
    } catch (error) {
      out.write('sh: $error\n', base: errorStyle);
      return (127, '');
    }
  }

  /// Output that goes straight to the screen is where a real terminal would
  /// be, so the programs that behave differently there are told so by hand:
  /// colours on, and `ls` in columns.
  static String _pretendTty(String command) {
    final stages = splitPipeline(command);
    // Toybox reads a bare --color as "always" and =auto as "only on a tty",
    // which this never is.
    var last = stages.last.replaceAll('--color=auto', '--color');
    if (firstWord(last) == 'ls' && !last.contains('>')) {
      final flags = last
          .split(RegExp(r'\s+'))
          .where((w) => w.startsWith('-') && !w.startsWith('--'));
      final listsOwnWay = flags.any((f) => RegExp('[l1gonmx]').hasMatch(f));
      if (!listsOwnWay) last = replaceFirstWord(last, 'ls -C');
    }
    stages[stages.length - 1] = last;
    return stages.join(' | ');
  }

  /// A line typed while a program runs goes to its input.
  void sendInput(String line) {
    out.write('$line\n');
    try {
      _process?.stdin.writeln(line);
    } catch (_) {
      // It closed its input already.
    }
  }

  /// Ctrl+D: closes a running program's input.
  void sendEof() {
    try {
      _process?.stdin.close();
    } catch (_) {}
  }

  /// Ctrl+C.
  void interrupt() {
    if (!busy.value) return;
    _cancelled = true;
    out.write('^C\n');
    for (final handler in List.of(_cancelHandlers)) {
      handler();
    }
    _cancelHandlers.clear();
    final process = _process;
    if (process != null) {
      // sh -c runs pipelines as children of its own; killing sh alone
      // would leave them running with nobody reading their output.
      Process.run(shellPath, ['-c', 'pkill -KILL -P ${process.pid}'])
          .whenComplete(() => process.kill(ProcessSignal.sigkill))
          .ignore();
    }
  }

  void dispose() {
    _process?.kill(ProcessSignal.sigkill);
    busy.dispose();
  }

  // ----------------------------------------------------------- directories

  String resolvePath(String path) {
    if (path.isEmpty) return cwd;
    if (path == '~') return home;
    if (path.startsWith('~/')) path = '$home${path.substring(1)}';
    final absolute = path.startsWith('/') ? path : '$cwd/$path';
    return _normalize(absolute);
  }

  static String _normalize(String path) {
    // Only a test run on Windows has paths that start with a drive letter.
    final rooted = path.startsWith('/');
    final parts = <String>[];
    for (final part in path.split('/')) {
      if (part.isEmpty || part == '.') continue;
      if (part == '..') {
        if (parts.isNotEmpty) parts.removeLast();
      } else {
        parts.add(part);
      }
    }
    return rooted ? '/${parts.join('/')}' : parts.join('/');
  }

  /// `cd`. Answers an error message or null.
  String? changeDirectory(String? target) {
    String path;
    if (target == null || target.isEmpty) {
      path = home;
    } else if (target == '-') {
      if (_oldPwd == null) return 'OLDPWD not set';
      path = _oldPwd!;
      out.write('$path\n');
    } else {
      path = resolvePath(target);
    }
    final dir = Directory(path);
    if (!dir.existsSync()) {
      return File(path).existsSync()
          ? '$target: Not a directory'
          : '$target: No such file or directory';
    }
    try {
      dir.listSync();
    } catch (_) {
      // Listing can fail on dirs that can still be entered (/data), so
      // only refuse when stat says no access at all.
      if (dir.statSync().type == FileSystemEntityType.notFound) {
        return '$target: Permission denied';
      }
    }
    _oldPwd = cwd;
    cwd = path;
    return null;
  }

  // --------------------------------------------------------------- history

  void _remember(String line) {
    // Like HISTCONTROL=ignoreboth: a leading space keeps a line out, and
    // repeating the last one does not add it twice.
    if (line.startsWith(' ')) return;
    if (history.isNotEmpty && history.last == line) return;
    history.add(line);
    if (history.length > _historyLimit) history.removeAt(0);
    _historyFile
        .writeAsString('$line\n', mode: FileMode.append)
        .catchError((_) => _historyFile)
        .ignore();
  }

  Future<void> clearHistory() async {
    history.clear();
    try {
      await _historyFile.writeAsString('');
    } catch (_) {}
  }

  /// `!!`, `!$`, `!n`, `!-n` and `!prefix`. Null when an event is missing.
  String? _expandHistory(String line) {
    if (!line.contains('!') || line.contains("'")) return line;
    String? failed;
    final result = line.replaceAllMapped(
      RegExp(r'!(!|\$|-?\d+|[A-Za-z][\w.-]*)'),
      (match) {
        final key = match.group(1)!;
        String? found;
        if (key == '!') {
          found = history.isEmpty ? null : history.last;
        } else if (key == r'$') {
          if (history.isNotEmpty) {
            found = history.last.trim().split(RegExp(r'\s+')).last;
          }
        } else if (RegExp(r'^-?\d+$').hasMatch(key)) {
          final n = int.parse(key);
          final index = n < 0 ? history.length + n : n - 1;
          if (index >= 0 && index < history.length) found = history[index];
        } else {
          for (final entry in history.reversed) {
            if (entry.startsWith(key)) {
              found = entry;
              break;
            }
          }
        }
        if (found == null) failed = match.group(0);
        return found ?? match.group(0)!;
      },
    );
    return failed == null ? result : null;
  }

  // ------------------------------------------------------------ completion

  List<String>? _pathCommands;

  Future<List<String>> _programs() async {
    final cached = _pathCommands;
    if (cached != null) return cached;
    final names = <String>{};
    for (final dir in (vars['PATH'] ?? '').split(':')) {
      try {
        for (final entity in Directory(dir).listSync()) {
          names.add(entity.uri.pathSegments.last);
        }
      } catch (_) {}
    }
    return _pathCommands = names.toList()..sort();
  }

  /// Tab. Answers the completed text and - when several things fit - what
  /// they were, for printing under the prompt.
  Future<(String, List<String>)> complete(String text) async {
    final start = _currentWordStart(text);
    final word = text.substring(start);
    final before = text.substring(0, start).trimRight();
    final commandPosition =
        before.isEmpty ||
        before.endsWith('|') ||
        before.endsWith(';') ||
        before.endsWith('&') ||
        before == 'sudo' ||
        before.endsWith(' sudo');

    List<String> candidates;
    var addSpace = true;
    final first = firstWord(before);
    final completer = terminalCompleters[first];
    if (commandPosition && !word.contains('/')) {
      candidates = {
        ...terminalCommands.keys,
        ...aliases.keys,
        ...await _programs(),
      }.where((name) => name.startsWith(word)).toList()..sort();
    } else if (completer != null && !word.contains('/')) {
      final words = before.split(RegExp(r'\s+'));
      candidates = [
        for (final option in await completer(this, words.skip(1).toList()))
          if (option.toLowerCase().startsWith(word.toLowerCase()))
            option.replaceAll(' ', r'\ '),
      ];
    } else {
      final (options, directories) = _completePath(word);
      candidates = [
        for (final option in options)
          if (!_hidesSecret(option, _hidden)) option,
      ];
      addSpace =
          !(candidates.length == 1 &&
              directories.contains(candidates.first));
    }

    if (candidates.isEmpty) return (text, const <String>[]);
    if (candidates.length == 1) {
      return (
        text.substring(0, start) + candidates.single + (addSpace ? ' ' : ''),
        const <String>[],
      );
    }
    final common = _commonPrefix(candidates);
    final completed = text.substring(0, start) +
        (common.length > word.length ? common : word);
    final shown = [
      for (final candidate in candidates)
        candidate.endsWith('/') && candidate.length > 1
            ? candidate.substring(
                  candidate.lastIndexOf('/', candidate.length - 2) + 1,
                )
            : candidate.substring(candidate.lastIndexOf('/') + 1),
    ];
    return (completed, shown);
  }

  (List<String>, Set<String>) _completePath(String word) {
    final slash = word.lastIndexOf('/');
    final dirPart = slash == -1 ? '' : word.substring(0, slash + 1);
    final prefix = word.substring(slash + 1).replaceAll(r'\ ', ' ');
    final dir = Directory(resolvePath(dirPart.isEmpty ? '.' : dirPart));
    final options = <String>[];
    final directories = <String>{};
    try {
      for (final entity in dir.listSync()) {
        final name = entity.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
        if (!name.startsWith(prefix)) continue;
        if (name.startsWith('.') && !prefix.startsWith('.')) continue;
        final isDir = entity is Directory;
        final escaped = name.replaceAll(' ', r'\ ');
        final option = '$dirPart$escaped${isDir ? '/' : ''}';
        options.add(option);
        if (isDir) directories.add(option);
      }
    } catch (_) {}
    options.sort();
    return (options, directories);
  }

  static int _currentWordStart(String text) {
    var i = text.length;
    while (i > 0) {
      final c = text[i - 1];
      if ((c == ' ' && !(i > 1 && text[i - 2] == r'\')) ||
          c == '|' ||
          c == ';' ||
          c == '&' ||
          c == '>' ||
          c == '<') {
        break;
      }
      i--;
    }
    return i;
  }

  static String _commonPrefix(List<String> values) {
    var prefix = values.first;
    for (final value in values.skip(1)) {
      var i = 0;
      while (i < prefix.length && i < value.length && prefix[i] == value[i]) {
        i++;
      }
      prefix = prefix.substring(0, i);
    }
    return prefix;
  }
}

bool _hidesSecret(String line, Set<String> hidden) {
  if (hidden.isEmpty) return false;
  for (final package in hidden) {
    if (line.contains(package)) return true;
  }
  return false;
}

/// Program output on its way to the screen, held back one line at a time
/// so a line naming a secret app can be dropped as a whole. A line still
/// open after a moment (a prompt waiting for input, a progress bar) is let
/// through as it is.
class _FilteredSink {
  _FilteredSink(this._out, this._hidden, {this.style});

  final TermBuffer _out;
  final Set<String> _hidden;
  final TermStyle? style;
  String _carry = '';
  Timer? _timer;

  void add(String chunk) {
    _timer?.cancel();
    final text = _carry + chunk;
    final end = text.lastIndexOf('\n');
    if (end == -1) {
      _carry = text;
    } else {
      _emit(text.substring(0, end + 1));
      _carry = text.substring(end + 1);
    }
    if (_carry.isNotEmpty) {
      _timer = Timer(const Duration(milliseconds: 120), _flush);
    }
  }

  void _flush() {
    if (_carry.isEmpty) return;
    if (!_hidesSecret(_carry, _hidden)) _out.write(_carry, base: style);
    _carry = '';
  }

  void _emit(String lines) {
    if (_hidden.isEmpty) {
      _out.write(lines, base: style);
      return;
    }
    final kept = lines
        .split('\n')
        .where((line) => !_hidesSecret(line, _hidden))
        .join('\n');
    _out.write(kept, base: style);
  }

  void close() {
    _timer?.cancel();
    _flush();
  }
}

const String defaultBashrc = r'''# ~/.bashrc: run by the hanneslauncher terminal when it opens.
#
# Every line runs as if typed at the prompt. Change it with `nano ~/.bashrc`
# and load it again with `source ~/.bashrc`.

# Who the prompt says you are.
export USER=hannes
export HOSTNAME=hanneslauncher

# Ubuntu's defaults.
alias ls='ls --color=auto'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'

# A few extras.
alias h='history'
alias c='clear'
alias q='exit'
alias ff='fastfetch'
alias sd='cd /sdcard'
''';
