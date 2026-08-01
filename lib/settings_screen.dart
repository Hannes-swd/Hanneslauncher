import 'package:flutter/material.dart';

import 'app_strings.dart';
import 'data_sources_controller.dart';
import 'data_sources_settings_screen.dart';
import 'home_screen_settings_screen.dart';
import 'locale_controller.dart';
import 'system_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LocaleController.instance,
      builder: (context, language, child) {
        final s = AppStrings(language);
        return Scaffold(
          appBar: AppBar(title: Text(s.settings)),
          body: ListView(
            children: [
              ListTile(
                leading: const Icon(Icons.home_outlined),
                title: Text(s.homescreen),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const HomeScreenSettingsScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.cloud_outlined),
                title: Text(s.dataSources),
                subtitle: Text(s.dataSourcesSubtitle(
                  DataSourcesController.instance.value.length,
                )),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          const DataSourcesSettingsScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: Text(s.system),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const SystemSettingsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
