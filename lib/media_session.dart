import 'package:flutter/services.dart';

/// One track, as Android's media session reports it.
class NowPlaying {
  const NowPlaying({required this.title, this.artist, this.playing = false});

  final String title;
  final String? artist;
  final bool playing;

  @override
  bool operator ==(Object other) =>
      other is NowPlaying &&
      other.title == title &&
      other.artist == artist &&
      other.playing == playing;

  @override
  int get hashCode => Object.hash(title, artist, playing);
}

/// What's playing on the phone right now, and the two skip buttons for it -
/// read from Android's own media sessions, the same place the lock screen
/// gets it from.
///
/// That means it follows whichever player is actually in use (Spotify,
/// YouTube Music, a podcast app) with no account and no subscription
/// anywhere. The one cost is the permission: Android only hands the
/// sessions to an app the user has switched on under "Notification access",
/// which has no runtime prompt - [requestPermission] opens that screen.
class MediaSession {
  static const _channel = MethodChannel('hanneslauncher/media');

  /// Whether this app is switched on as a notification listener. Everything
  /// else here answers with "nothing playing" until it is.
  static Future<bool> hasPermission() async {
    try {
      return await _channel.invokeMethod<bool>('hasPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens Android's "Notification access" settings. Returns false only if
  /// that screen couldn't be opened at all.
  static Future<bool> requestPermission() async {
    try {
      return await _channel.invokeMethod<bool>('requestPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// The current track, or null when nothing is playing (or the permission
  /// is missing - the caller draws nothing either way).
  static Future<NowPlaying?> current() async {
    try {
      final map = await _channel.invokeMapMethod<String, dynamic>('current');
      if (map == null) return null;
      final title = map['title'] as String?;
      if (title == null || title.isEmpty) return null;
      return NowPlaying(
        title: title,
        artist: map['artist'] as String?,
        playing: map['playing'] as bool? ?? false,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> next() async {
    try {
      await _channel.invokeMethod('next');
    } catch (_) {
      // Nothing to skip, or the player rejected it - either way there is
      // nothing useful to say about it on a screen showing only a clock.
    }
  }

  static Future<void> previous() async {
    try {
      await _channel.invokeMethod('previous');
    } catch (_) {}
  }
}
