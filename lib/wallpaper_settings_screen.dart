import 'dart:io';

import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'design_tokens.dart';
import 'design_widgets.dart';
import 'locale_controller.dart';
import 'lock_wallpaper_controller.dart';
import 'wallpaper_controller.dart';
import 'wallpaper_library.dart';

/// Which of the two backgrounds the screen is currently aiming at.
///
/// They are genuinely two different things - one is drawn by this app, the
/// other is handed to Android - but from the user's side they are the same
/// question asked twice, so it is one screen with a switch at the top rather
/// than two screens with the same library in both.
enum _Target { home, lock }

class WallpaperSettingsScreen extends StatefulWidget {
  const WallpaperSettingsScreen({super.key});

  @override
  State<WallpaperSettingsScreen> createState() =>
      _WallpaperSettingsScreenState();
}

class _WallpaperSettingsScreenState extends State<WallpaperSettingsScreen> {
  /// Read once when the screen opens: the bundled pictures are part of the
  /// build, so the list cannot change while the app is running.
  final Future<List<WallpaperAsset>> _assets = loadWallpaperAssets();

  _Target _target = _Target.home;

  /// Null while the phone is still being asked. The lock screen section only
  /// appears once the answer is in, so it never flickers into view and out
  /// again.
  bool? _lockSupported;

  @override
  void initState() {
    super.initState();
    _askLockSupport();
  }

  Future<void> _askLockSupport() async {
    final supported = await LockWallpaperController.supported();
    if (!mounted) return;
    setState(() {
      _lockSupported = supported;
      if (!supported) _target = _Target.home;
    });
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _applyAsset(WallpaperAsset asset, AppStrings s) async {
    if (_target == _Target.home) {
      final ok = await WallpaperController.instance.setAsset(asset.key);
      if (!ok) _say(s.wallpaperAssetMissing);
      return;
    }
    final ok = await LockWallpaperController.instance.setAsset(asset.key);
    if (!ok) _say(s.lockScreenFailed);
  }

  Future<void> _pick(AppStrings s) async {
    if (_target == _Target.home) {
      await WallpaperController.instance.pickAndSet();
      return;
    }
    // Null means the picker was dismissed - nothing happened, so nothing to
    // report.
    final ok = await LockWallpaperController.instance.pickAndSet();
    if (ok == false) _say(s.lockScreenFailed);
  }

  Future<void> _remove() async {
    if (_target == _Target.home) {
      await WallpaperController.instance.clear();
      return;
    }
    await LockWallpaperController.instance.clear();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LocaleController.instance,
      builder: (context, language, child) {
        final s = AppStrings(language);
        return Scaffold(
          appBar: AppBar(title: Text(s.wallpaper)),
          // Both backgrounds are listened to whichever one is being aimed at:
          // the switch at the top flips between them without anything being
          // rebuilt from scratch, and a restore landing while this screen is
          // open shows up immediately.
          body: ValueListenableBuilder<Wallpaper?>(
            valueListenable: WallpaperController.instance,
            builder: (context, home, child) {
              return ValueListenableBuilder<File?>(
                valueListenable: LockWallpaperController.instance,
                builder: (context, lock, child) => _body(s, home, lock),
              );
            },
          ),
        );
      },
    );
  }

