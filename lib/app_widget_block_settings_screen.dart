import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'app_widgets.dart';
import 'design_tokens.dart';
import 'locale_controller.dart';
import 'panel_blocks_controller.dart';

/// Settings for an app widget block. The width is always the panel's, so
/// the height is the one size there is to set.
class AppWidgetBlockSettingsScreen extends StatelessWidget {
  const AppWidgetBlockSettingsScreen({super.key, required this.blockId});

  final String blockId;

  static const _minHeight = 48.0;
  static const _maxHeight = 640.0;

  Future<void> _resetHeight(PanelBlock block) async {
    final providers = await AppWidgets.providers();
    for (final provider in providers) {
      if (provider.provider != block.appWidgetProvider) continue;
      final current = PanelBlocksController.instance.byId(block.id);
      if (current == null) return;
      await PanelBlocksController.instance.update(
        current.copyWith(cardHeight: provider.height),
      );
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LocaleController.instance,
      builder: (context, language, child) {
        final s = AppStrings(language);
        final design = context.design;
        return ValueListenableBuilder<List<PanelBlock>>(
          valueListenable: PanelBlocksController.instance,
          builder: (context, blocks, child) {
            final block = PanelBlocksController.instance.byId(blockId);
            // Deleted from this very screen.
            if (block == null) return const SizedBox.shrink();
            final height = block.cardHeight.clamp(_minHeight, _maxHeight);
            return Scaffold(
              appBar: AppBar(
                title: Text(
                  block.title.isEmpty ? s.blockAppWidget : block.title,
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: s.deleteBlock,
                    onPressed: () async {
                      await PanelBlocksController.instance.remove(block.id);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    s.appWidgetHint,
                    style: TextStyle(color: design.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${s.appWidgetHeight} (${height.round()})',
                    style: TextStyle(
                      fontSize: design.typeLabel,
                      fontWeight: FontWeight.bold,
                      color: design.textSecondary,
                    ),
                  ),
                  Slider(
                    value: height,
                    min: _minHeight,
                    max: _maxHeight,
                    divisions: ((_maxHeight - _minHeight) / 8).round(),
                    onChanged: (value) => PanelBlocksController.instance
                        .update(block.copyWith(cardHeight: value)),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _resetHeight(block),
                      icon: const Icon(Icons.restart_alt),
                      label: Text(s.appWidgetResetHeight),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(s.appWidgetScroll),
                    subtitle: Text(s.appWidgetScrollHint),
                    value: block.appWidgetScroll,
                    onChanged: (value) => PanelBlocksController.instance
                        .update(block.copyWith(appWidgetScroll: value)),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(s.appWidgetOnCard),
                    subtitle: Text(s.appWidgetOnCardHint),
                    value: !block.transparentBackground,
                    onChanged: (value) => PanelBlocksController.instance
                        .update(block.copyWith(transparentBackground: !value)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
