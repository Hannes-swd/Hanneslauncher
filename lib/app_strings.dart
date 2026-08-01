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

  String get customizeApps => _en ? 'Customize apps' : 'Apps anpassen';
  String get customizeAppsSubtitle =>
      _en ? 'Change name and icon' : 'Name und Icon ändern';
  String get changeIcon => _en ? 'Change icon' : 'Icon ändern';
  String get changeName => _en ? 'Change name' : 'Namen ändern';
  String get resetApp => _en ? 'Reset' : 'Zurücksetzen';
  String get cancel => _en ? 'Cancel' : 'Abbrechen';
  String get save => _en ? 'Save' : 'Speichern';
  String get nameLabel => _en ? 'Name' : 'Name';

  String get webApps => _en ? 'Web apps' : 'Web-Apps';
  String webAppsSubtitle(int count) => _en
      ? 'Websites and PWAs in the app list ($count)'
      : 'Webseiten und PWAs in der App-Liste ($count)';
  String get addWebApp => _en ? 'Add web app' : 'Web-App hinzufügen';
  String get editWebApp => _en ? 'Edit web app' : 'Web-App bearbeiten';
  String get urlLabel => _en ? 'Address' : 'Adresse';
  String get changeUrl => _en ? 'Change address' : 'Adresse ändern';
  String get remove => _en ? 'Remove' : 'Entfernen';
  String get noWebApps => _en
      ? 'No web apps yet. Add one with the button below - it then shows up in '
            'the app list and can be pinned to the home screen.'
      : 'Noch keine Web-Apps. Unten eine hinzufügen - sie erscheint dann in '
            'der App-Liste und kann auf den Homescreen gepinnt werden.';
  String get nameAndUrlRequired =>
      _en ? 'Name and address are required' : 'Name und Adresse sind nötig';

  String get iconTheme => _en ? 'Icon design' : 'Icon-Design';
  String get iconThemeSubtitle =>
      _en ? 'All icons in one color' : 'Alle Icons in einer Farbe';
  String get iconThemeEnabled =>
      _en ? 'Theme icons' : 'Icons einfärben';
  String get iconThemeHint => _en
      ? 'The original icons are kept - switching this off brings them back.'
      : 'Die Original-Icons bleiben erhalten - beim Ausschalten sind sie '
            'wieder da.';

  String get folders => _en ? 'Folders' : 'Ordner';
  String foldersSubtitle(int count) => _en
      ? 'Groups of apps in the app list ($count)'
      : 'App-Gruppen in der App-Liste ($count)';
  String get addFolder => _en ? 'Add folder' : 'Ordner hinzufügen';
  String get folderName => _en ? 'Folder name' : 'Ordnername';
  String get folderColor => _en ? 'Folder color' : 'Ordnerfarbe';
  String get folderContents => _en ? 'Contents' : 'Inhalt';
  String get addToFolder => _en ? 'Add to folder' : 'Zum Ordner hinzufügen';
  String get addApps => _en ? 'Add apps' : 'Apps hinzufügen';
  String get newSubfolder => _en ? 'New folder inside' : 'Neuer Unterordner';
  String get emptyFolder => _en ? 'This folder is empty' : 'Dieser Ordner ist leer';
  String get noFolders => _en
      ? 'No folders yet. Add one with the button below - it then shows up in '
            'the app list and can be pinned to the home screen.'
      : 'Noch keine Ordner. Unten einen hinzufügen - er erscheint dann in der '
            'App-Liste und kann auf den Homescreen gepinnt werden.'
      ;
  String get nameRequired => _en ? 'A name is required' : 'Ein Name ist nötig';
  String get deleteFolder => _en ? 'Delete folder' : 'Ordner löschen';
  String get folderCycleBlocked => _en
      ? "A folder can't be put inside itself"
      : 'Ein Ordner kann nicht in sich selbst';

  String get languageLabel => _en ? 'Language' : 'Sprache';
  String get languageSubtitle => _en ? 'App language' : 'App-Sprache';
  String get german => 'Deutsch';
  String get english => 'English';
}
