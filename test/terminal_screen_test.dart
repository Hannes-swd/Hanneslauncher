import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanneslauncher/terminal_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The terminal end to end, with only the commands that run in Dart - the
/// phone's `sh` is not there on the machine running the tests.
void main() {
  late Directory root;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    root = Directory.systemTemp.createTempSync('terminal_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => root.path,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> type(WidgetTester tester, String line) async {
    await tester.enterText(find.byType(TextField), line);
    await tester.runAsync(() async {
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await settle(tester);
  }

  String screen(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((text) => text.data ?? text.textSpan?.toPlainText() ?? '')
      .join('\n');

  testWidgets('runs the Dart-side commands, with pipes and redirections', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    addTearDown(tester.view.resetPhysicalSize);

    // Started inside real time: the shell's file access has to finish
    // under it, which fake time never lets happen.
    await tester.runAsync(() async {
      await tester.pumpWidget(const MaterialApp(home: TerminalScreen()));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await settle(tester);

    final home = '${root.path}/home'.replaceAll(r'\', '/');
    expect(File('$home/.bashrc').existsSync(), isTrue);
    expect(screen(tester), contains('Welcome to hanneslauncher'));

    await type(tester, 'bc 6*7');
    expect(screen(tester), contains('42'));

    await type(tester, 'bc 2^10 > out.txt && less out.txt');
    expect(File('$home/out.txt').readAsStringSync().trim(), '1024');
    expect(screen(tester), contains('1024'));

    await type(tester, 'cowsay moo');
    expect(screen(tester), contains('< moo >'));

    // An alias from ~/.bashrc, and one defined here.
    await type(tester, "alias hello='cowsay hallo'");
    await type(tester, 'hello');
    expect(screen(tester), contains('< hallo >'));

    await type(tester, 'tree');
    expect(screen(tester), contains('└── out.txt'));

    await type(tester, 'cd nowhere');
    expect(screen(tester), contains('cd: nowhere: No such file or directory'));

    await type(tester, 'history');
    expect(screen(tester), contains('bc 6*7'));
    expect(File('$home/.bash_history').readAsStringSync(), contains('bc 6*7'));

    // A tap far below the last line still lands in the input field.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(_inputFocused(tester), isFalse);
    await tester.tapAt(const Offset(180, 1100));
    await tester.pump();
    expect(_inputFocused(tester), isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}

bool _inputFocused(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus;
