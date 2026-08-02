import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'data_packages_controller.dart';
import 'locale_controller.dart';

/// One entry in the searchable picker below - a ready-made source or the
/// device-data package, everything except "type my own URL", which lives as
/// its own "+" instead of being just another row in a list meant to grow.
class _Preset {
  const _Preset({
    required this.id,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final String id;
  final IconData icon;
  final String title;
  final String? subtitle;
}

/// Picks what to add on the data sources screen: search as the catalog of
/// presets grows, plus a "+" of its own for typing a URL by hand - pops with
/// the chosen preset's id (or 'custom'), same contract a plain dialog had.
class AddDataSourceScreen extends StatefulWidget {
  const AddDataSourceScreen({super.key});

  @override
  State<AddDataSourceScreen> createState() => _AddDataSourceScreenState();
}

class _AddDataSourceScreenState extends State<AddDataSourceScreen> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<_Preset> _presets(AppStrings s, bool deviceDataAlready) => [
    _Preset(
      id: 'weatherHere',
      icon: Icons.my_location,
      title: s.presetWeatherHere,
      subtitle: s.presetWeatherHereHint,
    ),
    _Preset(
      id: 'weather',
      icon: Icons.wb_sunny_outlined,
      title: s.presetWeather,
    ),
    // Nothing left to turn on once it's already added.
    if (!deviceDataAlready)
      _Preset(
        id: 'deviceData',
        icon: Icons.smartphone_outlined,
        title: s.devicePackages,
        subtitle: s.devicePackagesHint,
      ),
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LocaleController.instance,
      builder: (context, language, child) {
        final s = AppStrings(language);
        return ValueListenableBuilder<bool>(
          valueListenable: DeviceDataController.instance,
          builder: (context, deviceDataEnabled, child) {
            final presets = _presets(s, deviceDataEnabled);
            final query = _search.text.trim().toLowerCase();
            final results = query.isEmpty
                ? presets
                : [
                    for (final preset in presets)
                      if (preset.title.toLowerCase().contains(query))
                        preset,
                  ];

            return Scaffold(
              appBar: AppBar(
                title: Text(s.addDataSource),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: s.presetCustom,
                    onPressed: () => Navigator.of(context).pop('custom'),
                  ),
                ],
              ),
              body: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: TextField(
                      controller: _search,
                      decoration: InputDecoration(
                        isDense: true,
                        prefixIcon: const Icon(Icons.search),
                        hintText: s.searchDataSources,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  Expanded(
                    child: results.isEmpty
                        ? Center(
                            child: Text(
                              s.noSearchResults,
                              style: const TextStyle(color: Colors.black54),
                            ),
                          )
                        : ListView(
                            children: [
                              for (final preset in results)
                                ListTile(
                                  leading: Icon(preset.icon),
                                  title: Text(preset.title),
                                  subtitle: preset.subtitle == null
                                      ? null
                                      : Text(preset.subtitle!),
                                  onTap: () =>
                                      Navigator.of(context).pop(preset.id),
                                ),
                            ],
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
