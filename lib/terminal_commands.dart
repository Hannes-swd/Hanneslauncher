import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:installed_apps/installed_apps.dart';
import 'package:url_launcher/url_launcher.dart';

import 'builtin_entries.dart';
import 'device_stats_controller.dart';
import 'expression_calculator.dart';
import 'folders_controller.dart';
import 'launcher_entries_controller.dart';
import 'launcher_entry.dart';
import 'locale_controller.dart';
import 'panel_blocks_controller.dart';
import 'pinned_apps_controller.dart';
import 'settings_backup_screen.dart';
import 'settings_screen.dart';
import 'terminal_parser.dart';
import 'terminal_shell.dart';
import 'update_controller.dart';
import 'update_screen.dart';
import 'wallpaper_controller.dart';
import 'web_apps_controller.dart';

/// The commands that run in Dart rather than in the phone's `sh`: the ones
/// that change the shell itself (`cd`, `export`, `alias`), the ones stock
/// Android does not have but Ubuntu does (`tree`, `nano`, `curl`, `apt`,
/// `lsb_release`), and the ones only a launcher can answer (`fastfetch`,
/// `hl`, `open`). Anything not in here goes to `sh`.
final Map<String, TerminalCommand> terminalCommands = {
  // ------------------------------------------------------------- shell
  'cd': const TerminalCommand(
    'Change the working directory',
    _cd,
    usage: 'cd [dir]   (cd -  goes back, cd  goes home)',
    group: 'Shell',
  ),
  'pwd': TerminalCommand('Print the working directory', (c) async {
    c.writeln(c.shell.cwd);
    return 0;
  }, group: 'Shell'),
  'export': const TerminalCommand(
    'Set a variable for this shell and the programs it starts',
    _export,
    usage: 'export NAME=value ...',
    group: 'Shell',
  ),
  'unset': TerminalCommand('Remove a variable', (c) async {
    for (final name in c.args) {
      c.shell.vars.remove(name);
    }
    return 0;
  }, group: 'Shell'),
  'alias': const TerminalCommand(
    'Define or list aliases',
    _alias,
    usage: "alias name='command'",
    group: 'Shell',
  ),
  'unalias': TerminalCommand('Remove an alias', (c) async {
    if (c.args.contains('-a')) {
      c.shell.aliases.clear();
      return 0;
    }
    var code = 0;
    for (final name in c.args) {
      if (c.shell.aliases.remove(name) == null) {
        c.error('$name: not found');
        code = 1;
      }
    }
    return code;
  }, group: 'Shell'),
  'history': const TerminalCommand(
    'Show the command history',
    _history,
    usage: 'history [n] | history -c',
    group: 'Shell',
  ),
  'clear': TerminalCommand('Clear the screen', (c) async {
    c.out.clear();
    return 0;
  }, group: 'Shell'),
  'reset': TerminalCommand('Clear the screen', (c) async {
    c.out.clear();
    return 0;
  }, group: 'Shell'),
  'exit': TerminalCommand('Close the terminal', (c) async {
    c.host.closeTerminal();
    return 0;
  }, group: 'Shell'),
  'logout': TerminalCommand('Close the terminal', (c) async {
    c.host.closeTerminal();
    return 0;
  }, group: 'Shell'),
  'source': const TerminalCommand(
    'Run a file line by line in this shell',
    _source,
    usage: 'source ~/.bashrc',
    group: 'Shell',
  ),
  '.': const TerminalCommand('Same as source', _source, group: 'Shell'),
  'help': const TerminalCommand('This list', _help, group: 'Shell'),
  'man': const TerminalCommand(
    'Help for one command',
    _man,
    usage: 'man <command>',
    group: 'Shell',
  ),
  'which': const TerminalCommand('Where a command comes from', _which,
      group: 'Shell'),
  'type': const TerminalCommand('Where a command comes from', _which,
      group: 'Shell'),
  'sudo': const TerminalCommand(
    'Run a command (you are already as root as it gets)',
    _sudo,
    group: 'Shell',
  ),
  'whoami': TerminalCommand('Print the user name', (c) async {
    c.writeln(c.shell.user);
    return 0;
  }, group: 'Shell'),

  // ------------------------------------------------------------- files
  'tree': const TerminalCommand(
    'Directory tree',
    _tree,
    usage: 'tree [-a] [-d] [-L depth] [dir]',
    group: 'Files',
  ),
  'nano': const TerminalCommand('Edit a file', _edit,
      usage: 'nano <file>', group: 'Files'),
  'vi': const TerminalCommand('Edit a file', _edit, group: 'Files'),
  'vim': const TerminalCommand('Edit a file', _edit, group: 'Files'),
  'edit': const TerminalCommand('Edit a file', _edit, group: 'Files'),
  'less': const TerminalCommand('Show a file', _less, group: 'Files'),
  'more': const TerminalCommand('Show a file', _less, group: 'Files'),
  'open': const TerminalCommand(
    'Open an app, a web address or a launcher screen',
    _open,
    usage: 'open <app name> | open <url>',
    group: 'Files',
  ),
  'xdg-open': const TerminalCommand('Same as open', _open, group: 'Files'),
  'setup-storage': const TerminalCommand(
    'Allow access to /sdcard (photos, downloads, ...)',
    _setupStorage,
    group: 'Files',
  ),
  'termux-setup-storage': const TerminalCommand(
    'Same as setup-storage',
    _setupStorage,
    group: 'Files',
  ),

  // ----------------------------------------------------------- network
  'curl': const TerminalCommand(
    'Transfer a URL',
    _curl,
    usage: 'curl [-s] [-I] [-o file] [-X method] [-H header] [-d data] url',
    group: 'Network',
  ),
  'wget': const TerminalCommand(
    'Download a file',
    _wget,
    usage: 'wget [-O file] url',
    group: 'Network',
  ),
  'ifconfig': const TerminalCommand('Network interfaces', _ifconfig,
      group: 'Network'),
  'ip': const TerminalCommand('Network interfaces (ip a)', _ip,
      group: 'Network'),
  'myip': const TerminalCommand('Your public IP address', _myip,
      group: 'Network'),
  'weather': const TerminalCommand(
    'Weather from wttr.in',
    _weather,
    usage: 'weather [place] [--full]',
    group: 'Network',
  ),

  // ------------------------------------------------------------ system
  'fastfetch': const TerminalCommand(
    'Phone and launcher at a glance',
    _fastfetch,
    group: 'System',
  ),
  'neofetch': const TerminalCommand('Same as fastfetch', _fastfetch,
      group: 'System'),
  'screenfetch': const TerminalCommand('Same as fastfetch', _fastfetch,
      group: 'System'),
  'lsb_release': const TerminalCommand('Distribution info', _lsbRelease,
      usage: 'lsb_release [-a]', group: 'System'),
  'hostnamectl': const TerminalCommand('Host and OS info', _hostnamectl,
      group: 'System'),
  'battery': const TerminalCommand('Battery level', _battery, group: 'System'),
  'reboot': const TerminalCommand('Not allowed for apps', _power,
      group: 'System'),
  'shutdown': const TerminalCommand('Not allowed for apps', _power,
      group: 'System'),
  'poweroff': const TerminalCommand('Not allowed for apps', _power,
      group: 'System'),

  // ---------------------------------------------------------- launcher
  'apt': const TerminalCommand(
    'Apps the Ubuntu way: list, search, show, install, remove, update',
    _apt,
    usage:
        'apt list [--installed] | apt search <text> | apt show <app>\n'
        '  apt install <app> | apt remove <app> | apt update | apt upgrade',
    group: 'Launcher',
  ),
  'apt-get': const TerminalCommand('Same as apt', _apt, group: 'Launcher'),
  'hl': const TerminalCommand(
    'hanneslauncher itself',
    _hl,
    usage:
        'hl info | apps | pins | folders | version\n'
        '  hl settings | backup | update | offline',
    group: 'Launcher',
  ),
  'hanneslauncher': const TerminalCommand('Same as hl', _hl, group: 'Launcher'),
  'apps': const TerminalCommand('List your apps', _apps, group: 'Launcher'),

  // --------------------------------------------------------------- fun
  'bc': const TerminalCommand(
    'Calculator',
    _bc,
    usage: 'bc 12*7   or   echo "2^10" | bc',
    group: 'Fun',
  ),
  'calc': const TerminalCommand('Calculator', _bc, group: 'Fun'),
  'cowsay': const TerminalCommand('A talking cow', _cowsay, group: 'Fun'),
  'fortune': const TerminalCommand('A random saying', _fortune, group: 'Fun'),
  'lolcat': const TerminalCommand(
    'Rainbow colours',
    _lolcat,
    usage: 'fastfetch | lolcat',
    group: 'Fun',
  ),
  'cmatrix': const TerminalCommand('Wake up, Neo', _cmatrix, group: 'Fun'),
};

