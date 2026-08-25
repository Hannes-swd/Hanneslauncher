import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_list_settings_controller.dart' show appListColorPalette;
import 'clock_widget.dart';
import 'media_session.dart';
import 'offline_mode_controller.dart';
import 'screen_wake.dart';

/// Opens the offline mode over everything else and stays there until it is
/// closed from the inside.
Future<void> openOfflineMode(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (context) => const OfflineModeScreen(),
    ),
  );
}

/// A black screen with nothing on it but the clock, locked to landscape and
/// kept awake: the phone stood on its side while charging, readable across
/// a room.
///
/// Everything that would normally frame it is gone - status bar, navigation
/// bar, wallpaper, apps. Tapping brings back a single close button, and that
/// button is what ends the mode; it fades out again on its own so the screen
/// goes back to being just the clock.
class OfflineModeScreen extends StatefulWidget {
  const OfflineModeScreen({super.key});

  @override
  State<OfflineModeScreen> createState() => _OfflineModeScreenState();
}

class _OfflineModeScreenState extends State<OfflineModeScreen> {
  /// How long the close button stays up after a tap before the screen goes
  /// clean again.
  static const _closeButtonVisible = Duration(seconds: 4);

  /// The media session is polled rather than listened to: a track changes at
  /// most every few minutes, and a poll this slow costs nothing next to a
  /// screen that is on the whole time anyway.
  static const _mediaPollInterval = Duration(seconds: 2);

  bool _showClose = false;
  Timer? _hideTimer;
  Timer? _mediaTimer;
  NowPlaying? _nowPlaying;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // Not just hidden but sticky: a stray touch near an edge should bring
    // the clock straight back, not leave the system bars sitting on top of
    // it for the rest of the night.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    ScreenWake.setKeepOn(true);
    OfflineModeController.instance.addListener(_onSettingsChanged);
    _startMediaPolling();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _mediaTimer?.cancel();
    OfflineModeController.instance.removeListener(_onSettingsChanged);
    ScreenWake.setKeepOn(false);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // An empty list is "no preference", which hands rotation back to the
    // phone's own setting rather than pinning the launcher to one side.
    SystemChrome.setPreferredOrientations(const []);
    super.dispose();
  }

  /// The media line can be switched on while the mode is already open (from
  /// the settings screen it can be started from), so the polling follows the
  /// setting instead of only being decided once.
  void _onSettingsChanged() => _startMediaPolling();

  void _startMediaPolling() {
    _mediaTimer?.cancel();
    if (!OfflineModeController.instance.value.showMedia) {
      if (_nowPlaying != null) setState(() => _nowPlaying = null);
      return;
    }
    _pollMedia();
    _mediaTimer = Timer.periodic(_mediaPollInterval, (_) => _pollMedia());
  }

  Future<void> _pollMedia() async {
    final playing = await MediaSession.current();
    if (!mounted) return;
    if (playing != _nowPlaying) setState(() => _nowPlaying = playing);
  }

  void _revealClose() {
    setState(() => _showClose = true);
    _hideTimer?.cancel();
    _hideTimer = Timer(_closeButtonVisible, () {
      if (mounted) setState(() => _showClose = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<OfflineModeSettings>(
      valueListenable: OfflineModeController.instance,
      builder: (context, settings, child) {
        final color = appListColorPalette[settings.colorIndex];
        return Scaffold(
          backgroundColor: Colors.black,
          body: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _revealClose,
            child: Stack(
              children: [
                Positioned.fill(
                  child: SafeArea(
                    child: Padding(
                      // Room for the close button in the corner and for the
                      // track line below, so neither ever lands on top of
                      // the digits.
                      padding: const EdgeInsets.fromLTRB(64, 24, 64, 16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            // Every face draws at its own natural size, so
                            // scaling here is what makes all eight of them
                            // fill a landscape screen equally.
                            child: FittedBox(
                              fit: BoxFit.contain,
                              child: clockFace(
                                settings.style,
                                settings: settings.toClockSettings(),
                                showDate: false,
                                digitalWeight: offlineDigitalWeight,
                              ),
                            ),
                          ),
                          if (_nowPlaying != null)
                            _MediaLine(playing: _nowPlaying!, color: color),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_showClose)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: SafeArea(
                      child: IconButton(
                        icon: const Icon(Icons.close),
                        color: color,
                        iconSize: 32,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The current track under the clock, with the two skip buttons. Sized and
/// dimmed to stay clearly secondary to the time - meant to be readable when
/// looked for, not to compete with the clock from across the room.
class _MediaLine extends StatelessWidget {
  const _MediaLine({required this.playing, required this.color});

  final NowPlaying playing;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final artist = playing.artist;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.skip_previous),
          color: color.withValues(alpha: 0.7),
          iconSize: 28,
          onPressed: MediaSession.previous,
        ),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                playing.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color.withValues(alpha: 0.85),
                  fontSize: 16,
                ),
              ),
              if (artist != null && artist.isNotEmpty)
                Text(
                  artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: color.withValues(alpha: 0.5),
                    fontSize: 13,
                  ),
                ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.skip_next),
          color: color.withValues(alpha: 0.7),
          iconSize: 28,
          onPressed: MediaSession.next,
        ),
      ],
    );
  }
}
