/// The command-line grammar of the terminal, as far as it has to be
/// understood in Dart.
///
/// Most of a line is handed to the phone's own `/system/bin/sh` untouched -
/// it does globbing, loops, `$(...)` and the rest far better than a
/// re-implementation would. What has to be understood here is only what
/// decides *where* a piece runs: the `;`, `&&`, `||` and `|` between
/// commands (so `cd` can run in Dart and change the directory the next
/// command starts in), the first word of each command (builtin, alias or
/// program), and - for the commands that do run in Dart - their words with
/// quotes, variables and redirections resolved.
library;

/// One command of a `;` / `&&` / `||` list, with the operator that joined
/// it to the one before (null for the first).
class ListItem {
  const ListItem(this.text, this.op);

  final String text;

  /// `;`, `&&`, `||`, `&` or a newline - null for the first command.
  final String? op;

  @override
  String toString() => 'ListItem(${op ?? ''} $text)';
}

class _Piece {
  const _Piece(this.text, {this.op});

  final String text;
  final String? op;
}

/// Walks [line] and cuts it at the operators outside quotes, brackets and
/// `$(...)`. Everything between two operators comes back verbatim.
List<_Piece> _scan(String line) {
  final pieces = <_Piece>[];
  final current = StringBuffer();
  var single = false;
  var double = false;
  var backtick = false;
  var depth = 0; // ( ) and $( ) nesting
  var braces = 0; // ${ } and { } groups

  var i = 0;
  while (i < line.length) {
    final c = line[i];
    final next = i + 1 < line.length ? line[i + 1] : '';

    if (single) {
      current.write(c);
      if (c == "'") single = false;
      i++;
      continue;
    }
    if (c == r'\' && next.isNotEmpty) {
      current
        ..write(c)
        ..write(next);
      i += 2;
      continue;
    }
    if (double) {
      current.write(c);
      if (c == '"') double = false;
      if (c == r'$' && next == '(') {
        current.write(next);
        depth++;
        i += 2;
        continue;
      }
      if (c == ')' && depth > 0) depth--;
      i++;
      continue;
    }
    if (backtick) {
      current.write(c);
      if (c == '`') backtick = false;
      i++;
      continue;
    }

    switch (c) {
      case "'":
        single = true;
      case '"':
        double = true;
      case '`':
        backtick = true;
      case '(':
        depth++;
      case ')':
        if (depth > 0) depth--;
      case '{':
        braces++;
      case '}':
        if (braces > 0) braces--;
    }

    if (depth == 0 && braces == 0 && !single && !double && !backtick) {
      String? op;
      if (c == '&' && next == '&') {
        op = '&&';
      } else if (c == '|' && next == '|') {
        op = '||';
      } else if (c == ';' && next != ';') {
        op = ';';
      } else if (c == '\n') {
        op = '\n';
      } else if (c == '|') {
        op = '|';
      } else if (c == '&' && !_isRedirectAmpersand(line, i)) {
        op = '&';
      }
      if (op != null) {
        pieces.add(_Piece(current.toString()));
        pieces.add(_Piece('', op: op));
        current.clear();
        i += op.length;
        continue;
      }
    }

    current.write(c);
    i++;
  }
  pieces.add(_Piece(current.toString()));
  return pieces;
}

/// `2>&1`, `>&2`, `&>file` - an ampersand that belongs to a redirection
/// rather than sending a command to the background.
bool _isRedirectAmpersand(String line, int index) {
  final before = index > 0 ? line[index - 1] : '';
  final after = index + 1 < line.length ? line[index + 1] : '';
  return before == '>' || before == '<' || after == '>';
}

/// Splits at `;`, `&&`, `||`, `&` and newlines. Empty commands (a trailing
/// `;`) are dropped.
List<ListItem> splitCommandList(String line) {
  final items = <ListItem>[];
  String? op;
  final buffer = StringBuffer();
  for (final piece in _scan(line)) {
    if (piece.op == null) {
      buffer.write(piece.text);
    } else if (piece.op == '|') {
      buffer.write('|');
    } else {
      final text = buffer.toString().trim();
      if (text.isNotEmpty) items.add(ListItem(text, items.isEmpty ? null : op));
      buffer.clear();
      op = piece.op;
    }
  }
  final text = buffer.toString().trim();
  if (text.isNotEmpty) items.add(ListItem(text, items.isEmpty ? null : op));
  return items;
}

/// Splits one command of a list into the stages of its pipeline.
List<String> splitPipeline(String command) {
  final stages = <String>[];
  final buffer = StringBuffer();
  for (final piece in _scan(command)) {
    if (piece.op == '|') {
      stages.add(buffer.toString().trim());
      buffer.clear();
    } else if (piece.op != null) {
      buffer.write(piece.op);
    } else {
      buffer.write(piece.text);
    }
  }
  stages.add(buffer.toString().trim());
  return stages;
}

