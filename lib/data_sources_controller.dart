import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'locale_controller.dart';
import 'location_controller.dart';

/// One value a card can reference, ready to be offered for picking.
class PlaceholderOption {
  const PlaceholderOption({
    required this.label,
    required this.placeholder,
    required this.preview,
    required this.sourceName,
  });

  /// The path inside its source, or the key for a built-in value.
  final String label;

  /// What gets inserted into the text, e.g. `{{wetter.current.temp}}`.
  final String placeholder;

  /// The value right now, so the right one can be picked by looking at it.
  final String preview;

  /// Which source it comes from; null for the built-in values.
  final String? sourceName;
}

/// A JSON endpoint the widget cards read their values from. Text fields hold
/// placeholders like `{{wetter.current.temperature_2m}}`, where `wetter` is
/// this source's [key] and the rest is the path into the fetched response.
class DataSource {
  const DataSource({
    required this.id,
    required this.key,
    required this.name,
    required this.url,
    this.headers = const {},
    this.refreshMinutes = 30,
  });

  final String id;

  /// The short name placeholders address this source by, e.g. `wetter`.
  final String key;

  /// The display name shown in the settings list.
  final String name;

  final String url;

  /// Sent with every request, e.g. an API key.
  final Map<String, String> headers;

  /// How long a fetched response stays good; see [refreshStale].
  final int refreshMinutes;

  DataSource copyWith({
    String? key,
    String? name,
    String? url,
    Map<String, String>? headers,
    int? refreshMinutes,
  }) {
    return DataSource(
      id: id,
      key: key ?? this.key,
      name: name ?? this.name,
      url: url ?? this.url,
      headers: headers ?? this.headers,
      refreshMinutes: refreshMinutes ?? this.refreshMinutes,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'key': key,
    'name': name,
    'url': url,
    'headers': headers,
    'refreshMinutes': refreshMinutes,
  };

  static DataSource fromJson(Map<String, dynamic> json) => DataSource(
    id: json['id'] as String,
    key: json['key'] as String,
    name: json['name'] as String,
    url: json['url'] as String,
    headers: {
      for (final entry
          in (json['headers'] as Map<String, dynamic>? ?? const {}).entries)
        entry.key: entry.value as String,
    },
    // Never below a minute: a stored 0 would make every panel opening hit
    // the server again.
    refreshMinutes: math.max(1, json['refreshMinutes'] as int? ?? 30),
  );
}

/// The user's data sources plus the last response of each, both persisted
/// across restarts.
class DataSourcesController extends ValueNotifier<List<DataSource>> {
  DataSourcesController._() : super(const []);

  static final DataSourcesController instance = DataSourcesController._();

  static const _key = 'data_sources';

  /// The last response per source id, so a panel opened offline - or before
  /// the first fetch of this run comes back - already shows something.
  static const _cacheKey = 'data_sources_cache';

  static const _timeout = Duration(seconds: 10);

  bool _loaded = false;

  final Map<String, Object?> _data = {};

  /// The raw response text per source id, kept only to write the cache back
  /// exactly as it arrived.
  final Map<String, String> _bodies = {};

  final Map<String, DateTime> _fetchedAt = {};

  /// Only the last attempt's error; not persisted, since a stale error after
  /// a restart would say nothing about the current connection.
  final Map<String, String> _errors = {};

  /// Swapped in by tests so they never touch the network.
  @visibleForTesting
  http.Client? debugClientOverride;

  /// Reads the stored sources once. Later calls do nothing: what's in memory
  /// is by then the newer state, and re-reading would throw away sources
  /// created since - which is how they'd vanish seemingly at random.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    _loadCache(prefs.getString(_cacheKey));
    final raw = prefs.getStringList(_key);
    if (raw == null) return;
    final loaded = <DataSource>[];
    for (final entry in raw) {
      try {
        loaded.add(
          DataSource.fromJson(jsonDecode(entry) as Map<String, dynamic>),
        );
      } catch (_) {
        // Skip just the unreadable one. Dropping the whole list here would
        // be permanent: the next save would write the shortened list back.
      }
    }
    value = loaded;
  }

  /// Lets a test pretend the app restarted; there is no other way to make
  /// the one-shot [load] read again. Drops the cache too, because a real
  /// restart starts out with nothing until [load] reads it back.
  @visibleForTesting
  void debugResetLoadedForTest() {
    _loaded = false;
    _data.clear();
    _bodies.clear();
    _fetchedAt.clear();
    _errors.clear();
  }