/// What Tab offers after a command's name, for commands whose arguments
/// are not file names.
final Map<
  String,
  Future<List<String>> Function(TerminalShell shell, List<String> before)
>
terminalCompleters = {
  'open': (_, _) async => _appNames(),
  'xdg-open': (_, _) async => _appNames(),
  'apt': (_, before) async => before.isEmpty
      ? const ['list', 'search', 'show', 'install', 'remove', 'purge',
          'update', 'upgrade']
      : _appNames(),
  'apt-get': (_, before) async => before.isEmpty
      ? const ['install', 'remove', 'purge', 'update', 'upgrade']
      : _appNames(),
  'hl': (_, before) async => before.isEmpty
      ? const ['info', 'apps', 'pins', 'folders', 'version', 'settings',
          'backup', 'update', 'offline']
      : const [],
  'man': (_, _) async => terminalCommands.keys.toList()..sort(),
  'which': (shell, _) async => terminalCommands.keys.toList()..sort(),
  'sudo': (shell, _) async => terminalCommands.keys.toList()..sort(),
};

const _bold = '\x1B[1m';
const _reset = '\x1B[0m';
const _green = '\x1B[1;32m';
const _blue = '\x1B[1;34m';
const _cyan = '\x1B[36m';
const _yellow = '\x1B[33m';
const _red = '\x1B[31m';
const _dim = '\x1B[2m';

// --------------------------------------------------------------------- shell

Future<int> _cd(CommandContext c) async {
  if (c.args.length > 1) {
    c.error('too many arguments');
    return 1;
  }
  final error = c.shell.changeDirectory(c.args.isEmpty ? null : c.args.first);
  if (error != null) {
    c.error(error);
    return 1;
  }
  return 0;
}

Future<int> _export(CommandContext c) async {
  if (c.args.isEmpty || c.args.first == '-p') {
    final names = c.shell.vars.keys.toList()..sort();
    for (final name in names) {
      c.writeln('declare -x $name="${c.shell.vars[name]}"');
    }
    return 0;
  }
  for (final arg in c.args) {
    final eq = arg.indexOf('=');
    if (eq == -1) {
      c.shell.vars.putIfAbsent(arg, () => c.shell.lookup(arg));
    } else {
      c.shell.vars[arg.substring(0, eq)] = arg.substring(eq + 1);
    }
  }
  return 0;
}

Future<int> _alias(CommandContext c) async {
  final aliases = c.shell.aliases;
  if (c.args.isEmpty) {
    final names = aliases.keys.toList()..sort();
    for (final name in names) {
      c.writeln("alias $name='${aliases[name]}'");
    }
    return 0;
  }
  var code = 0;
  for (final arg in c.args) {
    final eq = arg.indexOf('=');
    if (eq == -1) {
      final value = aliases[arg];
      if (value == null) {
        c.error('$arg: not found');
        code = 1;
      } else {
        c.writeln("alias $arg='$value'");
      }
    } else {
      aliases[arg.substring(0, eq)] = arg.substring(eq + 1);
    }
  }
  return code;
}

Future<int> _history(CommandContext c) async {
  if (c.args.contains('-c')) {
    await c.shell.clearHistory();
    return 0;
  }
  final history = c.shell.history;
  final count = c.args.isEmpty ? history.length : int.tryParse(c.args.first);
  if (count == null) {
    c.error('${c.args.first}: numeric argument required');
    return 1;
  }
  final start = math.max(0, history.length - count);
  final width = '${history.length}'.length;
  for (var i = start; i < history.length; i++) {
    c.writeln('  ${'${i + 1}'.padLeft(width)}  ${history[i]}');
  }
  return 0;
}

Future<int> _source(CommandContext c) async {
  if (c.args.isEmpty) {
    c.error('filename argument required');
    return 2;
  }
  return c.shell.source(c.args.first);
}

Future<int> _help(CommandContext c) async {
  c.writeln('${_bold}hanneslauncher terminal$_reset - Ubuntu syntax on your '
      "phone. Everything that isn't listed here runs in Android's own shell "
      '(ls, cat, mkdir, cp, mv, rm, grep, find, sed, awk, ping, ps, df, '
      'du, tar, ...).');
  c.writeln();
  final groups = <String, List<String>>{};
  terminalCommands.forEach((name, command) {
    groups.putIfAbsent(command.group ?? 'Other', () => []).add(name);
  });
  for (final entry in groups.entries) {
    c.writeln('$_green${entry.key}$_reset');
    for (final name in entry.value) {
      final command = terminalCommands[name]!;
      c.writeln('  $_bold${name.padRight(14)}$_reset ${command.summary}');
    }
    c.writeln();
  }
  c.writeln('${_green}Keys$_reset');
  c.writeln('  Tab completes, ↑/↓ walk the history, ^C stops a command,');
  c.writeln('  pinch to change the font size, long press to copy.');
  c.writeln('  Operators: | > >> < && || ;  -  !! repeats the last command.');
  return 0;
}

Future<int> _man(CommandContext c) async {
  if (c.args.isEmpty) {
    c.writeln('What manual page do you want?');
    c.writeln('For example, try \'man man\'.');
    return 1;
  }
  final name = c.args.first;
  final command = terminalCommands[name];
  if (command != null) {
    c.writeln('$_bold${name.toUpperCase()}$_reset');
    c.writeln('    ${command.summary}');
    if (command.usage != null) {
      c.writeln();
      c.writeln('${_bold}USAGE$_reset');
      c.writeln('    ${command.usage}');
    }
    return 0;
  }
  // Android has no manual pages; the program's own --help is the closest.
  final help = await c.shell.captureOutput('$name --help 2>&1');
  if (help.trim().isEmpty) {
    c.writeln('No manual entry for $name');
    return 16;
  }
  c.write(help);
  return 0;
}

