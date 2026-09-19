import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hanneslauncher/data_sources_controller.dart';

/// The guard that makes "I added a placeholder that needs a position and
/// forgot to say so" impossible to do quietly.
///
/// Whoever is about to draw a placeholder has to fetch a position *first*,
/// and the panel cannot know which ones need one - it can only ask. The
/// answer is [DataSourcesController.locationBuiltInKeys], and the only other
/// place that knows the truth is the switch in `_builtIn`, which is a
/// hundred lines away. That is exactly how `{{sonnenauf}}` came to be
/// missing from the panel's own hand-kept list of four: a card showing
/// nothing but the sunrise never caused a position to be fetched and showed
/// a dash for good.
///
/// So the list is checked against the switch rather than remembered. Same
/// shape as `settings_keys_test.dart`: two lists that have to agree, checked
/// in both directions, read out of the source because the source is where a
/// new case actually appears.
void main() {
  late Set<String> readsLocation;

  setUpAll(() {
    readsLocation = _keysWhoseCaseReadsLocation();
  });

  test('the guard can still find the switch it reads', () {
    // If `_builtIn` is renamed or restructured, the scan below would come
    // back empty and every other test here would pass for the wrong reason.
    expect(
      readsLocation,
      isNotEmpty,
      reason:
          'Found no built-in placeholder reading LocationController at all. '
          'The scan in this test no longer matches the shape of _builtIn in '
          'lib/data_sources_controller.dart - fix the scan, not this '
          'expectation.',
    );
  });

  test('every placeholder that reads a position is declared as needing one', () {
    final undeclared =
        readsLocation
            .where((key) => !DataSourcesController.locationBuiltInKeys.contains(key))
            .toList(growable: false)
          ..sort();

    expect(
      undeclared,
      isEmpty,
      reason:
          'These cases in _builtIn read LocationController, so a card using '
          'them needs a position fetched before it is drawn - but nothing '
          'asks for one, and they will show a dash for good.\n\n'
          'Add them to DataSourcesController.locationBuiltInKeys: '
          '${undeclared.join(', ')}',
    );
  });

  test('the list names nothing that stopped needing a position', () {
    final stale =
        DataSourcesController.locationBuiltInKeys
            .where((key) => !readsLocation.contains(key))
            .toList(growable: false)
          ..sort();

    expect(
      stale,
      isEmpty,
      reason:
          'These are declared as needing a position but their case in '
          '_builtIn no longer reads one. A list that keeps dead entries is '
          'one nobody trusts to be the whole list, and each one costs a '
          'location fix nobody asked for: ${stale.join(', ')}',
    );
  });

  group('what the panel asks about a card', () {
    test('a placeholder needing a position is recognised', () {
      expect(DataSourcesController.templateNeedsLocation('{{sonnenauf}}'), isTrue);
      expect(DataSourcesController.templateNeedsLocation('{{sunset}}'), isTrue);
      expect(DataSourcesController.templateNeedsLocation('{{ort}}'), isTrue);
      expect(
        DataSourcesController.templateNeedsLocation(
          'https://api.example.com/?lat={{lat}}&lon={{lon}}',
        ),
        isTrue,
      );
    });

    test('it reads a placeholder the way resolve does, not as plain text', () {
      // resolve() trims the body and understands the |url modifier, so both
      // of these are placeholders it fills - a substring test for '{{lat}}'
      // matched neither.
      expect(DataSourcesController.templateNeedsLocation('{{ lat }}'), isTrue);
      expect(DataSourcesController.templateNeedsLocation('{{ort|url}}'), isTrue);
    });

    test('a card that needs nothing does not cost a location fix', () {
      expect(DataSourcesController.templateNeedsLocation('{{zeit}}'), isFalse);
      expect(DataSourcesController.templateNeedsLocation('{{mondphase}}'), isFalse);
      expect(DataSourcesController.templateNeedsLocation('Guten Morgen'), isFalse);
      expect(DataSourcesController.templateNeedsLocation(''), isFalse);
      // A fetched source's own value that happens to be called "ort".
      expect(
        DataSourcesController.templateNeedsLocation('{{wetter.ort}}'),
        isFalse,
      );
    });
  });
}

/// Every `case` label in `_builtIn` whose body reaches for
/// [LocationController], read out of the source.
///
/// `_builtIn` is one switch of `case 'x' || 'y':` labels, each falling
/// through to the next until a `return`. A case's body is everything from
/// its label to the next label, so a group of labels sharing one body - as
/// sunrise and sunset do - all count when that body reads a position.
Set<String> _keysWhoseCaseReadsLocation() {
  final source = File('lib/data_sources_controller.dart').readAsStringSync();
  final start = source.indexOf('static String? _builtIn(');
  if (start < 0) return const {};
  final end = source.indexOf('\n  }', start);
  final body = source.substring(start, end < 0 ? source.length : end);

  final labels = RegExp(r"^\s*case ([^:]+):", multiLine: true);
  final matches = labels.allMatches(body).toList(growable: false);

  final needs = <String>{};
  // A label with nothing of its own before the next label falls through to
  // it and runs the same lines - `case 'sonnenauf' || 'sunrise':` sits
  // directly above `case 'sonnenunter' || 'sunset':`, and all four names
  // are answered by the one body underneath. So labels are collected until
  // a body actually turns up, and then they all get it.
  final sharing = <String>[];
  for (var i = 0; i < matches.length; i++) {
    for (final quoted in RegExp(r"'([^']+)'").allMatches(matches[i].group(1)!)) {
      sharing.add(quoted.group(1)!);
    }
    final from = matches[i].end;
    final to = i + 1 < matches.length ? matches[i + 1].start : body.length;
    final segment = body.substring(from, to);
    if (segment.trim().isEmpty) continue;
    if (segment.contains('LocationController')) needs.addAll(sharing);
    sharing.clear();
  }
  return needs;
}
