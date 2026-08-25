import 'builtin_entries.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_list_settings_controller.dart' show appListColorPalette;
import 'app_strings.dart';
import 'data_sources_controller.dart';
import 'device_stats_controller.dart';
import 'folder_sheet.dart';
import 'launcher_entries_controller.dart';
import 'locale_controller.dart';
import 'location_controller.dart';
import 'panel_blocks_controller.dart';
import 'widget_action.dart';
import 'widget_element.dart';

/// Draws a widget card: its elements stacked on top of each other, each at
/// the spot it was dragged to, with the placeholders in them filled from the
/// data sources' last fetched values. The list order is the stacking order,
/// so the first element is at the back.
class WidgetCardView extends StatelessWidget {
  const WidgetCardView({super.key, required this.block, required this.s});

  final PanelBlock block;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      // The place name arrives separately from the fetched values, so both
      // have to be able to bring the card up to date.
      listenable: Listenable.merge([
        DataSourcesController.instance,
        LocationController.instance,
        DeviceStatsController.instance,
      ]),
      builder: (context, child) {
        Widget card;
        if (block.elements.isEmpty) {
          card = SizedBox(
            height: 72,
            child: Row(
              children: [
                const Icon(Icons.widgets_outlined, color: Colors.black45),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    block.title.isEmpty ? s.emptyWidget : block.title,
                    style: const TextStyle(color: Colors.black54),
                  ),
                ),
              ],
            ),
          );
        } else {
          card = SizedBox(
            height: block.cardHeight,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    for (final element in block.elements)
                      Align(
                        alignment: element.stackAlignment,
                        child: WidgetElementView(
                          element: element,
                          cardWidth: constraints.maxWidth,
                        ),
                      ),
                  ],
                );
              },
            ),
          );
        }

        if (block.linkedKey.isEmpty) return card;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _openLink(context),
          child: card,
        );
      },
    );
  }

  Future<void> _openLink(BuildContext context) async {
    final entries = LauncherEntriesController.instance.resolve(
      [block.linkedKey],
    );
    if (entries.isEmpty) return;
    final entry = entries.first;
    if (entry.isFolder) {
      showFolderSheet(context, entry.folder!);
    } else if (entry.isBuiltIn) {
      await openBuiltIn(context, entry.builtIn!);
    } else {
      await entry.launch();
    }
  }
}

extension WidgetElementPlacement on WidgetElement {
  /// Alignment counts from -1 to 1, the stored position from 0 to 1. Using
  /// alignment rather than a pixel offset means an element at the edge rests
  /// against it instead of hanging over it.
  Alignment get stackAlignment => Alignment(x * 2 - 1, y * 2 - 1);
}

/// A single element, both on the card and in the editor's preview.
class WidgetElementView extends StatelessWidget {
  const WidgetElementView({
    super.key,
    required this.element,
    required this.cardWidth,
    this.interactive = true,
  });

  final WidgetElement element;

  /// Needed for the elements sized as a share of the card.
  final double cardWidth;

  /// False in the canvas editor and the element editor's preview, where a
  /// tap is meant to open the element for editing (or just show what it
  /// looks like) - not actually fire an action element's HTTP call.
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    // Also used on its own in the element editor's preview, so it listens
    // for itself rather than relying on the card around it.
    return ListenableBuilder(
      listenable: Listenable.merge([
        DataSourcesController.instance,
        LocationController.instance,
        DeviceStatsController.instance,
      ]),
      builder: (context, child) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final sources = DataSourcesController.instance;
    final color = appListColorPalette[element.colorIndex];

    switch (element.type) {
      case WidgetElementType.text:
        return Text(
          sources.resolve(element.template),
          textAlign: element.alignment.textAlign,
          style: TextStyle(
            fontSize: element.fontSize,
            fontWeight: element.bold ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        );

      case WidgetElementType.icon:
        final value = sources.resolve(element.template);
        final match = element.rules.where((rule) => rule.matches(value));
        final iconName = match.isEmpty ? null : match.first.iconName;
        return Icon(
          widgetIcons[iconName] ?? Icons.help_outline,
          size: element.iconSize,
          color: color,
        );

      case WidgetElementType.box:
        return Container(
          width: math.min(element.width, cardWidth),
          height: element.height,
          decoration: BoxDecoration(
            color: color.withValues(alpha: element.opacity),
            borderRadius: BorderRadius.circular(element.radius),
          ),
        );

      case WidgetElementType.image:
        final url = sources.resolve(element.template);
        return ClipRRect(
          borderRadius: BorderRadius.circular(element.radius),
          child: SizedBox(
            height: element.height,
            width: math.min(element.width, cardWidth),
            child: Uri.tryParse(url)?.hasScheme != true
                ? const ColoredBox(color: Colors.black12)
                : Image.network(
                    url,
                    fit: BoxFit.cover,
                    // A broken or unreachable picture must not tear a hole
                    // in the panel, so it degrades to an empty tile.
                    errorBuilder: (context, error, stack) =>
                        const ColoredBox(color: Colors.black12),
                  ),
          ),
        );

      case WidgetElementType.action:
        return _ActionButton(
          element: element,
          color: color,
          interactive: interactive,
        );
    }
  }
}

/// An action element: an icon that fires the element's HTTP call when
/// tapped, with a brief spinner while it's in flight and a snackbar saying
/// whether it went through - the only feedback a fire-and-forget request
/// can give.
class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.element,
    required this.color,
    required this.interactive,
  });

  final WidgetElement element;
  final Color color;
  final bool interactive;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _running = false;

  Future<void> _run() async {
    if (_running) return;
    setState(() => _running = true);
    final result = await runWidgetAction(widget.element);
    if (!mounted) return;
    setState(() => _running = false);
    final s = AppStrings(LocaleController.instance.value);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.success ? s.actionSucceeded : s.actionFailed(
            result.detail ?? '',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final icon = widgetIcons[widget.element.template] ?? Icons.touch_app;
    final glyph = _running
        ? SizedBox(
            width: widget.element.iconSize,
            height: widget.element.iconSize,
            child: Padding(
              padding: EdgeInsets.all(widget.element.iconSize * 0.15),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: widget.color,
              ),
            ),
          )
        : Icon(icon, size: widget.element.iconSize, color: widget.color);

    if (!widget.interactive) return glyph;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _run,
      child: glyph,
    );
  }
}
