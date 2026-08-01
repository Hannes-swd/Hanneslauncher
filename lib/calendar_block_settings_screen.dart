import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'calendar_block_view.dart';
import 'calendar_controller.dart';
import 'locale_controller.dart';
import 'panel_blocks_controller.dart';

/// Settings for a calendar block: which of the device's calendars to show
/// and how far the agenda looks ahead.
class CalendarBlockSettingsScreen extends StatefulWidget {
  const CalendarBlockSettingsScreen({super.key, required this.blockId});

  final String blockId;

  @override
  State<CalendarBlockSettingsScreen> createState() =>
      _CalendarBlockSettingsScreenState();
}

class _CalendarBlockSettingsScreenState
    extends State<CalendarBlockSettingsScreen> {
  @override
  void initState() {
    super.initState();
    CalendarController.instance.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LocaleController.instance,
      builder: (context, language, child) {
        final s = AppStrings(language);
        return ValueListenableBuilder<List<PanelBlock>>(
          valueListenable: PanelBlocksController.instance,
          builder: (context, blocks, child) {
            final block = PanelBlocksController.instance.byId(
              widget.blockId,
            );
            // Deleted from this very screen.
            if (block == null) return const Scaffold();

            return Scaffold(
              appBar: AppBar(
                title: Text(s.blockCalendarTitle),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: s.deleteBlock,
                    onPressed: () async {
                      await PanelBlocksController.instance.remove(
                        widget.blockId,
                      );
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
              body: ListenableBuilder(
                listenable: CalendarController.instance,
                builder: (context, child) {
                  final controller = CalendarController.instance;
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (!controller.permissionGranted)
                        FilledButton.tonal(
                          onPressed: controller.requestPermission,
                          child: Text(s.allow),
                        )
                      else ...[
                        Text(
                          '${s.daysAheadLabel} '
                          '(${s.days(block.daysAhead)})',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black54,
                          ),
                        ),
                        Slider(
                          value: block.daysAhead.toDouble(),
                          min: 1,
                          max: 30,
                          divisions: 29,
                          onChanged: (value) =>
                              PanelBlocksController.instance.update(
                                block.copyWith(daysAhead: value.round()),
                              ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${s.cardHeightLabel} '
                          '(${block.cardHeight.round()})',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black54,
                          ),
                        ),
                        Slider(
                          value: block.cardHeight,
                          min: 100,
                          max: 800,
                          divisions: 70,
                          onChanged: (value) =>
                              PanelBlocksController.instance.update(
                                block.copyWith(cardHeight: value),
                              ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          s.calendarsLabel,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black54,
                          ),
                        ),
                        if (controller.calendars.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              s.noCalendarsFound,
                              style: const TextStyle(color: Colors.black54),
                            ),
                          )
                        else
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(s.allCalendars),
                            value: block.itemKeys.isEmpty,
                            onChanged: (_) => PanelBlocksController.instance
                                .update(block.copyWith(itemKeys: [])),
                          ),
                        for (final calendar in controller.calendars)
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            secondary: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: calendar.color == null
                                    ? Colors.black38
                                    : Color(calendar.color!),
                              ),
                            ),
                            title: Text(
                              calendar.name.isEmpty
                                  ? calendar.id
                                  : calendar.name,
                            ),
                            subtitle: calendar.accountName == null
                                ? null
                                : Text(calendar.accountName!),
                            value: block.itemKeys.isEmpty ||
                                block.itemKeys.contains(calendar.id),
                            onChanged: (_) {
                              // Starting from "all", ticking one specific
                              // calendar off means "every other one" -
                              // not everything minus this one forever, so
                              // the explicit list starts from the full set.
                              final current = block.itemKeys.isEmpty
                                  ? [
                                      for (final c in controller.calendars)
                                        c.id,
                                    ]
                                  : List<String>.from(block.itemKeys);
                              if (!current.remove(calendar.id)) {
                                current.add(calendar.id);
                              }
                              PanelBlocksController.instance.update(
                                block.copyWith(itemKeys: current),
                              );
                            },
                          ),
                        const Divider(height: 32),
                        Text(
                          s.preview,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: CalendarBlockView(block: block, s: s),
                        ),
                      ],
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
