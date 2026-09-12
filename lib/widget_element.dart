import 'package:flutter/material.dart';

/// What a single line on a widget card shows.
enum WidgetElementType {
  /// Free text with `{{source.path}}` placeholders filled in.
  text,

  /// An icon chosen by matching a value against [WidgetElement.rules].
  icon,

  /// A picture fetched from a URL - the URL itself may contain
  /// placeholders, which is how a map tile follows a coordinate.
  image,

  /// A plain rectangle. Put behind text on a busy picture, it makes the
  /// text readable again.
  box,

  /// A button: tapping it either fires an HTTP call (a smart home device's
  /// own local API, typically) or opens an address - see [WidgetActionKind].
  action,

  /// A field the user types into. What is typed is readable everywhere a
  /// `{{...}}` placeholder is, as `{{eingabe.<name>}}` - which is how a
  /// text element next to it becomes its display, and an action button
  /// next to it becomes its "go".
  input,

  /// The answers to what is in an input field: matching apps, settings,
  /// contacts, the result of a sum, and a web search as the last row. Each
  /// one is tappable. Which piles it looks in is a set of tick boxes, so a
  /// working search needs no address and no placeholder typed anywhere.
  results,
}

/// What an action element's tap does. Each kind uses a different handful of
/// the fields below, and the editor shows only that handful - a button set
/// to search has no business asking about an HTTP method.
enum WidgetActionKind {
  /// Sends the configured HTTP request and reports what came back. Uses
  /// [WidgetElement.actionUrl], [WidgetElement.actionMethod],
  /// [WidgetElement.actionHeaders], [WidgetElement.actionBody] and the
  /// toggle pair.
  http,

  /// Hands [WidgetElement.actionUrl] to the phone, which opens whatever
  /// handles it - a browser for https, the dialer for tel:, the map for
  /// geo:. Uses nothing else.
  open,

  /// Searches for whatever is typed in the input field named by
  /// [WidgetElement.inputName], using [WidgetElement.webSearchUrl]. Two
  /// dropdowns and no address to type, which is the whole point of it
  /// existing next to [open].
  search,
}

/// What a search address writes where the typed words belong. Deliberately
/// not one of the `{{...}}` data-source placeholders: this is filled in at
/// the moment of the tap, and going through the general resolution would
/// only mean it could be blanked out to "-".
const String webSearchQueryToken = '{{suche}}';

/// The search engines the editor offers, so nobody has to know what a search
/// URL looks like. "Own address" is the escape hatch and holds whatever was
/// typed instead of one of these.
const Map<String, String> webSearchPresets = {
  'DuckDuckGo': 'https://duckduckgo.com/?q=$webSearchQueryToken',
  'Google': 'https://www.google.com/search?q=$webSearchQueryToken',
  'Bing': 'https://www.bing.com/search?q=$webSearchQueryToken',
  'Wikipedia':
      'https://de.wikipedia.org/w/index.php?search=$webSearchQueryToken',
  'YouTube': 'https://www.youtube.com/results?search_query=$webSearchQueryToken',
  'Google Maps': 'https://www.google.com/maps/search/$webSearchQueryToken',
};

/// Which keyboard an input element brings up.
enum WidgetInputKeyboard { text, number, url }

/// Where a text element's line comes from.
enum WidgetTextMode {
  /// Written by hand, `{{...}}` placeholders and all. The original, and
  /// still the only one that can mix several values into one line.
  free,

  /// Shows what is typed in the input field named by
  /// [WidgetElement.inputName], and nothing else.
  inputValue,

  /// Shows the result of reading that field as a sum, and stays empty while
  /// what is in it isn't one. This is the calculator's display.
  calculation,
}

/// The HTTP method an action element's tap sends.
enum ActionMethod { get, post, put }

/// Whether an action always sends the same configured value, or reads the
/// current one first and sends its opposite - the difference between "an"
/// and "aus" being two separate buttons versus one that flips a light.
enum ActionValueMode { fixed, toggle }

/// A rule for the icon element: if the value matches, show [iconName].
/// The first matching rule in the list wins, so ordering is the priority.
class IconRule {
  const IconRule({this.min, this.max, this.equals, required this.iconName});

  /// Numeric range, either end optional. Ignored when [equals] is set.
  final double? min;
  final double? max;

  /// Exact text match, compared case-insensitively.
  final String? equals;

  final String iconName;