/// The command name of [command] with its quotes taken off - `'ls'` and
/// `\ls` are both `ls`, the way bash sees it. Leading `VAR=value`
/// assignments are skipped over.
String firstWord(String command) {
  var rest = command.trimLeft();
  while (true) {
    final end = _wordEnd(rest);
    final word = rest.substring(0, end);
    if (isAssignment(word) && end < rest.length) {
      rest = rest.substring(end).trimLeft();
      continue;
    }
    return word.replaceAll(RegExp(r'''['"\\]'''), '');
  }
}

/// [command] with its first word replaced by [replacement], everything else
/// left exactly as typed.
String replaceFirstWord(String command, String replacement) {
  final leading = command.length - command.trimLeft().length;
  final rest = command.substring(leading);
  final end = _wordEnd(rest);
  return command.substring(0, leading) + replacement + rest.substring(end);
}

int _wordEnd(String text) {
  var single = false;
  var double = false;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (single) {
      if (c == "'") single = false;
    } else if (double) {
      if (c == r'\') {
        i++;
      } else if (c == '"') {
        double = false;
      }
    } else if (c == r'\') {
      i++;
    } else if (c == "'") {
      single = true;
    } else if (c == '"') {
      double = true;
    } else if (c == ' ' || c == '\t' || c == '\n') {
      return i;
    }
  }
  return text.length;
}

bool isAssignment(String word) =>
    RegExp(r'^[A-Za-z_][A-Za-z0-9_]*=').hasMatch(word);

/// Replaces the first word of every command in [line] by its alias, the
/// way bash does - including aliases that expand to further aliases, but
/// never the same one twice (so `alias ls='ls --color'` terminates).
String expandAliases(String line, Map<String, String> aliases) {
  if (aliases.isEmpty) return line;
  return _expandAliases(line, aliases, const {});
}

String _expandAliases(
  String line,
  Map<String, String> aliases,
  Set<String> seen,
) {
  final out = StringBuffer();
  for (final piece in _scan(line)) {
    if (piece.op != null) {
      out.write(piece.op);
      continue;
    }
    final text = piece.text;
    final leading = text.length - text.trimLeft().length;
    final rest = text.substring(leading);
    final end = _wordEnd(rest);
    final word = rest.substring(0, end);
    final alias = aliases[word];
    if (alias == null || seen.contains(word)) {
      out.write(text);
      continue;
    }
    out
      ..write(text.substring(0, leading))
      ..write(
        _expandAliases(
          alias + rest.substring(end),
          aliases,
          {...seen, word},
        ),
      );
  }
  return out.toString();
}

const _rawShellWords = {
  'for',
  'while',
  'until',
  'if',
  'case',
  'function',
  'select',
  '{',
  '(',
  '((',
  '[[',
};

/// Lines that only the real shell can make sense of as a whole: loops,
/// conditionals, functions, here-documents and subshells. Cutting those up
/// at their `;` would break them, so they go to `sh` in one piece.
bool needsRawShell(String line) {
  final trimmed = line.trimLeft();
  if (trimmed.startsWith('(')) return true;
  final word = trimmed.split(RegExp(r'\s+')).first;
  if (_rawShellWords.contains(word)) return true;
  if (RegExp(r'^[A-Za-z_][A-Za-z0-9_]*\s*\(\s*\)').hasMatch(trimmed)) {
    return true;
  }
  return line.contains('<<');
}

/// A word of a command that runs in Dart.
class ShellWord {
  const ShellWord(this.text, {this.isOperator = false, this.glob = false});

  final String text;

  /// A redirection: `>`, `>>`, `<`, `2>`, `2>>`, `&>` or `2>&1`.
  final bool isOperator;

  /// Has an unquoted `*`, `?` or `[` - to be matched against file names.
  final bool glob;

  @override
  String toString() => isOperator ? '<$text>' : text;
}

