import 'package:flutter/material.dart';
import 'package:installed_apps/installed_apps.dart';

import 'app_icon.dart';
import 'app_strings.dart';
import 'builtin_entries.dart';
import 'calendar_block_view.dart';
import 'code_block_view.dart';
import 'folder_sheet.dart';
import 'launcher_entries_controller.dart';
import 'launcher_entry.dart';
import 'notes_block_view.dart';
import 'panel_blocks_controller.dart';
import 'widget_card_view.dart';

/// One block on the pull-down panel. Rendering only - holding, moving and
/// editing are handled by the list around it.
class PanelBlockCard extends StatelessWidget {
  const PanelBlockCard({super.key, required this.block, required this.s});

  final PanelBlock block;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    // A code widget paints its own page edge to edge, so it gets the card
    // without the usual padding - and none of the card at all when it was
    // set to draw its own background.
    if (block.type == PanelBlockType.code) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ColoredBox(
            color: block.transparentBackground
                ? Colors.transparent
                : Colors.white.withValues(alpha: 0.6),
            child: CodeBlockView(block: block, s: s),
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: Colors.white.withValues(alpha: 0.6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: switch (block.type) {
          PanelBlockType.appRow => _AppRow(block: block, s: s),
          PanelBlockType.widget => WidgetCardView(block: block, s: s),
          PanelBlockType.calendar => CalendarBlockView(block: block, s: s),
          PanelBlockType.notes => NotesBlockView(block: block, s: s),
          // Handled above, before the card is built.
          PanelBlockType.code => const SizedBox.shrink(),
        },
      ),
    );
  }
}

class _AppRow extends StatelessWidget {
  const _AppRow({required this.block, required this.s});

  final PanelBlock block;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LauncherEntriesController.instance,
      builder: (context, child) {
        final entries = LauncherEntriesController.instance.resolve(
          block.itemKeys,
        );
        if (entries.isEmpty) {
          return SizedBox(
            height: 56,
            child: Center(
              child: Text(
                s.emptyAppRow,
                style: const TextStyle(color: Colors.black54),
              ),
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            // Fixed number per line rather than "as many as fit", so the row
            // looks the same whatever is in it.
            final itemWidth = constraints.maxWidth / block.columns;
            return Wrap(
              runSpacing: 12,
              children: [
                for (final entry in entries)
                  SizedBox(
                    width: itemWidth,
                    child: _AppRowItem(
                      entry: entry,
                      showLabel: block.showLabels,
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _AppRowItem extends StatelessWidget {
  const _AppRowItem({required this.entry, required this.showLabel});

  final LauncherEntry entry;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (entry.isFolder) {
          showFolderSheet(context, entry.folder!);
        } else if (entry.isBuiltIn) {
          openBuiltIn(context, entry.builtIn!);
        } else if (entry.isWebApp) {
          entry.launch();
        } else {
          InstalledApps.startApp(entry.app!.packageName);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(entry: entry, size: 44),
          if (showLabel) ...[
            const SizedBox(height: 6),
            Text(
              entry.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Colors.black87),
            ),
          ],
        ],
      ),
    );
  }
}