Future<int> _which(CommandContext c) async {
  var code = 0;
  for (final name in c.args) {
    final alias = c.shell.aliases[name];
    if (c.name == 'type' && alias != null) {
      c.writeln('$name is aliased to `$alias\'');
    } else if (terminalCommands.containsKey(name)) {
      c.writeln(
        c.name == 'type'
            ? '$name is a shell builtin'
            : '$name: shell built-in command',
      );
    } else {
      final path = (await c.shell.captureOutput(
        'command -v ${shellQuote(name)}',
      )).trim();
      if (path.isEmpty) {
        if (c.name == 'type') c.error('$name: not found');
        code = 1;
      } else {
        c.writeln(c.name == 'type' ? '$name is $path' : path);
      }
    }
  }
  return code;
}

Future<int> _sudo(CommandContext c) async {
  if (c.args.isEmpty || const {'su', '-i', '-s'}.contains(c.args.first)) {
    c.writeln('[sudo] password for ${c.shell.user}: ');
    await Future<void>.delayed(const Duration(milliseconds: 700));
    c.writeln('${c.shell.user} is not in the sudoers file. '
        'This incident will be reported.');
    return 1;
  }
  // No root on an unrooted phone - but `sudo apt update` is muscle memory,
  // so the command simply runs as the user it would have run as anyway.
  final line = c.args.map(shellQuote).join(' ');
  return c.shell.execute(line);
}

// --------------------------------------------------------------------- files

Future<int> _tree(CommandContext c) async {
  var all = false;
  var dirsOnly = false;
  var maxDepth = 1 << 30;
  final roots = <String>[];
  for (var i = 0; i < c.args.length; i++) {
    final arg = c.args[i];
    if (arg == '-a') {
      all = true;
    } else if (arg == '-d') {
      dirsOnly = true;
    } else if (arg == '-L' && i + 1 < c.args.length) {
      maxDepth = int.tryParse(c.args[++i]) ?? maxDepth;
    } else {
      roots.add(arg);
    }
  }
  if (roots.isEmpty) roots.add('.');

  var dirs = 0;
  var files = 0;
  var shown = 0;
  const limit = 3000;

  void walk(Directory dir, String prefix, int depth) {
    if (depth > maxDepth || shown > limit) return;
    List<FileSystemEntity> children;
    try {
      children = dir.listSync(followLinks: false);
    } catch (_) {
      c.writeln('$prefix└── $_red[error opening dir]$_reset');
      return;
    }
    children = [
      for (final child in children)
        if (all || !_name(child).startsWith('.'))
          if (!dirsOnly || child is Directory) child,
    ]..sort((a, b) => _name(a).toLowerCase().compareTo(_name(b).toLowerCase()));
    for (var i = 0; i < children.length; i++) {
      if (++shown > limit) {
        c.writeln('$prefix... (stopped after $limit entries)');
        return;
      }
      final child = children[i];
      final last = i == children.length - 1;
      final branch = last ? '└── ' : '├── ';
      if (child is Directory) {
        dirs++;
        c.writeln('$prefix$branch$_blue${_name(child)}$_reset');
        walk(child, '$prefix${last ? '    ' : '│   '}', depth + 1);
      } else if (child is Link) {
        files++;
        String target;
        try {
          target = child.targetSync();
        } catch (_) {
          target = '?';
        }
        c.writeln('$prefix$branch$_cyan${_name(child)}$_reset -> $target');
      } else {
        files++;
        c.writeln('$prefix$branch${_name(child)}');
      }
    }
  }

  for (final root in roots) {
    final dir = Directory(c.resolve(root));
    if (!dir.existsSync()) {
      c.writeln('$root  [error opening dir]');
      continue;
    }
    c.writeln('$_blue$root$_reset');
    walk(dir, '', 1);
  }
  c.writeln();
  c.writeln(dirsOnly
      ? '$dirs director${dirs == 1 ? 'y' : 'ies'}'
      : '$dirs director${dirs == 1 ? 'y' : 'ies'}, '
          '$files file${files == 1 ? '' : 's'}');
  return 0;
}

String _name(FileSystemEntity entity) =>
    entity.uri.pathSegments.lastWhere((s) => s.isNotEmpty, orElse: () => '/');

Future<int> _edit(CommandContext c) async {
  final paths = c.args.where((a) => !a.startsWith('-')).toList();
  if (paths.isEmpty) {
    c.error('which file? Try: ${c.name} notes.txt');
    return 1;
  }
  final file = File(c.resolve(paths.first));
  if (Directory(file.path).existsSync()) {
    c.error('${paths.first} is a directory');
    return 1;
  }
  await c.host.openEditor(file);
  return 0;
}

Future<int> _less(CommandContext c) async {
  if (c.args.isEmpty) {
    if (c.stdin != null) c.write(c.stdin!);
    return 0;
  }
  var code = 0;
  for (final path in c.args.where((a) => !a.startsWith('-'))) {
    try {
      c.write(await File(c.resolve(path)).readAsString());
    } catch (_) {
      c.error('$path: No such file or directory');
      code = 1;
    }
  }
  return code;
}

Future<int> _open(CommandContext c) async {
  if (c.args.isEmpty) {
    c.error('open what? An app name, a web address or a launcher screen');
    return 1;
  }
  final target = c.args.join(' ');
  final looksLikeUrl =
      RegExp(r'^[a-z][a-z0-9+.-]*:', caseSensitive: false).hasMatch(target) ||
      RegExp(r'^[\w-]+(\.[\w-]+)+(/\S*)?$').hasMatch(target) &&
          !File(c.resolve(target)).existsSync();
  if (looksLikeUrl) {
    final uri = Uri.parse(target.contains(':') ? target : 'https://$target');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) c.error('nothing on this phone opens $uri');
    return ok ? 0 : 1;
  }
  final matches = _findEntries(target);
  if (matches.isEmpty) {
    c.error("no app called '$target'. Try: apps | grep -i ${c.args.first}");
    return 1;
  }
  if (matches.length > 1) {
    c.writeln('Which one?');
    for (final entry in matches.take(12)) {
      c.writeln('  ${entry.name}');
    }
    return 1;
  }
  final entry = matches.single;
  c.writeln('Opening ${entry.name}...');
  if (entry.isBuiltIn) {
    if (!c.host.context.mounted) return 1;
    await openBuiltIn(c.host.context, entry.builtIn!);
    return 0;
  }
  return await entry.launch() ? 0 : 1;
}

Future<int> _setupStorage(CommandContext c) async {
  if (await _terminalChannel.invokeMethod<bool>('hasStorageAccess') ?? false) {
    c.writeln('Storage access is already on. Your files are under '
        '$_blue/sdcard$_reset (try: cd /sdcard && ls).');
    return 0;
  }
  c.writeln('Android opens a switch now: turn on "Allow access to manage all '
      'files" for hanneslauncher, then come back.');
  await _terminalChannel.invokeMethod<bool>('requestStorageAccess');
  return 0;
}

const _terminalChannel = MethodChannel('hanneslauncher/terminal');

