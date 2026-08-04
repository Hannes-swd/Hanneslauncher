import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One of the device's own calendars - a Google account added in Android's
/// own settings included.
class DeviceCalendar {
  const DeviceCalendar({
    required this.id,
    required this.name,
    required this.accountName,
    required this.color,
  });

  final String id;
  final String name;
  final String? accountName;

  /// ARGB, as reported by the platform - converted to a [Color] only where
  /// one is actually drawn.
  final int? color;
}

/// A single event, reduced to what the agenda needs to draw.
class CalendarEvent {
  const CalendarEvent({
    required this.title,
    required this.start,
    required this.end,
    required this.allDay,
    required this.calendarColor,
    required this.eventId,
    required this.calendarId,
  });

  final String title;
  final DateTime start;
  final DateTime? end;
  final bool allDay;
  final int? calendarColor;
  final String? eventId;
  final String calendarId;
}

/// Reads events from the calendars already synced on the device - a Google
/// account added in Android's own settings included, exactly the source the
/// system calendar widget itself reads from. No sign-in inside the app: the
/// account is whatever is already set up on the phone.
///
/// Reads Android's CalendarContract directly through a small native channel
/// (`android/.../MainActivity.kt`) rather than through a plugin: the
/// `device_calendar` package this originally used came back with every
/// field null on this device's Android version, while the platform's own
/// ContentResolver query works correctly.
class CalendarController extends ChangeNotifier {
  CalendarController._();

  static final CalendarController instance = CalendarController._();

  static const _channel = MethodChannel('hanneslauncher/calendar');

  bool _permissionGranted = false;
  bool get permissionGranted => _permissionGranted;

  List<DeviceCalendar> _calendars = [];
  List<DeviceCalendar> get calendars => _calendars;

  bool _loaded = false;
  String? error;

  /// Asks for the calendar permission the first time and reads the list of
  /// calendars. A refusal is remembered by Android, so this does not nag on
  /// every call - [requestPermission] is there for when the user wants to
  /// try again deliberately (e.g. after granting it in system settings).
  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    await _checkPermission();
    if (_permissionGranted) await _loadCalendars();
  }

  /// Re-reads calendars and events. The panel's own widget tree stays
  /// mounted for as long as the launcher runs - closing it only moves it
  /// off-screen - so without an explicit refresh a calendar block would
  /// keep showing whatever it last fetched, possibly hours old, until the
  /// app restarts. Called each time the panel is opened.
  Future<void> refresh() async {
    _loaded = true;
    await _checkPermission();
    if (_permissionGranted) await _loadCalendars();
    // Every calendar block listens for this: even when nothing above
    // changed, each one re-queries its own events (new ones, changed ones,
    // and the "today"/"tomorrow" labels).
    notifyListeners();
  }

  Future<void> requestPermission() async {
    try {
      final granted = await _channel.invokeMethod<bool>('requestPermission');
      _permissionGranted = granted ?? false;
      error = _permissionGranted ? null : 'permission denied';
      if (_permissionGranted) await _loadCalendars();
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  Future<void> _checkPermission() async {
    try {
      final granted = await _channel.invokeMethod<bool>('hasPermission');
      _permissionGranted = granted ?? false;
    } catch (e) {
      _permissionGranted = false;
      error = e.toString();
    }
  }

  Future<void> _loadCalendars() async {
    try {
      final raw = await _channel.invokeMethod<List<Object?>>('getCalendars');
      _calendars =
          [
              for (final entry in raw ?? const [])
                _calendarFrom(entry as Map),
            ]
            ..sort((a, b) => a.name.compareTo(b.name));
      error = null;
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
  }

  static DeviceCalendar _calendarFrom(Map raw) => DeviceCalendar(
    id: raw['id'] as String,
    name: raw['name'] as String? ?? '',
    accountName: raw['accountName'] as String?,
    color: raw['color'] as int?,
  );

  /// Every event across [calendarIds] (all calendars if empty) starting
  /// within the next [days] days, earliest first.
  Future<List<CalendarEvent>> upcomingEvents({
    required List<String> calendarIds,
    required int days,
  }) async {
    if (!_permissionGranted) return const [];

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(Duration(days: days));

    try {
      final raw = await _channel.invokeMethod<List<Object?>>('getEvents', {
        'calendarIds': calendarIds,
        'start': start.millisecondsSinceEpoch,
        'end': end.millisecondsSinceEpoch,
      });
      final events = [
        for (final entry in raw ?? const []) _eventFrom(entry as Map),
      ];
      events.sort((a, b) => a.start.compareTo(b.start));
      return events;
    } catch (e) {
      error = e.toString();
      return const [];
    }
  }

  static CalendarEvent _eventFrom(Map raw) {
    final allDay = raw['allDay'] as bool? ?? false;
    // All-day events are stored as UTC midnight; reading them back in the
    // local zone would shift the date by however far off UTC the device is
    // - interpreting them as UTC keeps the date the one actually set.
    DateTime toDateTime(Object? millis) {
      final value = (millis as num).toInt();
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: allDay);
    }

    return CalendarEvent(
      title: raw['title'] as String? ?? '',
      start: toDateTime(raw['begin']),
      end: raw['end'] == null ? null : toDateTime(raw['end']),
      allDay: allDay,
      calendarColor: raw['color'] as int?,
      eventId: raw['eventId'] as String?,
      calendarId: raw['calendarId'] as String,
    );
  }
}
