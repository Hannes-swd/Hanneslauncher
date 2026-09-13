import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';

import 'code_widget_store.dart';
import 'data_sources_controller.dart';
import 'widget_action.dart';
import 'widget_input_store.dart';

/// The name the page posts its calls to. Everything a code widget can reach
/// outside its own folder goes through this one channel, and through the
/// short list of operations [CodeWidgetBridge._run] answers - nothing else
/// is exposed, so a snippet copied off the internet can do exactly what it
/// was given and no more.
const String launcherChannelName = 'LauncherBridge';

/// Everything the page can read without asking: the fetched data sources,
/// the built-in values, and what is currently typed into the widget cards'
/// input fields.
///
/// Pushed in as a whole rather than answered call by call, so `launcher.get`
/// can be an ordinary function instead of something that has to be awaited -
/// which is the difference between a readable one-liner and a page full of
/// promises for what is, on the Dart side, a map lookup.
Map<String, dynamic> launcherSnapshot() {
  final sources = DataSourcesController.instance;

  final builtIns = <String, Object?>{};
  for (final key in DataSourcesController.builtInKeys) {
    final value = sources.valueOf(key, '');
    builtIns[key] = value;
    // Both spellings, always - same reasoning as the placeholders: code
    // written on a German app keeps working on an English one.
    final english = DataSourcesController.englishKeys[key];
    if (english != null) builtIns[english] = value;
  }

  final inputs = <String, String>{};
  for (final name in WidgetInputStore.instance.names) {
    inputs[name] = WidgetInputStore.instance.textOf(name) ?? '';
  }

  final data = <String, Object?>{};
  for (final source in sources.value) {
    data[source.key] = sources.dataFor(source.id);
  }

  return {'sources': data, 'builtins': builtIns, 'inputs': inputs};
}

/// Answers the page's calls and keeps its copy of [launcherSnapshot] fresh.
/// One per running widget - the block id decides which folder and which
/// stored state the calls land in.
class CodeWidgetBridge {
  CodeWidgetBridge({
    required this.blockId,
    this.onLog,
    this.onHeight,
    this.onToast,
    this.onOpenEntry,
  });

  final String blockId;

  /// Console output and uncaught errors, for the editor's preview. The card
  /// on the panel passes nothing - there is nowhere to show it there.
  final void Function(String message)? onLog;

  /// What the page says it needs, in CSS pixels. Only sent by a flexible
  /// card; a fixed one is the height it was set to whatever the page does.
  final void Function(double height)? onHeight;

  final void Function(String text)? onToast;

  /// Opens an app, web app or folder by the same key the pinned apps and
  /// app rows use. Needs a BuildContext (a folder opens a sheet), which is
  /// why it comes from the view rather than living here.
  final Future<bool> Function(String key)? onOpenEntry;

  WebViewController? controller;

  /// Sends the current snapshot into the page. Called once the document is
  /// up, and again whenever a source, the location or an input field moves.
  Future<void> pushSnapshot() async {
    final target = controller;
    if (target == null) return;
    final json = jsonEncode(launcherSnapshot());
    try {
      await target.runJavaScript('window.__launcherUpdate($json)');
    } catch (_) {
      // The page can be mid-reload; the next push carries the same data.
    }
  }

