import 'package:flutter/material.dart';

import 'app_list_settings_screen.dart';
import 'wallpaper_controller.dart';

class HomeScreenSettingsScreen extends StatelessWidget {
  const HomeScreenSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Homescreen')),
      body: ValueListenableBuilder(
        valueListenable: WallpaperController.instance,
        builder: (context, wallpaper, child) {
          return ListView(
            children: [
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text('Hintergrundbild'),
                subtitle: Text(
                  wallpaper == null ? 'Kein Bild ausgewählt' : 'Bild ausgewählt',
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
                onTap: () => WallpaperController.instance.pickAndSetImage(),
              ),
              if (wallpaper != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Hintergrundbild entfernen'),
                  onTap: () => WallpaperController.instance.clear(),
                ),
              ListTile(
                leading: const Icon(Icons.list_alt_outlined),
                title: const Text('App-Liste'),
                subtitle: const Text('Farbe, Schriftart, Größe, Abstand'),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const AppListSettingsScreen(),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
