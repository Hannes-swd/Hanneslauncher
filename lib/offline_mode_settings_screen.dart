import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'clock_settings_controller.dart';
import 'clock_widget.dart';
import 'color_swatch_picker.dart';
import 'locale_controller.dart';
import 'media_session.dart';
import 'offline_mode_controller.dart';
import 'offline_mode_screen.dart';

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
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: FilledButton.icon(
                      icon: const Icon(Icons.bedtime_outlined),
                      label: Text(s.startOfflineMode),
                      onPressed: () => openOfflineMode(context),
                    ),
                  ),
                  const Divider(height: 32),
                  _heading(s.style),
                  _StyleGrid(settings: settings),
                  _heading(s.colorLabel),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ColorSwatchPicker(
                      s: s,
                      selectedIndex: settings.colorIndex,
                      onSelected: (index) =>
                          OfflineModeController.instance.update(
                            settings.copyWith(colorIndex: index),
                          ),
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
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _heading(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.black54,
        ),
      ),
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
        return GridView(
          // Inside the settings list, so it neither scrolls on its own nor
          // guesses a height - the page it sits in does the scrolling.
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: 128,
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Colors.black : Colors.black26,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: double.infinity,
                  color: Colors.black,
                  padding: const EdgeInsets.all(4),
                  // Scaled down rather than cropped: the faces are real
                  // clocks of quite different sizes (a whole letter grid
                  // next to four digits), and half a word clock says
                  // nothing about what it looks like.
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
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (selected) ...[
                  const Icon(Icons.check_circle, size: 14),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
