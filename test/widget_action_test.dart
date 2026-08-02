import 'package:flutter_test/flutter_test.dart';
import 'package:hanneslouncher/data_sources_controller.dart';
import 'package:hanneslouncher/widget_action.dart';
import 'package:hanneslouncher/widget_element.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('rejects an address that is not http or https', () async {
    final result = await runWidgetAction(
      const WidgetElement(
        id: '1',
        type: WidgetElementType.action,
        actionUrl: 'ftp://example.com',
      ),
    );
    expect(result.success, false);
  });

  test('rejects an empty address without making a request', () async {
    final result = await runWidgetAction(
      const WidgetElement(id: '1', type: WidgetElementType.action),
    );
    expect(result.success, false);
  });

  test('plain http is accepted as a valid scheme (rejected only later, '
      'by the actual request)', () async {
    // Nothing listens on port 1, so the connection is refused near-instantly
    // - this only checks that the scheme itself isn't what rejects it, not
    // that the request succeeds.
    final result = await runWidgetAction(
      const WidgetElement(
        id: '1',
        type: WidgetElementType.action,
        actionUrl: 'http://127.0.0.1:1/relay/0?turn=on',
      ),
    );
    expect(result.detail, isNot('Not a valid address'));
  });

  test(
    'toggle mode fails cleanly when the current value cannot be read',
    () async {
      final result = await runWidgetAction(
        const WidgetElement(
          id: '1',
          type: WidgetElementType.action,
          actionValueMode: ActionValueMode.toggle,
          actionToggleSource: '{{nichtvorhanden.wert}}',
          actionUrl: 'http://127.0.0.1:1/set?on={{!wert}}',
        ),
      );
      expect(result.success, false);
      expect(result.detail, 'Current value not readable');
    },
  );

  group('resolveAction', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      DataSourcesController.instance.value = const [];
      DataSourcesController.instance.debugResetLoadedForTest();
    });

    test(
      'fixed mode leaves the address and body untouched',
      () {
        final resolved = resolveAction(
          const WidgetElement(
            id: '1',
            type: WidgetElementType.action,
            actionUrl: 'http://127.0.0.1:1/on',
            actionBody: 'egal',
          ),
        );
        expect(resolved.url, 'http://127.0.0.1:1/on');
        expect(resolved.body, 'egal');
        expect(resolved.error, isNull);
      },
    );

    test(
      'toggle mode substitutes the opposite of the current value',
      () async {
        DataSourcesController.instance.debugClientOverride = MockClient(
          (request) async => http.Response('{"on": true}', 200),
        );
        final source = await DataSourcesController.instance.add(
          key: 'schalter',
          name: 'Schalter',
          url: 'http://example.com/state',
        );
        await DataSourcesController.instance.refresh(source);

        final resolved = resolveAction(
          const WidgetElement(
            id: '1',
            type: WidgetElementType.action,
            actionValueMode: ActionValueMode.toggle,
            actionToggleSource: '{{schalter.on}}',
            actionUrl: 'http://127.0.0.1:1/set?on={{!wert}}',
            actionBody: '{"on": {{!wert}}}',
          ),
        );

        // The current value is true, so the opposite - false - is what
        // lands wherever {{!wert}} was.
        expect(resolved.url, 'http://127.0.0.1:1/set?on=false');
        expect(resolved.body, '{"on": false}');
        expect(resolved.error, isNull);
      },
    );

    test(
      'a computed value landing right after a bare host with no path or '
      'query separator produces an address the URL check rejects',
      () async {
        // The exact mistake the editor's live preview exists to catch:
        // a toggle value inserted straight after the host, no "/" first.
        DataSourcesController.instance.debugClientOverride = MockClient(
          (request) async => http.Response('{"on": true}', 200),
        );
        final source = await DataSourcesController.instance.add(
          key: 'schalter',
          name: 'Schalter',
          url: 'http://example.com/state',
        );
        await DataSourcesController.instance.refresh(source);

        final resolved = resolveAction(
          const WidgetElement(
            id: '1',
            type: WidgetElementType.action,
            actionValueMode: ActionValueMode.toggle,
            actionToggleSource: '{{schalter.on}}',
            actionUrl: 'http://192.168.178.44:8765{{!wert}}',
          ),
        );
        expect(resolved.url, 'http://192.168.178.44:8765false');
        expect(Uri.tryParse(resolved.url), isNull);
      },
    );
  });
}
