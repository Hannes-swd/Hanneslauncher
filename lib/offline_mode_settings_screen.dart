import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'clock_font_picker.dart';
import 'clock_settings_controller.dart';
import 'clock_widget.dart';
import 'color_swatch_picker.dart';
import 'design_tokens.dart';
import 'design_widgets.dart';
import 'locale_controller.dart';
import 'media_session.dart';
import 'offline_mode_controller.dart';
import 'offline_mode_screen.dart';
import 'screen_wake.dart';

class OfflineModeSettingsScreen extends StatefulWidget {
  const OfflineModeSettingsScreen({super.key});

  @override
  State<OfflineModeSettingsScreen> createState() =>
      _OfflineModeSettingsScreenState();
}

class _OfflineModeSettingsScreenState extends State<OfflineModeSettingsScreen>
    with WidgetsBindingObserver {
  bool _mediaPermission = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// The permission is granted in Android's own settings, so the only moment
  /// this screen's answer can have changed is coming back from there.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshPermission();
  }

  Future<void> _refreshPermission() async {
    final granted = await MediaSession.hasPermission();
    if (!mounted || granted == _mediaPermission) return;
    setState(() => _mediaPermission = granted);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LocaleController.instance,
      builder: (context, language, child) {
        final s = AppStrings(language);
        return Scaffold(
          appBar: AppBar(title: Text(s.offlineMode)),
          body: ValueListenableBuilder<OfflineModeSettings>(
            valueListenable: OfflineModeController.instance,
            builder: (context, settings, child) {
              return ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      s.offlineModeExplanation,
                      style: TextStyle(color: context.design.textSecondary),
                    ),
                  ),
                  Padding(
                    padding: context.design.pagePadding,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.bedtime_outlined),
                      label: Text(s.startOfflineMode),
                      onPressed: () => openOfflineMode(context),
                    ),
                  ),
                  const Divider(height: 32),
                  SettingsHeading(s.style),
                  _StyleGrid(settings: settings),
                  if (settings.style == ClockStyle.digital) ...[
                    SettingsHeading(s.font),
                    Padding(
                      padding: context.design.pagePadding,
                      child: ClockFontPicker(
                        s: s,
                        selected: settings.digitalFontFamily,
                        onSelected: (family) =>
                            OfflineModeController.instance.update(
                              settings.copyWith(digitalFontFamily: family),
                            ),
                      ),
                    ),
                  ],
                  SettingsHeading(s.colorLabel),
                  Padding(
                    padding: context.design.pagePadding,
                    child: ColorSwatchPicker(
                      s: s,
                      selectedIndex: settings.colorIndex,
                      onSelected: (index) => OfflineModeController.instance
                          .update(settings.copyWith(colorIndex: index)),
                    ),
                  ),
                  const Divider(height: 32),
                  SwitchListTile(
                    title: Text(s.offlineModeMedia),
                    subtitle: Text(s.offlineModeMediaHint),
                    value: settings.showMedia,
                    onChanged: (value) => OfflineModeController.instance.update(
                      settings.copyWith(showMedia: value),
                    ),
                  ),
                  // Only worth showing once the music line is actually
                  // wanted: before that the permission has nothing to do
                  // with anything on screen.
                  if (settings.showMedia)
                    ListTile(
                      leading: Icon(
                        _mediaPermission
                            ? Icons.check_circle_outline
                            : Icons.lock_outline,
                      ),
                      title: Text(
                        _mediaPermission
                            ? s.offlineModeMediaPermissionGranted
                            : s.offlineModeMediaPermission,
                      ),
                      subtitle: _mediaPermission
                          ? null
                          : Text(s.offlineModeMediaPermissionHint),
                      trailing: _mediaPermission
                          ? null
                          : const Icon(Icons.open_in_new),
                      onTap: _mediaPermission
                          ? null
                          : MediaSession.requestPermission,
                    ),
                  const Divider(height: 32),
                  SwitchListTile(
                    title: Text(s.offlineModeBurnIn),
                    subtitle: Text(s.offlineModeBurnInHint),
                    value: settings.burnInProtection,
                    onChanged: (value) => OfflineModeController.instance.update(
                      settings.copyWith(burnInProtection: value),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.battery_saver_outlined),
                    title: Text(s.offlineModeBatterySaver),
                    subtitle: Text(s.offlineModeBatterySaverHint),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: ScreenWake.openBatterySaverSettings,
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

/// The clock faces as tiles, each drawn the way the offline mode would
/// actually draw it: on black, in the chosen color. The home screen's own
/// style grid can't be reused for that - its previews are tuned for a
/// wallpaper, and on this screen the point is seeing the black version.
class _StyleGrid extends StatelessWidget {
  const _StyleGrid({required this.settings});

  final OfflineModeSettings settings;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LocaleController.instance,
      builder: (context, language, child) {
        final s = AppStrings(language);
        final titles = <ClockStyle, String>{
          ClockStyle.digital: s.digital,
          ClockStyle.word: s.custom,
          ClockStyle.roman: s.roman,
          ClockStyle.bars: s.bars,
          ClockStyle.dotMatrix: s.dotMatrix,
          ClockStyle.splitFlap: s.splitFlap,
          ClockStyle.orbit: s.orbit,
          ClockStyle.vertical: s.vertical,
        };
        final design = context.design;
        return GridView(
          // Inside the settings list, so it neither scrolls on its own nor
          // guesses a height - the page it sits in does the scrolling.
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: design.pagePadding,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: design.spaceSm,
            crossAxisSpacing: design.spaceSm,
            mainAxisExtent:
                design.surfaceStyle(SurfaceLevel.compact).minHeight * 1.28,
          ),
          children: [
            for (final style in ClockStyle.values)
              _StyleOption(
                title: titles[style] ?? style.name,
                selected: settings.style == style,
                settings: settings.copyWith(style: style),
                onTap: () => OfflineModeController.instance.update(
                  settings.copyWith(style: style),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _StyleOption extends StatelessWidget {
  const _StyleOption({
    required this.title,
    required this.selected,
    required this.settings,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final OfflineModeSettings settings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final design = context.design;
    return OptionTile(
      title: title,
      selected: selected,
      onTap: onTap,
      preview: ClipRRect(
        borderRadius: BorderRadius.circular(design.radiusSmall),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          // Black regardless of the theme: this is what the offline screen
          // actually looks like, and a tile drawn on the theme's background
          // would be showing something the mode never does.
          color: Colors.black,
          padding: EdgeInsets.all(design.spaceXs),
          // Scaled down rather than cropped: the faces are real clocks of
          // quite different sizes (a whole letter grid next to four digits),
          // and half a word clock says nothing about what it looks like.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: clockFace(
              settings.style,
              settings: settings.toClockSettings(),
              showDate: false,
              digitalWeight: offlineDigitalWeight,
            ),
          ),
        ),
      ),
    );
  }
}
