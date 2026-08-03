import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { de, en }

/// Holds the app's UI language. The value is always one of the two languages
/// the app actually has - everything that formats text reads it - while
/// [followsSystem] remembers whether that came from the phone or from the
/// user picking a language by hand. A fresh install starts in English.
class LocaleController extends ValueNotifier<AppLanguage>
    with WidgetsBindingObserver {
  // English until the stored choice is read: it's the language a fresh
  // install runs in, so there is no wrong-language flash on the first frame.
  LocaleController._() : super(AppLanguage.en);

  static final LocaleController instance = LocaleController._();

  static const _key = 'app_language';
  static const _systemValue = 'system';

  bool _followsSystem = false;

  /// True while the app takes its language from the phone rather than from a
  /// choice made in the settings.
  bool get followsSystem => _followsSystem;

  /// The phone's language as far as this app has one: only German is German,
  /// everything else gets English rather than a language nobody can read.
  static AppLanguage _systemLanguage() =>
      PlatformDispatcher.instance.locale.languageCode == 'de'
      ? AppLanguage.de
      : AppLanguage.en;

  Future<void> load() async {
    // The phone's language can change while the app is only paused, and
    // Android keeps the process alive across that.
    WidgetsBinding.instance.addObserver(this);
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    // Following the phone is a choice like any other, not the fallback: a
    // fresh install - nothing stored yet - runs in English, and German or
    // the phone's language are picked in the settings.
    _followsSystem = stored == _systemValue;
    value = _followsSystem
        ? _systemLanguage()
        : (stored == 'de' ? AppLanguage.de : AppLanguage.en);
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    if (_followsSystem) value = _systemLanguage();
  }

  /// Pins the app to one language, whatever the phone is set to.
  Future<void> update(AppLanguage language) async {
    _followsSystem = false;
    value = language;
    // Notified by hand as well: picking the language the app already shows
    // changes nothing about [value], but it still has to stop following the
    // phone from here on.
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, language.name);
  }

  /// Hands the choice back to the phone.
  Future<void> useSystem() async {
    _followsSystem = true;
    value = _systemLanguage();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _systemValue);
  }
}