  Future<void> handleMessage(String raw) async {
    Map<String, dynamic> message;
    try {
      message = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final id = (message['id'] as num?)?.toInt();
    final op = message['op'] as String? ?? '';
    final args = message['args'] as Map<String, dynamic>? ?? const {};
    try {
      final result = await _run(op, args);
      if (id != null) _reply(id, true, result);
    } catch (error) {
      if (id != null) _reply(id, false, '$error');
    }
  }

  void _reply(int id, bool ok, Object? payload) {
    final target = controller;
    if (target == null) return;
    try {
      target.runJavaScript(
        'window.__launcherReply($id, $ok, ${jsonEncode(payload)})',
      );
    } catch (_) {
      // Same as above: a reply into a page that has gone away is not a
      // failure worth reporting anywhere.
    }
  }

  Future<Object?> _run(String op, Map<String, dynamic> args) async {
    switch (op) {
      case 'list':
        return [
          for (final option in DataSourcesController.instance.options())
            {
              'reference': option.placeholder
                  .replaceAll('{{', '')
                  .replaceAll('}}', ''),
              'placeholder': option.placeholder,
              'label': option.label,
              'preview': option.preview,
              'source': option.sourceName,
            },
        ];

      case 'refresh':
        final key = args['key'] as String?;
        if (key == null || key.isEmpty) {
          await DataSourcesController.instance.refreshStale();
        } else {
          final source = DataSourcesController.instance.byKey(key);
          if (source == null) throw 'Keine Datenquelle "$key"';
          await DataSourcesController.instance.refresh(source);
        }
        await pushSnapshot();
        return true;

      case 'fetch':
        return _fetch(args);

      case 'open':
        final key = args['key'] as String? ?? '';
        final open = onOpenEntry;
        if (open == null) return false;
        return open(key);

      case 'openUrl':
        final result = await openExternalUrl(args['url'] as String? ?? '');
        if (!result.success) throw result.detail ?? 'failed';
        return true;

      case 'store':
        final key = args['key'] as String? ?? '';
        if (key.isEmpty) throw 'Kein Name';
        final state = await CodeWidgetStore.instance.readState(blockId);
        state[key] = args['value'];
        await CodeWidgetStore.instance.writeState(blockId, state);
        return true;

      case 'load':
        final state = await CodeWidgetStore.instance.readState(blockId);
        final key = args['key'] as String?;
        if (key == null || key.isEmpty) return state;
        return state[key];

      case 'forget':
        final state = await CodeWidgetStore.instance.readState(blockId);
        state.remove(args['key'] as String? ?? '');
        await CodeWidgetStore.instance.writeState(blockId, state);
        return true;

      case 'toast':
        onToast?.call(args['text']?.toString() ?? '');
        return true;

      case 'height':
        final value = (args['value'] as num?)?.toDouble();
        if (value != null) onHeight?.call(value);
        return true;

      case 'log':
        onLog?.call(args['text']?.toString() ?? '');
        return true;

      default:
        throw 'Unbekannter Aufruf "$op"';
    }
  }

  /// The page's own HTTP call, made from Dart rather than by the page.
  ///
  /// Two reasons it is worth the round trip: the document is loaded from a
  /// file, so its origin is `null` and a plain `fetch()` is refused by every
  /// API that checks CORS; and going through here means an API key can stay
  /// in the data source it belongs to (`useSource`) instead of being typed
  /// into widget code that then travels into every backup.
  ///
  /// Plain `http://` is allowed on purpose, exactly as it is for a widget
  /// card's action button - local smart home devices have no certificate.
  Future<Object?> _fetch(Map<String, dynamic> args) async {
    final raw = (args['url'] as String? ?? '').trim();
    final uri = Uri.tryParse(raw);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw 'Keine gültige Adresse: "$raw"';
    }

    final headers = <String, String>{};
    final useSource = args['useSource'] as String?;
    if (useSource != null && useSource.isNotEmpty) {
      final source = DataSourcesController.instance.byKey(useSource);
      if (source == null) throw 'Keine Datenquelle "$useSource"';
      headers.addAll(source.headers);
    }
    final givenHeaders = args['headers'];
    if (givenHeaders is Map) {
      for (final entry in givenHeaders.entries) {
        headers['${entry.key}'] = '${entry.value}';
      }
    }

    final method = (args['method'] as String? ?? 'GET').toUpperCase();
    final body = args['body'] is String
        ? args['body'] as String
        : args['body'] == null
        ? null
        : jsonEncode(args['body']);

    final http.Response response;
    switch (method) {
      case 'POST':
        response = await http
            .post(uri, headers: headers, body: body)
            .timeout(const Duration(seconds: 15));
      case 'PUT':
        response = await http
            .put(uri, headers: headers, body: body)
            .timeout(const Duration(seconds: 15));
      case 'DELETE':
        response = await http
            .delete(uri, headers: headers, body: body)
            .timeout(const Duration(seconds: 15));
      default:
        response = await http
            .get(uri, headers: headers)
            .timeout(const Duration(seconds: 15));
    }

    Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      // Not JSON - the text is still there under 'text'.
    }
    return {
      'status': response.statusCode,
      'ok': response.statusCode >= 200 && response.statusCode < 300,
      'text': response.body,
      'json': decoded,
    };
  }
}

