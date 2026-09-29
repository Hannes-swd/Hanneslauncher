import 'package:flutter_test/flutter_test.dart';
import 'package:hanneslauncher/terminal_output.dart';
import 'package:hanneslauncher/terminal_parser.dart';

void main() {
  group('command list', () {
    test('splits at ; && || outside quotes', () {
      final items = splitCommandList("cd /sdcard && ls -la; echo 'a;b' || x");
      expect(items.map((i) => i.text), [
        'cd /sdcard',
        'ls -la',
        "echo 'a;b'",
        'x',
      ]);
      expect(items.map((i) => i.op), [null, '&&', ';', '||']);
    });

    test('keeps pipes inside one command', () {
      final items = splitCommandList('ls | grep a && echo ok');
      expect(items.first.text, 'ls | grep a');
      expect(splitPipeline(items.first.text), ['ls', 'grep a']);
    });

    test('2>&1 is a redirection, not a background job', () {
      expect(splitCommandList('ls nope 2>&1').single.text, 'ls nope 2>&1');
    });

    test(r'does not cut inside $(...)', () {
      expect(
        splitPipeline(r'echo $(ls | wc -l) | cat'),
        [r'echo $(ls | wc -l)', 'cat'],
      );
    });
  });

  group('words', () {
    String lookup(String name) =>
        {'HOME': '/h', 'X': 'val', '?': '1'}[name] ?? '';

    List<String> words(String text) => [
      for (final w in tokenizeWords(text, lookup: lookup, home: '/h'))
        w.toString(),
    ];

    test('quotes, escapes and variables', () {
      expect(words(r'''echo "a $X" 'b $X' c\ d $? ${X}s'''), [
        'echo',
        'a val',
        r'b $X',
        'c d',
        '1',
        'vals',
      ]);
    });

    test('tilde and redirections', () {
      expect(words('cat ~/f >out 2> err >>log'), [
        'cat',
        '/h/f',
        '<>>',
        'out',
        '<2>>',
        'err',
        '<>>>',
        'log',
      ]);
    });

    test('an empty quoted word stays a word', () {
      expect(words('a "" b'), ['a', '', 'b']);
    });

    test('first word ignores quotes and assignments', () {
      expect(firstWord("  'ls' -la"), 'ls');
      expect(firstWord('FOO=1 BAR=2 fastfetch'), 'fastfetch');
    });
  });

  group('aliases', () {
    test('expand once per name, in every command', () {
      final aliases = {'ls': 'ls --color=auto', 'll': 'ls -alF'};
      expect(
        expandAliases('ll /x && ls | ls', aliases),
        'ls --color=auto -alF /x && ls --color=auto | ls --color=auto',
      );
    });

    test('loops do not hang', () {
      expect(expandAliases('a', {'a': 'b', 'b': 'a'}), 'a');
    });
  });

  test('loops and functions go to sh whole', () {
    expect(needsRawShell('for i in 1 2; do echo \$i; done'), true);
    expect(needsRawShell('f() { echo; }'), true);
    expect(needsRawShell('cat <<EOF'), true);
    expect(needsRawShell('ls -la; cd ..'), false);
  });

  test('command substitutions are found with their quoting', () {
    final found = findCommandSubstitutions(r'cd $(dirname "$f") "`pwd`"');
    expect(found.map((f) => f.command), [r'dirname "$f"', 'pwd']);
    expect(found.map((f) => f.quoted), [false, true]);
  });

  test('shellQuote round-trips awkward names', () {
    expect(shellQuote('plain.txt'), 'plain.txt');
    expect(shellQuote("it's here"), r"'it'\''s here'");
  });

  group('output', () {
    test('colours become spans', () {
      final buffer = TermBuffer()..write('a\x1B[1;34mdir\x1B[0m b\n');
      final line = buffer.lines.first;
      expect(TermBuffer.textOf(line), 'adir b');
      expect(line[1].style.bold, true);
      expect(line[1].style.fg, 4);
      // Bold brightens the eight basic colours, the way terminals do.
      expect(line[1].style.foregroundColor, terminalPalette[12]);
      buffer.dispose();
    });

    test('an escape split across writes is still one escape', () {
      final buffer = TermBuffer()
        ..write('x\x1B[3')
        ..write('1my');
      expect(TermBuffer.textOf(buffer.lines.first), 'xy');
      expect(buffer.lines.first.last.style.fg, 1);
      buffer.dispose();
    });

    test('carriage return redraws the line', () {
      final buffer = TermBuffer()
        ..write(' 10%\r 50%\r100%\ndone\n');
      expect(buffer.lines.map(TermBuffer.textOf).take(2), ['100%', 'done']);
      buffer.dispose();
    });

    test('tabs expand to the next stop', () {
      final buffer = TermBuffer()..write('ab\tc');
      expect(TermBuffer.textOf(buffer.lines.first), 'ab      c');
      buffer.dispose();
    });

    test('stripAnsi leaves plain text', () {
      expect(stripAnsi('\x1B[38;5;208mhot\x1B[0m'), 'hot');
    });
  });
}
