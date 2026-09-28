import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hanneslauncher/data_sources_controller.dart';

/// The guard that makes "I added a placeholder that reads what's playing and
/// forgot to say so" impossible to do quietly - the same shape as
/// `location_placeholders_guard_test.dart`, one placeholder set later.
///
/// Whoever is about to draw one of these has to refresh
/// `MediaSessionController` first, and the panel cannot know which
/// placeholders those are - it can only ask. The answer is
/// [DataSourcesController.mediaBuiltInKeys], and the only other place that
/// knows the truth is the switch in `_builtIn`. So the list is checked
/// against the switch rather than remembered.
void main() {
  late Set<String> readsMedia;

  setUpAll(() {
    readsMedia = _keysWhoseCaseReadsMedia();
  });

  test('the guard can still find the switch it reads', () {
    expect(
      readsMedia,
      isNotEmpty,
      reason:
          'Found no built-in placeholder reading MediaSessionController at '
          'all. The scan in this test no longer matches the shape of '
          '_builtIn in lib/data_sources_controller.dart - fix the scan, not '
          'this expectation.',
    );
  });

  test('every placeholder that reads the media session is declared as needing it', () {
    final undeclared =
        readsMedia
            .where((key) => !DataSourcesController.mediaBuiltInKeys.contains(key))
            .toList(growable: false)
          ..sort();

    expect(
      undeclared,
      isEmpty,
      reason:
          'These cases in _builtIn read MediaSessionController, so a card '
          'using them needs it refreshed before it is drawn - but nothing '
          'asks for one, and they will show a dash for good.\n\n'
          'Add them to DataSourcesController.mediaBuiltInKeys: '
          '${undeclared.join(', ')}',
    );
  });

  test('the list names nothing that stopped needing the media session', () {
    final stale =
        DataSourcesController.mediaBuiltInKeys
            .where((key) => !readsMedia.contains(key))
            .toList(growable: false)
          ..sort();

    expect(
      stale,
      isEmpty,
      reason:
          'These are declared as needing MediaSessionController but their '
          'case in _builtIn no longer reads it: ${stale.join(', ')}',
    );
  });

  group('what the panel asks about a card', () {
    test('a placeholder needing the media session is recognised', () {
      expect(DataSourcesController.templateNeedsMedia('{{musik_titel}}'), isTrue);
      expect(DataSourcesController.templateNeedsMedia('{{media_artist}}'), isTrue);
      expect(DataSourcesController.templateNeedsMedia('{{ media_status }}'), isTrue);
    });

    test('a card that needs nothing does not cost a media session read', () {
      expect(DataSourcesController.templateNeedsMedia('{{zeit}}'), isFalse);
      expect(DataSourcesController.templateNeedsMedia('Guten Morgen'), isFalse);
      expect(DataSourcesController.templateNeedsMedia(''), isFalse);
      expect(
        DataSourcesController.templateNeedsMedia('{{wetter.musik_titel}}'),
        isFalse,
      );
    });
  });
}

/// Every `case` label in `_builtIn` whose body reaches for
/// `MediaSessionController`, read out of the source - see the identical
/// scan in `location_placeholders_guard_test.dart` for the full reasoning.
Set<String> _keysWhoseCaseReadsMedia() {
  final source = File('lib/data_sources_controller.dart').readAsStringSync();
  final start = source.indexOf('static String? _builtIn(');
  if (start < 0) return const {};
  final end = source.indexOf('\n  }', start);
  final body = source.substring(start, end < 0 ? source.length : end);

  final labels = RegExp(r"^\s*case ([^:]+):", multiLine: true);
  final matches = labels.allMatches(body).toList(growable: false);

  final needs = <String>{};
  final sharing = <String>[];
  for (var i = 0; i < matches.length; i++) {
    for (final quoted in RegExp(r"'([^']+)'").allMatches(matches[i].group(1)!)) {
      sharing.add(quoted.group(1)!);
    }
    final from = matches[i].end;
    final to = i + 1 < matches.length ? matches[i + 1].start : body.length;
    final segment = body.substring(from, to);
    if (segment.trim().isEmpty) continue;
    if (segment.contains('MediaSessionController')) needs.addAll(sharing);
    sharing.clear();
  }
  return needs;
}
