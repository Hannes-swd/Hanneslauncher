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

  // The settings screen is one flat list grouped under these headings, so
  // everything is visible at once instead of hidden behind category pages
  // you have to guess your way into.
  String get searchSettings =>
      _en ? 'Search settings' : 'Einstellungen durchsuchen';
  String get sectionAppearance => _en ? 'Appearance' : 'Aussehen';
  String get sectionApps => 'Apps';
  String get sectionPanelData => _en ? 'Panel & data' : 'Panel & Daten';
  String get sectionApp => 'App';
  String get noSettingsFound =>
      _en ? 'No setting found' : 'Keine Einstellung gefunden';

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
  String get searchDataSources => _en ? 'Search sources' : 'Quelle suchen';
  String get noSearchResults =>
      _en ? 'No app found' : 'Keine App gefunden';
  String get sortBy => _en ? 'Sort' : 'Sortieren';
  String get sortAlphabetical => _en ? 'A to Z' : 'Alphabetisch';
  String get sortNewestFirst =>
      _en ? 'Newest first' : 'Neueste zuerst';
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
      _en ? 'On/off, digital or custom' : 'An/Aus, Digital oder Eigene';
  String get showClock => _en ? 'Show clock' : 'Uhr anzeigen';
  String get style => _en ? 'Style' : 'Stil';
  String get digital => 'Digital';
  String get custom => _en ? 'Custom' : 'Eigene';
  String get roman => _en ? 'Roman numerals' : 'Römische Zahlen';
  String get bars => _en ? 'Bars' : 'Balken';
  String get dotMatrix => _en ? 'Dot matrix' : 'Punktraster';
  String get splitFlap => _en ? 'Split-flap' : 'Klapptafel';
  String get orbit => 'Orbit';
  String get vertical => _en ? 'Vertical' : 'Vertikal';
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
  String get uninstallApp => _en ? 'Uninstall' : 'Deinstallieren';
  String get uninstallFailed => _en
      ? 'Could not uninstall this app'
      : 'App konnte nicht deinstalliert werden';
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
  String get atLeastOneCalendar => _en
      ? 'At least one calendar has to stay selected'
      : 'Mindestens ein Kalender muss ausgewählt bleiben';
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
  String get elementAction => _en ? 'Action button' : 'Aktions-Button';
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
  String get ruleTrue => _en ? 'True' : 'Wahr';
  String get ruleFalse => _en ? 'False' : 'Falsch';
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
  String get onlyHttps => _en
      ? 'http:// works too - for a local smart home device without a '
            'certificate'
      : 'http:// geht auch - für ein lokales Smart-Home-Gerät ohne '
            'Zertifikat';
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
  String get languageSystem =>
      _en ? 'System language' : 'Sprache des Systems';
  String languageSystemSubtitle(String language) => _en
      ? 'System language · $language'
      : 'Sprache des Systems · $language';

  String get backup => _en ? 'Backup' : 'Sicherung';
  String get backupSubtitle => _en
      ? 'Export or import all settings as a file'
      : 'Alle Einstellungen als Datei exportieren oder importieren';
  String get backupHint => _en
      ? 'Exports the clock, widgets, panel, pinned apps, folders, web apps, '
            'data sources, device data packages, custom colors, app '
            'renames and language into one file. Custom pictures '
            '(wallpaper, replaced icons) aren\'t included - their '
            'files stay behind on this install.'
      : 'Exportiert Uhr, Widgets, Panel, angepinnte Apps, Ordner, Web-Apps, '
            'Datenquellen, Gerätedaten-Pakete, eigene Farben, '
            'App-Umbenennungen und Sprache in eine Datei. '
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

  // The update check (update_screen.dart) - this app doesn't come from a
  // store, so new versions arrive as an APK attached to a GitHub release
  // and the check is what notices one is there.
  String get update => _en ? 'Update' : 'Update';
  String get updateSubtitleUpToDate => _en ? 'Up to date' : 'Aktuell';
  String updateSubtitleInstalled(String version) =>
      _en ? 'Version $version · up to date' : 'Version $version · aktuell';
  String updateSubtitleAvailable(String version) => _en
      ? 'Version $version available'
      : 'Version $version verfügbar';
  String get updateSubtitleUnknown =>
      _en ? 'Check for a new version' : 'Auf neue Version prüfen';
  String updateInstalledVersion(String version) =>
      _en ? 'Installed: $version' : 'Installiert: $version';
  String get updateVersionUnknown => _en
      ? 'Installed version unknown'
      : 'Installierte Version unbekannt';
  String updateLatestVersion(String version) =>
      _en ? 'Latest release: $version' : 'Neuestes Release: $version';
  String get updateNoReleaseYet =>
      _en ? 'No release found yet' : 'Noch kein Release gefunden';
  String get updateAvailableTitle =>
      _en ? 'Update available' : 'Update verfügbar';
  String get updateUpToDate => _en
      ? 'You have the latest version.'
      : 'Du hast die neueste Version.';
  String get updateDownload => _en ? 'Download APK' : 'APK herunterladen';
  String get updateNoApkInRelease => _en
      ? 'This release has no APK attached - open it on GitHub to see what\'s '
            'in it.'
      : 'An dieses Release ist keine APK angehängt - auf GitHub öffnen, um '
            'zu sehen, was drin ist.';
  String get updateInstallHint => _en
      ? 'The browser downloads the file; tapping the finished download starts '
            'Android\'s installer. It installs over the current version, so '
            'all settings stay - the app is never uninstalled in between.'
      : 'Der Browser lädt die Datei; ein Tipp auf den fertigen Download '
            'startet Androids Installer. Er installiert über die aktuelle '
            'Version, alle Einstellungen bleiben also erhalten - die App '
            'wird zwischendurch nie deinstalliert.';
  String get updateCheckNow => _en ? 'Check now' : 'Jetzt prüfen';
  String get updateChecking => _en ? 'Checking…' : 'Wird geprüft…';
  String get updateNeverChecked =>
      _en ? 'Never checked yet' : 'Noch nie geprüft';
  String updateLastChecked(String when) =>
      _en ? 'Last checked: $when' : 'Zuletzt geprüft: $when';
  String get updateCheckFailed => _en
      ? 'Check failed - no connection, or GitHub didn\'t answer.'
      : 'Prüfung fehlgeschlagen - keine Verbindung, oder GitHub hat nicht '
            'geantwortet.';
  String get updateWhatsNew => _en ? 'What\'s new' : 'Was ist neu';
  String get updateOpenRelease =>
      _en ? 'Open release on GitHub' : 'Release auf GitHub öffnen';
  String get updateOpenFailed => _en
      ? 'Couldn\'t open the link'
      : 'Link konnte nicht geöffnet werden';

  String get addColor => _en ? 'Add color' : 'Farbe hinzufügen';

  // The single device-data package, added from the "+" picker on the data
  // sources screen exactly like a source (see
  // data_sources_settings_screen.dart / device_data_screen.dart).
  String get devicePackages => _en ? 'Device data' : 'Gerätedaten';
  String get devicePackagesHint => _en
      ? 'Battery, storage, connection, sunrise/sunset, moon phase, steps, '
            'most used app - as placeholders, all in one go'
      : 'Akku, Speicher, Verbindung, Sonnenauf-/-untergang, Mondphase, '
            'Schritte, meistgenutzte App - als Platzhalter, alle auf einmal';
  String get packageBattery => _en ? 'Battery' : 'Akku';
  String get packageStorage => _en ? 'Storage' : 'Speicherplatz';
  String get packageConnection => _en ? 'Connection' : 'Verbindung';
  String get packageSunTimes => _en ? 'Sunrise/sunset' : 'Sonnenauf-/-untergang';
  String get packageMoonPhase => _en ? 'Moon phase' : 'Mondphase';
  String get packageSteps => _en ? 'Steps' : 'Schritte';
  String get packageMostUsedApp =>
      _en ? 'Most used app today' : 'Meistgenutzte App heute';
  String get grantAccess => _en ? 'Grant access' : 'Zugriff erlauben';

  // Action element (widget_editor_screen.dart / widget_card_view.dart) -
  // a button that fires an HTTP call, typically at a smart home device's
  // own local API, when tapped.
  String get iconLabel => _en ? 'Icon' : 'Symbol';
  String get actionHostFromSource => _en
      ? 'Take the host from a data source (path still needs typing - it\'s '
            'almost never the same one the source reads from)'
      : 'Host von einer Datenquelle übernehmen (Pfad noch selbst ergänzen - '
            'der ist fast nie derselbe, von dem die Quelle liest)';
  String get actionUrlLabel => _en ? 'Address' : 'Adresse';
  String get actionUrlHint => _en
      ? 'The one that actually changes something - not a status/read '
            'address, those look similar but do nothing here. http:// is '
            'fine, most local smart home devices have no certificate.'
      : 'Die Adresse, die wirklich etwas ändert - nicht eine Status-/'
            'Lese-Adresse, die sieht oft ähnlich aus, tut hier aber nichts. '
            'http:// ist erlaubt, die meisten lokalen Smart-Home-Geräte '
            'haben kein Zertifikat.';
  String get actionUrlNotValid => _en
      ? 'Doesn\'t look like a real address yet - it needs to start with '
            'http:// or https://, e.g. http://192.168.1.50/toggle. '
            'Placeholders add to that, they don\'t replace it.'
      : 'Sieht noch nicht nach einer echten Adresse aus - sie muss mit '
            'http:// oder https:// beginnen, z.B. http://192.168.1.50/'
            'toggle. Platzhalter ergänzen das, ersetzen es nicht.';
  String get actionMethodLabel => _en ? 'Method' : 'Methode';
  String get actionMethodGetHint => _en
      ? 'GET - almost never changes anything, only fetches. Some simple '
            'devices (Shelly) use it for commands anyway - check the '
            'device\'s own docs if unsure.'
      : 'GET - ändert fast nie etwas, ruft nur ab. Manche einfachen Geräte '
            '(Shelly) nutzen es trotzdem für Befehle - im Zweifel in der '
            'Anleitung des Geräts nachsehen.';
  String get actionMethodPostHint => _en
      ? 'POST - the usual choice for "do something" (most smart home hubs, '
            'e.g. Home Assistant)'
      : 'POST - die übliche Wahl für "tu etwas" (die meisten Smart-Home-'
            'Zentralen, z.B. Home Assistant)';
  String get actionMethodPutHint => _en
      ? 'PUT - some APIs use this instead of POST for "set this value"'
      : 'PUT - manche APIs nutzen das statt POST für "setze diesen Wert"';
  String get actionBodyLabel => _en ? 'Request body' : 'Anfrage-Inhalt';
  String get testAction => _en ? 'Test' : 'Testen';
  String get actionSucceeded => _en ? 'Done' : 'Erledigt';
  String actionFailed(String detail) =>
      _en ? 'Failed: $detail' : 'Fehlgeschlagen: $detail';
  String get actionModeLabel => _en ? 'Value' : 'Wert';
  String get actionModeFixed => _en ? 'Fixed value' : 'Fester Wert';
  String get actionModeToggle => _en ? 'Toggle' : 'Umschalten';
  String get actionModeFixedHint => _en
      ? 'Always sends the same thing - use the Wahr/Falsch buttons below to '
            'build an on-button and a separate off-button'
      : 'Schickt immer dasselbe - mit den Wahr/Falsch-Kacheln unten baust '
            'du einen An-Button und einen separaten Aus-Button';
  String get actionModeToggleHint => _en
      ? 'Reads the current value first, then sends the opposite - one '
            'button that flips between on and off'
      : 'Liest zuerst den aktuellen Wert, schickt dann das Gegenteil - ein '
            'einziger Button, der zwischen An und Aus wechselt';
  String get actionToggleSourceLabel =>
      _en ? 'Current value (true/false)' : 'Aktueller Wert (wahr/falsch)';
  String get actionToggleSourceHint => _en
      ? 'Where to read it from right now - e.g. {{schalter.on}}. Must '
            'resolve to exactly "true" or "false".'
      : 'Woher der Wert gerade gelesen wird - z.B. {{schalter.on}}. Muss '
            'genau "true" oder "false" ergeben.';
  String get actionToggleSourceNoneYet => _en
      ? 'No data source currently returns true/false - fetch or add one '
            'that reports the device\'s current state, e.g. {{schalter.on}}.'
      : 'Keine Datenquelle liefert gerade wahr/falsch - richte eine ein '
            '(oder aktualisiere sie), die den aktuellen Gerätezustand '
            'meldet, z.B. {{schalter.on}}.';
  String get actionHostPathReminder => _en
      ? 'Now add the path that changes something, e.g. toggle'
      : 'Jetzt noch den Pfad ergänzen, der etwas ändert, z.B. toggle';
  String get insertToggledValue =>
      _en ? 'Insert toggled value' : 'Umgeschalteten Wert einfügen';
  String get actionPreviewLabel =>
      _en ? 'This is what a tap sends right now:' : 'Das wird beim Antippen gerade gesendet:';
  String get actionPreviewEmpty =>
      _en ? '(no address yet)' : '(noch keine Adresse)';
  String get actionToggleUnreadable => _en
      ? 'Current value isn\'t readable as true/false yet - check "Current '
            'value" above'
      : 'Aktueller Wert ist noch nicht als wahr/falsch lesbar - "Aktueller '
            'Wert" oben prüfen';
  String get advanced => _en ? 'Advanced' : 'Erweitert';

  // What went wrong while fetching a source or firing an action
  // (data_sources_controller.dart, location_controller.dart,
  // widget_action.dart). These end up next to a data source or on a card, so
  // they follow the app's language like every other text.
  String get errorNoLocation => _en ? 'No location yet' : 'Noch kein Standort';
  String get errorOnlyHttp => _en
      ? 'Only http/https addresses can be used'
      : 'Nur http/https-Adressen sind möglich';
  String errorServerAnswered(int status) =>
      _en ? 'Server answered with $status' : 'Server antwortete mit $status';
  String get errorNotJson =>
      _en ? 'Answer is not valid JSON' : 'Antwort ist kein gültiges JSON';
  String get errorInvalidAddress =>
      _en ? 'Not a valid address' : 'Keine gültige Adresse';
  String get errorValueNotReadable =>
      _en ? 'Current value not readable' : 'Aktueller Wert nicht lesbar';
  String get errorLocationDenied =>
      _en ? 'Location permission denied' : 'Standort-Berechtigung verweigert';
  String get errorLocationOff =>
      _en ? 'Location is switched off' : 'Standort ist ausgeschaltet';
  String get errorNoPosition =>
      _en ? 'No position available' : 'Keine Position verfügbar';
}
