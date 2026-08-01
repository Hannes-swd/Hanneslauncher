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
  String get searchApps => _en ? 'Search apps' : 'App suchen';
  String get noSearchResults =>
      _en ? 'No app found' : 'Keine App gefunden';
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
  String get roman => _en ? 'Roman numerals' : 'Römische Zahlen';
  String get bars => _en ? 'Bars' : 'Balken';
  String get position => _en ? 'Position' : 'Position';
  String get alignLeft => _en ? 'Left' : 'Links';
  String get alignCenter => _en ? 'Center' : 'Mittig';
  String get alignRight => _en ? 'Right' : 'Rechts';
  String distanceFromTop(int pixels) =>
      _en ? 'Distance from top ($pixels)' : 'Abstand von oben ($pixels)';
  String distanceFromSide(int pixels) => _en
      ? 'Distance from edge ($pixels)'
      : 'Abstand vom Rand ($pixels)';
  String get appearanceCustom => _en ? 'Appearance' : 'Aussehen';
  String get backgroundColor =>
      _en ? 'Background color' : 'Hintergrundfarbe';
  String backgroundStrength(int percent) => _en
      ? 'Background strength ($percent%)'
      : 'Hintergrundstärke ($percent%)';
  String get activeLetters => _en ? 'Active letters' : 'Aktive Buchstaben';
  String get inactiveLetters =>
      _en ? 'Inactive letters' : 'Inaktive Buchstaben';
  String get barsFilledColor =>
      _en ? 'Filled bar color' : 'Farbe gefüllter Balken';
  String get barsUnfilledColor =>
      _en ? 'Unfilled bar color' : 'Farbe leerer Balken';
  String barsUnfilledStrength(int percent) => _en
      ? 'Unfilled bar strength ($percent%)'
      : 'Stärke leerer Balken ($percent%)';
  String get barsTextColor => _en ? 'Number color' : 'Zahlenfarbe';

  String get pinnedApps => _en ? 'Pinned apps' : 'Angepinnte Apps';
  String pinnedAppsSubtitle(int count, int max) => _en
      ? 'Shown on the home screen ($count/$max)'
      : 'Auf dem Homescreen angezeigt ($count/$max)';
  String get pinnedAppsFull => _en
      ? 'Limit reached - unpin one first'
      : 'Maximum erreicht - zuerst eine entfernen';
  String pinnedAppsLeftMargin(int pixels) => _en
      ? 'Distance from left edge ($pixels)'
      : 'Abstand vom linken Rand ($pixels)';

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

  String get addBlock => _en ? 'Add' : 'Hinzufügen';
  String get blockWidget => 'Widget';
  String get blockAppRow => _en ? 'Apps' : 'Apps';
  String get blockAppRowTitle => _en ? 'App row' : 'App-Reihe';
  String get blockCalendar => _en ? 'Calendar' : 'Kalender';
  String get blockCalendarTitle => _en
      ? 'Upcoming events from the device'
      : 'Anstehende Termine vom Gerät';
  String get calendarPermissionNeeded => _en
      ? 'Needs permission to read calendars'
      : 'Braucht Zugriff auf die Kalender';
  String get allow => _en ? 'Allow' : 'Erlauben';
  String get noUpcomingEvents =>
      _en ? 'No upcoming events' : 'Keine anstehenden Termine';
  String get today => _en ? 'Today' : 'Heute';
  String get tomorrow => _en ? 'Tomorrow' : 'Morgen';
  String get calendarsLabel => _en ? 'Calendars' : 'Kalender';
  String get allCalendars => _en ? 'All calendars' : 'Alle Kalender';
  String get daysAheadLabel => _en ? 'Look ahead' : 'Vorschau';
  String days(int count) => _en ? '$count days' : '$count Tage';
  String get noCalendarsFound => _en
      ? 'No calendars found on this device'
      : 'Keine Kalender auf diesem Gerät gefunden';
  String get emptyPanel => _en
      ? 'Nothing here yet. Add widgets or a row of apps with + above.'
      : 'Noch nichts hier. Oben mit + Widgets oder eine App-Reihe '
            'hinzufügen.';
  String get emptyAppRow =>
      _en ? 'No apps selected yet' : 'Noch keine Apps ausgewählt';
  String get editBlock => _en ? 'Edit' : 'Bearbeiten';
  String get deleteBlock => _en ? 'Delete' : 'Löschen';
  String get columnsLabel => _en ? 'Per row' : 'Pro Zeile';
  String get showLabelsLabel => _en ? 'Show names' : 'Namen anzeigen';
  String get chooseApps => _en ? 'Choose apps' : 'Apps auswählen';
  String get widgetPlaceholder => _en
      ? 'Widget content comes in the next step'
      : 'Widget-Inhalt kommt im nächsten Schritt';
  String get emptyWidget =>
      _en ? 'Empty widget - hold to edit' : 'Leeres Widget - halten zum Bearbeiten';
  String get widgetTitle => _en ? 'Widget name' : 'Widget-Name';
  String get addElement => _en ? 'Add line' : 'Zeile hinzufügen';
  String get elementText => _en ? 'Text' : 'Text';
  String get elementIcon => _en ? 'Icon by rule' : 'Symbol nach Regel';
  String get elementImage => _en ? 'Picture' : 'Bild';
  String get elementBox => _en ? 'Box' : 'Fläche';
  String get colorLabel => _en ? 'Color' : 'Farbe';
  String currentValue(String value) =>
      _en ? 'Value right now: $value' : 'Wert gerade: $value';
  String get noRuleMatches =>
      _en ? 'No rule matches it' : 'Keine Regel trifft darauf zu';
  String ruleMatches(String icon) =>
      _en ? 'Matches: $icon' : 'Passende Regel: $icon';
  String get rangeInverted => _en
      ? "\"From\" is greater than \"to\" - this can never match"
      : '"Von" ist größer als "Bis" - das kann nie zutreffen';
  String get iconTemplateTitle =>
      _en ? 'Start from' : 'Ausgangspunkt';
  String get weatherIconTemplate =>
      _en ? 'Weather icons (auto)' : 'Wettersymbole (automatisch)';
  String get weatherIconTemplateHint => _en
      ? 'Sun, cloud, rain ... filled in for every weather code'
      : 'Sonne, Wolke, Regen ... für jeden Wettercode ausgefüllt';
  String get ownRules => _en ? 'Empty, add my own' : 'Leer, selbst anlegen';
  String get insertWeatherTemplate =>
      _en ? 'Insert weather icons' : 'Wettersymbole einfügen';
  String get replaceRulesConfirm => _en
      ? 'This replaces the current rules with the standard weather icon set.'
      : 'Das ersetzt die aktuellen Regeln durch den Standard-Satz an '
            'Wettersymbolen.';
  String get noWeatherSourceHint => _en
      ? 'No weather source found - fill in the value field yourself'
      : 'Keine Wetterquelle gefunden - Wert-Feld selbst ausfüllen';
  String get testAnotherValue =>
      _en ? 'Test a value' : 'Einen Wert testen';
  String get valueMissing => _en
      ? 'The value is empty - check the placeholder above'
      : 'Der Wert ist leer - Platzhalter oben prüfen';
  String get canvasHint => _en
      ? 'Drag to move, tap to edit'
      : 'Ziehen zum Verschieben, antippen zum Bearbeiten';
  String get layersHint => _en
      ? 'Layers, bottom first - the arrows move an element forward or back'
      : 'Ebenen, unterste zuerst - die Pfeile legen ein Element nach vorne '
            'oder hinten';
  String get cardHeightLabel => _en ? 'Card height' : 'Kartenhöhe';
  String get widthShort => _en ? 'Width' : 'Breite';
  String get radiusShort => _en ? 'Corners' : 'Ecken';
  String get opacityShort => _en ? 'Opacity' : 'Deckkraft';
  String get elementValue => _en ? 'Value' : 'Wert';
  String get availableValues => _en ? 'Insert value' : 'Wert einfügen';
  String get textSizeShort => _en ? 'Size' : 'Größe';
  String get iconSizeShort => _en ? 'Icon size' : 'Symbolgröße';
  String get heightShort => _en ? 'Height' : 'Höhe';
  String get boldLabel => _en ? 'Bold' : 'Fett';
  String get alignLabel => _en ? 'Alignment' : 'Ausrichtung';
  String get rulesLabel => _en ? 'Rules' : 'Regeln';
  String get addRule => _en ? 'Add rule' : 'Regel hinzufügen';
  String get ruleFrom => _en ? 'From' : 'Von';
  String get ruleTo => _en ? 'To' : 'Bis';
  String get ruleEquals => _en ? 'Exactly' : 'Genau';
  String get ruleAny => _en ? 'anything' : 'alles';
  String get preview => _en ? 'Preview' : 'Vorschau';
  String get openOnTap => _en ? 'Open on tap' : 'Beim Antippen öffnen';
  String get openOnTapNone => _en ? 'Nothing' : 'Nichts';
  String get linkPickerTitle =>
      _en ? 'Choose app or folder' : 'App oder Ordner wählen';

  String get dataSources => _en ? 'Data sources' : 'Datenquellen';
  String dataSourcesSubtitle(int count) => _en
      ? 'APIs the widgets read from ($count)'
      : 'APIs, aus denen die Widgets lesen ($count)';
  String get addDataSource => _en ? 'Add source' : 'Quelle hinzufügen';
  String get sourceKey => _en ? 'Short key' : 'Kurzschlüssel';
  String get sourceKeyHint =>
      _en ? 'used in placeholders, e.g. weather' : 'für Platzhalter, z.B. wetter';
  String get sourceName => _en ? 'Name' : 'Name';
  String get sourceUrl => 'URL';
  String get sourceHeaders =>
      _en ? 'Headers (one per line, name: value)' : 'Header (pro Zeile, Name: Wert)';
  String refreshEvery(int minutes) =>
      _en ? 'Refresh every $minutes min' : 'Alle $minutes min aktualisieren';
  String get testSource => _en ? 'Test' : 'Testen';
  String get presets => _en ? 'Templates' : 'Vorlagen';
  String get presetWeather =>
      _en ? 'Weather, fixed place' : 'Wetter, fester Ort';
  String get presetWeatherHere =>
      _en ? 'Weather here' : 'Wetter am aktuellen Ort';
  String get presetWeatherHereHint => _en
      ? 'Follows the phone, asks for location'
      : 'Folgt dem Handy, fragt nach dem Standort';
  String get presetCustom => _en ? 'Own URL' : 'Eigene URL';
  String get noDataYet =>
      _en ? 'No data yet - press Test' : 'Noch keine Daten - Testen drücken';
  String get tapValueToInsert => _en
      ? 'Tap a value to insert it'
      : 'Einen Wert antippen, um ihn einzufügen';
  String get onlyHttps =>
      _en ? 'Only https addresses are allowed' : 'Nur https-Adressen sind erlaubt';
  String get keyAndUrlRequired => _en
      ? 'Short key and URL are required'
      : 'Kurzschlüssel und URL sind nötig';

  String get blockHint => _en
      ? 'Hold to move, hold and release to edit'
      : 'Halten zum Verschieben, halten und loslassen zum Bearbeiten';

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

  String get backup => _en ? 'Backup' : 'Sicherung';
  String get backupSubtitle => _en
      ? 'Export or import all settings as a file'
      : 'Alle Einstellungen als Datei exportieren oder importieren';
  String get backupHint => _en
      ? 'Exports the clock, widgets, panel, pinned apps, folders, web apps, '
            'data sources, app renames and language into one file. Custom '
            'pictures (wallpaper, replaced icons) aren\'t included - their '
            'files stay behind on this install.'
      : 'Exportiert Uhr, Widgets, Panel, angepinnte Apps, Ordner, Web-Apps, '
            'Datenquellen, App-Umbenennungen und Sprache in eine Datei. '
            'Eigene Bilder (Hintergrund, ersetzte Icons) sind nicht '
            'enthalten - deren Dateien bleiben auf diesem Gerät.';
  String get backupExport => _en ? 'Export' : 'Exportieren';
  String get backupImport => _en ? 'Import' : 'Importieren';
  String get backupImportConfirm => _en
      ? 'This replaces all current settings with the ones from the file. '
            'Continue?'
      : 'Das ersetzt alle aktuellen Einstellungen durch die aus der Datei. '
            'Fortfahren?';
  String get backupExportFailed => _en
      ? 'Couldn\'t create or share the backup file'
      : 'Sicherungsdatei konnte nicht erstellt oder geteilt werden';
  String get backupImportSuccess =>
      _en ? 'Settings imported' : 'Einstellungen importiert';
  String get backupImportFailed => _en
      ? 'Not a readable backup file'
      : 'Keine lesbare Sicherungsdatei';

  String get addColor => _en ? 'Add color' : 'Farbe hinzufügen';
}
