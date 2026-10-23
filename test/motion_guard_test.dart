import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every dialog and every sheet opens through `lib/app_dialogs.dart`, which
/// is what gives them the design's timing and the grow out of the spot they
/// were opened from. Flutter's own `showDialog` is a fixed 150 ms fade that
/// nothing in the theme reaches, so a single direct call is a dialog that
/// pops up differently from all the others - and nobody notices which one
/// until it is on screen.
///
/// A rule like that is broken by the next feature, not this one, so it is
/// checked here rather than remembered.
void main() {
  // The one file allowed to call them: the wrappers themselves.
  const home = 'lib/app_dialogs.dart';

  // Flutter's ways of putting a modal on screen that bypass the wrappers.
  final direct = RegExp(
    r'\b(showDialog|showModalBottomSheet|showGeneralDialog|'
    r'showCupertinoDialog|showCupertinoModalPopup|showAdaptiveDialog)\s*[<(]',
  );

  List<File> dartFiles() => [
    for (final entity in Directory('lib').listSync(recursive: true))
      if (entity is File && entity.path.endsWith('.dart')) entity,
  ];

  String normalised(String path) => path.replaceAll(r'\', '/');

  test('no dialog or sheet is opened past lib/app_dialogs.dart', () {
    final offenders = <String>[];
    for (final file in dartFiles()) {
      final path = normalised(file.path);
      if (path == home) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trimLeft();
        // Prose about them is fine - the reasons are written down in
        // comments all over the place.
        if (line.startsWith('//')) continue;
        if (direct.hasMatch(line)) offenders.add('$path:${i + 1}: $line');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Use showAppDialog / showAppBottomSheet from app_dialogs.dart, '
          'so the dialog moves like every other one:\n'
          '${offenders.join('\n')}',
    );
  });

  test('the wrappers are actually in use', () {
    // A guard over code nobody calls would pass just as quietly as the bug
    // it is there for.
    var calls = 0;
    for (final file in dartFiles()) {
      if (normalised(file.path) == home) continue;
      calls += RegExp(
        r'\bshowApp(Dialog|BottomSheet)\s*[<(]',
      ).allMatches(file.readAsStringSync()).length;
    }
    expect(calls, greaterThan(50));
  });
}
