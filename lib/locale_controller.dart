import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { de, en }

/// Holds the app's UI language, persisted across restarts.
class LocaleController extends ValueNotifier<AppLanguage> {
  LocaleController._() : super(AppLanguage.de);

  static final LocaleController instance = LocaleController._();

  static const _key = 'app_language';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    value = prefs.getString(_key) == 'en' ? AppLanguage.en : AppLanguage.de;
  }

  Future<void> update(AppLanguage language) async {
    value = language;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, language.name);
  }
}
