import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_strings.dart';
import 'locale_controller.dart';
import 'note_document.dart';
import 'note_format_panel.dart';
import 'note_text_controller.dart';
import 'panel_blocks_controller.dart';

/// The window a note block opens: the note itself, and below it the button
/// that opens the format panel.
///
/// Every line of the note is its own text field. That's what makes a line
/// able to carry its own bullet, checkbox, alignment and heading size - one
/// single field can only ever be aligned and decorated as a whole.
class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({super.key, required this.blockId});

  final String blockId;

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  final List<_NoteLine> _lines = [];

  /// The line the cursor was last in - what the format panel acts on.
  _NoteLine? _active;

  bool _formatOpen = false;
  String _title = '';
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    final block = PanelBlocksController.instance.byId(widget.blockId);
    _title = block?.title ?? '';
    final stored = block?.notes ?? const <NoteParagraph>[];
    for (final paragraph in stored) {
      _lines.add(_lineFor(paragraph));
    }
    // A note is never empty of lines: there has to be something to type in.
    if (_lines.isEmpty) _lines.add(_lineFor(const NoteParagraph()));
    _active = _lines.first;
  }

  _NoteLine _lineFor(NoteParagraph paragraph) {
    final line = _NoteLine(paragraph);
    line.controller.addListener(() => _onLineTouched(line));
    return line;
  }

  /// Keeps track of where the cursor is, and - while the format panel is
  /// open - keeps its toggles showing the format under it.
  void _onLineTouched(_NoteLine line) {
    _active = line;
    if (!_formatOpen) return;
    // The notification can arrive while the tree is still locked for the
    // current frame, so the rebuild waits for it to finish.
    Future.microtask(() {
      if (mounted && _formatOpen) setState(() {});
    });
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    // Read the lines out before tearing their controllers down, and hold on
    // to the id: neither is reachable once this screen is gone.
    final blockId = widget.blockId;
    final paragraphs = [for (final line in _lines) line.toParagraph()];
    // Saving tells the panel its blocks changed, and it rebuilds on the
    // spot - which it may not do while the framework is busy taking this
    // screen down. A microtask runs right after that work is finished.
    Future.microtask(() => _persist(blockId, paragraphs));
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    // Notes are written on every keystroke; a short delay keeps that from
    // being one preferences write per letter.
    _saveTimer = Timer(const Duration(milliseconds: 600), () {
      unawaited(
        _persist(widget.blockId, [
          for (final line in _lines) line.toParagraph(),
        ]),
      );
    });
  }

  static Future<void> _persist(
    String blockId,
    List<NoteParagraph> paragraphs,
  ) async {
    final block = PanelBlocksController.instance.byId(blockId);
    if (block == null) return;
    await PanelBlocksController.instance.update(
      block.copyWith(notes: paragraphs),
    );
  }

  // -- editing ------------------------------------------------------------

  void _onChanged(_NoteLine line) {
    final newlineAt = line.controller.text.indexOf('\n');
    if (newlineAt < 0) {
      _scheduleSave();
      return;
    }
    // Enter on a line that carries a checkbox, a bullet or a heading but no
    // text ends that run instead of starting yet another one of it. Without
    // this the first checkbox would drag itself down the rest of the note,
    // with no way back to plain text between two lists.
    if (line.controller.text.replaceAll('\n', '').isEmpty && line.isDecorated) {
      setState(() {
        line.list = NoteListKind.none;
        line.checked = false;
        line.style = NoteBlockStyle.text;
        line.controller.value = const TextEditingValue(
          text: '',
          selection: TextSelection.collapsed(offset: 0),
        );
      });
      _scheduleSave();
      return;
    }
    _splitLine(line, newlineAt);
  }

  /// Enter (or a pasted line break) ends the line at [cutOffset] and moves
  /// the rest into a new one below it.
  ///
  /// The new line continues a list - that's what makes writing one bearable -
  /// but never a heading: what follows a title is text, not another title.
  void _splitLine(_NoteLine line, int cutOffset) {
    final index = _lines.indexOf(line);
    if (index < 0) return;
    final nextStyle = switch (line.style) {
      NoteBlockStyle.title || NoteBlockStyle.heading => NoteBlockStyle.text,
      NoteBlockStyle.text || NoteBlockStyle.note => line.style,
    };
    final head = line.controller
        .splitAt(
          cutOffset,
          style: line.style,
          list: line.list,
          align: line.align,
        )
        .head;
    // One past the cut, so the line break itself is dropped rather than
    // starting the new line with it.
    final tail = line.controller
        .splitAt(
          cutOffset + 1,
          style: nextStyle,
          list: line.list,
          align: line.align,
        )
        .tail;

    final next = _lineFor(tail);
    setState(() {
      line.controller.value = TextEditingValue(
        text: head.text,
        selection: TextSelection.collapsed(offset: head.text.length),
      );
      _lines.insert(index + 1, next);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      next.controller.selection = const TextSelection.collapsed(offset: 0);
      next.focus.requestFocus();
      // A pasted block of text arrives as one change; keep splitting until
      // every line break has become a line.
      final more = next.controller.text.indexOf('\n');
      if (more >= 0) _splitLine(next, more);
    });
    _scheduleSave();
  }

  /// Backspace at the very start of a line pulls it into the one above,
  /// which is the only way to get rid of a line break again.
  KeyEventResult _onKey(_NoteLine line, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey != LogicalKeyboardKey.backspace) {
      return KeyEventResult.ignored;
    }
    final selection = line.controller.selection;
    if (!selection.isCollapsed || selection.baseOffset != 0) {
      return KeyEventResult.ignored;
    }
    // A checkbox, bullet or heading goes first, the line break only after
    // it: the same way back to plain text that Enter on an empty line gives,
    // and the reason a checklist can be interrupted at all.
    if (line.isDecorated) {
      setState(() {
        line.list = NoteListKind.none;
        line.checked = false;
        line.style = NoteBlockStyle.text;
      });
      _scheduleSave();
      return KeyEventResult.handled;
    }
    final index = _lines.indexOf(line);
    if (index <= 0) return KeyEventResult.ignored;
    _mergeIntoPrevious(index);
    return KeyEventResult.handled;
  }

  void _mergeIntoPrevious(int index) {
    final line = _lines[index];
    final previous = _lines[index - 1];
    final caret = previous.controller.text.length;
    previous.controller.append(line.toParagraph());
    setState(() => _lines.removeAt(index));
    _active = previous;
    previous.focus.requestFocus();
    previous.controller.selection = TextSelection.collapsed(offset: caret);
    // The removed line's field is still on screen until this frame is done.
    WidgetsBinding.instance.addPostFrameCallback((_) => line.dispose());
    _scheduleSave();
  }

  void _deleteActiveLine() {
    final line = _active;
    if (line == null || _lines.length < 2) return;
    final index = _lines.indexOf(line);
    if (index < 0) return;
    if (index > 0) {
      _mergeIntoPrevious(index);
      return;
    }
    setState(() => _lines.removeAt(index));
    _active = _lines.first;
    _lines.first.focus.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) => line.dispose());
    _scheduleSave();
  }

  // -- formatting ---------------------------------------------------------

  void _applyInline(NoteInlineFormat Function(NoteInlineFormat) transform) {
    final line = _active;
    if (line == null) return;
    final selection = line.controller.selection;
    // start == end (nothing selected) is taken as "this whole line" by
    // applyFormat, so a format button is never a no-op.
    line.controller.applyFormat(selection.start, selection.end, transform);
    _keepShowingSelection(line, selection);
    setState(() {});
    _scheduleSave();
  }

  void _applyLine(void Function(_NoteLine line) change) {
    final line = _active;
    if (line == null) return;
    final selection = line.controller.selection;
    setState(() => change(line));
    _keepShowingSelection(line, selection);
    _scheduleSave();
  }

  /// A text field only paints its selection while it has the focus, so
  /// anything in the panel that takes the focus away (a dropdown asks for it
  /// outright, the colour picker is a route of its own) would leave the user
  /// formatting something they can no longer see. The selection itself is
  /// never lost - only the field showing it - so handing the focus back is
  /// enough.
  void _keepShowingSelection(_NoteLine line, TextSelection selection) {
    if (!line.focus.hasFocus) {
      line.focus.requestFocus();
      _hideKeyboard();
    }
    if (line.controller.selection != selection) {
      line.controller.selection = selection;
    }
  }

  void _openFormatPanel() {
    setState(() => _formatOpen = true);
    // The field keeps the focus - and with it the visible selection - while
    // the keyboard steps aside to make room for the panel.
    _hideKeyboard();
  }

  void _hideKeyboard() {
    // After the frame: a field that has just been focused opens the keyboard
    // when the next frame attaches its input connection, which would undo an
    // immediate hide.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChannels.textInput.invokeMethod('TextInput.hide');
    });
  }

  // -- building -----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LocaleController.instance,
      builder: (context, language, child) {
        final s = AppStrings(language);
        return Scaffold(
          appBar: AppBar(title: Text(_title.isEmpty ? s.blockNotes : _title)),
          body: Column(
            children: [
              Expanded(
                child: GestureDetector(
                  // Tapping the empty space below the note continues writing
                  // at its end instead of doing nothing.
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    final last = _lines.last;
                    _active = last;
                    last.focus.requestFocus();
                    last.controller.selection = TextSelection.collapsed(
                      offset: last.controller.text.length,
                    );
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: _lines.length,
                    itemBuilder: (context, index) => _buildLine(index, s),
                  ),
                ),
              ),
              // Both the button and the panel have to keep their hands off
              // the focus: a text field drops it as soon as something
              // outside it is tapped, and a field without focus stops
              // painting the very selection these buttons act on.
              // TextFieldTapRegion says "this still belongs to the field",
              // ExcludeFocus keeps the buttons from taking it themselves.
              TextFieldTapRegion(
                child: ExcludeFocus(
                  child: _formatOpen
                      ? NoteFormatPanel(
                          s: s,
                          format:
                              _active?.controller.formatAt(
                                _active!.controller.selection,
                              ) ??
                              NoteInlineFormat.plain,
                          style: _active?.style ?? NoteBlockStyle.text,
                          list: _active?.list ?? NoteListKind.none,
                          align: _active?.align ?? NoteAlign.left,
                          onInline: _applyInline,
                          onStyle: (style) =>
                              _applyLine((line) => line.style = style),
                          onList: (list) => _applyLine((line) {
                            line.list = list;
                            if (list != NoteListKind.checklist) {
                              line.checked = false;
                            }
                          }),
                          onAlign: (align) =>
                              _applyLine((line) => line.align = align),
                          onDeleteLine: _deleteActiveLine,
                          onClose: () => setState(() => _formatOpen = false),
                        )
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                          child: Center(
                            child: FilledButton.tonalIcon(
                              icon: const Icon(Icons.text_format),
                              label: Text(s.formatLabel),
                              onPressed: _openFormatPanel,
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLine(int index, AppStrings s) {
    final line = _lines[index];
    final base = noteBaseStyle(line.style);
    return Padding(
      key: line.key,
      padding: EdgeInsets.only(
        top: line.style == NoteBlockStyle.title ? 8 : 2,
        bottom: 2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (line.list != NoteListKind.none) _buildLeading(line, index, base),
          Expanded(
            child: Focus(
              // Sits above the field so a backspace that the field itself
              // has nothing left to delete still reaches this screen.
              onKeyEvent: (node, event) => _onKey(line, event),
              child: TextField(
                controller: line.controller,
                focusNode: line.focus,
                maxLines: null,
                textAlign: noteTextAlign(line.align),
                style: base,
                cursorColor: Colors.black87,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  hintText: index == 0 && _lines.length == 1
                      ? s.noteHint
                      : null,
                ),
                onChanged: (_) => _onChanged(line),
                onTap: () => _active = line,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeading(_NoteLine line, int index, TextStyle base) {
    // Roughly where the first text line sits, so the marker lines up with it
    // instead of with the top of a wrapped paragraph.
    final top = (base.fontSize ?? 16) * 0.25;
    final marker = switch (line.list) {
      NoteListKind.bullet => Padding(
        padding: EdgeInsets.only(top: top, right: 8),
        child: Text('•', style: base),
      ),
      NoteListKind.numbered => Padding(
        padding: EdgeInsets.only(top: top, right: 8),
        child: Text('${_numberOf(index)}.', style: base),
      ),
      NoteListKind.checklist => Padding(
        padding: EdgeInsets.only(top: top * 0.2, right: 4),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Checkbox(
            value: line.checked,
            visualDensity: VisualDensity.compact,
            onChanged: (checked) {
              setState(() => line.checked = checked ?? false);
              _scheduleSave();
            },
          ),
        ),
      ),
      NoteListKind.none => const SizedBox.shrink(),
    };
    return marker;
  }

  /// A numbered line counts from the first one of its run, so a second list
  /// further down the note starts at 1 again.
  int _numberOf(int index) {
    var number = 1;
    for (var i = index - 1; i >= 0; i--) {
      if (_lines[i].list != NoteListKind.numbered) break;
      number++;
    }
    return number;
  }
}

/// One line of the note while it's being edited: its text (in a controller
/// that carries the formatting) plus the attributes of the line itself.
class _NoteLine {
  _NoteLine(NoteParagraph paragraph)
    : controller = NoteTextController(paragraph: paragraph),
      style = paragraph.style,
      list = paragraph.list,
      checked = paragraph.checked,
      align = paragraph.align;

  final NoteTextController controller;
  final FocusNode focus = FocusNode();

  /// Stable across inserts and removals, so Flutter keeps each line's field
  /// (and its cursor) with the line it belongs to.
  final Key key = UniqueKey();

  NoteBlockStyle style;
  NoteListKind list;
  bool checked;
  NoteAlign align;

  /// Whether the line carries anything on top of plain text - a list marker
  /// or a heading style. That's what an empty line drops first, before it
  /// starts merging into its neighbour.
  bool get isDecorated =>
      list != NoteListKind.none || style != NoteBlockStyle.text;

  NoteParagraph toParagraph() => controller.toParagraph(
    style: style,
    list: list,
    checked: checked,
    align: align,
  );

  void dispose() {
    controller.dispose();
    focus.dispose();
  }
}
