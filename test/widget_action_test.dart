import 'package:flutter_test/flutter_test.dart';
import 'package:hanneslouncher/widget_action.dart';
import 'package:hanneslouncher/widget_element.dart';

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
}
