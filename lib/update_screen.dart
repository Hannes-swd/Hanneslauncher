import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_strings.dart';
import 'locale_controller.dart';
import 'update_controller.dart';

/// The red dot that says "there is a newer version". Shown on the settings
/// button, on the App group and on the update row itself, so the news
/// travels all the way from the home screen to the row that acts on it
/// instead of waiting to be discovered.
class UpdateDot extends StatelessWidget {
  const UpdateDot({super.key, this.size = 10});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFFD32F2F),
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Puts an [UpdateDot] on the corner of [child] while an update is
/// available - for the icon buttons, which have no room for a row.
class UpdateDotBadge extends StatelessWidget {
  const UpdateDotBadge({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UpdateState>(
      valueListenable: UpdateController.instance,
      builder: (context, state, child) {
        return Stack(
          alignment: Alignment.topRight,
          clipBehavior: Clip.none,
          children: [
            child!,
            if (state.available)
              const Positioned(top: 8, right: 8, child: UpdateDot()),
          ],
        );
      },
      child: child,
    );
  }
}

/// Shows which version is installed, which one GitHub has, and hands the
/// APK to the browser. Deliberately not an in-app installer: that needs the
/// "install unknown apps" permission plus its own download and file handling,
/// while the browser already does all of it and Android's own installer is
/// what the user ends up in either way.
class UpdateScreen extends StatefulWidget {
  const UpdateScreen({super.key});

  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen> {
  @override
  void initState() {
    super.initState();
    // Opening this screen is asking about updates, so it checks - but only
    // if the last check has aged out, so repeatedly opening it doesn't burn
    // through GitHub's request budget.
    UpdateController.instance.refreshStale();
  }

  Future<void> _open(String url, AppStrings s) async {
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.updateOpenFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        LocaleController.instance,
        UpdateController.instance,
      ]),
      builder: (context, child) {
        final s = AppStrings(LocaleController.instance.value);
        final state = UpdateController.instance.value;
        final release = state.latest;

        return Scaffold(
          appBar: AppBar(title: Text(s.update)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                state.installedVersion.isEmpty
                    ? s.updateVersionUnknown
                    : s.updateInstalledVersion(state.installedVersion),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                release == null
                    ? s.updateNoReleaseYet
                    : s.updateLatestVersion(release.version),
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 16),
              if (state.available) ...[
                Row(
                  children: [
                    const UpdateDot(size: 12),
                    const SizedBox(width: 8),
                    Text(
                      s.updateAvailableTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFD32F2F),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (release!.apkUrl.isNotEmpty)
                  FilledButton.icon(
                    onPressed: () => _open(release.apkUrl, s),
                    icon: const Icon(Icons.download_outlined),
                    label: Text(s.updateDownload),
                  )
                else
                  Text(
                    s.updateNoApkInRelease,
                    style: const TextStyle(color: Colors.black54),
                  ),
                const SizedBox(height: 8),
                Text(
                  s.updateInstallHint,
                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                ),
                const SizedBox(height: 16),
              ] else if (release != null && !state.checking) ...[
                Text(
                  s.updateUpToDate,
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 16),
              ],
              OutlinedButton.icon(
                onPressed: state.checking
                    ? null
                    : () => UpdateController.instance.check(),
                icon: const Icon(Icons.refresh),
                label: Text(state.checking ? s.updateChecking : s.updateCheckNow),
              ),
              const SizedBox(height: 8),
              Text(
                state.lastCheck == null
                    ? s.updateNeverChecked
                    : s.updateLastChecked(_formatTime(state.lastCheck!, s)),
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
              if (state.lastCheckFailed) ...[
                const SizedBox(height: 8),
                Text(
                  s.updateCheckFailed,
                  style: const TextStyle(color: Color(0xFFD32F2F), fontSize: 13),
                ),
              ],
              if (release != null && release.notes.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  s.updateWhatsNew,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(release.notes),
              ],
              if (release != null && release.pageUrl.isNotEmpty) ...[
                const SizedBox(height: 24),
                TextButton.icon(
                  onPressed: () => _open(release.pageUrl, s),
                  icon: const Icon(Icons.open_in_new),
                  label: Text(s.updateOpenRelease),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _formatTime(DateTime time, AppStrings s) {
    final date = s.language == AppLanguage.en
        ? '${time.year}-${_two(time.month)}-${_two(time.day)}'
        : '${_two(time.day)}.${_two(time.month)}.${time.year}';
    return '$date, ${_two(time.hour)}:${_two(time.minute)}';
  }

  String _two(int value) => value.toString().padLeft(2, '0');
}