/// Composes what the WebView actually loads: a base stylesheet, the bridge,
/// the user's HTML, and - only when they hold something - `style.css` and
/// `script.js` next to it.
///
/// [flexible] follows the card: a card that grows to fit its contents must
/// let the page be its natural height, while a fixed one hands the page the
/// full card to lay out in (`height: 100%` then means the card).
String buildCodeDocument(CodeWidgetSource source, {bool flexible = false}) {
  final body = stripDocumentSkeleton(source.html);
  final css = source.css.trim().isEmpty
      ? ''
      : '<link rel="stylesheet" href="${CodeWidgetStore.cssFile}">';
  final js = source.js.trim().isEmpty
      ? ''
      : '<script src="${CodeWidgetStore.jsFile}"></script>';
  final sizing = flexible
      ? 'html,body{margin:0;padding:0;}'
      : 'html,body{margin:0;padding:0;height:100%;}';

  return '''<!doctype html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, user-scalable=no">
<style>
$sizing
*{box-sizing:border-box;}
body{
  font-family:system-ui,-apple-system,Roboto,"Segoe UI",sans-serif;
  font-size:15px;color:#111;background:transparent;
  overflow:hidden;
  -webkit-tap-highlight-color:transparent;
  -webkit-user-select:none;user-select:none;
}
img{max-width:100%;}
button,input,textarea,select{font:inherit;color:inherit;}
input,textarea{-webkit-user-select:text;user-select:text;}
</style>
<script>${_bridgeScript(flexible)}</script>
$css
</head>
<body>
$body
$js
</body>
</html>''';
}

/// Keeps a pasted full page working inside the composed document.
///
/// Examples off the internet come as a whole document - doctype, `<html>`,
/// `<head>`, `<body>`. Dropping just those four wrappers leaves everything
/// that matters (the `<style>`, the `<script>`, the markup) exactly where it
/// was, and it all still works from inside the body. The alternative - not
/// composing at all when the HTML looks complete - would mean the bridge,
/// the stylesheet and the script file silently stop being included for
/// precisely the widgets built by pasting something in.
String stripDocumentSkeleton(String html) {
  var text = html;
  final patterns = <RegExp>[
    RegExp(r'<!doctype[^>]*>', caseSensitive: false),
    RegExp(r'</?html[^>]*>', caseSensitive: false),
    RegExp(r'</?head[^>]*>', caseSensitive: false),
    RegExp(r'</?body[^>]*>', caseSensitive: false),
  ];
  for (final pattern in patterns) {
    text = text.replaceAll(pattern, '');
  }
  return text;
}

/// The `launcher` object the page is written against. Put in the head so it
/// exists before any `<script>` inside the user's own HTML runs.
String _bridgeScript(bool reportHeight) =>
    // ignore: prefer_interpolation_to_compose_strings
    _bridgeCore + (reportHeight ? _heightReporting : '') + '})();';