  bool matches(String value) {
    final wanted = equals;
    if (wanted != null && wanted.isNotEmpty) {
      return value.trim().toLowerCase() == wanted.trim().toLowerCase();
    }
    final number = _numberIn(value);
    if (number == null) return false;
    if (min != null && number < min!) return false;
    if (max != null && number > max!) return false;
    // A rule with neither bound set would match anything numeric, which is
    // useful as a catch-all at the end of the list.
    return true;
  }

  /// The first number in the text. A value is often written with something
  /// around it - a unit, a degree sign - and demanding a bare number would
  /// silently match nothing at all.
  static double? _numberIn(String value) {
    final match = RegExp(r'-?\d+([.,]\d+)?').firstMatch(value);
    if (match == null) return null;
    return double.tryParse(match.group(0)!.replaceAll(',', '.'));
  }

  IconRule copyWith({
    double? min,
    double? max,
    String? equals,
    String? iconName,
  }) {
    return IconRule(
      min: min ?? this.min,
      max: max ?? this.max,
      equals: equals ?? this.equals,
      iconName: iconName ?? this.iconName,
    );
  }

  Map<String, dynamic> toJson() => {
    if (min != null) 'min': min,
    if (max != null) 'max': max,
    if (equals != null) 'equals': equals,
    'iconName': iconName,
  };

  static IconRule fromJson(Map<String, dynamic> json) => IconRule(
    min: (json['min'] as num?)?.toDouble(),
    max: (json['max'] as num?)?.toDouble(),
    equals: json['equals'] as String?,
    iconName: json['iconName'] as String? ?? 'help',
  );
}

/// One line on a widget card.
class WidgetElement {
  const WidgetElement({
    required this.id,
    required this.type,
    this.template = '',
    this.fontSize = 16,
    this.colorIndex = 0,
    this.bold = false,
    this.alignment = WidgetAlignment.left,
    this.iconSize = 32,
    this.height = 140,
    this.rules = const [],
    this.x = 0.5,
    this.y = 0.5,
    this.width = 200,
    this.opacity = 1,
    this.radius = 12,
    this.actionUrl = '',
    this.actionMethod = ActionMethod.post,
    this.actionHeaders = const {},
    this.actionBody = '',
    this.actionValueMode = ActionValueMode.fixed,
    this.actionToggleSource = '',
    this.actionKind = WidgetActionKind.http,
    this.inputName = '',
    this.inputHint = '',
    this.inputKeyboard = WidgetInputKeyboard.text,
    this.searchApps = true,
    this.searchSettings = true,
    this.searchCalculation = true,
    this.searchContacts = false,
    this.webSearchUrl = '',
    this.resultLimit = 4,
    this.textMode = WidgetTextMode.free,
  });

  final String id;
  final WidgetElementType type;

  /// Text: the line itself. Icon: the value that gets matched against the
  /// rules. Image: the picture's URL. Action: which of [widgetIcons] it
  /// shows. All may hold `{{...}}` placeholders except action's.
  final String template;

  final double fontSize;
  final int colorIndex;
  final bool bold;
  final WidgetAlignment alignment;
  final double iconSize;

  /// Image and box.
  final double height;

  /// Icon only.
  final List<IconRule> rules;

  /// Where it sits on the card, 0..1 from the top left corner. At 0 and 1
  /// the element rests against that edge instead of hanging over it, so
  /// nothing can be dragged out of sight.
  final double x;
  final double y;

  /// Image and box: how wide it is, in the same unit as [height]. Capped at
  /// the card's width when drawn, so it can never stick out.
  final double width;

  /// Box only: how solid it is, and how round its corners are.
  final double opacity;
  final double radius;

  /// Action only: what the tap sends. The URL and body may hold `{{...}}`
  /// placeholders, resolved the same way a data source's own URL is - a
  /// smart home hub's address can follow {{lat}}/{{lon}} same as anything
  /// else. Plain http is allowed here (unlike a data source's fetch),
  /// since most local smart home devices have no certificate at all.
  final String actionUrl;
  final ActionMethod actionMethod;
  final Map<String, String> actionHeaders;
  final String actionBody;

  /// Action only: [ActionValueMode.fixed] sends [actionUrl]/[actionBody]
  /// exactly as configured. [ActionValueMode.toggle] first resolves
  /// [actionToggleSource] (a `{{...}}` placeholder, same as anywhere else)
  /// to "true"/"false", then sends the opposite wherever `{{!wert}}`
  /// appears in the URL or body.
  final ActionValueMode actionValueMode;
  final String actionToggleSource;

