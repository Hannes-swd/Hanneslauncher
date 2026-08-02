import 'package:http/http.dart' as http;

import 'data_sources_controller.dart';
import 'widget_element.dart';

class WidgetActionResult {
  const WidgetActionResult({required this.success, this.detail});

  final bool success;

  /// The HTTP status on success, or an error message on failure - shown to
  /// the user as the only confirmation a fire-and-forget request gets.
  final String? detail;
}

/// Fires an action element's HTTP call. Unlike a data source's fetch, plain
/// `http://` is allowed here (not just `https://`) - almost every local
/// smart home device (Shelly, Tasmota, a local Home Assistant) has no
/// certificate at all, so requiring https would make this useless for
/// exactly the thing it's for.
Future<WidgetActionResult> runWidgetAction(WidgetElement element) async {
  final sources = DataSourcesController.instance;
  final url = sources.resolve(element.actionUrl).trim();
  final uri = Uri.tryParse(url);
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    return const WidgetActionResult(
      success: false,
      detail: 'Not a valid address',
    );
  }

  final body = element.actionBody.isEmpty
      ? null
      : sources.resolve(element.actionBody);

  try {
    final http.Response response;
    switch (element.actionMethod) {
      case ActionMethod.post:
        response = await http
            .post(uri, headers: element.actionHeaders, body: body)
            .timeout(const Duration(seconds: 10));
      case ActionMethod.put:
        response = await http
            .put(uri, headers: element.actionHeaders, body: body)
            .timeout(const Duration(seconds: 10));
      case ActionMethod.get:
        response = await http
            .get(uri, headers: element.actionHeaders)
            .timeout(const Duration(seconds: 10));
    }
    final ok = response.statusCode >= 200 && response.statusCode < 300;
    return WidgetActionResult(
      success: ok,
      detail: ok ? null : 'HTTP ${response.statusCode}',
    );
  } catch (e) {
    return WidgetActionResult(success: false, detail: e.toString());
  }
}