/// Whether the shell can see /sdcard - asked once at start, for the hint.
Future<bool> terminalHasStorageAccess() async {
  try {
    return await _terminalChannel.invokeMethod<bool>('hasStorageAccess') ??
        false;
  } catch (_) {
    return false;
  }
}

// ------------------------------------------------------------------- network

const _curlAgent = 'curl/8.5.0';

Future<int> _curl(CommandContext c) async {
  var silent = false;
  var headOnly = false;
  var includeHeaders = false;
  var method = 'GET';
  String? output;
  var remoteName = false;
  String? data;
  final headers = <String, String>{'User-Agent': _curlAgent, 'Accept': '*/*'};
  String? url;

  for (var i = 0; i < c.args.length; i++) {
    final arg = c.args[i];
    String next() => i + 1 < c.args.length ? c.args[++i] : '';
    switch (arg) {
      case '-s' || '--silent' || '-sS' || '-S' || '-L' || '-sL' || '-Ls' ||
          '-f' || '-fsSL' || '-sSL' || '--location' || '-k':
        silent = silent || arg.contains('s');
      case '-I' || '--head':
        headOnly = true;
        method = 'HEAD';
      case '-i' || '--include':
        includeHeaders = true;
      case '-X' || '--request':
        method = next().toUpperCase();
      case '-o' || '--output':
        output = next();
      case '-O' || '--remote-name':
        remoteName = true;
      case '-d' || '--data' || '--data-raw' || '--json':
        data = next();
        if (method == 'GET') method = 'POST';
        if (arg == '--json') headers['Content-Type'] = 'application/json';
      case '-H' || '--header':
        final header = next();
        final colon = header.indexOf(':');
        if (colon > 0) {
          headers[header.substring(0, colon).trim()] =
              header.substring(colon + 1).trim();
        }
      case '-A' || '--user-agent':
        headers['User-Agent'] = next();
      default:
        if (arg.startsWith('-')) {
          // Unknown flags are skipped rather than fatal - scripts copied
          // off the internet pass plenty that change nothing here.
          continue;
        }
        url = arg;
    }
  }
  if (url == null) {
    c.error('try \'curl --help\' - no URL given');
    return 2;
  }
  if (!url.contains('://')) url = 'http://$url';
  final uri = Uri.tryParse(url);
  if (uri == null) {
    c.error('(3) URL rejected: Malformed input to a URL function');
    return 3;
  }
  if (remoteName) {
    output = uri.pathSegments.isNotEmpty && uri.pathSegments.last.isNotEmpty
        ? uri.pathSegments.last
        : 'index.html';
  }

  final client = http.Client();
  c.onCancel(client.close);
  try {
    final request = http.Request(method, uri)..headers.addAll(headers);
    if (data != null) {
      request.body = data;
      request.headers.putIfAbsent(
        'Content-Type',
        () => 'application/x-www-form-urlencoded',
      );
    }
    final response = await client
        .send(request)
        .timeout(const Duration(seconds: 30));
    if (includeHeaders || headOnly) {
      c.writeln(
        'HTTP/1.1 ${response.statusCode} ${response.reasonPhrase ?? ''}',
      );
      response.headers.forEach((name, value) => c.writeln('$name: $value'));
      c.writeln();
      if (headOnly) return 0;
    }
    if (output != null) {
      final file = File(c.resolve(output));
      final sink = file.openWrite();
      var received = 0;
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
      }
      await sink.close();
      if (!silent) c.error('saved ${_size(received)} to $output');
      return 0;
    }
    await response.stream
        .transform(const Utf8Decoder(allowMalformed: true))
        .forEach(c.write);
    return 0;
  } on TimeoutException {
    c.error('(28) Operation timed out');
    return 28;
  } catch (error) {
    if (c.cancelled) return 130;
    c.error('(6) Could not resolve host: ${uri.host} ($error)');
    return 6;
  } finally {
    client.close();
  }
}

Future<int> _wget(CommandContext c) async {
  String? output;
  String? url;
  for (var i = 0; i < c.args.length; i++) {
    final arg = c.args[i];
    if (arg == '-O' && i + 1 < c.args.length) {
      output = c.args[++i];
    } else if (!arg.startsWith('-')) {
      url = arg;
    }
  }
  if (url == null) {
    c.error('missing URL');
    return 1;
  }
  if (!url.contains('://')) url = 'https://$url';
  final uri = Uri.parse(url);
  output ??= uri.pathSegments.isNotEmpty && uri.pathSegments.last.isNotEmpty
      ? uri.pathSegments.last
      : 'index.html';
  final toStdout = output == '-';
  c.writeln('--${DateTime.now().toString().substring(0, 19)}--  $url');
  c.writeln('Resolving ${uri.host}... connecting... ');

  final client = http.Client();
  c.onCancel(client.close);
  try {
    final response = await client
        .send(http.Request('GET', uri)..headers['User-Agent'] = 'Wget/1.21.4')
        .timeout(const Duration(seconds: 30));
    final total = response.contentLength;
    c.writeln('HTTP request sent, awaiting response... '
        '${response.statusCode} ${response.reasonPhrase ?? ''}');
    final length = total == null ? 'unspecified' : '$total (${_size(total)})';
    c.writeln(
      'Length: $length [${response.headers['content-type'] ?? '?'}]',
    );
    if (toStdout) {
      await response.stream
          .transform(const Utf8Decoder(allowMalformed: true))
          .forEach(c.write);
      return 0;
    }
    c.writeln("Saving to: ‘$output’");
    c.writeln();
    final file = File(c.resolve(output));
    final sink = file.openWrite();
    var received = 0;
    var lastDraw = DateTime(0);
    final started = DateTime.now();
    await for (final chunk in response.stream) {
      sink.add(chunk);
      received += chunk.length;
      final now = DateTime.now();
      if (now.difference(lastDraw).inMilliseconds > 150 && c.isTty) {
        lastDraw = now;
        c.write('\r${_progress(output, received, total, c.host.columns)}');
      }
    }
    await sink.close();
    final elapsed = DateTime.now().difference(started).inMilliseconds;
    final seconds = math.max(0.001, elapsed / 1000);
    if (c.isTty) {
      final columns = c.host.columns;
      c.write('\r${_progress(output, received, total ?? received, columns)}');
    }
    c.writeln();
    c.writeln();
    c.writeln('${DateTime.now().toString().substring(0, 19)} '
        '(${_size((received / seconds).round())}/s) - ‘$output’ saved '
        '[$received${total == null ? '' : '/$total'}]');
    return response.statusCode < 400 ? 0 : 8;
  } catch (error) {
    if (c.cancelled) return 130;
    c.error('unable to resolve host address ‘${uri.host}’');
    return 4;
  } finally {
    client.close();
  }
}

String _progress(String name, int received, int? total, int columns) {
  final label = name.length > 14 ? '${name.substring(0, 13)}…' : name;
  final size = _size(received).padLeft(8);
  if (total == null || total <= 0) return '$label  $size';
  final percent = (received * 100 ~/ total).clamp(0, 100);
  final barWidth = math.max(5, columns - label.length - 18);
  final filled = barWidth * percent ~/ 100;
  final bar = '${'=' * math.max(0, filled - 1)}${filled > 0 ? '>' : ''}'
      .padRight(barWidth);
  return '$label ${'$percent%'.padLeft(4)}[$bar] $size';
}