  /// Action only: whether the tap sends a request or opens the address.
  /// Everything above applies to [WidgetActionKind.http] alone - opening
  /// needs nothing but [actionUrl].
  final WidgetActionKind actionKind;

  /// Input: the name this field is referenced by, as `{{eingabe.<name>}}`.
  /// Results and a text element in a mode other than [WidgetTextMode.free]:
  /// the name of the input field being watched.
  ///
  /// Stored the way it was typed; every lookup goes through
  /// [WidgetInputStore.normalizeName] first, so case and stray punctuation
  /// don't decide whether a reference finds it.
  final String inputName;

  /// Input only: what the empty field shows. May hold `{{...}}`
  /// placeholders like any other text.
  final String inputHint;

  final WidgetInputKeyboard inputKeyboard;

  /// Results only: which piles are searched. Ticked rather than typed, so a
  /// working search needs no address and no placeholder anywhere. Contacts
  /// starts off because it is the only one that costs a permission.
  final bool searchApps;
  final bool searchSettings;
  final bool searchCalculation;
  final bool searchContacts;

  /// Results and a [WidgetActionKind.search] button: the search address,
  /// with [webSearchQueryToken] where the typed words go. Normally one of
  /// [webSearchPresets], picked from a dropdown. On a results element,
  /// empty means no web row at all.
  final String webSearchUrl;

  /// Results only: how many rows each pile may contribute. The web row is
  /// not counted - it is the one that says "nothing here matched, but this
  /// will find something", so cutting it off would defeat it.
  final int resultLimit;

  /// Text only: whether the line is written by hand (with `{{...}}`
  /// placeholders) or simply follows an input field. The latter two exist so
  /// a display can be set up by picking a field from a dropdown rather than
  /// by knowing the placeholder syntax at all.
  final WidgetTextMode textMode;

