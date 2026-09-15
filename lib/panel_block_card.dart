import 'package:flutter/material.dart';
import 'package:installed_apps/installed_apps.dart';

import 'app_icon.dart';
import 'app_strings.dart';
import 'builtin_entries.dart';
import 'calendar_block_view.dart';
import 'code_block_view.dart';
import 'design_tokens.dart';
import 'folder_sheet.dart';
import 'launcher_entries_controller.dart';
import 'launcher_entry.dart';
import 'notes_block_view.dart';
import 'panel_blocks_controller.dart';
import 'widget_card_view.dart';

/// Which tier of the design a block is drawn at - see [SurfaceLevel].
///
/// The blocks a user builds something in (a widget card, a note, a code
/// widget, the calendar) are what the panel exists for, so they carry the
/// hero treatment: roundest corners, deepest shadow. An app row is a strip of
/// shortcuts next to them, useful but not the point, so it sits one tier
/// down. Everything stays on screen either way - the tiers only decide how
/// loudly each one says what it is.
SurfaceLevel levelFor(PanelBlockType type) => switch (type) {
  PanelBlockType.widget ||
  PanelBlockType.notes ||
  PanelBlockType.code ||
  PanelBlockType.calendar => SurfaceLevel.hero,
  PanelBlockType.appRow => SurfaceLevel.normal,
};

/// One block on the pull-down panel. Rendering only - holding, moving and
/// editing are handled by the list around it.
class PanelBlockCard extends StatelessWidget {
  const PanelBlockCard({super.key, required this.block, required this.s});

  final PanelBlock block;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final level = levelFor(block.type);
    final style = design.surfaceStyle(level);
    final margin = EdgeInsets.symmetric(vertical: style.gap);

    // A code widget paints its own page edge to edge, so it gets the card
    // without the usual padding - and none of the card at all when it was
    // set to draw its own background.
    if (block.type == PanelBlockType.code) {
      return Padding(
        padding: margin,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: style.borderRadius,
            // A card that draws its own background gets no shadow either:
            // the shadow would outline a card that isn't there.
            boxShadow: block.transparentBackground ? null : style.shadow,
          ),
          child: ClipRRect(
            borderRadius: style.borderRadius,
            child: ColoredBox(
              color: block.transparentBackground
                  ? Colors.transparent
                  : design.cardSurface,
              child: CodeBlockView(block: block, s: s),
            ),
          ),
        ),
      );
    }

    return AnimatedContainer(
      duration: design.motionFast,
      curve: design.motionCurve,
      margin: margin,
      decoration: design.cardDecoration(
        level,
        color: design.cardSurface,
        // No outline on the panel: the cards sit on a translucent sheet over
        // the wallpaper, where a border draws a second edge right next to
        // the one the card's own tint already makes.
        bordered: false,
      ),
      child: Padding(
        padding: style.insets,
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
                style: TextStyle(color: context.design.textSecondary),
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
              runSpacing: context.design.spaceSm,
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
              style: TextStyle(
                fontSize: context.design.typeCaption,
                color: context.design.textPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
