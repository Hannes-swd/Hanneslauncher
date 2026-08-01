import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hanneslouncher/data_sources_controller.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final controller = DataSourcesController.instance;

  /// Puts the shared singleton back to how it looks before the first load.
  void startFresh([Map<String, Object> stored = const {}]) {
    SharedPreferences.setMockInitialValues(stored);
    controller.value = const [];
    controller.debugResetLoadedForTest();
    controller.debugClientOverride = null;
  }

  /// A client that answers every request with [body] under [status], and
  /// counts how often it was asked.
  ({http.Client client, List<Uri> calls}) mockClient(
    String body, {
    int status = 200,
  }) {
    final calls = <Uri>[];
    return (
      client: MockClient((request) async {
        calls.add(request.url);
        return http.Response(body, status);
      }),
      calls: calls,
    );
  }

  test('sources and their settings survive a reload', () async {
    startFresh();

    final weather = await controller.add(
      key: 'wetter',
      name: 'Wetter Berlin',
      url: 'https://api.example.com/wetter',
      headers: {'X-Api-Key': 'geheim'},
      refreshMinutes: 15,
    );
    final trains = await controller.add(
      key: 'bahn',
      name: 'Abfahrten',
      url: 'https://api.example.com/bahn',
    );

    // Simulate a fresh app start: drop what's in memory and read back.
    controller.value = const [];
    controller.debugResetLoadedForTest();
    await controller.load();

    expect(controller.value.map((s) => s.id), [weather.id, trains.id]);
    final loaded = controller.value.first;
    expect(loaded.key, 'wetter');
    expect(loaded.name, 'Wetter Berlin');
    expect(loaded.url, 'https://api.example.com/wetter');
    expect(loaded.headers, {'X-Api-Key': 'geheim'});
    expect(loaded.refreshMinutes, 15);
    expect(controller.byKey('bahn')?.id, trains.id);
    expect(controller.byId(trains.id)?.refreshMinutes, 30);
  });

  test('a later load does not drop sources added meanwhile', () async {
    startFresh();

    await controller.load();
    final source = await controller.add(
      key: 'wetter',
      name: 'Wetter',
      url: 'https://api.example.com/wetter',
    );
    // The panel rebuilding (e.g. after Android recreated the launcher) must
    // not wipe what was created in the meantime.
    await controller.load();

    expect(controller.value.map((s) => s.id), [source.id]);
  });

  test('a single unreadable entry does not take the others with it', () async {
    const good = DataSource(
      id: '42',
      key: 'wetter',
      name: 'Wetter',
      url: 'https://api.example.com/wetter',
      refreshMinutes: 5,
    );
    startFresh({
      'data_sources': <String>[
        'kein json',
        jsonEncode({'id': '7', 'name': 'ohne key'}),
        jsonEncode(good.toJson()),
      ],
    });

    await controller.load();

    expect(controller.value.length, 1);
    expect(controller.value.single.id, '42');
    expect(controller.value.single.key, 'wetter');
    expect(controller.value.single.refreshMinutes, 5);
  });

  test('a key already in use gets numbered', () async {
    startFresh();

    final first = await controller.add(
      key: 'wetter',
      name: 'Berlin',
      url: 'https://api.example.com/a',
    );
    final second = await controller.add(
      key: 'wetter',
      name: 'Hamburg',
      url: 'https://api.example.com/b',
    );
    final third = await controller.add(
      key: 'wetter',
      name: 'Kiel',
      url: 'https://api.example.com/c',
    );

    expect(
      [first.key, second.key, third.key],
      ['wetter', 'wetter2', 'wetter3'],
    );
    expect(controller.byKey('wetter')?.id, first.id);

    // Renaming a key onto a taken one is caught the same way, while keeping
    // one's own key is not treated as a clash with itself.
    await controller.update(second.copyWith(key: 'wetter'));
    expect(controller.byId(second.id)?.key, 'wetter2');
    await controller.update(third.copyWith(key: 'wetter3', name: 'Kiel Nord'));
    expect(controller.byId(third.id)?.key, 'wetter3');
    expect(controller.byId(third.id)?.name, 'Kiel Nord');
  });

  test('valueAt walks names, indexes and dead ends', () {
    final data = jsonDecode('''
      {
        "current": {"temperature_2m": 21.5, "text": "sonnig"},
        "days": [
          {"max": 24, "min": 12},
          {"max": 19, "min": 9}
        ]
      }
    ''');

    expect(DataSourcesController.valueAt(data, 'current.temperature_2m'), 21.5);
    expect(DataSourcesController.valueAt(data, 'days[1].max'), 19);
    expect(DataSourcesController.valueAt(data, 'current.gibtsnicht'), isNull);
    expect(DataSourcesController.valueAt(data, 'days[7].max'), isNull);
    expect(DataSourcesController.valueAt(data, 'current.text.tiefer'), isNull);
    expect(DataSourcesController.valueAt(jsonDecode('[5, 6]'), '[0]'), 5);
    expect(DataSourcesController.valueAt(null, 'current.text'), isNull);
  });

  test('resolve fills in placeholders and marks what it cannot', () async {
    startFresh();
    final answer = mockClient(
      '{"current": {"temperature_2m": 21.0, "text": "sonnig"}}',
    );
    controller.debugClientOverride = answer.client;

    final source = await controller.add(
      key: 'wetter',
      name: 'Wetter',
      url: 'https://api.example.com/wetter',
    );
    await controller.refresh(source);

    expect(
      controller.resolve(
        'Es ist {{wetter.current.temperature_2m}}° und {{wetter.current.text}}.',
      ),
      'Es ist 21° und sonnig.',
    );
    expect(controller.resolve('{{bahn.abfahrt}}'), '-');
    expect(controller.resolve('{{wetter.gibtsnicht}}'), '-');
    expect(controller.resolve('ohne Platzhalter'), 'ohne Platzhalter');
    expect(controller.valueOf('wetter', 'current.temperature_2m'), 21.0);
  });

  test(
    'refresh stores the answer and keeps it when the next one fails',
    () async {
      startFresh();
      final good = mockClient('{"value": 7}');
      controller.debugClientOverride = good.client;

      final source = await controller.add(
        key: 'zaehler',
        name: 'Zähler',
        url: 'https://api.example.com/zaehler',
        headers: {'X-Api-Key': 'geheim'},
      );

      expect(await controller.refresh(source), isNull);
      expect(controller.dataFor(source.id), {'value': 7});
      expect(controller.fetchedAt(source.id), isNotNull);
      expect(controller.errorFor(source.id), isNull);
      expect(good.calls.single.toString(), 'https://api.example.com/zaehler');

      final failing = mockClient('nope', status: 500);
      controller.debugClientOverride = failing.client;

      final error = await controller.refresh(source);
      expect(error, isNotNull);
      expect(controller.errorFor(source.id), error);
      // The old answer stays: an offline panel showing the last value beats an
      // empty one.
      expect(controller.dataFor(source.id), {'value': 7});
      expect(controller.fetchedAt(source.id), isNotNull);

      // And the cached answer is still there after a restart.
      controller.value = const [];
      controller.debugResetLoadedForTest();
      controller.debugClientOverride = null;
      await controller.load();

      expect(controller.dataFor(source.id), {'value': 7});
      expect(controller.fetchedAt(source.id), isNotNull);
      expect(controller.errorFor(source.id), isNull);
    },
  );

  test('an answer that is not JSON is an error, not a crash', () async {
    startFresh();
    controller.debugClientOverride = mockClient('<html>nope</html>').client;

    final source = await controller.add(
      key: 'kaputt',
      name: 'Kaputt',
      url: 'https://api.example.com/html',
    );

    expect(await controller.refresh(source), isNotNull);
    expect(controller.dataFor(source.id), isNull);
  });

  test('http addresses are refused without a request', () async {
    startFresh();
    final answer = mockClient('{"value": 1}');
    controller.debugClientOverride = answer.client;

    final source = await controller.add(
      key: 'unsicher',
      name: 'Unsicher',
      url: 'http://api.example.com/wetter',
    );

    expect(await controller.refresh(source), isNotNull);
    expect(answer.calls, isEmpty);
    expect(controller.dataFor(source.id), isNull);
    expect(
      (await controller.preview('http://example.com', const {})).error,
      isNotNull,
    );
  });

  test('refreshStale only fetches what has run out', () async {
    final now = DateTime.now();
    final fresh = DataSource(
      id: '1',
      key: 'frisch',
      name: 'Frisch',
      url: 'https://api.example.com/frisch',
    );
    final stale = DataSource(
      id: '2',
      key: 'alt',
      name: 'Alt',
      url: 'https://api.example.com/alt',
      refreshMinutes: 30,
    );
    const never = DataSource(
      id: '3',
      key: 'nie',
      name: 'Nie',
      url: 'https://api.example.com/nie',
    );
    startFresh({
      'data_sources': <String>[
        jsonEncode(fresh.toJson()),
        jsonEncode(stale.toJson()),
        jsonEncode(never.toJson()),
      ],
      'data_sources_cache': jsonEncode({
        '1': {'body': '{"value": 1}', 'at': now.millisecondsSinceEpoch},
        '2': {
          'body': '{"value": 2}',
          'at': now.subtract(const Duration(hours: 2)).millisecondsSinceEpoch,
        },
      }),
    });

    await controller.load();
    expect(controller.dataFor('1'), {'value': 1});

    final answer = mockClient('{"value": 99}');
    controller.debugClientOverride = answer.client;
    await controller.refreshStale();

    expect(answer.calls.map((uri) => uri.path), ['/alt', '/nie']);
    expect(controller.dataFor('1'), {'value': 1});
    expect(controller.dataFor('2'), {'value': 99});
    expect(controller.dataFor('3'), {'value': 99});
  });

  test('remove drops the source and its cached answer', () async {
    startFresh();
    controller.debugClientOverride = mockClient('{"value": 3}').client;

    final first = await controller.add(
      key: 'a',
      name: 'A',
      url: 'https://api.example.com/a',
    );
    final second = await controller.add(
      key: 'b',
      name: 'B',
      url: 'https://api.example.com/b',
    );
    await controller.refresh(first);
    await controller.refresh(second);
    await controller.remove(first.id);

    controller.value = const [];
    controller.debugResetLoadedForTest();
    await controller.load();

    expect(controller.value.map((s) => s.id), [second.id]);
    expect(controller.dataFor(first.id), isNull);
    expect(controller.dataFor(second.id), {'value': 3});
  });
}
