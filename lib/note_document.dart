import 'package:flutter/material.dart';

import 'app_list_settings_controller.dart' show appListColorPalette;

/// What a whole line of a note is - picked in the format panel's top row.
enum NoteBlockStyle { title, heading, text, note }

/// The bullet, number or checkbox a line is drawn with, if any.
enum NoteListKind { none, bullet, numbered, checklist }

enum NoteAlign { left, center, right }

/// The weights offered as "thickness". Stored as the numeric value, not an
/// index, so the list can grow later without changing what's on disk.
const List<int> noteFontWeights = [300, 400, 500, 700, 900];

/// Font sizes offered in the format panel. Stored as the size itself.
const List<double> noteFontSizes = [12, 14, 16, 18, 20, 24, 28, 32];

FontWeight noteWeightOf(int value) =>
    FontWeight.values[(value ~/ 100 - 1).clamp(0, 8)];

/// A palette entry, or null when the index is out of range - the palette
/// grows with the user's own colors, and a restored backup can name one that
/// isn't there (yet).
Color? noteColorAt(int? index) {
  if (index == null || index < 0) return null;
  final palette = appListColorPalette;
  return index < palette.length ? palette[index] : null;
}

/// How a stretch of characters inside a line looks. Every field is an
/// override: null (or false) means "whatever the line's style says".
@immutable
class NoteInlineFormat {
  const NoteInlineFormat({
    this.bold = false,
    this.italic = false,
    this.strikethrough = false,
    this.underline = false,
    this.underlineColorIndex,
    this.highlightColorIndex,
    this.colorIndex,
    this.fontFamily,
    this.fontSize,
    this.weight,
  });

  static const plain = NoteInlineFormat();

  final bool bold;
  final bool italic;
  final bool strikethrough;
  final bool underline;
  final int? underlineColorIndex;
  final int? highlightColorIndex;
  final int? colorIndex;
  final String? fontFamily;
  final double? fontSize;
  final int? weight;

  bool get isPlain => this == plain;

  /// Clearing a field needs its own flag: passing null to [copyWith] means
  /// "leave it alone", which is what almost every caller wants.
  NoteInlineFormat copyWith({
    bool? bold,
    bool? italic,
    bool? strikethrough,
    bool? underline,
    int? underlineColorIndex,
    int? highlightColorIndex,
    int? colorIndex,
    String? fontFamily,
    double? fontSize,
    int? weight,
    bool clearUnderlineColor = false,
    bool clearHighlight = false,
    bool clearColor = false,
    bool clearFontFamily = false,
    bool clearFontSize = false,
    bool clearWeight = false,
  }) {
    return NoteInlineFormat(
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      strikethrough: strikethrough ?? this.strikethrough,
      underline: underline ?? this.underline,
      underlineColorIndex: clearUnderlineColor
          ? null
          : (underlineColorIndex ?? this.underlineColorIndex),
      highlightColorIndex: clearHighlight
          ? null
          : (highlightColorIndex ?? this.highlightColorIndex),
      colorIndex: clearColor ? null : (colorIndex ?? this.colorIndex),
      fontFamily: clearFontFamily ? null : (fontFamily ?? this.fontFamily),
      fontSize: clearFontSize ? null : (fontSize ?? this.fontSize),
      weight: clearWeight ? null : (weight ?? this.weight),
    );
  }

  /// Only what differs from plain is written, so an unformatted note stays
  /// small on disk.
  Map<String, dynamic> toJson() => {
    if (bold) 'b': true,
    if (italic) 'i': true,
    if (strikethrough) 's': true,
    if (underline) 'u': true,
    if (underlineColorIndex != null) 'uc': underlineColorIndex,
    if (highlightColorIndex != null) 'hl': highlightColorIndex,
    if (colorIndex != null) 'c': colorIndex,
    if (fontFamily != null) 'ff': fontFamily,
    if (fontSize != null) 'fs': fontSize,
    if (weight != null) 'w': weight,
  };

