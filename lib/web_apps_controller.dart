import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'picked_image_store.dart';
import 'pinned_apps_controller.dart';

/// A website saved to the launcher (a PWA or any other link). It behaves
/// like an installed app: it shows up in the app list under its letter, can
/// be pinned to the home screen, and opens in the browser when tapped.
///
/// PWAs that Chrome installs as a WebAPK are real packages and already show
/// up on their own - this covers the ones that are only a saved link.
class WebApp {
  const WebApp({
    required this.id,
    required this.name,
    required this.url,
    this.iconPath,
  });

  /// Stable id, also used as the pin key (prefixed, see [webAppIdPrefix]).
  final String id;
  final String name;
  final String url;
  final String? iconPath;

  /// The picked icon as a file, or null if none was set (or it went missing).
  File? get iconFile {
    final path = iconPath;
    if (path == null) return null;
    final file = File(path);
    return file.existsSync() ? file : null;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    if (iconPath != null) 'iconPath': iconPath,
  };

  static WebApp fromJson(Map<String, dynamic> json) => WebApp(
    id: json['id'] as String,
    name: json['name'] as String,
    url: json['url'] as String,
    iconPath: json['iconPath'] as String?,
  );
}

/// Marks a pinned entry as a web app rather than a package name, so both
/// kinds can live in the same pinned list.
const String webAppIdPrefix = 'web:';

/// The user's saved web apps, persisted across restarts.
class WebAppsController extends ValueNotifier<List<WebApp>> {
  WebAppsController._() : super(const []);

  static final WebAppsController instance = WebAppsController._();

  static const _key = 'web_apps';

  bool _loaded = false;

  /// Reads the stored web apps once. Later calls do nothing: what's in
  /// memory is by then the newer state, and re-reading would throw away web
  /// apps added since.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key);
    if (raw == null) return;
    final loaded = <WebApp>[];
    for (final entry in raw) {
      try {
        loaded.add(WebApp.fromJson(jsonDecode(entry) as Map<String, dynamic>));
      } catch (_) {
        // Skip just the unreadable one. Dropping the whole list here would
        // be permanent: the next save would write the shortened list back.
      }
    }
    value = loaded;
  }

  WebApp? byId(String id) {
    for (final app in value) {
      if (app.id == id) return app;
    }
    return null;
  }

  /// The pin key for a web app, distinguishable from a package name.
  static String pinKeyFor(String id) => '$webAppIdPrefix$id';

  Future<WebApp> add({required String name, required String url}) async {
    final app = WebApp(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim(),
      url: normalizeUrl(url),
    );
    await _save([...value, app]);
    return app;
  }

  Future<void> rename(String id, String name) async {
    await _replace(id, (app) => WebApp(
      id: app.id,
      name: name.trim(),
      url: app.url,
      iconPath: app.iconPath,
    ));
  }

  Future<void> setUrl(String id, String url) async {
    await _replace(id, (app) => WebApp(
      id: app.id,
      name: app.name,
      url: normalizeUrl(url),
      iconPath: app.iconPath,
    ));
  }

  /// Lets the user pick an image and uses it as the web app's icon.
  /// Returns false if the picker was dismissed without a selection.
  Future<bool> pickIcon(String id) async {
    final savedFile = await pickImageInto('web_app_icons', id);
    if (savedFile == null) return false;
    await deleteStoredImage(byId(id)?.iconPath);
    await _replace(id, (app) => WebApp(
      id: app.id,
      name: app.name,
      url: app.url,
      iconPath: savedFile.path,
    ));
    return true;
  }

  /// Deletes a web app, unpinning it so it doesn't keep occupying one of the
  /// home screen's slots invisibly. Folders holding it skip it on their own.
  Future<void> remove(String id) async {
    await deleteStoredImage(byId(id)?.iconPath);
    await PinnedAppsController.instance.remove(pinKeyFor(id));
    await _save([
      for (final app in value)
        if (app.id != id) app,
    ]);
  }

  /// Opens the web app in whatever browser handles the link.
  static Future<void> launch(WebApp app) async {
    final uri = Uri.tryParse(app.url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Accepts what people actually type ("example.com") and turns it into
  /// something launchable.
  static String normalizeUrl(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return trimmed;
    if (trimmed.contains('://')) return trimmed;
    return 'https://$trimmed';
  }

  Future<void> _replace(String id, WebApp Function(WebApp) update) async {
    await _save([
      for (final app in value)
        if (app.id == id) update(app) else app,
    ]);
  }

  Future<void> _save(List<WebApp> apps) async {
    value = apps;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      [for (final app in apps) jsonEncode(app.toJson())],
    );
  }
}