  DataSource? byId(String id) {
    for (final source in value) {
      if (source.id == id) return source;
    }
    return null;
  }

  DataSource? byKey(String key) {
    for (final source in value) {
      if (source.key == key) return source;
    }
    return null;
  }

  Future<DataSource> add({
    required String key,
    required String name,
    required String url,
    Map<String, String> headers = const {},
    int refreshMinutes = 30,
  }) async {
    final source = DataSource(
      id: _newId(),
      key: _uniqueKey(key),
      name: name.trim(),
      url: url.trim(),
      headers: headers,
      refreshMinutes: refreshMinutes,
    );
    await _save([...value, source]);
    return source;
  }

  /// Replaces the source carrying the same id, keeping its position.
  Future<void> update(DataSource source) async {
    final unique = source.copyWith(
      key: _uniqueKey(source.key, ownerId: source.id),
      name: source.name.trim(),
      url: source.url.trim(),
    );
    await _save([
      for (final existing in value)
        if (existing.id == source.id) unique else existing,
    ]);
  }

  Future<void> remove(String id) async {
    _data.remove(id);
    _bodies.remove(id);
    _fetchedAt.remove(id);
    _errors.remove(id);
    await _save([
      for (final source in value)
        if (source.id != id) source,
    ]);
    await _saveCache();
  }

  /// The last fetched, decoded response of a source, or null if there is
  /// none yet.
  Object? dataFor(String sourceId) => _data[sourceId];

  DateTime? fetchedAt(String sourceId) => _fetchedAt[sourceId];

  /// The last fetch's error, or null if it went through.
  String? errorFor(String sourceId) => _errors[sourceId];

  /// Fetches a source and stores the response with a timestamp. Returns an
  /// error text, or null on success. A failed fetch leaves the cached
  /// response alone - a card showing this morning's value beats a card
  /// showing nothing because the train went into a tunnel.
  Future<String?> refresh(DataSource source) async {
    final result = await _fetch(source.url, source.headers);
    if (result.error != null) {
      _errors[source.id] = result.error!;
      notifyListeners();
      return result.error;
    }
    _errors.remove(source.id);
    _data[source.id] = result.data;
    _bodies[source.id] = result.body!;
    _fetchedAt[source.id] = DateTime.now();
    await _saveCache();
    notifyListeners();
    return null;
  }

  /// Fetches every source whose [DataSource.refreshMinutes] have run out, and
  /// every source that was never fetched at all.
  Future<void> refreshStale() async {
    final now = DateTime.now();
    // One after another: a handful of sources refreshing at once on a phone's
    // connection is slower than it looks, and nothing here needs to race.
    for (final source in [...value]) {
      final at = _fetchedAt[source.id];
      if (at != null &&
          now.difference(at) < Duration(minutes: source.refreshMinutes)) {
        continue;
      }
      await refresh(source);
    }
  }

  /// One-off fetch for the editor's "test" button. Stores nothing.
  Future<({Object? data, String? error})> preview(
    String url,
    Map<String, String> headers,
  ) async {
    final result = await _fetch(url, headers);
    return (data: result.data, error: result.error);
  }

  /// Walks a path like `a.b`, `a[0].b` or plain `[0]` into a decoded JSON
  /// response. Returns null if the path doesn't lead anywhere.
  static Object? valueAt(Object? data, String path) {
    var current = data;
    for (final match in _pathStep.allMatches(path)) {
      if (current == null) return null;
      final index = match.group(1);
      if (index != null) {
        final at = int.parse(index);
        if (current is! List || at >= current.length) return null;
        current = current[at];
      } else {
        final name = match.group(2)!;
        if (current is! Map || !current.containsKey(name)) return null;
        current = current[name];
      }
    }
    return current;
  }

  /// The raw value behind a single placeholder. A placeholder without a
  /// path (`{{weather}}`) has no single value - dumping the whole response
  /// into a card's text line helps nobody, so it counts as missing.
  Object? valueOf(String key, String path) {
    final builtIn = _builtIn(key);
    if (builtIn != null) return builtIn;
    if (path.isEmpty) return null;
    final source = byKey(key);
    if (source == null) return null;
    return valueAt(_data[source.id], path);
  }