  static NoteInlineFormat fromJson(Map<String, dynamic> json) {
    return NoteInlineFormat(
      bold: json['b'] as bool? ?? false,
      italic: json['i'] as bool? ?? false,
      strikethrough: json['s'] as bool? ?? false,
      underline: json['u'] as bool? ?? false,
      underlineColorIndex: json['uc'] as int?,
      highlightColorIndex: json['hl'] as int?,
      colorIndex: json['c'] as int?,
      fontFamily: json['ff'] as String?,
      fontSize: (json['fs'] as num?)?.toDouble(),
      weight: json['w'] as int?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NoteInlineFormat &&
      other.bold == bold &&
      other.italic == italic &&
      other.strikethrough == strikethrough &&
      other.underline == underline &&
      other.underlineColorIndex == underlineColorIndex &&
      other.highlightColorIndex == highlightColorIndex &&
      other.colorIndex == colorIndex &&
      other.fontFamily == fontFamily &&
      other.fontSize == fontSize &&
      other.weight == weight;

  @override
  int get hashCode => Object.hash(
    bold,
    italic,
    strikethrough,
    underline,
    underlineColorIndex,
    highlightColorIndex,
    colorIndex,
    fontFamily,
    fontSize,
    weight,
  );
}

/// One line of a note: its text, one [NoteInlineFormat] per character of it,
/// and how the line as a whole is drawn.
@immutable
class NoteParagraph {
  const NoteParagraph({
    this.text = '',
    this.formats = const [],
    this.style = NoteBlockStyle.text,
    this.list = NoteListKind.none,
    this.checked = false,
    this.align = NoteAlign.left,
  });

  final String text;

  /// One entry per UTF-16 code unit of [text] - the same unit the text
  /// field's selection offsets count in, so the two never drift apart.
  final List<NoteInlineFormat> formats;

  final NoteBlockStyle style;
  final NoteListKind list;

  /// Checklist lines only: whether the box is ticked.
  final bool checked;
  final NoteAlign align;

  /// Run-length encoded: notes are mostly long stretches of one format, and
  /// one JSON object per character would dwarf the text itself.
  Map<String, dynamic> toJson() {
    final runs = <Map<String, dynamic>>[];
    final fitted = fittedFormats(text, formats);
    for (var i = 0; i < fitted.length; i++) {
      if (runs.isNotEmpty && fitted[i] == fitted[i - 1]) {
        runs.last['n'] = (runs.last['n'] as int) + 1;
      } else {
        runs.add({'n': 1, 'f': fitted[i].toJson()});
      }
    }
    return {
      'text': text,
      'runs': runs,
      'style': style.name,
      'list': list.name,
      if (checked) 'checked': true,
      'align': align.name,
    };
  }

  static NoteParagraph fromJson(Map<String, dynamic> json) {
    final text = json['text'] as String? ?? '';
    final formats = <NoteInlineFormat>[];
    for (final run in (json['runs'] as List<dynamic>? ?? const [])) {
      final map = run as Map<String, dynamic>;
      final format = NoteInlineFormat.fromJson(
        map['f'] as Map<String, dynamic>? ?? const {},
      );
      for (var i = 0; i < (map['n'] as int? ?? 0); i++) {
        formats.add(format);
      }
    }
    return NoteParagraph(
      text: text,
      formats: fittedFormats(text, formats),
      style: _enumByName(NoteBlockStyle.values, json['style']) ??
          NoteBlockStyle.text,
      list: _enumByName(NoteListKind.values, json['list']) ?? NoteListKind.none,
      checked: json['checked'] as bool? ?? false,
      align: _enumByName(NoteAlign.values, json['align']) ?? NoteAlign.left,
    );
  }

  static T? _enumByName<T extends Enum>(List<T> values, Object? name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
  }
}

/// Pads or trims [formats] to exactly one entry per character of [text].
/// Anything hand-edited or written by an older version is made to line up
/// here rather than crashing the editor later.
List<NoteInlineFormat> fittedFormats(
  String text,
  List<NoteInlineFormat> formats,
) {
  if (formats.length == text.length) return List.of(formats);
  final fitted = List<NoteInlineFormat>.of(formats.take(text.length));
  while (fitted.length < text.length) {
    fitted.add(NoteInlineFormat.plain);
  }
  return fitted;
}

/// The look a line's [NoteBlockStyle] gives it before any inline format.
TextStyle noteBaseStyle(NoteBlockStyle style) => switch (style) {
  NoteBlockStyle.title => const TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: Colors.black87,
    height: 1.3,
  ),
  NoteBlockStyle.heading => const TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: Colors.black87,
    height: 1.3,
  ),
  NoteBlockStyle.text => const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: Colors.black87,
    height: 1.4,
  ),
  NoteBlockStyle.note => const TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    fontStyle: FontStyle.italic,
    color: Colors.black54,
    height: 1.4,
  ),
};

TextAlign noteTextAlign(NoteAlign align) => switch (align) {
  NoteAlign.left => TextAlign.left,
  NoteAlign.center => TextAlign.center,
  NoteAlign.right => TextAlign.right,
};

/// Lays one character's format over the line's base style.
TextStyle applyNoteFormat(TextStyle base, NoteInlineFormat format) {
  final decorations = <TextDecoration>[
    if (format.underline) TextDecoration.underline,
    if (format.strikethrough) TextDecoration.lineThrough,
  ];
  return base.copyWith(
    fontFamily: (format.fontFamily != null && format.fontFamily!.isNotEmpty)
        ? format.fontFamily
        : base.fontFamily,
    fontSize: format.fontSize ?? base.fontSize,
    // An explicit thickness wins over the bold toggle, which in turn wins
    // over whatever the line's style brings.
    fontWeight: format.weight != null
        ? noteWeightOf(format.weight!)
        : (format.bold ? FontWeight.w700 : base.fontWeight),
    fontStyle: format.italic ? FontStyle.italic : base.fontStyle,
    color: noteColorAt(format.colorIndex) ?? base.color,
    backgroundColor: noteColorAt(format.highlightColorIndex),
    decoration: decorations.isEmpty
        ? TextDecoration.none
        : TextDecoration.combine(decorations),
    // Only the underline can carry a color of its own; a strikethrough drawn
    // in a different color than the text reads as a mistake.
    decorationColor: format.underline
        ? (noteColorAt(format.underlineColorIndex) ??
              noteColorAt(format.colorIndex) ??
              base.color)
        : null,
    decorationThickness: format.underline ? 2 : null,
  );
}

/// Builds one line as a span, e.g. for the read-only preview on the panel.
TextSpan noteParagraphSpan(NoteParagraph paragraph, {TextStyle? base}) {
  final style = (base ?? const TextStyle()).merge(
    noteBaseStyle(paragraph.style),
  );
  final formats = fittedFormats(paragraph.text, paragraph.formats);
  final children = <TextSpan>[];
  var runStart = 0;
  for (var i = 1; i <= paragraph.text.length; i++) {
    if (i == paragraph.text.length || formats[i] != formats[runStart]) {
      children.add(
        TextSpan(
          text: paragraph.text.substring(runStart, i),
          style: applyNoteFormat(style, formats[runStart]),
        ),
      );
      runStart = i;
    }
  }
  return TextSpan(style: style, children: children);
}