  Widget _body(AppStrings s, Wallpaper? home, File? lock) {
    final design = context.design;
    final lockScreen = _target == _Target.lock;
    final hasPicture = lockScreen ? lock != null : home != null;

    return ListView(
      padding: EdgeInsets.only(bottom: design.spaceXl),
      children: [
        if (_lockSupported == true)
          Padding(
            padding: EdgeInsets.fromLTRB(
              design.spaceMd,
              design.spaceMd,
              design.spaceMd,
              0,
            ),
            child: SegmentedButton<_Target>(
              segments: [
                ButtonSegment(
                  value: _Target.home,
                  label: Text(s.homescreen),
                  icon: const Icon(Icons.home_outlined),
                ),
                ButtonSegment(
                  value: _Target.lock,
                  label: Text(s.lockScreen),
                  icon: const Icon(Icons.lock_outline),
                ),
              ],
              selected: {_target},
              showSelectedIcon: false,
              onSelectionChanged: (selection) =>
                  setState(() => _target = selection.first),
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            design.spaceMd,
            design.spaceMd,
            design.spaceMd,
            design.spaceSm,
          ),
          child: Text(
            lockScreen ? s.lockScreenWallpaperHint : s.homeWallpaperHint,
            style: design.textStyle(TypeRole.body, color: design.textSecondary),
          ),
        ),
        Padding(
          padding: design.pagePadding,
          child: _CurrentWallpaper(
            s: s,
            file: lockScreen ? lock : home?.file,
            isVideo: !lockScreen && (home?.isVideo ?? false),
            lockScreen: lockScreen,
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            design.spaceMd,
            design.spaceMd,
            design.spaceMd,
            0,
          ),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(s.wallpaperFromGallery),
                  onPressed: () => _pick(s),
                ),
              ),
              if (hasPicture) ...[
                SizedBox(width: design.spaceSm),
                IconButton(
                  tooltip: lockScreen ? s.lockScreenReset : s.removeWallpaper,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _remove,
                ),
              ],
            ],
          ),
        ),
        SettingsHeading(s.wallpaperLibrary),
        FutureBuilder<List<WallpaperAsset>>(
          future: _assets,
          builder: (context, snapshot) {
            final assets = snapshot.data;
            if (assets == null) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (assets.isEmpty) {
              return Padding(
                padding: design.pagePadding,
                child: Text(
                  s.wallpaperLibraryEmpty,
                  style: design.textStyle(
                    TypeRole.body,
                    color: design.textSecondary,
                  ),
                ),
              );
            }
            return _LibraryGrid(
              assets: assets,
              selected: lockScreen
                  ? LockWallpaperController.instance.assetKey
                  : home?.assetKey,
              // A video cannot go on the lock screen, so it is not offered
              // there - greyed out rather than hidden, because a wallpaper
              // that is simply missing from one of the two lists reads as a
              // bug in the list.
              disabled: lockScreen,
              onPick: (asset) => _applyAsset(asset, s),
            );
          },
        ),
        if (_lockSupported == false)
          Padding(
            padding: EdgeInsets.fromLTRB(
              design.spaceMd,
              design.spaceLg,
              design.spaceMd,
              0,
            ),
            child: Text(
              '${s.lockScreen}: ${s.lockScreenUnsupported}',
              style: design.textStyle(
                TypeRole.caption,
                color: design.textMuted,
              ),
            ),
          ),
      ],
    );
  }
}

/// What is on the chosen background right now, as the picture itself.
class _CurrentWallpaper extends StatelessWidget {
  const _CurrentWallpaper({
    required this.s,
    required this.file,
    required this.isVideo,
    required this.lockScreen,
  });

  final AppStrings s;
  final File? file;
  final bool isVideo;
  final bool lockScreen;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    final current = file;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 64,
          height: 114,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(design.radiusSmall),
            child: current == null
                ? ColoredBox(
                    color: design.fillSubtle,
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color: design.textMuted,
                    ),
                  )
                // No frame is pulled out of a video for this: it would cost a
                // decoder run for a thumbnail, which is the same trade the
                // settings list already makes.
                : isVideo
                ? ColoredBox(
                    color: design.fillSubtle,
                    child: const Icon(Icons.movie_outlined),
                  )
                : Image.file(current, fit: BoxFit.cover),
          ),
        ),
        SizedBox(width: design.spaceMd),
        Expanded(
          child: Text(
            current == null
                ? (lockScreen ? s.lockScreenNotSet : s.noImageSelected)
                : lockScreen
                ? s.lockScreenImageSet
                : (isVideo ? s.videoSelected : s.imageSelected),
            style: design.textStyle(
              TypeRole.body,
              color: design.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// The pictures that ship with the app.
class _LibraryGrid extends StatelessWidget {
  const _LibraryGrid({
    required this.assets,
    required this.selected,
    required this.disabled,
    required this.onPick,
  });

  final List<WallpaperAsset> assets;
  final String? selected;

  /// True where a moving wallpaper cannot go - the lock screen takes a still
  /// picture and nothing else.
  final bool disabled;

  final void Function(WallpaperAsset asset) onPick;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    return GridView(
      // Inside the settings list, so it neither scrolls on its own nor
      // guesses a height - the page it sits in does the scrolling.
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: design.pagePadding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: design.spaceSm,
        crossAxisSpacing: design.spaceSm,
        // An aspect ratio rather than a fixed height, unlike the clock
        // styles: these tiles are the picture, so on a wider screen they
        // should get bigger rather than sit in more empty space.
        childAspectRatio: 0.54,
      ),
      children: [
        for (final asset in assets)
          Builder(
            builder: (context) {
              final video = isVideoWallpaperPath(asset.key);
              final off = disabled && video;
              return Opacity(
                opacity: off ? 0.4 : 1,
                child: OptionTile(
                  title: asset.name,
                  selected: !off && asset.key == selected,
                  level: SurfaceLevel.compact,
                  // Expanded rather than sized to the picture: the tile is
                  // the wallpaper here, so it fills whatever room the grid
                  // gives it and the picture is cropped to that - the same
                  // framing the home screen will give it.
                  preview: SizedBox.expand(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(design.radiusSmall),
                      child: video
                          ? ColoredBox(
                              color: design.fillSubtle,
                              child: const Icon(Icons.movie_outlined),
                            )
                          : Image.asset(asset.key, fit: BoxFit.cover),
                    ),
                  ),
                  onTap: () {
                    if (off) return;
                    onPick(asset);
                  },
                ),
              );
            },
          ),
      ],
    );
  }
}