String _size(num bytes) {
  const units = ['B', 'K', 'M', 'G', 'T'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return unit == 0
      ? '${value.round()}B'
      : '${value.toStringAsFixed(1)}${units[unit]}';
}

Future<int> _ifconfig(CommandContext c) async {
  final interfaces = await NetworkInterface.list(
    includeLoopback: true,
    includeLinkLocal: true,
  );
  for (final interface in interfaces) {
    c.writeln('$_bold${interface.name}$_reset: flags=<UP,RUNNING>');
    for (final address in interface.addresses) {
      final isV4 = address.type == InternetAddressType.IPv4;
      c.writeln('        ${isV4 ? 'inet' : 'inet6'} ${address.address}');
    }
    c.writeln();
  }
  return 0;
}

Future<int> _ip(CommandContext c) async {
  final sub = c.args.isEmpty ? '' : c.args.first;
  if (sub == 'a' || sub == 'addr' || sub == 'address' || sub.isEmpty) {
    final interfaces = await NetworkInterface.list(
      includeLoopback: true,
      includeLinkLocal: true,
    );
    for (final interface in interfaces) {
      c.writeln('${interface.index}: $_bold${interface.name}$_reset: '
          '<UP,LOWER_UP>');
      for (final address in interface.addresses) {
        final isV4 = address.type == InternetAddressType.IPv4;
        c.writeln('    ${isV4 ? 'inet' : 'inet6'} '
            '${isV4 ? _green : _blue}${address.address}$_reset');
      }
    }
    return 0;
  }
  // Everything else is Android's own `ip` - most of which an app may not
  // use, but some (ip route) it may.
  final line = ['ip', ...c.args].map(shellQuote).join(' ');
  c.write(await c.shell.captureOutput('$line 2>&1'));
  return 0;
}

Future<int> _myip(CommandContext c) async {
  try {
    final response = await http
        .get(Uri.parse('https://api.ipify.org'))
        .timeout(const Duration(seconds: 10));
    c.writeln(response.body.trim());
    return 0;
  } catch (_) {
    c.error('no connection');
    return 1;
  }
}

Future<int> _weather(CommandContext c) async {
  final full = c.args.contains('--full') || c.args.contains('-f');
  final place = c.args.where((a) => !a.startsWith('-')).join('+');
  final lang = LocaleController.instance.value == AppLanguage.de ? 'de' : 'en';
  // The full forecast is 125 columns wide; a phone gets the narrow one.
  final format = full
      ? (c.host.columns >= 125 ? '' : 'n')
      : (c.host.columns >= 60 ? '0' : '0n');
  final uri = Uri.parse(
    'https://wttr.in/${Uri.encodeComponent(place).replaceAll('%2B', '+')}'
    '?${format.isEmpty ? '' : '$format&'}M&lang=$lang',
  );
  try {
    final response = await http
        .get(uri, headers: {'User-Agent': _curlAgent})
        .timeout(const Duration(seconds: 15));
    c.write(utf8.decode(response.bodyBytes, allowMalformed: true));
    return response.statusCode < 400 ? 0 : 1;
  } catch (_) {
    c.error('wttr.in is not reachable');
    return 1;
  }
}

// -------------------------------------------------------------------- system

/// `getprop` as a map. Read once per call: it is quick, and a fresh read
/// is what makes the answer trustworthy.
Future<Map<String, String>> _props(TerminalShell shell) async {
  final text = await shell.captureOutput('getprop');
  final props = <String, String>{};
  for (final match in RegExp(r'^\[(.+?)\]: \[(.*)\]$', multiLine: true)
      .allMatches(text)) {
    props[match.group(1)!] = match.group(2)!;
  }
  return props;
}

String? _first(Map<String, String> props, List<String> keys) {
  for (final key in keys) {
    final value = props[key];
    if (value != null && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}

String _deviceName(Map<String, String> props) {
  final brand = _capitalize(
    props['ro.product.brand'] ?? props['ro.product.manufacturer'] ?? '',
  );
  final model = props['ro.product.model'] ?? '';
  final market = _first(props, const [
    'ro.product.marketname',
    'ro.product.vendor.marketname',
    'ro.vendor.oplus.market.name',
    'ro.oppo.market.name',
    'ro.config.marketing_name',
    'ro.product.odm.marketname',
  ]);
  if (market != null) return '$market ($model)';
  return '$brand $model'.trim();
}

String _capitalize(String value) =>
    value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

String _uptime() {
  try {
    final seconds =
        double.parse(File('/proc/uptime').readAsStringSync().split(' ').first)
            .round();
    final days = seconds ~/ 86400;
    final hours = seconds % 86400 ~/ 3600;
    final minutes = seconds % 3600 ~/ 60;
    return [
      if (days > 0) '$days day${days == 1 ? '' : 's'}',
      if (hours > 0) '$hours hour${hours == 1 ? '' : 's'}',
      '$minutes min${minutes == 1 ? '' : 's'}',
    ].join(', ');
  } catch (_) {
    return '?';
  }
}

String? _memory() {
  try {
    final info = <String, int>{};
    for (final line in File('/proc/meminfo').readAsLinesSync()) {
      final match = RegExp(r'^(\w+):\s+(\d+)').firstMatch(line);
      if (match != null) info[match.group(1)!] = int.parse(match.group(2)!);
    }
    final total = info['MemTotal'];
    final available = info['MemAvailable'];
    if (total == null || available == null) return null;
    final used = total - available;
    return '${_gib(used * 1024)} / ${_gib(total * 1024)} '
        '(${used * 100 ~/ total}%)';
  } catch (_) {
    return null;
  }
}

String _gib(num bytes) => '${(bytes / (1 << 30)).toStringAsFixed(2)} GiB';

const _androidLogo = [
  r'  ;,           ,;  ',
  r"   ';,.-----.,;'   ",
  r"  ,'           ',  ",
  r' /    O     O    \ ',
  r'|                 |',
  r"'-----------------'",
  r'  _______________  ',
  r' |               | ',
  r' |  HANNES       | ',
  r' |    LAUNCHER   | ',
  r' |_______________| ',
  r'    |_|     |_|    ',
];

Future<int> _fastfetch(CommandContext c) async {
  final shell = c.shell;
  final results = await Future.wait([
    _props(shell),
    shell.captureOutput('uname -sr; uname -m'),
    DeviceStatsController.instance.refresh(),
  ]);
  final props = results[0] as Map<String, String>;
  final uname = (results[1] as String).trim().split('\n');
  final stats = DeviceStatsController.instance;
  if (UpdateController.instance.value.installedVersion.isEmpty) {
    await UpdateController.instance.load();
  }
  if (!c.host.context.mounted) return 1;
  final media = MediaQuery.of(c.host.context);
  final pixels = media.size * media.devicePixelRatio;

  final version = UpdateController.instance.value.installedVersion;
  final total = stats.storageTotalGb;
  final free = stats.storageFreeGb;
  final disk = total == null || free == null
      ? null
      : '${(total - free).toStringAsFixed(1)} GB / '
            '${total.toStringAsFixed(1)} GB '
            '(${((1 - free / total) * 100).round()}%)';

  final entries = LauncherEntriesController.instance.entries;
  final appCount = entries.where((e) => e.app != null).length;
  final webCount = WebAppsController.instance.value.length;
  final wallpaper = WallpaperController.instance.value;
  final soc = _first(props, const [
    'ro.soc.model',
    'ro.board.platform',
    'ro.hardware',
  ]);
  final socMaker = props['ro.soc.manufacturer'];
  final rom = _first(props, const [
    'ro.build.version.oplusrom.display',
    'ro.build.version.oplusrom',
    'ro.build.version.opporom',
    'ro.miui.ui.version.name',
    'ro.build.version.oneui',
    'ro.build.display.id',
  ]);

  final info = <(String, String)>[
    ('OS', 'Android ${props['ro.build.version.release'] ?? '?'} '
        '(SDK ${props['ro.build.version.sdk'] ?? '?'}) '
        '${uname.length > 1 ? uname[1] : ''}'),
    if (rom != null) ('ROM', rom),
    ('Host', _deviceName(props)),
    ('Kernel', uname.isNotEmpty ? uname.first : '?'),
    ('Uptime', _uptime()),
    ('Packages', '$appCount (apps)${webCount > 0 ? ', $webCount (web)' : ''}'),
    ('Shell', 'sh (mksh)'),
    ('Display', '${pixels.width.round()}x${pixels.height.round()}'),
    ('Terminal', 'hanneslauncher-term'),
    ('Launcher', 'hanneslauncher $version'),
    ('Home', '${PinnedAppsController.instance.value.length} pinned, '
        '${FoldersController.instance.value.length} folders, '
        '${PanelBlocksController.instance.value.length} widgets'),
    (
      'Wallpaper',
      wallpaper == null
          ? 'none'
          : wallpaper.isVideo
          ? 'video'
          : 'image',
    ),
    ('CPU', '${[?socMaker, ?soc].join(' ')} (${Platform.numberOfProcessors})'),
    if (_memory() != null) ('Memory', _memory()!),
    if (disk != null) ('Disk (/)', disk),
    if (stats.batteryPercent != null)
      (
        'Battery',
        '${stats.batteryPercent}%'
            '${stats.batteryCharging ? ' [Charging]' : ''}',
      ),
    ('Network', switch (stats.connectionType) {
      'wifi' => 'Wi-Fi',
      'mobile' => 'Mobile data',
      'ethernet' => 'Ethernet',
      'none' => 'offline',
      _ => stats.connectionType,
    }),
    ('Security patch', props['ro.build.version.security_patch'] ?? '?'),
    ('Locale', LocaleController.instance.value.name),
  ];

  final title = '$_green${shell.user}$_reset@$_green${shell.hostname}$_reset';
  final titleLength = shell.user.length + shell.hostname.length + 1;
  final lines = <String>[
    title,
    '-' * titleLength,
    for (final (key, value) in info) '$_green$key$_reset: $value',
    '',
    [for (var i = 0; i < 8; i++) '\x1B[4${i}m   '].join() + _reset,
    [for (var i = 0; i < 8; i++) '\x1B[10${i}m   '].join() + _reset,
  ];

  const logoWidth = 19;
  final sideBySide = c.host.columns >= logoWidth + 3 + 34;
  if (!sideBySide) {
    for (final line in _androidLogo) {
      c.writeln('$_green$line$_reset');
    }
    c.writeln();
    for (final line in lines) {
      c.writeln(line);
    }
    return 0;
  }
  final height = math.max(_androidLogo.length, lines.length);
  for (var i = 0; i < height; i++) {
    final logo = i < _androidLogo.length ? _androidLogo[i] : ' ' * logoWidth;
    final text = i < lines.length ? lines[i] : '';
    c.writeln('$_green$logo$_reset   $text');
  }
  return 0;
}

Future<int> _lsbRelease(CommandContext c) async {
  final props = await _props(c.shell);
  final release = props['ro.build.version.release'] ?? '?';
  final codename = props['ro.build.version.codename'] ?? 'REL';
  final all = c.args.isEmpty || c.args.contains('-a');
  if (all) c.writeln('No LSB modules are available.');
  if (all || c.args.contains('-i')) c.writeln('Distributor ID:\tAndroid');
  if (all || c.args.contains('-d')) {
    c.writeln('Description:\tAndroid $release (hanneslauncher)');
  }
  if (all || c.args.contains('-r')) c.writeln('Release:\t$release');
  if (all || c.args.contains('-c')) {
    c.writeln('Codename:\t${codename == 'REL' ? 'stable' : codename}');
  }
  return 0;
}

Future<int> _hostnamectl(CommandContext c) async {
  final props = await _props(c.shell);
  final kernel = (await c.shell.captureOutput('uname -sr')).trim();
  final rows = {
    'Static hostname': c.shell.hostname,
    'Chassis': 'handset 📱',
    'Operating System': 'Android ${props['ro.build.version.release'] ?? '?'}',
    'Kernel': kernel,
    'Architecture': props['ro.product.cpu.abi'] ?? '?',
    'Hardware Vendor': _capitalize(props['ro.product.manufacturer'] ?? '?'),
    'Hardware Model': _deviceName(props),
    'Firmware Version': props['ro.build.display.id'] ?? '?',
  };
  rows.forEach((key, value) => c.writeln('${key.padLeft(17)}: $value'));
  return 0;
}

Future<int> _battery(CommandContext c) async {
  final stats = DeviceStatsController.instance;
  await stats.refresh();
  final percent = stats.batteryPercent;
  if (percent == null) {
    c.error('no battery reading');
    return 1;
  }
  final color = percent > 50 ? _green : percent > 20 ? _yellow : _red;
  const width = 20;
  final filled = width * percent ~/ 100;
  c.writeln('[$color${'█' * filled}$_reset${'░' * (width - filled)}] '
      '$percent%${stats.batteryCharging ? ' ⚡ charging' : ''}');
  return 0;
}

Future<int> _power(CommandContext c) async {
  c.writeln('Failed to ${c.name == 'reboot' ? 'reboot' : 'power off'} '
      'system: Access denied');
  c.writeln('$_dim(Android only lets system apps do that - hold the power '
      'button.)$_reset');
  return 1;
}

// ------------------------------------------------------------------ launcher

/// Apps and launcher screens the user can see - never the secret ones, since
/// [LauncherEntriesController.entries] already leaves those out.
List<LauncherEntry> _launchable() => [
  for (final entry in LauncherEntriesController.instance.entries)
    if (!entry.isFolder) entry,
];

List<String> _appNames() =>
    [for (final entry in _launchable()) entry.name]..sort();

List<LauncherEntry> _findEntries(String query) {
  final q = query.toLowerCase().trim();
  final all = _launchable();
  bool packageIs(LauncherEntry e) => e.app?.packageName.toLowerCase() == q;
  for (final test in <bool Function(LauncherEntry)>[
    (e) => e.name.toLowerCase() == q || packageIs(e),
    (e) => e.name.toLowerCase().startsWith(q),
    (e) => e.name.toLowerCase().contains(q),
    (e) => e.app?.packageName.toLowerCase().contains(q) ?? false,
  ]) {
    final found = all.where(test).toList();
    if (found.isNotEmpty) return found;
  }
  return const [];
}

Future<int> _apps(CommandContext c) async {
  final entries = _launchable()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  final width = entries.fold(0, (w, e) => math.max(w, e.name.length));
  for (final entry in entries) {
    final detail = entry.app?.packageName ??
        (entry.isWebApp ? 'web app' : entry.isBuiltIn ? 'launcher' : '');
    c.writeln(c.isTty
        ? '${entry.name.padRight(width)}  $_dim$detail$_reset'
        : '${entry.name}\t$detail');
  }
  return 0;
}

Future<int> _apt(CommandContext c) async {
  if (c.args.isEmpty) {
    c.writeln('apt 2.7.14 (hanneslauncher)');
    c.writeln('Usage: ${terminalCommands['apt']!.usage}');
    return 1;
  }
  final sub = c.args.first;
  final rest = c.args.skip(1).where((a) => !a.startsWith('-')).toList();
  final name = rest.join(' ');
  const arch = 'arm64';

  switch (sub) {
    case 'list':
      if (c.isTty) c.writeln('Listing... Done');
      final apps = [
        for (final e in _launchable())
          if (e.app != null) e,
      ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      for (final entry in apps) {
        if (name.isNotEmpty &&
            !entry.name.toLowerCase().contains(name.toLowerCase())) {
          continue;
        }
        final app = entry.app!;
        c.writeln('$_green${entry.name.toLowerCase().replaceAll(' ', '-')}'
            '$_reset/${app.packageName},now ${app.versionName} $arch '
            '[installed]');
      }
      return 0;
    case 'search':
      if (name.isEmpty) {
        c.error('E: You must give at least one search pattern');
        return 100;
      }
      c.writeln('Sorting... Done');
      c.writeln('Full Text Search... Done');
      final found = _findEntries(name).where((e) => e.app != null);
      for (final entry in found) {
        c.writeln('$_green${entry.name}$_reset/${entry.app!.packageName} '
            '${entry.app!.versionName} [installed]');
      }
      c.writeln();
      c.writeln('${_dim}To find it on Google Play: apt install $name$_reset');
      return 0;
    case 'show':
      final entry = _single(c, name);
      if (entry == null) return 100;
      final app = entry.app;
      c.writeln('${_bold}Package$_reset: ${app?.packageName ?? entry.key}');
      c.writeln('${_bold}Name$_reset: ${entry.name}');
      if (app != null) {
        c.writeln('${_bold}Version$_reset: ${app.versionName} '
            '(${app.versionCode})');
        c.writeln('${_bold}Installed$_reset: '
            '${DateTime.fromMillisecondsSinceEpoch(app.installedTimestamp)}');
      }
      final pinned = PinnedAppsController.instance.value.contains(entry.key);
      c.writeln('${_bold}Pinned$_reset: ${pinned ? 'yes' : 'no'}');
      return 0;
    case 'install' || 'reinstall':
      if (name.isEmpty) {
        c.writeln('0 upgraded, 0 newly installed, 0 to remove and 0 not '
            'upgraded.');
        return 0;
      }
      c.writeln('Reading package lists... Done');
      c.writeln('Building dependency tree... Done');
      final isPackage = RegExp(r'^[a-z][\w]*(\.[\w]+)+$').hasMatch(name);
      c.writeln('Opening Google Play for "$name"...');
      final uri = Uri.parse(isPackage
          ? 'market://details?id=$name'
          : 'market://search?q=${Uri.encodeQueryComponent(name)}&c=apps');
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        await launchUrl(
          Uri.parse(isPackage
              ? 'https://play.google.com/store/apps/details?id=$name'
              : 'https://play.google.com/store/search?q='
                  '${Uri.encodeQueryComponent(name)}&c=apps'),
          mode: LaunchMode.externalApplication,
        );
      }
      return 0;
    case 'remove' || 'purge' || 'uninstall' || 'autoremove':
      if (name.isEmpty) {
        c.writeln('0 upgraded, 0 newly installed, 0 to remove and 0 not '
            'upgraded.');
        return 0;
      }
      final entry = _single(c, name);
      if (entry == null) return 100;
      final app = entry.app;
      if (app == null) {
        c.error('E: ${entry.name} is not an installed app');
        return 100;
      }
      c.writeln('Reading package lists... Done');
      c.writeln('The following packages will be REMOVED:');
      c.writeln('  ${app.packageName}');
      c.writeln('Android asks you to confirm...');
      final started = await InstalledApps.uninstallApp(app.packageName);
      return started == true ? 0 : 1;
    case 'update':
      c.writeln('Hit:1 https://github.com hanneslauncher InRelease');
      await UpdateController.instance.check();
      final state = UpdateController.instance.value;
      c.writeln('Reading package lists... Done');
      if (state.available) {
        c.writeln('1 package can be upgraded. Run \'apt upgrade\' to see it.');
      } else {
        c.writeln('All packages are up to date.');
      }
      return 0;
    case 'upgrade' || 'full-upgrade' || 'dist-upgrade':
      final state = UpdateController.instance.value;
      if (!state.available) {
        c.writeln('Calculating upgrade... Done');
        c.writeln('0 upgraded, 0 newly installed, 0 to remove and 0 not '
            'upgraded.');
        return 0;
      }
      c.writeln('The following packages will be upgraded:');
      c.writeln('  hanneslauncher (${state.installedVersion} -> '
          '${state.latest?.version})');
      await _push(c, const UpdateScreen());
      return 0;
    default:
      c.error('E: Invalid operation $sub');
      return 100;
  }
}

LauncherEntry? _single(CommandContext c, String name) {
  if (name.isEmpty) {
    c.error('E: which app?');
    return null;
  }
  final found = _findEntries(name);
  if (found.isEmpty) {
    c.error('E: Unable to locate package $name');
    return null;
  }
  if (found.length > 1) {
    c.error('E: "$name" fits ${found.length} apps: '
        '${found.take(6).map((e) => e.name).join(', ')}');
    return null;
  }
  return found.single;
}

Future<void> _push(CommandContext c, Widget screen) async {
  if (!c.host.context.mounted) return;
  await Navigator.of(c.host.context).push(
    MaterialPageRoute<void>(builder: (_) => screen),
  );
}

Future<int> _hl(CommandContext c) async {
  final sub = c.args.isEmpty ? 'info' : c.args.first;
  switch (sub) {
    case 'info':
      if (UpdateController.instance.value.installedVersion.isEmpty) {
        await UpdateController.instance.load();
      }
      final entries = LauncherEntriesController.instance.entries;
      final wallpaper = WallpaperController.instance.value;
      final rows = {
        'Version': UpdateController.instance.value.installedVersion,
        'Apps': '${entries.where((e) => e.app != null).length}',
        'Web apps': '${WebAppsController.instance.value.length}',
        'Pinned': '${PinnedAppsController.instance.value.length}',
        'Folders': '${FoldersController.instance.value.length}',
        'Widgets': '${PanelBlocksController.instance.value.length}',
        'Wallpaper': wallpaper == null
            ? 'none'
            : '${wallpaper.isVideo ? 'video' : 'image'} '
                '(${wallpaper.file.uri.pathSegments.last})',
        'Language': LocaleController.instance.value.name,
        'Terminal home': c.shell.home,
      };
      c.writeln('$_green${_bold}hanneslauncher$_reset');
      rows.forEach((key, value) =>
          c.writeln('  $_bold${key.padRight(14)}$_reset$value'));
      return 0;
    case 'version' || '--version' || '-v':
      if (UpdateController.instance.value.installedVersion.isEmpty) {
        await UpdateController.instance.load();
      }
      final version = UpdateController.instance.value.installedVersion;
      c.writeln('hanneslauncher $version');
      return 0;
    case 'apps':
      return _apps(c);
    case 'pins':
      final pinned = LauncherEntriesController.instance
          .resolve(PinnedAppsController.instance.value);
      for (var i = 0; i < pinned.length; i++) {
        c.writeln('${i + 1}. ${pinned[i].name}');
      }
      return 0;
    case 'folders':
      for (final folder in FoldersController.instance.value) {
        c.writeln('$_blue${folder.name}/$_reset');
        final items =
            LauncherEntriesController.instance.resolve(folder.itemKeys);
        for (var i = 0; i < items.length; i++) {
          c.writeln('${i == items.length - 1 ? '└── ' : '├── '}'
              '${items[i].name}');
        }
      }
      return 0;
    case 'settings':
      await _push(c, const SettingsScreen());
      return 0;
    case 'backup':
      await _push(c, const SettingsBackupScreen());
      return 0;
    case 'update':
      await _push(c, const UpdateScreen());
      return 0;
    case 'offline':
      if (!c.host.context.mounted) return 1;
      await openBuiltIn(c.host.context, BuiltInEntry.offlineMode);
      return 0;
    default:
      c.error("unknown command '$sub'");
      c.writeln('Usage: ${terminalCommands['hl']!.usage}');
      return 1;
  }
}

// ----------------------------------------------------------------------- fun

Future<int> _bc(CommandContext c) async {
  final input = c.args.isNotEmpty
      ? c.args.join(' ')
      : (c.stdin ?? '');
  var code = 0;
  for (final raw in input.split(RegExp(r'[\n;]'))) {
    final line = raw.trim();
    if (line.isEmpty || line == 'quit') continue;
    final power = RegExp(r'^(-?[\d.]+)\s*\^\s*(-?[\d.]+)$').firstMatch(line);
    if (power != null) {
      c.writeln(formatNumber(math
          .pow(double.parse(power.group(1)!), double.parse(power.group(2)!))
          .toDouble()));
      continue;
    }
    final sqrt = RegExp(r'^sqrt\(\s*([\d.]+)\s*\)$').firstMatch(line);
    if (sqrt != null) {
      c.writeln(formatNumber(math.sqrt(double.parse(sqrt.group(1)!))));
      continue;
    }
    final number = double.tryParse(line);
    final result = number != null
        ? formatNumber(number)
        : calculateExpression(line);
    if (result == null) {
      c.error('syntax error: $line');
      code = 1;
    } else {
      c.writeln(result);
    }
  }
  return code;
}

Future<int> _cowsay(CommandContext c) async {
  var text = c.args.isNotEmpty ? c.args.join(' ') : (c.stdin ?? '').trim();
  if (text.isEmpty) text = 'Moo.';
  final width = math.min(40, math.max(8, c.host.columns - 6));
  final lines = <String>[];
  for (final paragraph in text.split('\n')) {
    var line = '';
    for (final word in paragraph.split(' ')) {
      if (line.isNotEmpty && line.length + word.length + 1 > width) {
        lines.add(line);
        line = word;
      } else {
        line = line.isEmpty ? word : '$line $word';
      }
    }
    lines.add(line);
  }
  final max = lines.fold(0, (w, l) => math.max(w, l.length));
  c.writeln(' ${'_' * (max + 2)}');
  for (var i = 0; i < lines.length; i++) {
    final (open, close) = lines.length == 1
        ? ('<', '>')
        : i == 0
        ? ('/', r'\')
        : i == lines.length - 1
        ? (r'\', '/')
        : ('|', '|');
    c.writeln('$open ${lines[i].padRight(max)} $close');
  }
  c.writeln(' ${'-' * (max + 2)}');
  c.writeln(r'        \   ^__^');
  c.writeln(r'         \  (oo)\_______');
  c.writeln(r'            (__)\       )\/\');
  c.writeln(r'                ||----w |');
  c.writeln(r'                ||     ||');
  return 0;
}

const _fortunes = [
  'There is no place like 127.0.0.1',
  'rm -rf / is not a cleaning tool.',
  "It works on my machine. - Every developer ever",
  'Talk is cheap. Show me the code. - Linus Torvalds',
  'Wer nichts weiß, muss alles glauben. - Marie von Ebner-Eschenbach',
  'Premature optimization is the root of all evil. - Donald Knuth',
  'Der Weg ist das Ziel.',
  'To understand recursion, you must first understand recursion.',
  'Any sufficiently advanced technology is indistinguishable from magic. '
      '- Arthur C. Clarke',
  'Es gibt 10 Arten von Menschen: die, die Binär verstehen, und die anderen.',
  'Simplicity is prerequisite for reliability. - Edsger Dijkstra',
  'Wer aufhört, besser zu werden, hat aufgehört, gut zu sein.',
  'The best way to predict the future is to invent it. - Alan Kay',
  'Tipp: "fastfetch | lolcat" sieht noch besser aus.',
  'Tipp: "open spotify" startet eine App direkt von hier.',
  'Tipp: "weather Berlin" zeigt das Wetter für einen Ort.',
  'Tipp: Mit Tab werden Befehle, Dateien und App-Namen vervollständigt.',
  "Have you tried turning it off and on again?",
  'In der Ruhe liegt die Kraft.',
  'sudo make me a sandwich.',
];

Future<int> _fortune(CommandContext c) async {
  c.writeln(_fortunes[math.Random().nextInt(_fortunes.length)]);
  return 0;
}

Future<int> _lolcat(CommandContext c) async {
  var text = c.stdin ?? '';
  if (c.args.isNotEmpty) {
    final buffer = StringBuffer();
    for (final path in c.args) {
      try {
        buffer.write(await File(c.resolve(path)).readAsString());
      } catch (_) {
        c.error('$path: No such file or directory');
      }
    }
    text = buffer.toString();
  }
  if (!c.isTty) {
    c.write(text);
    return 0;
  }
  final seed = math.Random().nextDouble() * 6;
  final out = StringBuffer();
  var row = 0;
  for (final line in text.split('\n')) {
    var column = 0;
    for (final rune in line.runes) {
      final t = seed + (row * 0.5 + column) * 0.1;
      final r = (math.sin(t) * 127 + 128).round();
      final g = (math.sin(t + 2 * math.pi / 3) * 127 + 128).round();
      final b = (math.sin(t + 4 * math.pi / 3) * 127 + 128).round();
      out.write('\x1B[38;2;$r;$g;${b}m${String.fromCharCode(rune)}');
      column++;
    }
    out.write('$_reset\n');
    row++;
  }
  var result = out.toString();
  if (!text.endsWith('\n')) {
    result = result.substring(0, result.length - 1);
  } else {
    // split() made one empty line too many at the end.
    result = result.substring(0, result.length - '$_reset\n'.length);
  }
  c.write(result);
  return 0;
}

Future<int> _cmatrix(CommandContext c) async {
  await c.host.showMatrix();
  return 0;
}
