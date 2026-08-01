import 'package:flutter/material.dart';

import 'app_icon.dart';
import 'app_strings.dart';
import 'launcher_entries_controller.dart';
import 'locale_controller.dart';
import 'panel_blocks_controller.dart';

/// Settings for one app row on the pull-down panel: which entries it holds,
/// how many fit per line, and whether their names are shown.
class AppRowSettingsScreen extends StatelessWidget {
  const AppRowSettingsScreen({super.key, required this.blockId});

  final String blockId;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LocaleController.instance,
      builder: (context, language, child) {
        final s = AppStrings(language);
        return ValueListenableBuilder<List<PanelBlock>>(
          valueListenable: PanelBlocksController.instance,
          builder: (context, blocks, child) {
            final block = PanelBlocksController.instance.byId(blockId);
            // Deleted from this very screen.
            if (block == null) return const Scaffold();

            return Scaffold(
              appBar: AppBar(
                title: Text(s.blockAppRowTitle),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: s.deleteBlock,
                    onPressed: () async {
                      await PanelBlocksController.instance.remove(blockId);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
              body: ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      s.columnsLabel,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        for (var count = 3; count <= 6; count++)
                          ChoiceChip(
                            label: Text('$count'),
                            selected: block.columns == count,
                            onSelected: (_) => PanelBlocksController.instance
                                .update(block.copyWith(columns: count)),
                          ),
                      ],
                    ),
                  ),
                  SwitchListTile(
                    title: Text(s.showLabelsLabel),
                    value: block.showLabels,
                    onChanged: (value) => PanelBlocksController.instance
                        .update(block.copyWith(showLabels: value)),
                  ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text(
                      s.chooseApps,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  _Picker(block: block),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _Picker extends StatelessWidget {
  const _Picker({required this.block});

  final PanelBlock block;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LauncherEntriesController.instance,
      builder: (context, child) {
        if (!LauncherEntriesController.instance.isLoaded) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        // Folders and web apps first: there are only a handful of them and
        // they'd be tedious to find among hundreds of packages otherwise.
        final all = LauncherEntriesController.instance.entries;
        final entries = [
          for (final entry in all)
            if (entry.isFolder) entry,
          for (final entry in all)
            if (entry.isWebApp) entry,
          for (final entry in all)
            if (!entry.isFolder && !entry.isWebApp) entry,
        ];

        return Column(
          children: [
            for (final entry in entries)
              CheckboxListTile(
                value: block.itemKeys.contains(entry.key),
                secondary: AppIcon(entry: entry, size: 36),
                title: Text(entry.name),
                onChanged: (_) {
                  final keys = List<String>.from(block.itemKeys);
                  // Newly ticked entries go to the end, so the row's order
                  // follows the order they were picked in.
                  if (!keys.remove(entry.key)) keys.add(entry.key);
                  PanelBlocksController.instance.update(
                    block.copyWith(itemKeys: keys),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}
