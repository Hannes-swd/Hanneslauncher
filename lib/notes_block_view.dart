import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'note_document.dart';
import 'note_editor_screen.dart';
import 'panel_blocks_controller.dart';

/// A note as it looks on the panel: its name and the first few lines of what
/// it says, formatting and all. Tapping it opens the note itself.
class NotesBlockView extends StatelessWidget {
  const NotesBlockView({super.key, required this.block, required this.s});

  final PanelBlock block;
  final AppStrings s;

  /// How much of the note the card shows before it's just a wall of text.
  static const int _previewLines = 6;

  @override
  Widget build(BuildContext context) {
    final lines = block.notes;
    final hasText = lines.any((line) => line.text.trim().isNotEmpty);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => NoteEditorScreen(blockId: block.id),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.sticky_note_2_outlined,
                size: 18,
                color: Colors.black54,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  block.title.isEmpty ? s.blockNotes : block.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!hasText)
            Text(
              s.emptyNote,
              style: const TextStyle(color: Colors.black54),
            )
          else
            for (var i = 0; i < lines.length && i < _previewLines; i++)
              NoteParagraphView(
                paragraph: lines[i],
                number: _numberOf(lines, i),
              ),
          if (lines.length > _previewLines)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('…', style: TextStyle(color: Colors.black54)),
            ),
        ],
      ),
    );
  }

  static int _numberOf(List<NoteParagraph> lines, int index) {
    var number = 1;
    for (var i = index - 1; i >= 0; i--) {
      if (lines[i].list != NoteListKind.numbered) break;
      number++;
    }
    return number;
  }
}

/// One line of a note, read-only: its bullet, number or checkbox and the
/// text with everything the editor put on it.
class NoteParagraphView extends StatelessWidget {
  const NoteParagraphView({
    super.key,
    required this.paragraph,
    this.number = 1,
  });

  final NoteParagraph paragraph;

  /// Numbered lines only: the position this one is at in its run.
  final int number;

  @override
  Widget build(BuildContext context) {
    final base = noteBaseStyle(paragraph.style);
    return Padding(
      padding: EdgeInsets.only(
        top: paragraph.style == NoteBlockStyle.title ? 6 : 1,
        bottom: 1,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          switch (paragraph.list) {
            NoteListKind.bullet => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text('•', style: base),
            ),
            NoteListKind.numbered => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text('$number.', style: base),
            ),
            NoteListKind.checklist => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(
                paragraph.checked
                    ? Icons.check_box_outlined
                    : Icons.check_box_outline_blank,
                size: (base.fontSize ?? 16) + 2,
                color: Colors.black54,
              ),
            ),
            NoteListKind.none => const SizedBox.shrink(),
          },
          Expanded(
            child: Text.rich(
              noteParagraphSpan(paragraph),
              textAlign: noteTextAlign(paragraph.align),
            ),
          ),
        ],
      ),
    );
  }
}
