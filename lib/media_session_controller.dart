import 'media_session.dart';

/// What's playing right now, cached the same way `DeviceStatsController`
/// caches battery and storage: a synchronous read for the `{{...}}`
/// placeholders in `DataSourcesController`, kept fresh by whoever is about
/// to draw one of them or has just sent a transport command.
class MediaSessionController {
  MediaSessionController._();

  static final MediaSessionController instance = MediaSessionController._();

  bool hasPermission = false;
  String? title;
  String? artist;
  bool playing = false;

  Future<void> refresh() async {
    hasPermission = await MediaSession.hasPermission();
    if (!hasPermission) {
      title = null;
      artist = null;
      playing = false;
      return;
    }
    final now = await MediaSession.current();
    title = now?.title;
    artist = now?.artist;
    playing = now?.playing ?? false;
  }
}