  /// Values every card can use without setting up a source at all. Kept here
  /// so they go through the same `{{...}}` mechanism as fetched values.
  static const builtInKeys = [
    'zeit',
    'zeit24',
    'zeit12',
    'ampm',
    'datum',
    'wochentag',
    'ort',
    'lat',
    'lon',
  ];

  /// Whether `{{zeit}}` is written 24-hour. Mirrors the phone's own clock
  /// setting, so the card and the status bar never disagree; set from the
  /// widget tree, which is where that setting can be read.
  static bool use24HourFormat = true;

  static String _time24(DateTime now) =>
      '${now.hour.toString().padLeft(2, '0')}:'
      '${now.minute.toString().padLeft(2, '0')}';

  static String _time12(DateTime now) {
    // 0 and 12 o'clock are both written as 12 on a 12-hour clock.
    final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
    return '$hour:${now.minute.toString().padLeft(2, '0')} '
        '${now.hour < 12 ? 'AM' : 'PM'}';
  }

  static String? _builtIn(String key) {
    final now = DateTime.now();
    switch (key) {
      // Whichever the phone itself is set to, so card and status bar agree.
      case 'zeit' || 'time':
        return use24HourFormat ? _time24(now) : _time12(now);
      case 'zeit24' || 'time24':
        return _time24(now);
      case 'zeit12' || 'time12':
        return _time12(now);
      // On its own, so it can be placed and styled apart from the digits.
      case 'ampm':
        return now.hour < 12 ? 'AM' : 'PM';
      // Meant for a source's URL, so it follows wherever the phone is.
      case 'lat':
        return LocationController.instance.latText;
      case 'lon':
        return LocationController.instance.lonText;
      // The town those coordinates are in, so a card can name the place its
      // numbers belong to.
      case 'ort' || 'city':
        return LocationController.instance.city;
      case 'datum' || 'date':
        return '${now.day.toString().padLeft(2, '0')}.'
            '${now.month.toString().padLeft(2, '0')}.${now.year}';
      case 'wochentag' || 'weekday':
        // DateTime.weekday is 1..7 starting on Monday.
        const german = [
          'Montag',
          'Dienstag',
          'Mittwoch',
          'Donnerstag',
          'Freitag',
          'Samstag',
          'Sonntag',
        ];
        const english = [
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday',
        ];
        final names = LocaleController.instance.value == AppLanguage.en
            ? english
            : german;
        return names[now.weekday - 1];
      default:
        return null;
    }
  }

  /// Everything a card can put in a text field right now: the built-in
  /// values plus every single value in the fetched responses. This is what
  /// the editor offers for picking, so nobody has to know an API's shape.
  List<PlaceholderOption> options() {
    final options = [
      for (final key in builtInKeys)
        PlaceholderOption(
          label: key,
          placeholder: '{{$key}}',
          preview: _format(_builtIn(key)),
          sourceName: null,
        ),
    ];
    for (final source in value) {
      _collect(_data[source.id], '', source, options);
    }
    return options;
  }

  /// Flattens a response into one option per single value. Deeply nested or
  /// huge responses are cut off - past a few hundred entries the list is no
  /// longer something anyone scrolls through, and the tree picker still
  /// reaches the rest.
  void _collect(
    Object? node,
    String path,
    DataSource source,
    List<PlaceholderOption> into, {
    int depth = 0,
  }) {
    if (into.length > 300 || depth > 6) return;
    if (node is Map) {
      for (final entry in node.entries) {
        final childPath = path.isEmpty ? '${entry.key}' : '$path.${entry.key}';
        _collect(entry.value, childPath, source, into, depth: depth + 1);
      }
    } else if (node is List) {
      for (var i = 0; i < node.length; i++) {
        _collect(node[i], '$path[$i]', source, into, depth: depth + 1);
      }
    } else if (path.isNotEmpty) {
      into.add(
        PlaceholderOption(
          label: path,
          placeholder: '{{${source.key}.$path}}',
          preview: _format(node),
          sourceName: source.name,
        ),
      );
    }
  }

  /// Replaces every `{{key.path}}` in [template] with its current value.
  String resolve(String template) {
    return template.replaceAllMapped(_placeholder, (match) {
      final reference = match.group(1)!.trim();
      final dot = reference.indexOf('.');
      final key = dot == -1 ? reference : reference.substring(0, dot);
      final path = dot == -1 ? '' : reference.substring(dot + 1);
      return _format(valueOf(key, path));
    });
  }

