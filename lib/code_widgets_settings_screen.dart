import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'code_widget_editor_screen.dart';
import 'locale_controller.dart';
import 'panel_blocks_controller.dart';

/// Every code widget in one list, so they can be written from the settings
/// rather than only by finding the right card on the panel and holding it.
class CodeWidgetsSettingsScreen extends StatelessWidget {
  const CodeWidgetsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LocaleController.instance,
      builder: (context, language, child) {
        final s = AppStrings(language);
        return ValueListenableBuilder<List<PanelBlock>>(
          valueListenable: PanelBlocksController.instance,
          builder: (context, blocks, child) {
            final widgets = [
              for (final block in blocks)
                if (block.type == PanelBlockType.code) block,
            ];
            return Scaffold(
              appBar: AppBar(title: Text(s.codeWidgets)),
              floatingActionButton: FloatingActionButton.extended(
                onPressed: () => _create(context, s),
                icon: const Icon(Icons.add),
                label: Text(s.addCodeWidget),
              ),
              body: widgets.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        s.noCodeWidgets,
                        style: const TextStyle(color: Colors.black54),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 88),
                      itemCount: widgets.length,
                      itemBuilder: (context, index) {
                        final block = widgets[index];
                        return ListTile(
                          leading: const Icon(Icons.code),
                          title: Text(
                            block.title.isEmpty ? s.blockCode : block.title,
                          ),
                          subtitle: Text(
                            block.cardHeightFlexible
                                ? '${s.cardHeightFlexible}, '
                                      '${block.cardHeight.round()}-'
                                      '${block.cardMaxHeight.round()}'
                                : '${s.cardHeightFixed}, '
                                      '${block.cardHeight.round()}',
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  CodeWidgetEditorScreen(blockId: block.id),
                            ),
                          ),
                        );
                      },
                    ),
            );
          },
        );
      },
    );
  }

  Future<void> _create(BuildContext context, AppStrings s) async {
    final block = await createCodeWidget(context, s);
    if (block == null || !context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CodeWidgetEditorScreen(blockId: block.id),
      ),
    );
  }
}
