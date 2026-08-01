import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_strings.dart';
import 'calendar_controller.dart';
import 'locale_controller.dart';
import 'panel_blocks_controller.dart';

/// The agenda drawn on a calendar block: upcoming events, grouped by day,
/// nearest first. Tapping one opens it in the system calendar app, exactly
/// what the standard Android calendar widget does.
class CalendarBlockView extends StatefulWidget {
  const CalendarBlockView({super.key, required this.block, required this.s});

  final PanelBlock block;
  final AppStrings s;

  @override
  State<CalendarBlockView> createState() => _CalendarBlockViewState();
}

class _CalendarBlockViewState extends State<CalendarBlockView> {
  List<CalendarEvent>? _events;

  @override
  void initState() {
    super.initState();
    CalendarController.instance.addListener(_onCalendarChanged);
    _load();
  }

  @override
  void didUpdateWidget(covariant CalendarBlockView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.block.itemKeys != widget.block.itemKeys ||
        oldWidget.block.daysAhead != widget.block.daysAhead) {
      _load();
    }
  }

  @override
  void dispose() {
    CalendarController.instance.removeListener(_onCalendarChanged);
    super.dispose();
  }

  void _onCalendarChanged() => _load();

  Future<void> _load() async {
    await CalendarController.instance.ensureLoaded();
    if (!CalendarController.instance.permissionGranted) {
      if (mounted) setState(() => _events = const []);
      return;
    }
    final events = await CalendarController.instance.upcomingEvents(
      calendarIds: widget.block.itemKeys,
      days: widget.block.daysAhead,
    );
    if (mounted) setState(() => _events = events);
  }

  @override
  Widget build(BuildContext context) {
    final controller = CalendarController.instance;

    if (!controller.permissionGranted) {
      return SizedBox(
        height: 88,
        child: Row(
          children: [
            const Icon(Icons.calendar_month, color: Colors.black45),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.s.calendarPermissionNeeded,
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      onPressed: () async {
                        await controller.requestPermission();
                        _load();
                      },
                      child: Text(widget.s.allow),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final events = _events;
    if (events == null) {
      return const SizedBox(
        height: 88,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (events.isEmpty) {
      return SizedBox(
        height: 56,
        child: Center(
          child: Text(
            widget.s.noUpcomingEvents,
            style: const TextStyle(color: Colors.black54),
          ),
        ),
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: widget.block.cardHeight),
      child: ListView(
        shrinkWrap: true,
        children: _groupedByDay(events, widget.s),
      ),
    );
  }

  List<Widget> _groupedByDay(List<CalendarEvent> events, AppStrings s) {
    final widgets = <Widget>[];
    DateTime? lastDay;
    for (final event in events) {
      final day = DateTime(event.start.year, event.start.month, event.start.day);
      if (lastDay == null || day != lastDay) {
        widgets.add(
          Padding(
            padding: EdgeInsets.fromLTRB(4, lastDay == null ? 0 : 12, 4, 4),
            child: Text(
              _dayLabel(day, s),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
          ),
        );
        lastDay = day;
      }
      widgets.add(_EventRow(event: event));
    }
    return widgets;
  }

  String _dayLabel(DateTime day, AppStrings s) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final diff = day.difference(todayDate).inDays;
    if (diff == 0) return s.today;
    if (diff == 1) return s.tomorrow;
    const weekdaysDe = [
      'Montag',
      'Dienstag',
      'Mittwoch',
      'Donnerstag',
      'Freitag',
      'Samstag',
      'Sonntag',
    ];
    const weekdaysEn = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final names = LocaleController.instance.value == AppLanguage.en
        ? weekdaysEn
        : weekdaysDe;
    final weekday = names[day.weekday - 1];
    final date =
        '${day.day.toString().padLeft(2, '0')}.'
        '${day.month.toString().padLeft(2, '0')}.';
    return '$weekday, $date';
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});

  final CalendarEvent event;

  @override
  Widget build(BuildContext context) {
    final color = event.calendarColor == null
        ? Colors.black38
        : Color(event.calendarColor!);
    final time = event.allDay
        ? null
        : '${event.start.hour.toString().padLeft(2, '0')}:'
              '${event.start.minute.toString().padLeft(2, '0')}';

    return InkWell(
      onTap: () => _open(event),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            if (time != null)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Text(
                  time,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                  ),
                ),
              ),
            Expanded(
              child: Text(
                event.title.isEmpty ? '—' : event.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _open(CalendarEvent event) async {
    final id = event.eventId;
    // Deep link the stock calendar app recognises; degrades to nothing if
    // no app claims it rather than throwing.
    final uri = id == null
        ? Uri.parse(
            'content://com.android.calendar/time/${event.start.millisecondsSinceEpoch}',
          )
        : Uri.parse('content://com.android.calendar/events/$id');
    try {
      await launchUrl(uri);
    } catch (_) {
      // No app registered for the calendar content URI on this device.
    }
  }
}
