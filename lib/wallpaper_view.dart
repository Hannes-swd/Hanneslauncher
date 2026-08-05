import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'wallpaper_controller.dart';

/// The home screen's background: a plain colour, a picture, an animated GIF
/// or a video, whichever is currently set.
class WallpaperView extends StatelessWidget {
  const WallpaperView({super.key, required this.animate});

  /// Whether a moving wallpaper should be running. False whenever the home
  /// screen isn't the thing being looked at - another app in front, the
  /// screen off, the settings panel pulled all the way down - because a
  /// wallpaper nobody can see is only spending battery.
  final bool animate;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Wallpaper?>(
      valueListenable: WallpaperController.instance,
      builder: (context, wallpaper, child) {
        return Container(
          color: Colors.white,
          width: double.infinity,
          height: double.infinity,
          child: _background(wallpaper),
        );
      },
    );
  }

  Widget? _background(Wallpaper? wallpaper) {
    if (wallpaper == null) return null;
    if (wallpaper.isVideo) {
      return _VideoWallpaper(file: wallpaper.file, playing: animate);
    }
    // Image plays animated GIFs on its own, and stops on the frame it's on
    // when the ticker is switched off - which is exactly the pause wanted
    // here, and the same rule the video below follows.
    return TickerMode(
      enabled: animate,
      child: Image.file(
        wallpaper.file,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      ),
    );
  }
}

/// A looping, silent video filling the screen.
class _VideoWallpaper extends StatefulWidget {
  const _VideoWallpaper({required this.file, required this.playing});

  final File file;
  final bool playing;

  @override
  State<_VideoWallpaper> createState() => _VideoWallpaperState();
}

class _VideoWallpaperState extends State<_VideoWallpaper> {
  VideoPlayerController? _player;

  // Opening is asynchronous, so a wallpaper that gets replaced meanwhile has
  // to be able to tell that the player arriving isn't its own any more.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void didUpdateWidget(covariant _VideoWallpaper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path) {
      setState(_close);
      _open();
    } else if (oldWidget.playing != widget.playing) {
      _syncPlayback();
    }
  }

  @override
  void dispose() {
    _close();
    super.dispose();
  }

  Future<void> _open() async {
    final generation = ++_generation;
    final player = VideoPlayerController.file(
      widget.file,
      videoPlayerOptions: VideoPlayerOptions(
        // A background must not take audio focus off whatever the phone is
        // playing, and it must not keep the display awake either - which is
        // what a player does by default while something is running, and a
        // wallpaper runs for as long as the home screen is open.
        mixWithOthers: true,
        preventsDisplaySleepDuringVideoPlayback: false,
      ),
    );
    try {
      await player.initialize();
      // Wallpapers are silent, whatever the file happens to carry.
      await player.setVolume(0);
      await player.setLooping(true);
    } catch (_) {
      // A container this phone can't decode: keep the plain background
      // rather than let a wallpaper take the launcher down.
      await player.dispose();
      return;
    }
    if (!mounted || generation != _generation) {
      await player.dispose();
      return;
    }
    setState(() => _player = player);
    _syncPlayback();
  }

  void _close() {
    _generation++;
    _player?.dispose();
    _player = null;
  }

  void _syncPlayback() {
    final player = _player;
    if (player == null || !player.value.isInitialized) return;
    if (widget.playing) {
      player.play();
    } else {
      player.pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = _player;
    if (player == null) return const SizedBox.expand();
    final size = player.value.size;
    if (size.isEmpty) return const SizedBox.expand();
    // The player draws at the video's own size, so covering the screen means
    // scaling that up and cutting off what sticks out - the same framing
    // BoxFit.cover gives a picture.
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: VideoPlayer(player),
      ),
    );
  }
}
