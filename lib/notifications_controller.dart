import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'secret_apps_controller.dart';

/// One notification currently waiting.
@immutable
class WaitingNotification {
  const WaitingNotification({
    required this.key,
    required this.package,
    required this.title,
    required this.text,
    required this.postedAt,
  });

  /// Android's own key for it - what dismissing and opening it go by. Never
  /// shown.
  final String key;
  final String package;
  final String title;
  final String text;
  final DateTime postedAt;

  /// Whether there is anything at all to draw. An app is allowed to post a
  /// notification with neither, and a blank row is worse than no row.
  bool get hasContent => title.isNotEmpty || text.isNotEmpty;
}

/// What is currently waiting, for the panel's notification block.
///
/// This is the one place in the app that reads a notification's *text*. The
/// badge on a pinned icon has always read nothing but the count, and says so;
/// this reads the title and the line under it as well, because a block whose
/// whole purpose is "what is waiting" cannot answer that with a number.
///
/// The rules it keeps, which are the same ones the count keeps:
///
///   Nothing is stored. The list is fetched when the panel opens and thrown
///   away when it shuts. Nothing reaches disk, and nothing reaches the
///   network - the app has no route from here to either.
///
///   Nothing is read while nobody is looking. No listener, no stream, no
///   background work: the panel asks, once, when it is pulled down.
///
///   A hidden app is not here. An app in the secret folder must not announce
///   itself with a badge, and it certainly must not announce itself with the
///   text of its messages - filtered here at the controller, the way
///   `NotificationCounts` does it, rather than at whatever draws the list.
class NotificationsController extends ValueNotifier<List<WaitingNotification>> {
  NotificationsController._() : super(const []);

  static final NotificationsController instance = NotificationsController._();

  static const _channel = MethodChannel('hanneslauncher/notifications');

  /// Swapped in by tests, which have no platform channel to answer.
  @visibleForTesting
  static Future<Object?> Function(String method, Map<String, Object?> args)?
  debugChannelOverride;

  static Future<T?> _invoke<T>(String method, [Map<String, Object?>? args]) {
    final override = debugChannelOverride;
    if (override != null) {
      return override(method, args ?? const {}).then((value) => value as T?);
    }
    return _channel.invokeMethod<T>(method, args).catchError((_) => null);
  }

  /// Reads what is waiting. Called when the panel opens, alongside the data
  /// sources and the calendar.
  Future<void> refresh() async {
    final rows = await _invoke<List<Object?>>('list');
    if (rows == null) {
      value = const [];
      return;
    }
    // Awaited, not read: the panel can be pulled down before the secret
    // list has been read off disk, and this is the one path in the app that
    // shows a notification's text rather than only counting it.
    final secret = await SecretAppsController.instance.loadedKeys();
    final waiting = <WaitingNotification>[];
    for (final row in rows) {
      if (row is! Map) continue;
      final key = row['key'];
      final package = row['package'];
      if (key is! String || package is! String) continue;
      if (secret.contains(package)) continue;
      final notification = WaitingNotification(
        key: key,
        package: package,
        title: (row['title'] as String?)?.trim() ?? '',
        text: (row['text'] as String?)?.trim() ?? '',
        postedAt: DateTime.fromMillisecondsSinceEpoch(
          (row['postedAt'] as num?)?.toInt() ?? 0,
        ),
      );
      if (notification.hasContent) waiting.add(notification);
    }
    value = waiting;
  }

  /// Swipes one away, exactly as pulling it off the system shade would.
  ///
  /// Taken out of the list here rather than by refetching: the row is being
  /// dismissed under a finger, and waiting for a channel round trip before
  /// it leaves is the difference between a swipe and a stutter.
  Future<void> dismiss(WaitingNotification notification) async {
    value = [
      for (final existing in value)
        if (existing.key != notification.key) existing,
    ];
    await _invoke<bool>('dismiss', {'key': notification.key});
  }

  /// Fires the notification's own intent - into the chat it came from, not
  /// merely into the app. False when it carries none, which is ordinary for
  /// a purely informational one.
  Future<bool> open(WaitingNotification notification) async =>
      await _invoke<bool>('open', {'key': notification.key}) ?? false;

  /// Emptied when the panel shuts. The point of not keeping it: a list of
  /// what was waiting an hour ago is both wrong and more than anyone asked
  /// this app to hold on to.
  void clear() => value = const [];
}
