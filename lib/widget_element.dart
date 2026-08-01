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
}

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
  });

  final String id;
  final WidgetElementType type;

  /// Text: the line itself. Icon: the value that gets matched against the
  /// rules. Image: the picture's URL. All three may hold placeholders.
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
  );

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
};