  static final _placeholder = RegExp(r'\{\{([^{}]*)\}\}');

  /// A name, or a `[0]` index, in a path.
  static final _pathStep = RegExp(r'\[(\d+)\]|([^.\[\]]+)');

  static String _format(Object? value) {
    // An unknown source or a path that isn't in the response prints as a
    // dash instead of leaving a gap in the card's text.
    if (value == null) return '-';
    // JSON hands whole numbers over as 21.0, which nobody wants to read on a
    // weather card.
    if (value is double && value.isFinite && value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toString();
  }

  Future<({Object? data, String? error, String? body})> _fetch(
    String rawUrl,
    Map<String, String> headers,
  ) async {
    // The URL goes through the same placeholders as the cards, so a source
    // can follow the current position with `latitude={{lat}}`.
    if (rawUrl.contains('{{lat}}') || rawUrl.contains('{{lon}}')) {
      await LocationController.instance.ensureFresh();
      if (LocationController.instance.value == null) {
        return (
          data: null,
          error:
              'No location yet'
              '${LocationController.instance.error == null ? '' : ' - '
                  '${LocationController.instance.error}'}',
          body: null,
        );
      }
    }
    final url = resolve(rawUrl);
    final uri = Uri.tryParse(url.trim());
    if (uri == null || uri.scheme != 'https') {
      // The headers can carry an API key, so plain http is not an option.
      return (
        data: null,
        error: 'Only https addresses can be used',
        body: null,
      );
    }
    final override = debugClientOverride;
    final client = override ?? http.Client();
    try {
      final response = await client
          .get(uri, headers: headers)
          .timeout(_timeout);
      if (response.statusCode != 200) {
        return (
          data: null,
          error: 'Server answered with ${response.statusCode}',
          body: null,
        );
      }
      return (
        data: jsonDecode(response.body),
        error: null,
        body: response.body,
      );
    } on FormatException {
      return (data: null, error: 'Answer is not valid JSON', body: null);
    } catch (error) {
      // No connection, timeout, bad certificate: all of it is something the
      // panel shows next to the card, never something that reaches the UI as
      // an exception.
      return (data: null, error: error.toString(), body: null);
    } finally {
      if (override == null) client.close();
    }
  }

  /// Placeholders name a source by its key, so two sources sharing one would
  /// make `{{wetter.…}}` point at either. Number the later one instead.
  String _uniqueKey(String key, {String? ownerId}) {
    final base = key.trim().isEmpty ? 'quelle' : key.trim();
    var candidate = base;
    var suffix = 2;
    while (value.any((s) => s.key == candidate && s.id != ownerId)) {
      candidate = '$base$suffix';
      suffix++;
    }
    return candidate;
  }

  /// Ids are the creation time. Windows only advances the clock every few
  /// milliseconds, so two sources added in quick succession can ask for the
  /// same one - and sources sharing an id would be edited and removed
  /// together. Step past anything already taken.
  String _newId() {
    var stamp = DateTime.now().microsecondsSinceEpoch;
    while (byId(stamp.toString()) != null) {
      stamp++;
    }
    return stamp.toString();
  }

  void _loadCache(String? raw) {
    if (raw == null) return;
    final Map<String, dynamic> stored;
    try {
      stored = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    for (final entry in stored.entries) {
      try {
        final cached = entry.value as Map<String, dynamic>;
        final body = cached['body'] as String;
        _data[entry.key] = jsonDecode(body);
        _bodies[entry.key] = body;
        _fetchedAt[entry.key] = DateTime.fromMillisecondsSinceEpoch(
          cached['at'] as int,
        );
      } catch (_) {
        // A cache entry that can't be read costs one refresh, nothing more.
      }
    }
  }

  Future<void> _saveCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cacheKey,
      // Only what still belongs to a source, so deleted ones don't keep
      // their response around forever.
      jsonEncode({
        for (final source in value)
          if (_bodies[source.id] != null)
            source.id: {
              'body': _bodies[source.id],
              'at': _fetchedAt[source.id]?.millisecondsSinceEpoch ?? 0,
            },
      }),
    );
  }

  Future<void> _save(List<DataSource> sources) async {
    value = sources;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, [
      for (final source in sources) jsonEncode(source.toJson()),
    ]);
  }
}