  WidgetElement copyWith({
    String? template,
    double? fontSize,
    int? colorIndex,
    bool? bold,
    WidgetAlignment? alignment,
    double? iconSize,
    double? height,
    List<IconRule>? rules,
    double? x,
    double? y,
    double? width,
    double? opacity,
    double? radius,
    String? actionUrl,
    ActionMethod? actionMethod,
    Map<String, String>? actionHeaders,
    String? actionBody,
    ActionValueMode? actionValueMode,
    String? actionToggleSource,
    WidgetActionKind? actionKind,
    String? inputName,
    String? inputHint,
    WidgetInputKeyboard? inputKeyboard,
    bool? searchApps,
    bool? searchSettings,
    bool? searchCalculation,
    bool? searchContacts,
    String? webSearchUrl,
    int? resultLimit,
    WidgetTextMode? textMode,
  }) {
    return WidgetElement(
      id: id,
      type: type,
      template: template ?? this.template,
      fontSize: fontSize ?? this.fontSize,
      colorIndex: colorIndex ?? this.colorIndex,
      bold: bold ?? this.bold,
      alignment: alignment ?? this.alignment,
      iconSize: iconSize ?? this.iconSize,
      height: height ?? this.height,
      rules: rules ?? this.rules,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      opacity: opacity ?? this.opacity,
      radius: radius ?? this.radius,
      actionUrl: actionUrl ?? this.actionUrl,
      actionMethod: actionMethod ?? this.actionMethod,
      actionHeaders: actionHeaders ?? this.actionHeaders,
      actionBody: actionBody ?? this.actionBody,
      actionValueMode: actionValueMode ?? this.actionValueMode,
      actionToggleSource: actionToggleSource ?? this.actionToggleSource,
      actionKind: actionKind ?? this.actionKind,
      inputName: inputName ?? this.inputName,
      inputHint: inputHint ?? this.inputHint,
      inputKeyboard: inputKeyboard ?? this.inputKeyboard,
      searchApps: searchApps ?? this.searchApps,
      searchSettings: searchSettings ?? this.searchSettings,
      searchCalculation: searchCalculation ?? this.searchCalculation,
      searchContacts: searchContacts ?? this.searchContacts,
      webSearchUrl: webSearchUrl ?? this.webSearchUrl,
      resultLimit: resultLimit ?? this.resultLimit,
      textMode: textMode ?? this.textMode,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'template': template,
    'fontSize': fontSize,
    'colorIndex': colorIndex,
    'bold': bold,
    'alignment': alignment.name,
    'iconSize': iconSize,
    'height': height,
    'rules': [for (final rule in rules) rule.toJson()],
    'x': x,
    'y': y,
    'width': width,
    'opacity': opacity,
    'radius': radius,
    'actionUrl': actionUrl,
    'actionMethod': actionMethod.name,
    'actionHeaders': actionHeaders,
    'actionBody': actionBody,
    'actionValueMode': actionValueMode.name,
    'actionToggleSource': actionToggleSource,
    'actionKind': actionKind.name,
    'inputName': inputName,
    'inputHint': inputHint,
    'inputKeyboard': inputKeyboard.name,
    'searchApps': searchApps,
    'searchSettings': searchSettings,
    'searchCalculation': searchCalculation,
    'searchContacts': searchContacts,
    'webSearchUrl': webSearchUrl,
    'resultLimit': resultLimit,
    'textMode': textMode.name,
  };

  static WidgetElement fromJson(Map<String, dynamic> json) => WidgetElement(
    id: json['id'] as String,
    type: _typeFromName(json['type']),
    template: json['template'] as String? ?? '',
    fontSize: (json['fontSize'] as num?)?.toDouble() ?? 16,
    colorIndex: json['colorIndex'] as int? ?? 0,
    bold: json['bold'] as bool? ?? false,
    alignment: _alignmentFromName(json['alignment']),
    iconSize: (json['iconSize'] as num?)?.toDouble() ?? 32,
    height: (json['height'] as num?)?.toDouble() ?? 140,
    rules: [
      for (final rule in (json['rules'] as List<dynamic>? ?? const []))
        IconRule.fromJson(rule as Map<String, dynamic>),
    ],
    x: (json['x'] as num?)?.toDouble() ?? 0.5,
    y: (json['y'] as num?)?.toDouble() ?? 0.5,
    // Widths used to be a share of the card. Anything stored that way is
    // converted once, using a typical card width, so old cards keep roughly
    // the size they had.
    width:
        (json['width'] as num?)?.toDouble() ??
        ((json['widthFactor'] as num?)?.toDouble() ?? 1) * 320,
    opacity: (json['opacity'] as num?)?.toDouble() ?? 1,
    radius: (json['radius'] as num?)?.toDouble() ?? 12,
    actionUrl: json['actionUrl'] as String? ?? '',
    actionMethod: _actionMethodFromName(json['actionMethod']),
    actionHeaders: {
      for (final entry
          in (json['actionHeaders'] as Map<String, dynamic>? ?? const {})
              .entries)
        entry.key: entry.value as String,
    },
    actionBody: json['actionBody'] as String? ?? '',
    actionValueMode: _actionValueModeFromName(json['actionValueMode']),
    actionToggleSource: json['actionToggleSource'] as String? ?? '',
    // Absent on every card built before buttons could open something, and
    // those all sent a request - which is exactly the fallback.
    actionKind: _actionKindFromName(json['actionKind']),
    inputName: json['inputName'] as String? ?? '',
    inputHint: json['inputHint'] as String? ?? '',
    inputKeyboard: _inputKeyboardFromName(json['inputKeyboard']),
    searchApps: json['searchApps'] as bool? ?? true,
    searchSettings: json['searchSettings'] as bool? ?? true,
    searchCalculation: json['searchCalculation'] as bool? ?? true,
    searchContacts: json['searchContacts'] as bool? ?? false,
    webSearchUrl: json['webSearchUrl'] as String? ?? '',
    resultLimit: (json['resultLimit'] as num?)?.toInt() ?? 4,
    textMode: _textModeFromName(json['textMode']),
  );

  static WidgetTextMode _textModeFromName(Object? name) {
    for (final mode in WidgetTextMode.values) {
      if (mode.name == name) return mode;
    }
    return WidgetTextMode.free;
  }

  static WidgetActionKind _actionKindFromName(Object? name) {
    for (final kind in WidgetActionKind.values) {
      if (kind.name == name) return kind;
    }
    return WidgetActionKind.http;
  }

  static WidgetInputKeyboard _inputKeyboardFromName(Object? name) {
    for (final keyboard in WidgetInputKeyboard.values) {
      if (keyboard.name == name) return keyboard;
    }
    return WidgetInputKeyboard.text;
  }

  static ActionMethod _actionMethodFromName(Object? name) {
    for (final method in ActionMethod.values) {
      if (method.name == name) return method;
    }
    return ActionMethod.get;
  }

  static ActionValueMode _actionValueModeFromName(Object? name) {
    for (final mode in ActionValueMode.values) {
      if (mode.name == name) return mode;
    }
    return ActionValueMode.fixed;
  }

  /// Whether this was stored before elements had a position of their own.
  /// Such cards were drawn as rows, so their elements get spread down the
  /// card rather than all landing on the same spot.
  static bool hasNoStoredPosition(Map<String, dynamic> json) =>
      json['y'] == null;

  /// Throws on an unknown type so the caller drops that one element instead
  /// of guessing what it was meant to be.
  static WidgetElementType _typeFromName(Object? name) {
    for (final type in WidgetElementType.values) {
      if (type.name == name) return type;
    }
    throw FormatException('unknown widget element type: $name');
  }

  static WidgetAlignment _alignmentFromName(Object? name) {
    for (final alignment in WidgetAlignment.values) {
      if (alignment.name == name) return alignment;
    }
    return WidgetAlignment.left;
  }
}

enum WidgetAlignment { left, center, right }

extension WidgetAlignmentX on WidgetAlignment {
  Alignment get alignment => switch (this) {
    WidgetAlignment.left => Alignment.centerLeft,
    WidgetAlignment.center => Alignment.center,
    WidgetAlignment.right => Alignment.centerRight,
  };