/// Splits [command] into words the way the shell would: quotes removed,
/// backslash escapes applied, `$VAR`, `${VAR}`, `$?` and a leading `~`
/// replaced. [lookup] answers a variable's value ('' when unset).
List<ShellWord> tokenizeWords(
  String command, {
  required String Function(String name) lookup,
  required String home,
}) {
  final words = <ShellWord>[];
  final current = StringBuffer();
  var started = false; // an empty "" is still a word
  var glob = false;
  var i = 0;

  void finish() {
    if (started || current.isNotEmpty) {
      words.add(ShellWord(current.toString(), glob: glob));
    }
    current.clear();
    started = false;
    glob = false;
  }

  // Reads a variable reference starting at the `$` at [at]; returns its
  // value and the index after it, or null when it is not one.
  (String, int)? variable(int at) {
    if (at + 1 >= command.length) return null;
    final next = command[at + 1];
    if (next == '{') {
      final close = command.indexOf('}', at + 2);
      if (close == -1) return null;
      return (lookup(command.substring(at + 2, close)), close + 1);
    }
    if (next == '?' || next == r'$' || next == '#' || next == '0') {
      return (lookup(next), at + 2);
    }
    final match = RegExp(
      r'[A-Za-z_][A-Za-z0-9_]*',
    ).matchAsPrefix(command, at + 1);
    if (match == null) return null;
    return (lookup(match.group(0)!), match.end);
  }

  while (i < command.length) {
    final c = command[i];
    final next = i + 1 < command.length ? command[i + 1] : '';

    if (c == ' ' || c == '\t' || c == '\n') {
      finish();
      i++;
      continue;
    }
    if (c == r'\') {
      if (next.isNotEmpty) current.write(next);
      started = true;
      i += 2;
      continue;
    }
    if (c == "'") {
      final close = command.indexOf("'", i + 1);
      final end = close == -1 ? command.length : close;
      current.write(command.substring(i + 1, end));
      started = true;
      i = end + 1;
      continue;
    }
    if (c == '"') {
      started = true;
      i++;
      while (i < command.length && command[i] != '"') {
        final d = command[i];
        if (d == r'\' && i + 1 < command.length) {
          final escaped = command[i + 1];
          if (r'$`"\'.contains(escaped) || escaped == '\n') {
            current.write(escaped);
          } else {
            current.write('$d$escaped');
          }
          i += 2;
          continue;
        }
        if (d == r'$') {
          final value = variable(i);
          if (value != null) {
            current.write(value.$1);
            i = value.$2;
            continue;
          }
        }
        current.write(d);
        i++;
      }
      i++; // closing quote
      continue;
    }
    if (c == r'$') {
      final value = variable(i);
      if (value != null) {
        current.write(value.$1);
        started = true;
        i = value.$2;
        continue;
      }
    }
    if (c == '~' && current.isEmpty && !started) {
      if (next.isEmpty || next == '/' || next == ' ') {
        current.write(home);
        i++;
        continue;
      }
    }
    // Redirections - only at the start of a word, or `2>` as a whole word.
    if (c == '>' || c == '<' || (c == '&' && next == '>')) {
      final isFd2 = current.toString() == '2' && !started;
      if (current.isEmpty || isFd2) {
        final match = RegExp(r'&>|>>|>&1|>&2|>|<').matchAsPrefix(command, i)!;
        var op = match.group(0)!;
        if (isFd2) {
          current.clear();
          op = '2$op';
        }
        words.add(ShellWord(op, isOperator: true));
        i = match.end;
        continue;
      }
      finish();
      continue;
    }
    if (c == '*' || c == '?' || c == '[') glob = true;
    current.write(c);
    i++;
  }
  finish();
  return words;
}

/// A `$(...)` or backtick substitution in a command, as found by
/// [findCommandSubstitutions].
class CommandSubstitution {
  const CommandSubstitution(this.start, this.end, this.command, this.quoted);

  final int start;
  final int end;
  final String command;

  /// Inside double quotes, where the result is not split into words.
  final bool quoted;
}

List<CommandSubstitution> findCommandSubstitutions(String text) {
  final found = <CommandSubstitution>[];
  var single = false;
  var double = false;
  var i = 0;
  while (i < text.length) {
    final c = text[i];
    if (single) {
      if (c == "'") single = false;
      i++;
      continue;
    }
    if (c == r'\') {
      i += 2;
      continue;
    }
    if (c == "'" && !double) {
      single = true;
    } else if (c == '"') {
      double = !double;
    } else if (c == r'$' &&
        i + 1 < text.length &&
        text[i + 1] == '(' &&
        !(i + 2 < text.length && text[i + 2] == '(')) {
      var depth = 1;
      var j = i + 2;
      while (j < text.length && depth > 0) {
        if (text[j] == '(') depth++;
        if (text[j] == ')') depth--;
        j++;
      }
      if (depth == 0) {
        found.add(
          CommandSubstitution(i, j, text.substring(i + 2, j - 1), double),
        );
        i = j;
        continue;
      }
    } else if (c == '`') {
      final close = text.indexOf('`', i + 1);
      if (close != -1) {
        found.add(
          CommandSubstitution(
            i,
            close + 1,
            text.substring(i + 1, close),
            double,
          ),
        );
        i = close + 1;
        continue;
      }
    }
    i++;
  }
  return found;
}

/// [value] escaped so that pasting it back into a command line reads as the
/// same text - inside double quotes when [quoted], bare otherwise (where
/// whitespace is kept as a word separator, which is how bash splits a
/// substitution's output).
String escapeForShell(String value, {required bool quoted}) {
  final out = StringBuffer();
  for (final rune in value.runes) {
    final c = String.fromCharCode(rune);
    if (quoted) {
      if (r'$`"\'.contains(c)) out.write(r'\');
      out.write(c);
    } else if (c == ' ' || c == '\t' || c == '\n') {
      out.write(' ');
    } else if (RegExp(r'''[A-Za-z0-9_./,:@%+=-]''').hasMatch(c) ||
        rune > 127) {
      out.write(c);
    } else {
      out
        ..write(r'\')
        ..write(c);
    }
  }
  return out.toString();
}

/// Quotes one argument for a command line handed to `sh`.
String shellQuote(String value) {
  if (value.isNotEmpty && RegExp(r'^[A-Za-z0-9_./,:@%+=-]+$').hasMatch(value)) {
    return value;
  }
  return "'${value.replaceAll("'", r"'\''")}'";
}
