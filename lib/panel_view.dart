import 'dart:async';

import 'package:flutter/material.dart';

import 'app_row_settings_screen.dart';
import 'app_strings.dart';
import 'calendar_block_settings_screen.dart';
import 'data_packages_controller.dart';
import 'data_sources_controller.dart';
import 'device_stats_controller.dart';
import 'locale_controller.dart';
import 'location_controller.dart';
import 'panel_block_card.dart';
import 'panel_blocks_controller.dart';
import 'settings_screen.dart';
import 'update_screen.dart';
import 'widget_editor_screen.dart';

/// Contents of the panel that pulls down from the top: a fixed header with
/// the add and settings buttons, and below it the user's blocks - app rows
/// and widgets - stacked in their chosen order.
class PanelView extends StatefulWidget {
  const PanelView({
    super.key,
    required this.onHandleDragStart,
    required this.onHandleDragUpdate,
    required this.onHandleDragEnd,
    required this.onCloseRequested,
  });

  /// Dragging the header closes/opens the panel. Only the header does this,
  /// so dragging inside the block list scrolls it instead of fighting the
  /// panel for the same gesture.
  final GestureDragStartCallback onHandleDragStart;
  final GestureDragUpdateCallback onHandleDragUpdate;
  final GestureDragEndCallback onHandleDragEnd;

  /// Pulling the list down while it's already at the top closes the panel,
  /// which is what the gesture would do anywhere else on the header.
  final VoidCallback onCloseRequested;

  @override
  State<PanelView> createState() => _PanelViewState();
}

class _PanelViewState extends State<PanelView> {
  // Set as soon as a drag actually moves a block, so releasing without
  // moving can be told apart from a finished reorder.
  bool _reordered = false;

  // Keeps the built-in {{zeit}} / {{datum}} values honest. Half a minute is
  // enough for a clock down to the minute and costs nothing measurable.
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _loadSources();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _loadSources() async {
    // The blocks first: whether a position is needed at all is read off
    // their elements, so checking before they are loaded would always come
    // back "no" and nothing would ever fetch one.
    await PanelBlocksController.instance.load();
    // The stored position next, so a source following the location has
    // something to work with before any permission dialog appears.
    await LocationController.instance.load();
    await DataSourcesController.instance.load();
    await DeviceDataController.instance.load();
    // A card may name the place without any source asking for coordinates,
    // and then nothing else would ever fetch a position.
    if (_usesLocation()) await LocationController.instance.ensureFresh();
    // Cached values show immediately; anything past its interval is fetched
    // once here rather than on a timer, so a panel nobody opens costs
    // nothing.
    await DataSourcesController.instance.refreshStale();
    await DeviceStatsController.instance.ensureFresh(
      wantsSteps: DeviceDataController.instance.value,
      wantsMostUsedApp: DeviceDataController.instance.value,
    );
  }

  bool _usesLocation() {
    bool mentionsLocation(String text) =>
        text.contains('{{ort}}') ||
        text.contains('{{city}}') ||
        text.contains('{{lat}}') ||
        text.contains('{{lon}}');

    for (final block in PanelBlocksController.instance.value) {
      for (final element in block.elements) {
        if (mentionsLocation(element.template)) return true;
      }
    }
    return DataSourcesController.instance.value.any(
      (source) => mentionsLocation(source.url),
    );
  }