  TextAlign get textAlign => switch (this) {
    WidgetAlignment.left => TextAlign.left,
    WidgetAlignment.center => TextAlign.center,
    WidgetAlignment.right => TextAlign.right,
  };
}

/// The standard WMO weather-code ranges Open-Meteo's `weather_code` field
/// uses, each mapped to a sensible icon. Typed out once here rather than
/// left for hand entry, which is exactly the kind of small transcription
/// mistake (a swapped digit, a missed range) that silently leaves a code
/// uncovered.
const List<IconRule> weatherWmoRules = [
  IconRule(min: 0, max: 0, iconName: 'sunny'),
  IconRule(min: 1, max: 2, iconName: 'partly'),
  IconRule(min: 3, max: 3, iconName: 'cloudy'),
  IconRule(min: 45, max: 48, iconName: 'fog'),
  IconRule(min: 51, max: 57, iconName: 'shower'),
  IconRule(min: 61, max: 67, iconName: 'rain'),
  IconRule(min: 71, max: 77, iconName: 'snow'),
  IconRule(min: 80, max: 82, iconName: 'shower'),
  IconRule(min: 85, max: 86, iconName: 'snow'),
  IconRule(min: 95, max: 99, iconName: 'thunder'),
];

/// The icons an icon rule can pick, by name. A fixed map rather than a
/// lookup by code point, so the build can still drop unused glyphs.
const Map<String, IconData> widgetIcons = {
  'sunny': Icons.wb_sunny,
  'cloudy': Icons.cloud,
  'partly': Icons.cloud_queue,
  'rain': Icons.umbrella,
  'shower': Icons.grain,
  'thunder': Icons.thunderstorm,
  'snow': Icons.ac_unit,
  'fog': Icons.foggy,
  'wind': Icons.air,
  'night': Icons.nightlight_round,
  'hot': Icons.local_fire_department,
  'cold': Icons.severe_cold,
  'water': Icons.water_drop,
  'battery': Icons.battery_full,
  'up': Icons.arrow_upward,
  'down': Icons.arrow_downward,
  'ok': Icons.check_circle,
  'warning': Icons.warning_amber,
  'help': Icons.help_outline,
  'power': Icons.power_settings_new,
  'bulb': Icons.lightbulb,
  'bulb_off': Icons.lightbulb_outline,
  'lock': Icons.lock_outline,
  'unlock': Icons.lock_open,
  'plug': Icons.electrical_services,
  'fan': Icons.mode_fan_off,
  // Useful mainly on an "open" button, where the glyph says where the tap
  // goes rather than what it switches.
  'search': Icons.search,
  'open': Icons.open_in_new,
  'send': Icons.send,
  'globe': Icons.public,
  'phone': Icons.call,
  'map': Icons.map_outlined,
  'mail': Icons.mail_outline,
  'shop': Icons.shopping_bag_outlined,
  'play': Icons.play_circle_outline,
};
