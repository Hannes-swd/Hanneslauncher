import 'package:flutter/material.dart';

import 'app_customize_screen.dart';
import 'app_list_settings_screen.dart';
import 'app_strings.dart';
import 'clock_settings_screen.dart';
import 'folders_controller.dart';
import 'folders_settings_screen.dart';
import 'icon_theme_controller.dart';
import 'icon_theme_settings_screen.dart';
import 'locale_controller.dart';
import 'pinned_apps_controller.dart';
import 'pinned_apps_settings_screen.dart';
import 'wallpaper_controller.dart';
import 'web_apps_controller.dart';
import 'web_apps_settings_screen.dart';

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
                  ListTile(
                    leading: const Icon(Icons.apps_outlined),
                    title: Text(s.customizeApps),
                    subtitle: Text(s.customizeAppsSubtitle),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const AppCustomizeScreen(),
                        ),
                      );
                    },
                  ),
                  ValueListenableBuilder<IconThemeSettings>(
                    valueListenable: IconThemeController.instance,
                    builder: (context, iconTheme, child) {
                      return ListTile(
                        leading: const Icon(Icons.palette_outlined),
                        title: Text(s.iconTheme),
                        subtitle: Text(s.iconThemeSubtitle),
                        trailing: iconTheme.enabled
                            ? CircleAvatar(
                                radius: 12,
                                backgroundColor: iconTheme.color,
                              )
                            : null,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  const IconThemeSettingsScreen(),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  ValueListenableBuilder<List<LauncherFolder>>(
                    valueListenable: FoldersController.instance,
                    builder: (context, folders, child) {
                      return ListTile(
                        leading: const Icon(Icons.folder_outlined),
                        title: Text(s.folders),
                        subtitle: Text(s.foldersSubtitle(folders.length)),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  const FoldersSettingsScreen(),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  ValueListenableBuilder<List<WebApp>>(
                    valueListenable: WebAppsController.instance,
                    builder: (context, webApps, child) {
                      return ListTile(
                        leading: const Icon(Icons.public),
                        title: Text(s.webApps),
                        subtitle: Text(s.webAppsSubtitle(webApps.length)),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  const WebAppsSettingsScreen(),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  ValueListenableBuilder<List<String>>(
                    valueListenable: PinnedAppsController.instance,
                    builder: (context, pinned, child) {
                      return ListTile(
                        leading: const Icon(Icons.push_pin_outlined),
                        title: Text(s.pinnedApps),
                        subtitle: Text(
                          s.pinnedAppsSubtitle(
                            pinned.length,
                            PinnedAppsController.maxPinned,
                          ),
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  const PinnedAppsSettingsScreen(),
                            ),
                          );
                        },
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
