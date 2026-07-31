import 'package:flutter/material.dart';

import 'app_list_settings_screen.dart';
import 'app_strings.dart';
import 'clock_settings_screen.dart';
import 'locale_controller.dart';
import 'wallpaper_controller.dart';

class HomeScreenSettingsScreen extends StatelessWidget {
  const HomeScreenSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LocaleController.instance,
      builder: (context, language, child) {
        final s = AppStrings(language);
        return Scaffold(
          appBar: AppBar(title: Text(s.homescreen)),
          body: ValueListenableBuilder(
            valueListenable: WallpaperController.instance,
            builder: (context, wallpaper, child) {
              return ListView(
                children: [
                  ListTile(
                    leading: const Icon(Icons.image_outlined),
                    title: Text(s.wallpaper),
                    subtitle: Text(
                      wallpaper == null ? s.noImageSelected : s.imageSelected,
                    ),
                    trailing: wallpaper == null
                        ? null
                        : SizedBox(
                            width: 40,
                            height: 40,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(wallpaper, fit: BoxFit.cover),
                            ),
                          ),
                    onTap: () =>
                        WallpaperController.instance.pickAndSetImage(),
                  ),
                  if (wallpaper != null)
                    ListTile(
                      leading: const Icon(Icons.delete_outline),
                      title: Text(s.removeWallpaper),
                      onTap: () => WallpaperController.instance.clear(),
                    ),
                  ListTile(
                    leading: const Icon(Icons.list_alt_outlined),
                    title: Text(s.appList),
                    subtitle: Text(s.appListSubtitle),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              const AppListSettingsScreen(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.access_time_outlined),
                    title: Text(s.clock),
                    subtitle: Text(s.clockSubtitle),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const ClockSettingsScreen(),
                        ),
                      );
                    },
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
