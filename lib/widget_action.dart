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

/// What an action element actually resolves to right now: the exact address
/// and body a tap would send. Computed the same way for a real send and for
/// the editor's live preview, so what the preview shows is never a guess.
class ResolvedAction {
  const ResolvedAction({required this.url, this.body, this.error});

  final String url;
  final String? body;

  /// Set only when [ActionValueMode.toggle] couldn't read a usable
  /// "true"/"false" to flip - [url]/[body] are meaningless in that case.
  final String? error;
}

/// The literal token a toggle action's URL/body puts wherever the computed
/// opposite value belongs - kept out of the normal `{{...}}` placeholder
/// syntax's own resolution (see below) since it isn't a data source lookup.
/// Public so the editor's "insert" button can use the exact same string.
const String toggleValueToken = '{{!wert}}';

/// Resolves an action element's address and body without sending anything -
/// shared by [runWidgetAction] and the editor's live preview, so the
/// preview can never show something different from what a tap would
/// actually do.
ResolvedAction resolveAction(WidgetElement element) {
  final sources = DataSourcesController.instance;

  String? toggled;
  if (element.actionValueMode == ActionValueMode.toggle) {
    final current = sources
        .resolve(element.actionToggleSource)
        .trim()
        .toLowerCase();
    if (current == 'true') {
      toggled = 'false';
    } else if (current == 'false') {
      toggled = 'true';
    } else {
      return const ResolvedAction(
        url: '',
        error: 'Current value not readable',
      );
    }
  }

  // {{!wert}} is filled in first and literally, before the general
  // {{...}} resolution below - otherwise that pass would see an unknown
  // placeholder ("!wert" isn't a data source) and blank it out to "-"
  // before the real value ever gets a chance to land there.
  String fillToggle(String text) =>
      toggled == null ? text : text.replaceAll(toggleValueToken, toggled);

  return ResolvedAction(
    url: sources.resolve(fillToggle(element.actionUrl)).trim(),
    body: element.actionBody.isEmpty
        ? null
        : sources.resolve(fillToggle(element.actionBody)),
  );
}

/// Fires an action element's HTTP call. Unlike a data source's fetch, plain
/// `http://` is allowed here (not just `https://`) - almost every local
/// smart home device (Shelly, Tasmota, a local Home Assistant) has no
/// certificate at all, so requiring https would make this useless for
/// exactly the thing it's for.
Future<WidgetActionResult> runWidgetAction(WidgetElement element) async {
  final resolved = resolveAction(element);
  if (resolved.error != null) {
    return WidgetActionResult(success: false, detail: resolved.error);
  }

  final uri = Uri.tryParse(resolved.url);
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    return const WidgetActionResult(
      success: false,
      detail: 'Not a valid address',
    );
  }

  try {
    final http.Response response;
    switch (element.actionMethod) {
      case ActionMethod.post:
        response = await http
            .post(uri, headers: element.actionHeaders, body: resolved.body)
            .timeout(const Duration(seconds: 10));
      case ActionMethod.put:
        response = await http
            .put(uri, headers: element.actionHeaders, body: resolved.body)
            .timeout(const Duration(seconds: 10));
      case ActionMethod.get:
        response = await http
            .get(uri, headers: element.actionHeaders)
            .timeout(const Duration(seconds: 10));
    }
    final ok = response.statusCode >= 200 && response.statusCode < 300;
    // A card showing this device's status (e.g. an icon reading
    // `{{schalter.on}}`) would otherwise keep showing whatever was fetched
    // before the tap, until that source's own refresh interval - up to 30
    // minutes by default - happens to run out on its own.
    if (ok) await _refreshSourcesAt(uri, DataSourcesController.instance);
    return WidgetActionResult(
      success: ok,
      detail: ok ? null : 'HTTP ${response.statusCode}',
    );
  } catch (e) {
    return WidgetActionResult(success: false, detail: e.toString());
  }
}

/// Refreshes every data source that reads from the same host the action just
/// changed something on - the only way to guess which ones are affected
/// without the device telling us, but a good one: a source and an action
/// aimed at the same host are almost always the same device.
Future<void> _refreshSourcesAt(Uri actionUri, DataSourcesController sources) {
  final matches = [
    for (final source in sources.value)
      if (_originOf(source.url) == actionUri.origin) source,
  ];
  return Future.wait([for (final source in matches) sources.refresh(source)]);
}

/// Uri.origin throws (rather than returning null) on anything without an
/// http(s) scheme, which a hand-typed data source URL could always be.
String? _originOf(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    return null;
  }
  return uri.origin;
}
