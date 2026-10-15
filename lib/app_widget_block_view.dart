import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_strings.dart';
import 'app_widgets.dart';
import 'design_tokens.dart';
import 'panel_blocks_controller.dart';
import 'panel_visibility.dart';

/// Draws a real Android app widget, as wide as the panel and
/// [PanelBlock.cardHeight] tall.
///
/// No gesture recognizers are claimed, for the same reason as the code
/// widget: taps reach the widget, while a vertical drag still scrolls the
/// panel and a long press still picks the card up.
class AppWidgetBlockView extends StatefulWidget {
  const AppWidgetBlockView({super.key, required this.block, required this.s});

  final PanelBlock block;
  final AppStrings s;

  @override
  State<AppWidgetBlockView> createState() => _AppWidgetBlockViewState();
}

enum _Status { unknown, ready, gone }

class _AppWidgetBlockViewState extends State<AppWidgetBlockView> {
  _Status _status = _Status.unknown;
  bool _settingUp = false;

  @override
  void initState() {
    super.initState();
    PanelVisibility.instance.addListener(_onPanelVisibility);
    _check();
  }

  @override
  void didUpdateWidget(covariant AppWidgetBlockView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.block.appWidgetId != widget.block.appWidgetId) _check();
  }

  @override
  void dispose() {
    PanelVisibility.instance.removeListener(_onPanelVisibility);
    super.dispose();
  }

  // Looked at again on every open: the widget's app may have been
  // uninstalled while the panel was closed.
  void _onPanelVisibility() {
    if (PanelVisibility.instance.value) _check();
  }

  Future<void> _check() async {
    final block = widget.block;
    final provider = await AppWidgets.providerOf(block.appWidgetId);
    if (!mounted) return;
    // A different provider counts as gone too: a restored backup's id may
    // since have been handed out again, for some other widget.
    final status = provider != null && provider == block.appWidgetProvider
        ? _Status.ready
        : _Status.gone;
    if (status != _status) setState(() => _status = status);
  }

  Future<void> _setUpAgain() async {
    setState(() => _settingUp = true);
    final block = widget.block;
    final id = await AppWidgets.create(block.appWidgetProvider);
    if (!mounted) return;
    setState(() => _settingUp = false);
    if (id == null) return;
    await AppWidgets.delete(block.appWidgetId);
    // Read fresh: the block may have been edited while Android's dialogs
    // were up.
    final current = PanelBlocksController.instance.byId(block.id) ?? block;
    await PanelBlocksController.instance.update(
      current.copyWith(appWidgetId: id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = widget.block.cardHeight;
    return switch (_status) {
      // Nothing is created before the panel has been opened once, the same
      // as the code widget: a platform view nobody looks at still costs.
      _Status.ready when PanelVisibility.instance.everOpened => SizedBox(
        height: height,
        child: AndroidView(
          // A new id is a new widget; the old view must not be reused for it.
          key: ValueKey(widget.block.appWidgetId),
          viewType: AppWidgets.viewType,
          creationParams: {'id': widget.block.appWidgetId},
          creationParamsCodec: const StandardMessageCodec(),
          // Switched on per widget: then drags belong to the widget, so its
          // lists scroll and its stacks flip - at the price of the panel not
          // scrolling while the finger starts on it.
          gestureRecognizers: widget.block.appWidgetScroll
              ? {
                  Factory<VerticalDragGestureRecognizer>(
                    VerticalDragGestureRecognizer.new,
                  ),
                  Factory<HorizontalDragGestureRecognizer>(
                    HorizontalDragGestureRecognizer.new,
                  ),
                }
              : const {},
        ),
      ),
      _Status.gone => _gone(context),
      _ => SizedBox(height: height),
    };
  }

  Widget _gone(BuildContext context) {
    final design = context.design;
    return Padding(
      padding: EdgeInsets.all(design.spaceMd),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.block.title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: design.textPrimary,
            ),
          ),
          SizedBox(height: design.spaceSm),
          Text(
            widget.s.appWidgetGone,
            textAlign: TextAlign.center,
            style: TextStyle(color: design.textSecondary),
          ),
          if (widget.block.appWidgetProvider.isNotEmpty)
            TextButton.icon(
              onPressed: _settingUp ? null : _setUpAgain,
              icon: const Icon(Icons.refresh),
              label: Text(widget.s.appWidgetSetUpAgain),
            ),
        ],
      ),
    );
  }
}
