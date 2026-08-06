import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'locale_controller.dart';
import 'note_editor_screen.dart';
import 'panel_blocks_controller.dart';

/// What holding a note block on the panel opens: its name, a way into the
/// note itself, and the delete button - the same shape the other blocks'
/// settings have.
class NoteBlockSettingsScreen extends StatefulWidget {
  const NoteBlockSettingsScreen({super.key, required this.blockId});

  final String blockId;

  @override
  State<NoteBlockSettingsScreen> createState() =>
      _NoteBlockSettingsScreenState();
}

class _NoteBlockSettingsScreenState extends State<NoteBlockSettingsScreen> {
  late final TextEditingController _name = TextEditingController(
    text: PanelBlocksController.instance.byId(widget.blockId)?.title ?? '',
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LocaleController.instance,
      builder: (context, language, child) {
        final s = AppStrings(language);
        final block = PanelBlocksController.instance.byId(widget.blockId);
        // Deleted from this very screen.
        if (block == null) return const Scaffold();

        return Scaffold(
          appBar: AppBar(
            title: Text(s.blockNotes),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: s.deleteBlock,
                onPressed: () async {
                  await PanelBlocksController.instance.remove(widget.blockId);
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: _name,
                decoration: InputDecoration(labelText: s.noteName),
                onChanged: (value) => PanelBlocksController.instance.update(
                  block.copyWith(title: value),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.edit_note),
                label: Text(s.openNote),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        NoteEditorScreen(blockId: widget.blockId),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
