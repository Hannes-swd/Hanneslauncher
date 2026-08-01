import 'locale_controller.dart';

/// Translated UI strings. The word clock's letter grid is intentionally not
/// covered here - it's a fixed German word-puzzle design, not plain UI text.
class AppStrings {
  const AppStrings(this.language);

  final AppLanguage language;

  bool get _en => language == AppLanguage.en;

  String get settings => _en ? 'Settings' : 'Einstellungen';
  String get homescreen => _en ? 'Home screen' : 'Homescreen';
  String get system => 'System';

  String get wallpaper => _en ? 'Wallpaper' : 'Hintergrundbild';
  String get noImageSelected =>
      _en ? 'No image selected' : 'Kein Bild ausgewählt';
  String get imageSelected => _en ? 'Image selected' : 'Bild ausgewählt';
  String get removeWallpaper =>
      _en ? 'Remove wallpaper' : 'Hintergrundbild entfernen';

  String get appList => _en ? 'App list' : 'App-Liste';
  String get appListSubtitle =>
      _en ? 'Color, font, size, spacing' : 'Farbe, Schriftart, Größe, Abstand';
  String get exampleApp => _en ? 'Example app' : 'Beispiel App';
  String get textColor => _en ? 'Text color' : 'Textfarbe';
  String get font => _en ? 'Font' : 'Schriftart';
  String get fontStandard => _en ? 'Default' : 'Standard';
  String get fontSerif => 'Serif';
  String get fontMonospace => 'Monospace';
  String textSize(int value) =>
      _en ? 'Text size ($value)' : 'Textgröße ($value)';
  String lineSpacing(int value) =>
      _en ? 'Line spacing ($value)' : 'Zeilenabstand ($value)';

  String get clock => _en ? 'Clock' : 'Uhr';
  String get clockSubtitle =>
      _en ? 'On/off, digital or custom' : 'An/Aus, Digital oder Custom';
  String get showClock => _en ? 'Show clock' : 'Uhr anzeigen';
  String get style => _en ? 'Style' : 'Stil';
  String get digital => 'Digital';
  String get custom => 'Custom';
  String get appearanceCustom =>
      _en ? 'Appearance (Custom)' : 'Aussehen (Custom)';
  String get backgroundColor =>
      _en ? 'Background color' : 'Hintergrundfarbe';
  String backgroundStrength(int percent) => _en
      ? 'Background strength ($percent%)'
      : 'Hintergrundstärke ($percent%)';
  String get activeLetters => _en ? 'Active letters' : 'Aktive Buchstaben';
  String get inactiveLetters =>
      _en ? 'Inactive letters' : 'Inaktive Buchstaben';

  String get pinnedApps => _en ? 'Pinned apps' : 'Angepinnte Apps';
  String pinnedAppsSubtitle(int count, int max) => _en
      ? 'Shown on the home screen ($count/$max)'
      : 'Auf dem Homescreen angezeigt ($count/$max)';
  String get pinnedAppsFull => _en
      ? 'Limit reached - unpin one first'
      : 'Maximum erreicht - zuerst eine entfernen';

  String get languageLabel => _en ? 'Language' : 'Sprache';
  String get languageSubtitle => _en ? 'App language' : 'App-Sprache';
  String get german => 'Deutsch';
  String get english => 'English';
}
