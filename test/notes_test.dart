import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanneslauncher/app_strings.dart';
import 'package:hanneslauncher/locale_controller.dart';
import 'package:hanneslauncher/note_document.dart';
import 'package:hanneslauncher/note_editor_screen.dart';
import 'package:hanneslauncher/note_text_controller.dart';
import 'package:hanneslauncher/panel_blocks_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Builds a paragraph whose every character carries [format].
NoteParagraph paragraphOf(String text, [NoteInlineFormat? format]) {
  return NoteParagraph(
    text: text,
    formats: List.filled(text.length, format ?? NoteInlineFormat.plain),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('a note line on disk', () {
    test('keeps its text, its formats and how the line is drawn', () {
      final paragraph = NoteParagraph(
        text: 'Milch',
        formats: [
          const NoteInlineFormat(bold: true),
          const NoteInlineFormat(bold: true),
          const NoteInlineFormat(),
          const NoteInlineFormat(highlightColorIndex: 4, italic: true),
          const NoteInlineFormat(highlightColorIndex: 4, italic: true),
        ],
        style: NoteBlockStyle.heading,
        list: NoteListKind.checklist,
        checked: true,
        align: NoteAlign.center,
      );

      final restored = NoteParagraph.fromJson(paragraph.toJson());

      expect(restored.text, 'Milch');
      expect(restored.formats.length, 5);
      expect(restored.formats[0].bold, true);
      expect(restored.formats[2].isPlain, true);
      expect(restored.formats[4].highlightColorIndex, 4);
      expect(restored.formats[4].italic, true);
      expect(restored.style, NoteBlockStyle.heading);
      expect(restored.list, NoteListKind.checklist);
      expect(restored.checked, true);
      expect(restored.align, NoteAlign.center);
    });

    test('stores stretches of one format once, not once per character', () {
      final json = paragraphOf(
        'aaaaaaaaaa',
        const NoteInlineFormat(bold: true),
      ).toJson();

      expect((json['runs'] as List).length, 1);
      expect((json['runs'] as List).single['n'], 10);
    });

    test('a format list that does not match the text is made to fit', () {
      // Hand-edited or written by an older version: too few entries.
      final restored = NoteParagraph.fromJson({
        'text': 'abc',
        'runs': [
          {'n': 1, 'f': {'b': true}},
        ],
      });

      expect(restored.formats.length, 3);
      expect(restored.formats[0].bold, true);
      expect(restored.formats[2].isPlain, true);
    });
  });

  group('typing in a formatted line', () {
    test('text typed inside a bold word stays bold', () {
      final controller = NoteTextController(
        paragraph: paragraphOf('Milch', const NoteInlineFormat(bold: true)),
      );

      controller.value = const TextEditingValue(
        text: 'Milxch',
        selection: TextSelection.collapsed(offset: 4),
      );

      expect(controller.formats.length, 6);
      expect(controller.formats.every((format) => format.bold), true);
    });

    test('deleting keeps every other character on its own format', () {
      final controller = NoteTextController(
        paragraph: NoteParagraph(
          text: 'abc',
          formats: const [
            NoteInlineFormat(bold: true),
            NoteInlineFormat(italic: true),
            NoteInlineFormat(underline: true),
          ],
        ),
      );

      // Middle character removed.
      controller.value = const TextEditingValue(
        text: 'ac',
        selection: TextSelection.collapsed(offset: 1),
      );

      expect(controller.formats.length, 2);
      expect(controller.formats[0].bold, true);
      expect(controller.formats[1].underline, true);
    });

    test('a format button with nothing selected takes the whole line', () {
      final controller = NoteTextController(paragraph: paragraphOf('abc'));
      controller.selection = const TextSelection.collapsed(offset: 1);

      controller.applyFormat(
        controller.selection.start,
        controller.selection.end,
        (format) => format.copyWith(bold: true),
      );

      expect(controller.formats.every((format) => format.bold), true);
    });

    test('a selection is formatted, the rest of the line is not', () {
      final controller = NoteTextController(paragraph: paragraphOf('abcdef'));

      controller.applyFormat(
        2,
        4,
        (format) => format.copyWith(strikethrough: true),
      );

      expect(
        [for (final format in controller.formats) format.strikethrough],
        [false, false, true, true, false, false],
      );
    });

    test('Enter splits the line and both halves keep their formats', () {
      final controller = NoteTextController(
        paragraph: NoteParagraph(
          text: 'ab\ncd',
          formats: const [
            NoteInlineFormat(bold: true),
            NoteInlineFormat(bold: true),
            NoteInlineFormat(),
            NoteInlineFormat(italic: true),
            NoteInlineFormat(italic: true),
          ],
          style: NoteBlockStyle.heading,
          list: NoteListKind.bullet,
        ),
      );

      final head = controller
          .splitAt(
            2,
            style: NoteBlockStyle.heading,
            list: NoteListKind.bullet,
            align: NoteAlign.left,
          )
          .head;
      final tail = controller
          .splitAt(
            3,
            style: NoteBlockStyle.heading,
            list: NoteListKind.bullet,
            align: NoteAlign.left,
          )
          .tail;

      expect(head.text, 'ab');
      expect(head.formats.every((format) => format.bold), true);
      // The line break itself does not start the new line.
      expect(tail.text, 'cd');
      expect(tail.formats.every((format) => format.italic), true);
      // A new line under a bullet is a bullet too.
      expect(tail.list, NoteListKind.bullet);
      expect(tail.checked, false);
    });

    test('backspacing a line break pulls the next line up formatted', () {
      final controller = NoteTextController(
        paragraph: paragraphOf('ab', const NoteInlineFormat(bold: true)),
      );

      controller.append(
        paragraphOf('cd', const NoteInlineFormat(underline: true)),
      );

      expect(controller.text, 'abcd');
      expect(
        [for (final format in controller.formats) format.bold],
        [true, true, false, false],
      );
      expect(
        [for (final format in controller.formats) format.underline],
        [false, false, true, true],
      );
    });
  });

  testWidgets('writing, a line break and the format panel', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final blocks = PanelBlocksController.instance;
    blocks.value = const [];
    blocks.debugResetLoadedForTest();
    final block = await blocks.addNotes('Test');

    await tester.pumpWidget(
      MaterialApp(home: NoteEditorScreen(blockId: block.id)),
    );

    // A line break turns into a second line of its own.
    await tester.enterText(find.byType(TextField).first, 'eins\nzwei');
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(2));

    // The panel opens on the button below the note.
    await tester.tap(find.byIcon(Icons.text_format));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.format_bold), findsOneWidget);

    // Neither the button nor the panel may take the focus off the note: an
    // unfocused field stops showing the selection the buttons work on.
    final second = tester.widget<TextField>(find.byType(TextField).last);
    expect(second.focusNode!.hasFocus, isTrue);

    // Bold with nothing selected takes the line the cursor is in.
    await tester.tap(find.byIcon(Icons.format_bold));
    await tester.pumpAndSettle();
    expect(second.focusNode!.hasFocus, isTrue);

    // And a selection stays exactly as it was, both times.
    second.controller!.selection = const TextSelection(
      baseOffset: 0,
      extentOffset: 2,
    );
    await tester.pump();
    await tester.tap(find.byIcon(Icons.format_italic));
    await tester.pumpAndSettle();
    expect(
      second.controller!.selection,
      const TextSelection(baseOffset: 0, extentOffset: 2),
    );
    expect(second.focusNode!.hasFocus, isTrue);
    // Only the selected half is italic.
    final controller = second.controller! as NoteTextController;
    expect(
      [for (final format in controller.formats) format.italic],
      [true, true, false, false],
    );

    // What counts is what the field actually paints, not just what the
    // controller stores.
    final painted =
        tester
                .state<EditableTextState>(find.byType(EditableText).last)
                .renderEditable
                .text!
            as TextSpan;
    expect(
      [
        for (final span in painted.children!.cast<TextSpan>())
          '${span.text}:${span.style?.fontWeight}:${span.style?.fontStyle}',
      ],
      // Bold over the whole line, italic only over what was selected.
      ['zw:${FontWeight.w700}:${FontStyle.italic}', 'ei:${FontWeight.w700}:null'],
    );

    // A dropdown asks for the focus itself, and the colour picker is a route
    // of its own - both used to leave the note unfocused, which stops it
    // painting the selection.
    final s = AppStrings(LocaleController.instance.value);
    await tester.tap(find.byType(DropdownButton<double?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('24').last);
    await tester.pumpAndSettle();
    expect(second.focusNode!.hasFocus, isTrue);
    expect(
      second.controller!.selection,
      const TextSelection(baseOffset: 0, extentOffset: 2),
    );
    expect(controller.formats.first.fontSize, 24);
    expect(controller.formats.last.fontSize, isNull);

    await tester.tap(find.byIcon(Icons.format_color_text));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.cancel));
    await tester.pumpAndSettle();
    expect(second.focusNode!.hasFocus, isTrue);

    // And a checklist is one tap.
    await tester.tap(find.byIcon(Icons.checklist));
    await tester.pumpAndSettle();
    expect(find.byType(Checkbox), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    // Everything above is written through to the block itself.
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pumpAndSettle();
    final stored = blocks.byId(block.id)!.notes;
    expect([for (final line in stored) line.text], ['eins', 'zwei']);
    expect(stored.last.formats.every((format) => format.bold), true);
    expect(stored.last.list, NoteListKind.checklist);
    expect(stored.last.checked, true);
  });

  test('a note block survives a restart with its lines', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = PanelBlocksController.instance;
    controller.value = const [];
    controller.debugResetLoadedForTest();

    final block = await controller.addNotes('Einkauf');
    await controller.update(
      block.copyWith(
        notes: [
          paragraphOf('Einkauf'),
          NoteParagraph(
            text: 'Milch',
            formats: List.filled(5, const NoteInlineFormat(bold: true)),
            list: NoteListKind.checklist,
            checked: true,
          ),
        ],
      ),
    );

    controller.value = const [];
    controller.debugResetLoadedForTest();
    await controller.load();

    final loaded = controller.value.single;
    expect(loaded.type, PanelBlockType.notes);
    expect(loaded.title, 'Einkauf');
    expect(loaded.notes.length, 2);
    expect(loaded.notes[1].text, 'Milch');
    expect(loaded.notes[1].formats.first.bold, true);
    expect(loaded.notes[1].list, NoteListKind.checklist);
    expect(loaded.notes[1].checked, true);
  });
}
