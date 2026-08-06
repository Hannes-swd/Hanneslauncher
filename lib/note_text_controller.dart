import 'package:flutter/material.dart';

import 'note_document.dart';

/// A text controller that carries one [NoteInlineFormat] per character and
/// paints the field with it.
///
/// Formats are kept per character rather than as ranges on purpose: every
/// edit would otherwise have to shift, split and merge those ranges, which
/// is where this kind of editor usually starts losing formatting. Here an
/// edit is a splice of the same length into a plain list.
class NoteTextController extends TextEditingController {
  NoteTextController({required NoteParagraph paragraph})
    : _formats = fittedFormats(paragraph.text, paragraph.formats),
      super(text: paragraph.text);

  final List<NoteInlineFormat> _formats;

  List<NoteInlineFormat> get formats => List.unmodifiable(_formats);

  @override
  set value(TextEditingValue newValue) {
    _syncFormats(value.text, newValue.text);
    super.value = newValue;
  }

  /// Rewrites the format list to match an edit, without being told what the
  /// edit was: the unchanged head and tail are found by comparison, and only
  /// what sits between them is replaced. Newly typed characters take on the
  /// format of the character in front of them, which is what makes typing
  /// inside a bold word stay bold.
  void _syncFormats(String oldText, String newText) {
    if (oldText == newText) return;
    if (_formats.length != oldText.length) {
      // Something set the text behind our back (e.g. `text = ...`); start
      // from a matching list rather than splicing against a stale one.
      _resetTo(oldText);
    }

    var prefix = 0;
    final maxPrefix = oldText.length < newText.length
        ? oldText.length
        : newText.length;
    while (prefix < maxPrefix &&
        oldText.codeUnitAt(prefix) == newText.codeUnitAt(prefix)) {
      prefix++;
    }
    var suffix = 0;
    final maxSuffix = maxPrefix - prefix;
    while (suffix < maxSuffix &&
        oldText.codeUnitAt(oldText.length - 1 - suffix) ==
            newText.codeUnitAt(newText.length - 1 - suffix)) {
      suffix++;
    }

    final removed = oldText.length - prefix - suffix;
    final inserted = newText.length - prefix - suffix;
    final inherited = prefix > 0
        ? _formats[prefix - 1]
        : (prefix < _formats.length ? _formats[prefix] : NoteInlineFormat.plain);
    if (removed > 0) _formats.removeRange(prefix, prefix + removed);
    if (inserted > 0) {
      _formats.insertAll(prefix, List.filled(inserted, inherited));
    }
    if (_formats.length != newText.length) _resetTo(newText);
  }

  void _resetTo(String text) {
    final fitted = fittedFormats(text, _formats);
    _formats
      ..clear()
      ..addAll(fitted);
  }

  /// Applies [transform] to every character in [start]..[end], or to the
  /// whole line when the two are the same - a format button with nothing
  /// selected means "this line", not "nothing".
  void applyFormat(
    int start,
    int end,
    NoteInlineFormat Function(NoteInlineFormat) transform,
  ) {
    var from = start;
    var to = end;
    if (from > to) {
      final swap = from;
      from = to;
      to = swap;
    }
    if (from == to) {
      from = 0;
      to = _formats.length;
    }
    from = from.clamp(0, _formats.length);
    to = to.clamp(0, _formats.length);
    if (from >= to) return;
    for (var i = from; i < to; i++) {
      _formats[i] = transform(_formats[i]);
    }
    notifyListeners();
  }

  /// Appends another line to this one, keeping its formats - the other half
  /// of [splitAt], used when a line is deleted into the one above it.
  void append(NoteParagraph other) {
    final start = text.length;
    value = TextEditingValue(
      text: text + other.text,
      selection: TextSelection.collapsed(offset: start),
    );
    // The splice above gave the appended characters the format of the one
    // they landed behind; they keep their own.
    final fitted = fittedFormats(other.text, other.formats);
    for (var i = 0; i < fitted.length; i++) {
      _formats[start + i] = fitted[i];
    }
    notifyListeners();
  }

  /// The format the format panel should show as "current": the one at the
  /// start of the selection, or of the character in front of the cursor.
  NoteInlineFormat formatAt(TextSelection selection) {
    if (_formats.isEmpty) return NoteInlineFormat.plain;
    final offset = selection.isValid
        ? (selection.isCollapsed
              ? selection.baseOffset - 1
              : (selection.start < selection.end
                    ? selection.start
                    : selection.end))
        : _formats.length - 1;
    return _formats[offset.clamp(0, _formats.length - 1)];
  }

  /// The line as it is right now, ready to be stored.
  NoteParagraph toParagraph({
    required NoteBlockStyle style,
    required NoteListKind list,
    required bool checked,
    required NoteAlign align,
  }) {
    return NoteParagraph(
      text: text,
      formats: formats,
      style: style,
      list: list,
      checked: checked,
      align: align,
    );
  }

  /// Splits at [offset] into what stays here and what moves to a new line -
  /// used when Enter is pressed in the middle of a line.
  ({NoteParagraph head, NoteParagraph tail}) splitAt(
    int offset, {
    required NoteBlockStyle style,
    required NoteListKind list,
    required NoteAlign align,
  }) {
    final cut = offset.clamp(0, text.length);
    return (
      head: NoteParagraph(
        text: text.substring(0, cut),
        formats: _formats.sublist(0, cut),
        style: style,
        list: list,
        align: align,
      ),
      tail: NoteParagraph(
        text: text.substring(cut),
        formats: _formats.sublist(cut),
        style: style,
        list: list,
        align: align,
      ),
    );
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (_formats.length != text.length) _resetTo(text);
    final base = style ?? const TextStyle();
    if (text.isEmpty) return TextSpan(style: base, text: '');

    final children = <TextSpan>[];
    var runStart = 0;
    for (var i = 1; i <= text.length; i++) {
      if (i == text.length || _formats[i] != _formats[runStart]) {
        children.add(
          TextSpan(
            text: text.substring(runStart, i),
            style: applyNoteFormat(base, _formats[runStart]),
          ),
        );
        runStart = i;
      }
    }
    return TextSpan(style: base, children: children);
  }
}