const String _bridgeCore = r'''
(function () {
  var pending = {};
  var nextId = 1;
  var handlers = [];
  var data = {sources: {}, builtins: {}, inputs: {}};

  function call(op, args) {
    return new Promise(function (resolve, reject) {
      var id = nextId++;
      pending[id] = {resolve: resolve, reject: reject};
      try {
        LauncherBridge.postMessage(
          JSON.stringify({id: id, op: op, args: args || {}})
        );
      } catch (e) {
        delete pending[id];
        reject(e);
      }
    });
  }

  window.__launcherReply = function (id, ok, payload) {
    var entry = pending[id];
    if (!entry) return;
    delete pending[id];
    if (ok) entry.resolve(payload);
    else entry.reject(new Error(String(payload)));
  };

  function walk(node, path) {
    if (!path) return node;
    var steps = path.match(/\[(\d+)\]|[^.\[\]]+/g) || [];
    var current = node;
    for (var i = 0; i < steps.length; i++) {
      if (current === null || current === undefined) return null;
      var index = /^\[(\d+)\]$/.exec(steps[i]);
      current = index
        ? current[parseInt(index[1], 10)]
        : current[steps[i]];
    }
    return current === undefined ? null : current;
  }

  // Same rules the {{...}} placeholders follow everywhere else in the app,
  // so a reference that works on a widget card works here unchanged.
  function get(reference) {
    if (!reference) return null;
    var ref = String(reference).trim();
    var pipe = ref.lastIndexOf('|');
    if (pipe !== -1 && ref.slice(pipe + 1).trim().toLowerCase() === 'url') {
      var plain = get(ref.slice(0, pipe));
      return plain === null ? null : encodeURIComponent(String(plain));
    }
    var dot = ref.indexOf('.');
    var key = dot === -1 ? ref : ref.slice(0, dot);
    var path = dot === -1 ? '' : ref.slice(dot + 1);
    var lower = key.toLowerCase();
    if (lower === 'eingabe' || lower === 'input') {
      var name = path
        .toLowerCase()
        .replace(/[^a-z0-9_]+/g, '_')
        .replace(/^_+|_+$/g, '');
      var typed = data.inputs[name];
      return typed === undefined ? null : typed;
    }
    if (Object.prototype.hasOwnProperty.call(data.builtins, key)) {
      return path ? null : data.builtins[key];
    }
    if (!path) return null;
    var source = data.sources[key];
    if (source === undefined || source === null) return null;
    return walk(source, path);
  }

  function text(value) {
    return value === null || value === undefined ? '-' : String(value);
  }

  function fill(template) {
    return String(template).replace(/\{\{([^{}]*)\}\}/g, function (all, ref) {
      return text(get(ref));
    });
  }

  // Anything carrying data-value shows that value and keeps showing it as
  // the sources refresh - which is what makes "put a number on the card"
  // possible without writing a line of JavaScript.
  function apply(root) {
    var nodes = (root || document).querySelectorAll('[data-value]');
    for (var i = 0; i < nodes.length; i++) {
      nodes[i].textContent = text(get(nodes[i].getAttribute('data-value')));
    }
    var filled = (root || document).querySelectorAll('[data-text]');
    for (var j = 0; j < filled.length; j++) {
      filled[j].textContent = fill(filled[j].getAttribute('data-text'));
    }
  }

  window.__launcherUpdate = function (next) {
    data = next || data;
    try {
      apply();
    } catch (e) {
      report('data-value: ' + e);
    }
    for (var i = 0; i < handlers.length; i++) {
      try {
        handlers[i](data);
      } catch (e) {
        report('onUpdate: ' + e);
      }
    }
  };

  function report(message) {
    call('log', {text: String(message)});
  }

  window.addEventListener('error', function (event) {
    report(
      event.message +
        (event.lineno ? ' (Zeile ' + event.lineno + ')' : '')
    );
  });
  window.addEventListener('unhandledrejection', function (event) {
    report('Unerledigt: ' + event.reason);
  });

  window.launcher = {
    get: get,
    text: function (reference) { return text(get(reference)); },
    data: function (key) {
      var source = data.sources[key];
      return source === undefined ? null : source;
    },
    all: function () { return data; },
    fill: fill,
    apply: apply,
    onUpdate: function (fn) { if (typeof fn === 'function') handlers.push(fn); },
    list: function () { return call('list'); },
    refresh: function (key) { return call('refresh', {key: key || null}); },
    fetch: function (url, options) {
      var args = {url: url};
      if (options) {
        for (var name in options) {
          if (Object.prototype.hasOwnProperty.call(options, name)) {
            args[name] = options[name];
          }
        }
      }
      return call('fetch', args);
    },
    open: function (key) { return call('open', {key: key}); },
    openUrl: function (url) { return call('openUrl', {url: url}); },
    store: function (key, value) { return call('store', {key: key, value: value}); },
    load: function (key) { return call('load', {key: key}); },
    forget: function (key) { return call('forget', {key: key}); },
    toast: function (message) { return call('toast', {text: String(message)}); },
    log: report
  };

  document.addEventListener('DOMContentLoaded', function () {
    try {
      apply();
    } catch (e) {
      report('data-value: ' + e);
    }
  });
''';

/// Only a card set to grow needs this: it tells Dart how tall the page came
/// out so the card can follow. A fixed card already knows its height, and
/// measuring would just be a message per repaint.
const String _heightReporting = r'''
  var lastHeight = 0;
  function measure() {
    if (!document.body) return;
    var height = Math.ceil(
      Math.max(document.body.scrollHeight, document.body.offsetHeight)
    );
    if (height === lastHeight || height <= 0) return;
    lastHeight = height;
    call('height', {value: height});
  }
  document.addEventListener('DOMContentLoaded', function () {
    measure();
    if (window.ResizeObserver) {
      new ResizeObserver(measure).observe(document.body);
    }
  });
  window.addEventListener('load', measure);
''';
