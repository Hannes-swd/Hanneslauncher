import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'data_packages_controller.dart';
import 'data_sources_controller.dart';
import 'device_stats_controller.dart';
import 'locale_controller.dart';

/// The device-data package's own screen, reached the same way a data
/// source's edit screen is: shows what each placeholder currently resolves
/// to (like a source's "test" button, just always live), and for the two
/// that need a permission, a button to grant it right there.
class DeviceDataScreen extends StatefulWidget {
  const DeviceDataScreen({super.key});

  @override
  State<DeviceDataScreen> createState() => _DeviceDataScreenState();
}

class _DeviceDataScreenState extends State<DeviceDataScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    DeviceStatsController.instance.refresh(
      wantsSteps: true,
      wantsMostUsedApp: true,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Usage access is only grantable from the system Settings screen, not a
  // runtime prompt - this is how the screen catches up once the user comes
  // back from it.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      DeviceStatsController.instance.refresh(
        wantsSteps: true,
        wantsMostUsedApp: true,
      );
    }
  }

  String _resolve(String placeholder) =>
      DataSourcesController.instance.resolve(placeholder);

  /// `{{akku}}` on a German app, `{{battery}}` on an English one - the name
  /// the user would type, next to what it currently reads.
  String _line(String key) {
    final name = DataSourcesController.displayKey(key);
    return '{{$name}} → ${_resolve('{{$name}}')}';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LocaleController.instance,
      builder: (context, language, child) {
        final s = AppStrings(language);
        return ListenableBuilder(
          listenable: DeviceStatsController.instance,
          builder: (context, child) {
            return Scaffold(
              appBar: AppBar(
                title: Text(s.devicePackages),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: s.deleteBlock,
                    onPressed: () async {
                      await DeviceDataController.instance.setEnabled(false);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    s.devicePackagesHint,
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  _valueTile(
                    icon: Icons.battery_full,
                    title: s.packageBattery,
                    lines: [_line('akku'), _line('akku_laedt')],
                  ),
                  _valueTile(
                    icon: Icons.storage_outlined,
                    title: s.packageStorage,
                    lines: [_line('speicher_frei'), _line('speicher_gesamt')],
                  ),
                  _valueTile(
                    icon: Icons.wifi,
                    title: s.packageConnection,
                    lines: [_line('verbindung')],
                  ),
                  _valueTile(
                    icon: Icons.wb_twilight_outlined,
                    title: s.packageSunTimes,
                    lines: [_line('sonnenauf'), _line('sonnenunter')],
                  ),
                  _valueTile(
                    icon: Icons.nightlight_outlined,
                    title: s.packageMoonPhase,
                    lines: [_line('mondphase')],
                  ),
                  _valueTile(
                    icon: Icons.directions_walk,
                    title: s.packageSteps,
                    lines: [_line('schritte')],
                    permissionGranted:
                        DeviceStatsController.instance.stepsPermissionGranted,
                    onRequestPermission: () async {
                      await DeviceStatsController.instance
                          .requestStepsPermission();
                    },
                    s: s,
                  ),
                  _valueTile(
                    icon: Icons.bar_chart,
                    title: s.packageMostUsedApp,
                    lines: [_line('meistgenutzt')],
                    permissionGranted:
                        DeviceStatsController.instance.usageAccessGranted,
                    onRequestPermission: () =>
                        DeviceStatsController.instance.requestUsageAccess(),
                    s: s,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _valueTile({
    required IconData icon,
    required String title,
    required List<String> lines,
    bool permissionGranted = true,
    Future<void> Function()? onRequestPermission,
    AppStrings? s,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: permissionGranted
          ? Text(lines.join('\n'))
          : TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
              ),
              onPressed: () async {
                await onRequestPermission?.call();
                if (mounted) setState(() {});
              },
              child: Text(s!.grantAccess),
            ),
    );
  }
}