  Future<void> _add(AppStrings s) async {
    final choice = await showDialog<PanelBlockType>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: Text(s.addBlock),
          children: [
            SimpleDialogOption(
              onPressed: () =>
                  Navigator.of(context).pop(PanelBlockType.appRow),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.apps),
                title: Text(s.blockAppRow),
                subtitle: Text(s.blockAppRowTitle),
              ),
            ),
            SimpleDialogOption(
              onPressed: () =>
                  Navigator.of(context).pop(PanelBlockType.widget),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.widgets_outlined),
                title: Text(s.blockWidget),
              ),
            ),
            SimpleDialogOption(
              onPressed: () =>
                  Navigator.of(context).pop(PanelBlockType.calendar),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_month),
                title: Text(s.blockCalendar),
                subtitle: Text(s.blockCalendarTitle),
              ),
            ),
          ],
        );
      },
    );
    if (choice == null || !mounted) return;

    final controller = PanelBlocksController.instance;
    switch (choice) {
      case PanelBlockType.appRow:
        final block = await controller.addAppRow();
        if (!mounted) return;
        // Straight into the picker: a new row is empty and would otherwise
        // just sit there as a blank strip.
        await _edit(block);
      case PanelBlockType.widget:
        await controller.addWidget(s.blockWidget);
      case PanelBlockType.calendar:
        final block = await controller.addCalendar();
        if (!mounted) return;
        // Straight into settings: this is also where the calendar
        // permission gets asked for the first time.
        await _edit(block);
    }
  }

  Future<void> _edit(PanelBlock block) async {
    final builder = switch (block.type) {
      PanelBlockType.appRow => (context) =>
          AppRowSettingsScreen(blockId: block.id),
      PanelBlockType.widget => (context) =>
          WidgetEditorScreen(blockId: block.id),
      PanelBlockType.calendar => (context) =>
          CalendarBlockSettingsScreen(blockId: block.id),
    };
    await Navigator.of(context).push(MaterialPageRoute(builder: builder));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LocaleController.instance,
      builder: (context, language, child) {
        final s = AppStrings(language);
        return Column(
          children: [
            _header(s),
            Expanded(child: _blockList(s)),
          ],
        );
      },
    );
  }

  Widget _header(AppStrings s) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: widget.onHandleDragStart,
      onVerticalDragUpdate: widget.onHandleDragUpdate,
      onVerticalDragEnd: widget.onHandleDragEnd,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: s.addBlock,
            onPressed: () => _add(s),
          ),
          // Badged rather than plain: this button is the only way into the
          // settings, so it's also the only place an available update can be
          // announced without the panel growing a row of its own.
          UpdateDotBadge(
            child: IconButton(
              icon: const Icon(Icons.settings),
              tooltip: s.settings,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _blockList(AppStrings s) {
    return ValueListenableBuilder<List<PanelBlock>>(
      valueListenable: PanelBlocksController.instance,
      builder: (context, blocks, child) {
        if (blocks.isEmpty) {
          return GestureDetector(
            // Nothing to scroll yet, so the empty area keeps working as a
            // drag handle for the panel.
            behavior: HitTestBehavior.opaque,
            onVerticalDragStart: widget.onHandleDragStart,
            onVerticalDragUpdate: widget.onHandleDragUpdate,
            onVerticalDragEnd: widget.onHandleDragEnd,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  s.emptyPanel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
            ),
          );
        }

        return NotificationListener<OverscrollNotification>(
          onNotification: (notification) {
            // Pulled further down while already at the top: treat it as the
            // close gesture rather than a dead end.
            if (notification.overscroll < -12) widget.onCloseRequested();
            return false;
          },
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            // Own handles: the whole card is the handle, but only after a
            // long press, so ordinary dragging still scrolls the list.
            buildDefaultDragHandles: false,
            itemCount: blocks.length,
            onReorderStart: (_) => _reordered = false,
            onReorderItem: (oldIndex, newIndex) {
              _reordered = true;
              // onReorderItem already accounts for the item being lifted out
              // of the list; the controller expects the raw target slot, so
              // the shift is added back here.
              PanelBlocksController.instance.reorder(
                oldIndex,
                newIndex >= oldIndex ? newIndex + 1 : newIndex,
              );
            },
            onReorderEnd: (index) {
              // Held and released without moving: that's the edit gesture.
              if (_reordered) return;
              final blocks = PanelBlocksController.instance.value;
              if (index < blocks.length) _edit(blocks[index]);
            },
            itemBuilder: (context, index) {
              final block = blocks[index];
              return ReorderableDelayedDragStartListener(
                key: ValueKey(block.id),
                index: index,
                child: PanelBlockCard(block: block, s: s),
              );
            },
          ),
        );
      },
    );
  }
}
