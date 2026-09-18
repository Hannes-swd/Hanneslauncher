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

  String get wallpaper => _en ? 'Wallpaper' : 'Hintergrund';
  String get noImageSelected =>
      _en ? 'No image or video' : 'Kein Bild, kein Video';
  String get imageSelected => _en ? 'Image selected' : 'Bild ausgewählt';
  String get videoSelected => _en ? 'Video selected' : 'Video ausgewählt';
  String get removeWallpaper =>
      _en ? 'Remove wallpaper' : 'Hintergrund entfernen';

  String get appList => _en ? 'App list' : 'App-Liste';
  String get appListSubtitle => _en
      ? 'Layout, color, font, size, spacing'
      : 'Anordnung, Farbe, Schriftart, Größe, Abstand';
  String get exampleApp => _en ? 'Example app' : 'Beispiel App';
  String get searchApps => _en ? 'Search apps' : 'App suchen';
  String get searchDataSources => _en ? 'Search sources' : 'Quelle suchen';
  String get noSearchResults => _en ? 'No app found' : 'Keine App gefunden';
  String get sortBy => _en ? 'Sort' : 'Sortieren';
  String get sortAlphabetical => _en ? 'A to Z' : 'Alphabetisch';
  String get sortNewestFirst => _en ? 'Newest first' : 'Neueste zuerst';
  String get appListLayout => _en ? 'Layout' : 'Anordnung';
  String get layoutSingleColumn =>
      _en ? 'One column (scrolls)' : 'Eine Spalte (scrollt)';
  String get layoutColumns => _en ? 'Multiple columns' : 'Mehrere Spalten';
  String get appListLayoutHint => _en
      ? 'In one column, drag towards the top or bottom edge to scroll through '
            'long letters.'
      : 'Bei einer Spalte zum oberen oder unteren Rand ziehen, um durch lange '
            'Buchstaben zu scrollen.';
  String get appListHand => _en ? 'Hand' : 'Bedienhand';
  String get handRight => _en ? 'Right-handed' : 'Rechtshänder';
  String get handLeft => _en ? 'Left-handed' : 'Linkshänder';
  String get appListHandHint => _en
      ? 'Left-handed mirrors the app list: alphabet on the left, apps to the '
            'right of it.'
      : 'Linkshänder spiegelt die App-Liste: Alphabet links, Apps rechts '
            'daneben.';
  String get hideAlphabet => _en ? 'Hide alphabet' : 'Alphabet ausblenden';
  String get hideAlphabetHint => _en
      ? 'The letters stay invisible and only appear while a finger is '
            'swiping over the bar at the edge of the screen.'
      : 'Die Buchstaben bleiben unsichtbar und erscheinen erst, wenn am '
            'Bildschirmrand über die Leiste gewischt wird.';
  String backgroundBlur(String value) => _en
      ? 'Blur the wallpaper ($value)'
      : 'Hintergrund weichzeichnen ($value)';
  String get backgroundBlurOff => _en ? 'off' : 'aus';
  String get backgroundBlurHint => _en
      ? 'Softens the wallpaper while the alphabet is showing and while '
            'searching, so the letters and app names stand out. 0 leaves it '
            'sharp.'
      : 'Zeichnet das Hintergrundbild weich, solange das Alphabet '
            'eingeblendet ist und beim Suchen - damit sich Buchstaben und '
            'App-Namen abheben. 0 lässt es scharf.';
  String get textColor => _en ? 'Text color' : 'Textfarbe';
  String get font => _en ? 'Font' : 'Schriftart';
  String get fontStandard => _en ? 'Default' : 'Standard';
  String get fontSerif => 'Serif';
  String get fontMonospace => 'Monospace';
  // The rest of Android's own families, offered for the clock's digits.
  String get fontCondensed => _en ? 'Condensed' : 'Schmal';
  String get fontCasual => _en ? 'Casual' : 'Locker';
  String get fontCursive => _en ? 'Handwriting' : 'Handschrift';
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
  // The offline mode: the screen turned into nothing but a clock on black,
  // for a phone stood on its side while charging.
  String get offlineMode => _en ? 'Offline mode' : 'Offline-Modus';
  String get offlineModeSubtitle => _en
      ? 'Clock on black, landscape, screen stays on'
      : 'Uhr auf Schwarz, quer, Bildschirm bleibt an';
  String get offlineModeExplanation => _en
      ? 'Turns the screen into a clock on black, in landscape, and keeps it '
            'on. Tap the screen to bring back the close button. It sits in '
            'the app list like an app, so it can be pinned or put on a '
            'widget the same way.'
      : 'Macht den Bildschirm zu einer Uhr auf Schwarz, im Querformat, und '
            'lässt ihn an. Zum Beenden auf den Bildschirm tippen, dann '
            'erscheint das X. Er steht wie eine App in der App-Liste und '
            'lässt sich genauso anpinnen oder auf ein Widget legen.';
  String get startOfflineMode => _en ? 'Start now' : 'Jetzt starten';
  String get offlineModeMedia => _en ? 'Show music' : 'Musik anzeigen';
  String get offlineModeMediaHint => _en
      ? 'Shows what is currently playing under the clock, with skip buttons. '
            'Works with any player - Spotify, YouTube Music, podcasts - with '
            'no account needed.'
      : 'Zeigt unter der Uhr, was gerade läuft, mit Knöpfen für vor und '
            'zurück. Funktioniert mit jedem Player - Spotify, YouTube Music, '
            'Podcasts - ganz ohne Konto.';
  String get offlineModeMediaPermission =>
      _en ? 'Allow music access' : 'Musik-Zugriff erlauben';
  String get offlineModeMediaPermissionHint => _en
      ? 'Android only shares the playing track with an app switched on under '
            '"Notification access". Open that screen and switch '
            'hanneslauncher on.'
      : 'Android gibt den laufenden Titel nur an Apps weiter, die unter '
            '"Benachrichtigungszugriff" eingeschaltet sind. Dort '
            'hanneslauncher einschalten.';
  String get offlineModeBurnIn => _en ? 'Burn-in protection' : 'Einbrennschutz';
  String get offlineModeBurnInHint => _en
      ? 'Moves the clock a few pixels every couple of minutes, so hours of '
            'standing still do not burn the digits into the screen.'
      : 'Verschiebt die Uhr alle paar Minuten um wenige Pixel, damit sich '
            'die Ziffern bei stundenlangem Stehen nicht in den Bildschirm '
            'einbrennen.';
  String get offlineModeBatterySaver =>
      _en ? 'Battery saver' : 'Energiesparmodus';
  String get offlineModeBatterySaverHint => _en
      ? "Opens Android's own battery saver. An app is not allowed to switch "
            'it on by itself, so the switch is there, not here.'
      : 'Öffnet Androids eigenen Energiesparmodus. Eine App darf ihn nicht '
            'selbst einschalten, der Schalter sitzt also dort, nicht hier.';

  String get offlineModeMediaPermissionGranted =>
      _en ? 'Access granted' : 'Zugriff erteilt';

  String get position => _en ? 'Position' : 'Position';
  String get alignLeft => _en ? 'Left' : 'Links';
  String get alignCenter => _en ? 'Center' : 'Mittig';
  String get alignRight => _en ? 'Right' : 'Rechts';
  String distanceFromTop(int pixels) =>
      _en ? 'Distance from top ($pixels)' : 'Abstand von oben ($pixels)';
  String distanceFromSide(int pixels) =>
      _en ? 'Distance from edge ($pixels)' : 'Abstand vom Rand ($pixels)';
  String get appearanceCustom => _en ? 'Appearance' : 'Aussehen';
  String get backgroundColor => _en ? 'Background color' : 'Hintergrundfarbe';
  String backgroundStrength(int percent) =>
      _en ? 'Background strength ($percent%)' : 'Hintergrundstärke ($percent%)';
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

  String get pinnedBadges => _en ? 'Notifications' : 'Benachrichtigungen';
  String get pinnedBadgesHint => _en
      ? 'What a pinned app shows while notifications are waiting in it. A '
            'folder adds up everything inside it.'
      : 'Was eine angepinnte App zeigt, solange Benachrichtigungen in ihr '
            'warten. Ein Ordner zählt alles zusammen, was in ihm steckt.';
  String get pinnedBadgesOff => _en ? 'Nothing' : 'Nichts';
  String get pinnedBadgesOffHint =>
      _en ? 'As before - no mark' : 'Wie bisher - kein Zeichen';
  String get pinnedBadgesDot => _en ? 'A dot' : 'Ein Punkt';
  String get pinnedBadgesDotHint => _en
      ? 'Shows that something is there'
      : 'Zeigt, dass etwas da ist';
  String get pinnedBadgesCount => _en ? 'A number' : 'Eine Zahl';
  String get pinnedBadgesCountHint => _en
      ? 'How many are waiting, like on WhatsApp'
      : 'Wie viele warten, z. B. bei WhatsApp';
  String get pinnedBadgesColor => _en ? 'Badge color' : 'Farbe des Zeichens';
  String get pinnedBadgesPermission =>
      _en ? 'Allow notification access' : 'Benachrichtigungszugriff erlauben';
  String get pinnedBadgesPermissionHint => _en
      ? 'Android only tells an app what is waiting when it is switched on '
            'under "Notification access". Open that screen and switch '
            'hanneslauncher on. Only the number is read - no text, no sender.'
      : 'Android verrät einer App nur dann, was wartet, wenn sie unter '
            '"Benachrichtigungszugriff" eingeschaltet ist. Dort '
            'hanneslauncher einschalten. Gelesen wird nur die Anzahl - kein '
            'Text, kein Absender.';
  String get pinnedBadgesPermissionGranted =>
      _en ? 'Access granted' : 'Zugriff erteilt';
  String get pinnedBadgesPermissionStalled => _en
      ? 'Switched on, but nothing is arriving'
      : 'Eingeschaltet, es kommt aber nichts an';
  String get pinnedBadgesPermissionStalledHint => _en
      ? 'Android is not handing the notifications over - it usually stops '
            'after a new version has been installed over the old one. Open '
            '"Notification access", switch hanneslauncher off and on again, '
            'or restart the phone.'
      : 'Android reicht die Benachrichtigungen nicht durch - meistens nach '
            'einem Update, das über die alte Version installiert wurde. '
            '"Benachrichtigungszugriff" öffnen, hanneslauncher aus- und '
            'wieder einschalten, oder das Handy neu starten.';
  String get pinnedBadgesRestricted =>
      _en ? 'Open app settings' : 'App-Einstellungen öffnen';
  String get pinnedBadgesRestrictedHint => _en
      ? 'If the switch refuses to stay on: hanneslauncher is installed from '
            'a file, not a store, so Android blocks it as a restricted '
            'setting. Use "Allow restricted settings" in the menu at the top '
            'right of this page first.'
      : 'Falls sich der Schalter nicht einschalten lässt: hanneslauncher ist '
            'aus einer Datei installiert, nicht aus einem Store - Android '
            'sperrt das als eingeschränkte Einstellung. Zuerst im Menü oben '
            'rechts "Eingeschränkte Einstellungen zulassen" verwenden.';

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

  // App shortcuts: what an app publishes about itself - a chat, "new tab", a
  // playlist. "Verknüpfung" rather than "Shortcut" because that is the word
  // Android's own German uses for exactly these.
  String get appShortcuts => _en ? 'Shortcuts' : 'Verknüpfungen';
  String get noAppShortcuts =>
      _en ? 'This app has no shortcuts' : 'Diese App hat keine Verknüpfungen';
  String get appShortcutsNeedHomeApp => _en
      ? 'Android only hands shortcuts to the app the home button opens. Set '
            'hanneslauncher as the home app to see them.'
      : 'Android gibt Verknüpfungen nur an die App, die der Home-Button '
            'öffnet. Dafür muss hanneslauncher als Home-App eingestellt sein.';
  String get keepAppShortcut => _en ? 'Keep in launcher' : 'Im Launcher behalten';
  String get appShortcutKeptHint => _en
      ? 'Kept shortcuts sit in the app list under their own letter, go into '
            'folders and can be pinned to the home screen.'
      : 'Behaltene Verknüpfungen stehen in der App-Liste unter ihrem eigenen '
            'Buchstaben, passen in Ordner und lassen sich anpinnen.';
  String appShortcutKept(String name) =>
      _en ? '"$name" is now in the app list' : '„$name" steht jetzt in der App-Liste';
  String get appShortcutAlreadyKept => _en ? 'Already kept' : 'Schon behalten';
  String get removeAppShortcut =>
      _en ? 'Remove shortcut' : 'Verknüpfung entfernen';
  String get appShortcutFailed => _en
      ? 'This shortcut no longer works - the app has dropped it'
      : 'Diese Verknüpfung funktioniert nicht mehr - die App hat sie '
            'aufgegeben';

  // The secret folder. Deliberately without a count anywhere: a subtitle
  // saying "3 apps" would give away in the settings list - and in the
  // settings search - what the password is there to keep to itself.
  String get secretFolder => _en ? 'Secret folder' : 'Geheimer Ordner';
  String get secretFolderLocked =>
      _en ? 'Password protected' : 'Mit Passwort geschützt';
  String get secretFolderWarning => _en
      ? 'Hidden in this launcher only. The apps stay installed and visible in '
            "Android's settings, the recents switcher and the share sheet."
      : 'Nur in diesem Launcher versteckt. Die Apps bleiben installiert und '
            'in den Android-Einstellungen, im App-Wechsler und im '
            'Teilen-Menü sichtbar.';
  String get secretFolderNoRecovery => _en
      ? 'Right after this you get a recovery code. Without the password and '
            'without that code there is no way back in.'
      : 'Gleich danach bekommst du einen Wiederherstellungscode. Ohne '
            'Passwort und ohne diesen Code gibt es keinen Weg zurück.';
  String get setPassword => _en ? 'Set password' : 'Passwort festlegen';
  String get setNewPassword =>
      _en ? 'Set a new password' : 'Neues Passwort festlegen';

  // The recovery code. Shown exactly once, because only its hash is kept -
  // there is deliberately no way to look it up again later.
  String get recoveryCode => _en ? 'Recovery code' : 'Wiederherstellungscode';
  String get recoveryCodeIntro => _en
      ? 'Write this down somewhere that is not this phone. It is the only way '
            'into the folder if you forget the password, and it is shown this '
            'once - afterwards only a new code can be made.'
      : 'Schreib ihn auf, am besten nicht auf diesem Handy. Er ist der '
            'einzige Weg in den Ordner, wenn du das Passwort vergisst, und er '
            'wird nur dieses eine Mal angezeigt - danach kann man nur einen '
            'neuen erzeugen.';
  String get copyCode => _en ? 'Copy' : 'Kopieren';
  String get codeCopied => _en ? 'Copied' : 'Kopiert';
  String get savedTheCode => _en ? 'I saved it' : 'Habe ich gespeichert';
  String get newRecoveryCode =>
      _en ? 'New recovery code' : 'Neuen Code erzeugen';
  String get newRecoveryCodeNote => _en
      ? 'The code you had until now stops working.'
      : 'Der bisherige Code funktioniert danach nicht mehr.';
  String get forgotPassword =>
      _en ? 'Forgot password?' : 'Passwort vergessen?';
  String get enterRecoveryCode => _en
      ? 'Enter recovery code'
      : 'Wiederherstellungscode eingeben';
  String get wrongRecoveryCode =>
      _en ? 'This code does not match' : 'Dieser Code passt nicht';
  String get enterPassword => _en ? 'Enter password' : 'Passwort eingeben';
  String get changePassword => _en ? 'Change password' : 'Passwort ändern';
  String get passwordChanged => _en ? 'Password changed' : 'Passwort geändert';
  String get passwordLabel => _en ? 'Password' : 'Passwort';
  String get passwordRepeatLabel =>
      _en ? 'Repeat password' : 'Passwort wiederholen';
  String get passwordsDiffer => _en
      ? 'The two entries are not the same'
      : 'Die beiden Eingaben sind nicht gleich';
  String get wrongPassword => _en ? 'Wrong password' : 'Falsches Passwort';
  String get secretFolderEmpty =>
      _en ? 'No app in here yet' : 'Noch keine App hier drin';
  String get addToSecretFolder => _en ? 'Add app' : 'App hinzufügen';
  String get whichApp => _en ? 'Which app?' : 'Welche App?';
  String get removeFromSecretFolder =>
      _en ? 'Show normally again' : 'Wieder normal anzeigen';
  String get secretAppUnpinned => _en
      ? 'Also removed from the home screen'
      : 'Auch vom Homescreen entfernt';
  String get openApp => _en ? 'Open' : 'Öffnen';

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
  String get webAppBrowser => 'Browser';
  String get chooseBrowser => _en ? 'Choose browser' : 'Browser auswählen';
  String get systemDefaultBrowser => _en ? 'System default' : 'Systemstandard';
  String get noBrowsersFound =>
      _en ? 'No browsers found' : 'Keine Browser gefunden';

  String get addBlock => _en ? 'Add' : 'Hinzufügen';
  String get blockWidget => 'Widget';
  String get blockAppRow => _en ? 'Apps' : 'Apps';
  String get blockAppRowTitle => _en ? 'App row' : 'App-Reihe';
  String get blockCalendar => _en ? 'Calendar' : 'Kalender';
  String get blockCalendarTitle =>
      _en ? 'Upcoming events from the device' : 'Anstehende Termine vom Gerät';
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
  String get blockNotes => _en ? 'Notes' : 'Notizen';
  String get blockNotesTitle =>
      _en ? 'A written note with formatting' : 'Eine Notiz mit Formatierung';

  // Code widgets: a block written in HTML, CSS and JavaScript instead of
  // assembled from elements.
  String get blockCode => 'Code';
  String get blockCodeTitle => _en
      ? 'Your own widget in HTML, CSS and JavaScript'
      : 'Eigenes Widget aus HTML, CSS und JavaScript';
  String get codeWidgets => _en ? 'Code widgets' : 'Code-Widgets';
  String codeWidgetsSubtitle(int count) => count == 0
      ? (_en ? 'None yet' : 'Noch keine')
      : (_en
            ? '$count ${count == 1 ? 'widget' : 'widgets'}'
            : '$count Widget${count == 1 ? '' : 's'}');
  String get codeWidgetName => _en ? 'Name' : 'Name';
  String get addCodeWidget => _en ? 'New code widget' : 'Neues Code-Widget';
  String get emptyCodeWidget => _en
      ? 'Empty code widget - open it in the settings to write in it'
      : 'Leeres Code-Widget - in den Einstellungen zum Schreiben öffnen';
  String get noCodeWidgets => _en
      ? 'No code widgets yet. The "+" on the panel creates one, and so does '
            'the button below.'
      : 'Noch keine Code-Widgets. Das "+" im Panel legt eines an, der Knopf '
            'unten auch.';

  String get codeTemplate => _en ? 'Starting point' : 'Vorlage';
  String get codeTemplateEmpty => _en ? 'Empty' : 'Leer';
  String get codeTemplateEmptyHint =>
      _en ? 'A heading and a line of text' : 'Eine Überschrift und eine Zeile';
  String get codeTemplateButton => _en ? 'Buttons' : 'Knöpfe';
  String get codeTemplateButtonHint => _en
      ? 'A counter that survives a restart'
      : 'Ein Zähler, der den Neustart übersteht';
  String get codeTemplateData => _en ? 'Data source' : 'Datenquelle';
  String get codeTemplateDataHint => _en
      ? 'Shows a value and keeps it current'
      : 'Zeigt einen Wert an und hält ihn aktuell';
  String get codeTemplateGallery => _en ? 'Pictures' : 'Bilder';
  String get codeTemplateGalleryHint => _en
      ? 'Tap through uploaded pictures'
      : 'Hochgeladene Bilder durchtippen';
  String get codeTemplateGame => _en ? 'Small game' : 'Kleines Spiel';
  String get codeTemplateGameHint =>
      _en ? 'Hit the dot, on a canvas' : 'Triff den Punkt, auf einem Canvas';

  String get codeFiles => _en ? 'Files' : 'Dateien';
  String get codeCard => _en ? 'Card' : 'Karte';
  String get codeConsole => _en ? 'Output' : 'Ausgabe';
  String get codeConsoleEmpty => _en
      ? 'Errors and console.log appear here'
      : 'Fehler und console.log erscheinen hier';
  String get codeUploadImage => _en ? 'Upload picture' : 'Bild hochladen';
  String get codeNewTextFile => _en ? 'New text file' : 'Textdatei anlegen';
  String get codeFileName => _en ? 'File name' : 'Dateiname';
  String get codeNoFiles => _en
      ? 'No files yet. Uploaded files sit next to the code and are '
            'referenced by their plain name.'
      : 'Noch keine Dateien. Hochgeladene Dateien liegen neben dem Code und '
            'werden einfach über ihren Namen angesprochen.';
  String get codeInsertFile => _en ? 'Insert into HTML' : 'Ins HTML einfügen';
  String get codeRenameFile => _en ? 'Rename' : 'Umbenennen';
  String get codeEditFile => _en ? 'Edit' : 'Bearbeiten';
  String get codeFileRenamed => _en
      ? 'Renamed - references to the old name no longer find it'
      : 'Umbenannt - Verweise auf den alten Namen finden sie nicht mehr';
  String get codeFileInserted =>
      _en ? 'Inserted into the HTML' : 'Ins HTML eingefügt';
  String get codeFileTooBigForBackup => _en
      ? 'Too big for the backup'
      : 'Zu groß fürs Backup';
  String get codeFileInBackup => _en ? 'In the backup' : 'Im Backup';
  String get codeTransparent =>
      _en ? 'Draw without a card' : 'Ohne Karte zeichnen';
  String get codeTransparentHint => _en
      ? 'The page paints the whole area itself - for a game or a picture '
            'that should reach the edges.'
      : 'Die Seite malt die ganze Fläche selbst - für ein Spiel oder ein '
            'Bild, das bis an den Rand gehen soll.';
  String get codeScrollHint => _en
      ? 'The page itself does not scroll: a drag on the card scrolls the '
            'panel. Set the card to grow if the contents need more room.'
      : 'Die Seite selbst scrollt nicht: Ein Wisch auf der Karte scrollt das '
            'Panel. Für mehr Inhalt die Karte mitwachsen lassen.';
  String get codeHelp => _en ? 'What launcher can do' : 'Was launcher kann';
  String get codeHelpBody => _en
      ? 'launcher.get("weather.current.temperature_2m") reads a value from '
            'your data sources, launcher.data("weather") hands over the whole '
            'response, and launcher.fill("{{time}}") fills in placeholders '
            'the way the widget cards do.\n\n'
            'In the HTML, <span data-value="battery"></span> shows a value '
            'and keeps it current without a line of JavaScript.\n\n'
            'launcher.fetch(url, {useSource: "weather"}) makes your own API '
            'call through the launcher - no CORS, plain http allowed, and '
            'the API key stays in the data source instead of in the code.\n\n'
            'launcher.store(name, value) and launcher.load(name) remember '
            'something across a restart. launcher.open("com.example.app") '
            'opens an app, launcher.openUrl(address) hands an address to the '
            'phone, launcher.toast(text) says something briefly.\n\n'
            'launcher.onUpdate(fn) runs whenever new data has arrived.\n\n'
            'The whole thing, with examples, is in CODE_WIDGETS.md in the '
            'project.'
      : 'launcher.get("wetter.current.temperature_2m") liest einen Wert aus '
            'deinen Datenquellen, launcher.data("wetter") gibt die ganze '
            'Antwort her, und launcher.fill("{{zeit}}") setzt Platzhalter ein '
            'wie auf den Widget-Karten.\n\n'
            'Im HTML zeigt <span data-value="akku"></span> einen Wert an und '
            'hält ihn aktuell, ganz ohne JavaScript.\n\n'
            'launcher.fetch(adresse, {useSource: "wetter"}) macht einen '
            'eigenen API-Aufruf über den Launcher - kein CORS, einfaches '
            'http erlaubt, und der API-Schlüssel bleibt in der Datenquelle '
            'statt im Code.\n\n'
            'launcher.store(name, wert) und launcher.load(name) merken sich '
            'etwas über den Neustart hinweg. launcher.open("com.beispiel.app") '
            'öffnet eine App, launcher.openUrl(adresse) gibt eine Adresse ans '
            'Handy weiter, launcher.toast(text) sagt kurz Bescheid.\n\n'
            'launcher.onUpdate(fn) läuft, sobald neue Daten da sind.\n\n'
            'Alles ausführlich, mit Beispielen, steht in CODE_WIDGETS.md im '
            'Projekt.';
  String get codeLinkHint => _en
      ? 'A code widget has no "open on tap": the card is the page, so a tap '
            'belongs to it. launcher.open("com.example.app") on a button of '
            'your own does the same thing.'
      : 'Ein Code-Widget hat kein "Beim Antippen öffnen": Die Karte ist die '
            'Seite, ein Tipp gehört also ihr. launcher.open("com.beispiel.app") '
            'auf einem eigenen Knopf macht dasselbe.';
  String get noteName => _en ? 'Note name' : 'Notiz-Name';
  String get openNote => _en ? 'Open note' : 'Notiz öffnen';
  String get emptyNote =>
      _en ? 'Empty note - tap to write' : 'Leere Notiz - zum Schreiben tippen';
  String get noteHint => _en ? 'Write something…' : 'Schreib etwas…';
  String get formatLabel => _en ? 'Format' : 'Formatieren';
  String get closeFormat => _en ? 'Close' : 'Schließen';
  String get deleteLine => _en ? 'Delete line' : 'Zeile löschen';
  String get styleTitle => _en ? 'Title' : 'Titel';
  String get styleHeading => _en ? 'Heading' : 'Überschrift';
  String get styleText => _en ? 'Text' : 'Text';
  String get styleNote => _en ? 'Annotation' : 'Anmerkung';
  String get italicLabel => _en ? 'Italic' : 'Kursiv';
  String get strikethroughLabel => _en ? 'Strikethrough' : 'Durchgestrichen';
  String get underlineLabel => _en ? 'Underline' : 'Unterstrichen';
  String get underlineColor => _en ? 'Underline color' : 'Unterstrich-Farbe';
  String get highlightColor => _en ? 'Highlight' : 'Markierfarbe';
  String get noColor => _en ? 'None' : 'Keine';
  String get bulletList => _en ? 'Bullet list' : 'Aufzählung';
  String get numberedList => _en ? 'Numbered list' : 'Nummerierung';
  String get checklist => _en ? 'Checklist' : 'Checkliste';
  String get weightLabel => _en ? 'Weight' : 'Dicke';
  String get fontSizeLabel => _en ? 'Size' : 'Größe';

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
  String get emptyWidget => _en
      ? 'Empty widget - hold to edit'
      : 'Leeres Widget - halten zum Bearbeiten';
  String get widgetTitle => _en ? 'Widget name' : 'Widget-Name';
  String get addElement => _en ? 'Add line' : 'Zeile hinzufügen';
  String get elementText => _en ? 'Text' : 'Text';
  String get elementIcon => _en ? 'Icon by rule' : 'Symbol nach Regel';
  String get elementImage => _en ? 'Picture' : 'Bild';
  String get elementBox => _en ? 'Box' : 'Fläche';
  String get elementAction => _en ? 'Action button' : 'Aktions-Button';
  String get elementInput => _en ? 'Input field' : 'Eingabefeld';
  String get elementResults => _en ? 'Search results' : 'Suchergebnisse';

  // One line each in the "add a line" dialog. Seven types with nothing but
  // their names is a list you have to try your way through.
  String get elementTextWhat => _en
      ? 'A line of text, or a value from a source'
      : 'Eine Zeile Text, oder ein Wert aus einer Quelle';
  String get elementIconWhat => _en
      ? 'A symbol that changes with a value'
      : 'Ein Symbol, das sich mit einem Wert ändert';
  String get elementImageWhat =>
      _en ? 'A picture from a web address' : 'Ein Bild von einer Web-Adresse';
  String get elementBoxWhat => _en
      ? 'A coloured area - behind text it makes it readable'
      : 'Eine farbige Fläche - hinter Text macht sie ihn lesbar';
  String get elementActionWhat => _en
      ? 'Sends a request, opens an address, or searches'
      : 'Schickt eine Anfrage, öffnet eine Adresse, oder sucht';
  String get elementInputWhat => _en
      ? 'A field to type in'
      : 'Ein Feld zum Reintippen';
  String get elementResultsWhat => _en
      ? 'Apps, settings, contacts and sums for what is typed'
      : 'Apps, Einstellungen, Kontakte und Rechnungen zum Getippten';

  // Search element - the tick boxes, and the rows they produce.
  String get searchWatchesField => _en ? 'Searches with' : 'Sucht mit';
  String get searchWatchesFieldHint => _en
      ? 'The input field whose text is searched for. Add an input field to '
            'the card first.'
      : 'Das Eingabefeld, dessen Text gesucht wird. Dafür zuerst ein '
            'Eingabefeld auf die Karte legen.';
  String get searchNoFieldYet => _en
      ? 'No input field on any card yet'
      : 'Noch kein Eingabefeld auf einer Karte';
  String get searchSourcesLabel => _en ? 'Search in' : 'Suchen in';
  String get searchSourceApps => 'Apps';
  String get searchSourceSettings => _en ? 'Settings' : 'Einstellungen';
  String get searchSourceCalculation => _en ? 'Sums' : 'Rechnen';
  String get searchSourceContacts => _en ? 'Contacts' : 'Kontakte';
  String get searchSourceAppsHint => _en
      ? 'Apps, folders and web apps - tapping one opens it'
      : 'Apps, Ordner und Web-Apps - Antippen öffnet sie';
  String get searchSourceSettingsHint => _en
      ? 'Every setting this launcher has, straight to the right screen'
      : 'Jede Einstellung dieses Launchers, direkt zum passenden Bildschirm';
  String get searchSourceCalculationHint => _en
      ? 'Typing 12*7 answers 84. Words are left alone.'
      : '12*7 eingetippt ergibt 84. Wörter bleiben unangetastet.';
  String get searchSourceContactsHint => _en
      ? 'Android asks for permission the first time you search - tapping a '
            'result puts the number in the dialer, it does not call'
      : 'Android fragt beim ersten Suchen nach der Berechtigung - ein '
            'Treffer legt die Nummer in die Telefon-App, ruft aber nicht an';
  String get searchWebLabel => _en ? 'Web search' : 'Web-Suche';
  String get searchWebNone => _en ? 'None' : 'Keine';
  String get searchWebOwn => _en ? 'Own address' : 'Eigene Adresse';
  String get searchWebOwnHint => _en
      ? 'Put {{suche}} where the typed words belong'
      : '{{suche}} dorthin setzen, wo die eingetippten Wörter hingehören';
  String searchOnTheWeb(String query) =>
      _en ? 'Search the web: $query' : 'Im Web suchen: $query';
  String get searchResultLimit => _en ? 'Rows per kind' : 'Zeilen pro Art';
  String get searchNothingFound => _en ? 'Nothing found' : 'Nichts gefunden';
  String get searchTypeSomething =>
      _en ? 'Type something' : 'Tipp etwas ein';

  // Text element - where its line comes from.
  String get textModeLabel => _en ? 'Shows' : 'Zeigt';
  String get textModeFree => _en ? 'Own text' : 'Eigener Text';
  String get textModeInputValue =>
      _en ? 'What is in a field' : 'Inhalt eines Feldes';
  String get textModeCalculation =>
      _en ? 'Result of a sum' : 'Ergebnis einer Rechnung';
  String get textModeCalculationHint => _en
      ? 'Reads the field as a sum and shows the answer - empty while it '
            'isn\'t one. This is the calculator display.'
      : 'Liest das Feld als Rechnung und zeigt das Ergebnis - leer, solange '
            'es keine ist. Das ist die Rechner-Anzeige.';
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
  String get iconTemplateTitle => _en ? 'Start from' : 'Ausgangspunkt';
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
  String get testAnotherValue => _en ? 'Test a value' : 'Einen Wert testen';
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
  String get cardHeightFixed => _en ? 'Fixed' : 'Fest';
  String get cardHeightFlexible => _en ? 'Flexible' : 'Flexibel';
  String get cardHeightFixedHint => _en
      ? 'Always exactly this tall, however much or little is on it'
      : 'Immer genau so hoch, egal wie viel oder wenig drauf ist';
  String get cardHeightFlexibleHint => _en
      ? 'As short as its contents allow, growing only when they need it - '
            'between the two heights below'
      : 'So flach wie möglich, wächst nur wenn der Inhalt es braucht - '
            'zwischen den beiden Höhen unten';
  String get cardMinHeightLabel => _en ? 'At least' : 'Mindestens';
  String get cardMaxHeightLabel => _en ? 'At most' : 'Höchstens';
  String get searchMaxHeight =>
      _en ? 'Height of the list' : 'Höhe der Liste';
  String get searchMaxHeightHint => _en
      ? 'The list never grows past this - once the rows need more, it '
            'scrolls instead of running over the rest of the card'
      : 'Die Liste wird nie höher - reichen die Zeilen nicht, scrollt sie, '
            'statt über den Rest der Karte zu laufen';
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
  String get sourceKeyHint => _en
      ? 'used in placeholders, e.g. weather'
      : 'für Platzhalter, z.B. wetter';
  String get sourceName => _en ? 'Name' : 'Name';
  String get sourceUrl => 'URL';
  String get sourceHeaders => _en
      ? 'Headers (one per line, name: value)'
      : 'Header (pro Zeile, Name: Wert)';
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

  // The design: one theme for everything the launcher draws itself - the
  // panel, the settings, the dialogs. The clock, the app list and the
  // wallpaper are left out on purpose and keep their own colors, because
  // they sit on top of the picture rather than on anything this theme paints.
  String get design => 'Design';
  String get designSubtitle => _en
      ? 'Theme, corners, shadows, spacing, text size'
      : 'Thema, Rundung, Schatten, Abstände, Schriftgröße';
  String get designScopeHint => _en
      ? 'Applies to the panel, the settings and dialogs. Clock, app list and '
            'wallpaper keep their own colors.'
      : 'Gilt für das Panel, die Einstellungen und Dialoge. Uhr, App-Liste '
            'und Hintergrundbild behalten ihre eigenen Farben.';

  String get designThemeLabel => _en ? 'Color theme' : 'Farbthema';
  String get designThemeGrey => _en ? 'Grey' : 'Grau';
  String get designThemeRose => _en ? 'Rose' : 'Rosa';
  String get designThemeGreen => _en ? 'Green' : 'Grün';
  String get designThemeBlue => _en ? 'Blue' : 'Blau';
  String get designThemeDark => _en ? 'Dark' : 'Dunkel';

  String get designColors => _en ? 'Colors' : 'Farben';
  String get designColorsHint => _en
      ? 'Tap a color to set it yourself. Picking a theme above puts all six '
            'back.'
      : 'Auf eine Farbe tippen, um sie selbst zu setzen. Ein Thema oben setzt '
            'alle sechs wieder zurück.';
  String get designRoleBackground => _en ? 'Ground' : 'Untergrund';
  String get designRoleSurface => _en ? 'Cards' : 'Karten';
  String get designRoleTextPrimary => _en ? 'Text' : 'Text';
  String get designRoleTextSecondary =>
      _en ? 'Text, quieter' : 'Text, leiser';
  String get designRoleAccent => _en ? 'Accent' : 'Akzent';
  String get designRoleBorder => _en ? 'Lines' : 'Linien';
  String get designResetColors =>
      _en ? 'Colors back to the theme' : 'Farben zurück auf das Thema';

  String get designFieldStyle => _en ? 'Input fields' : 'Eingabefelder';
  String get designFieldLine => _en ? 'Line' : 'Linie';
  String get designFieldBox => _en ? 'Box' : 'Rahmen';
  String get designFieldPlain => _en ? 'Tinted' : 'Fläche';
  String get designFieldHint => _en
      ? 'Applies to every text field in the app - search, names, addresses, '
            'the code editor.'
      : 'Gilt für jedes Eingabefeld der App - Suche, Namen, Adressen, den '
            'Code-Editor.';
  String get designFieldSample => _en ? 'Type here' : 'Hier tippen';

  String get designShape => _en ? 'Shape & spacing' : 'Form & Abstand';
  String designRounding(int pixels) =>
      _en ? 'Rounding ($pixels px)' : 'Rundung ($pixels px)';
  String get designRoundingHint => _en
      ? 'Sets the roundest surfaces; smaller cards and controls follow at a '
            'half and a quarter of it, so the order between them holds.'
      : 'Gilt für die rundesten Flächen; kleinere Karten und Bedienelemente '
            'folgen mit der Hälfte und einem Viertel davon, damit die '
            'Abstufung bleibt.';
  String designShadow(String strength) =>
      _en ? 'Shadows ($strength)' : 'Schatten ($strength)';
  String get designShadowOff => _en ? 'off' : 'aus';
  String get designShadowSubtle => _en ? 'subtle' : 'dezent';
  String get designShadowNormal => _en ? 'normal' : 'normal';
  String get designShadowStrong => _en ? 'strong' : 'stark';
  String designSpacing(int percent) =>
      _en ? 'Spacing ($percent%)' : 'Abstände ($percent%)';
  String designCardSize(int percent) =>
      _en ? 'Card height ($percent%)' : 'Kartenhöhe ($percent%)';
  String designFontSize(int percent) =>
      _en ? 'Text size ($percent%)' : 'Schriftgröße ($percent%)';
  String designPanelOpacity(int percent) =>
      _en ? 'Panel opacity ($percent%)' : 'Deckkraft des Panels ($percent%)';
  String get designPanelOpacityHint => _en
      ? 'How much of the wallpaper shows through the panel and its cards.'
      : 'Wie viel vom Hintergrundbild durch das Panel und seine Karten '
            'scheint.';

  String designMotion(String speed) =>
      _en ? 'Motion ($speed)' : 'Bewegung ($speed)';
  String get designMotionOff => _en ? 'off' : 'aus';
  String get designMotionBrisk => _en ? 'brisk' : 'flott';
  String get designMotionNormal => _en ? 'normal' : 'normal';
  String get designMotionCalm => _en ? 'calm' : 'ruhig';
  String get designMotionHint => _en
      ? 'How long a theme change, a page or a card takes to move. Off makes '
            'everything switch at once.'
      : 'Wie lange ein Themenwechsel, eine Seite oder eine Karte zum Bewegen '
            'braucht. Aus schaltet alles sofort um.';

  String designHaptics(String strength) =>
      _en ? 'Haptics ($strength)' : 'Haptik ($strength)';
  String get designHapticsOff => _en ? 'off' : 'aus';
  String get designHapticsSoft => _en ? 'soft' : 'sanft';
  String get designHapticsNormal => _en ? 'normal' : 'normal';
  String get designHapticsFirm => _en ? 'firm' : 'kräftig';
  String get designHapticsLabel => _en ? 'Haptics' : 'Haptik';
  String get designHapticsHint => _en
      ? 'How hard the phone answers a touch: the letter bar, a long press, '
            'the panel snapping open. The slider itself uses it, so dragging '
            'it is the preview.'
      : 'Wie stark das Handy auf eine Berührung antwortet: die '
            'Buchstabenleiste, ein langer Druck, das einrastende Panel. Der '
            'Regler selbst nutzt sie, Ziehen ist also die Vorschau.';

  String get designTypography => _en ? 'Type' : 'Schrift';
  String get designTypeSample =>
      _en ? 'The clock on the home screen' : 'Die Uhr auf dem Homescreen';
  String get designDepth => _en ? 'Shape & depth' : 'Form & Tiefe';
  String get designSpaceGroup => _en ? 'Spacing & size' : 'Abstand & Größe';
  String get designMotionLabel => _en ? 'Motion' : 'Bewegung';
  String get designMotionDemo => _en ? 'Tap me' : 'Antippen';

  String get designPreview => _en ? 'Preview' : 'Vorschau';
  String get designPreviewHero => _en ? 'Large' : 'Groß';
  String get designPreviewNormal => _en ? 'Normal' : 'Normal';
  String get designPreviewCompact => _en ? 'Small' : 'Klein';
  String get designPreviewBody => _en
      ? 'Three sizes of surface, so what matters reads as bigger without '
            'anything having to be hidden.'
      : 'Drei Flächengrößen - damit Wichtiges größer wirkt, ohne dass etwas '
            'verschwinden muss.';
  String get designPreviewSelected => _en ? 'Selected' : 'Ausgewählt';
  String get designReset => _en ? 'Reset the design' : 'Design zurücksetzen';

  String get iconTheme => _en ? 'Icon design' : 'Icon-Design';
  String get iconThemeSubtitle => _en
      ? 'Standard, icon pack or one color'
      : 'Standard, Icon-Paket oder eine Farbe';
  String get iconThemeHint => _en
      ? 'The original icons are kept - switching back to standard brings '
            'them straight back.'
      : 'Die Original-Icons bleiben erhalten - zurück auf Standard sind sie '
            'sofort wieder da.';

  String get iconStyleSystem => _en ? 'Standard' : 'Standard';
  String get iconStyleSystemHint => _en
      ? 'The icon every app brings along itself.'
      : 'Das Icon, das jede App selbst mitbringt.';
  String get iconStylePack => _en ? 'Icon pack' : 'Icon-Paket';
  String get iconStylePackHint => _en
      ? 'An icon pack installed on the phone redraws every app it covers.'
      : 'Ein installiertes Icon-Paket zeichnet jede App neu, die es kennt.';
  String get iconStyleColor => _en ? 'Colored' : 'Farbig';
  String get iconStyleColorHint => _en
      ? 'Every icon in one and the same color.'
      : 'Jedes Icon in ein und derselben Farbe.';
  String get iconStyleCustom => _en ? 'Own picture' : 'Eigenes Bild';
  String get iconStyleCustomHint => _en
      ? 'A picture from the gallery, per app. It always wins over the style '
            'above - remove it and the app follows the style again.'
      : 'Ein Bild aus der Galerie, pro App. Es geht immer vor - wird es '
            'entfernt, folgt die App wieder dem Stil oben.';

  String get iconPackChoose => _en ? 'Icon pack' : 'Icon-Paket';
  String get iconPackNone => _en
      ? 'No icon pack installed'
      : 'Kein Icon-Paket installiert';
  String get iconPackNoneHint => _en
      ? 'Icon packs are normal apps - install one from the store and it '
            'shows up here.'
      : 'Icon-Pakete sind normale Apps - eines aus dem Store installieren, '
            'dann steht es hier.';
  String get iconPackFormats => _en ? 'Recognised packs' : 'Erkannte Pakete';
  String get iconPackFormatsHint => _en
      ? 'A pack is recognised when it announces itself as one of these. '
            'Almost every pack in the store names several, so most simply '
            'work - if one is missing here, this is the list it failed to '
            'match.'
      : 'Ein Paket wird erkannt, wenn es sich als eines davon ausgibt. Fast '
            'jedes Paket aus dem Store nennt mehrere, deshalb funktionieren '
            'die meisten einfach - fehlt eines hier, passt es zu keinem '
            'dieser Einträge.';
  String iconPackCovered(int covered, int total) => _en
      ? '$covered of $total apps come from the pack'
      : '$covered von $total Apps kommen aus dem Paket';
  String get iconPackWorking =>
      _en ? 'Applying the pack...' : 'Paket wird angewendet...';
  String get iconPackRefresh => _en ? 'Apply again' : 'Neu anwenden';
  String get iconPackRefreshHint => _en
      ? 'After the pack itself was updated.'
      : 'Nachdem das Paket selbst aktualisiert wurde.';
  String get iconPackRest => _en
      ? 'Apps the pack does not know keep their own icon.'
      : 'Apps, die das Paket nicht kennt, behalten ihr eigenes Icon.';

  String iconPickedCount(int count) => _en
      ? '$count apps have a picture of their own'
      : '$count Apps haben ein eigenes Bild';
  String get iconPickedNone => _en
      ? 'No app has a picture of its own yet'
      : 'Noch hat keine App ein eigenes Bild';
  String get iconPickedEdit => _en ? 'Pick per app' : 'Pro App auswählen';
  String get iconPickedClear =>
      _en ? 'Remove all own pictures' : 'Alle eigenen Bilder entfernen';
  String get iconPickedClearConfirm => _en
      ? 'Every picked picture is removed and those apps follow the icon '
            'style again. Renames are kept.'
      : 'Jedes ausgewählte Bild wird entfernt, die Apps folgen dann wieder '
            'dem Icon-Stil. Umbenennungen bleiben.';

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
  String get emptyFolder =>
      _en ? 'This folder is empty' : 'Dieser Ordner ist leer';
  String get noFolders => _en
      ? 'No folders yet. Add one with the button below - it then shows up in '
            'the app list and can be pinned to the home screen.'
      : 'Noch keine Ordner. Unten einen hinzufügen - er erscheint dann in der '
            'App-Liste und kann auf den Homescreen gepinnt werden.';
  String get nameRequired => _en ? 'A name is required' : 'Ein Name ist nötig';
  String get deleteFolder => _en ? 'Delete folder' : 'Ordner löschen';
  String get folderCycleBlocked => _en
      ? "A folder can't be put inside itself"
      : 'Ein Ordner kann nicht in sich selbst';

  String get languageLabel => _en ? 'Language' : 'Sprache';
  String get languageSubtitle => _en ? 'App language' : 'App-Sprache';
  String get german => 'Deutsch';
  String get english => 'English';
  String get languageSystem => _en ? 'System language' : 'Sprache des Systems';
  String languageSystemSubtitle(String language) =>
      _en ? 'System language · $language' : 'Sprache des Systems · $language';

  // Making this the home app happens outside the app, in a system dialog or
  // a settings screen whose path differs by manufacturer - so besides the
  // button there is written help for when neither opens.
  String get defaultLauncher => _en ? 'Default home app' : 'Standard-Start-App';
  String get defaultLauncherIsDefault => _en
      ? 'This launcher opens with the home button'
      : 'Dieser Launcher öffnet sich mit der Home-Taste';
  String defaultLauncherCurrently(String name) =>
      _en ? 'Currently: $name' : 'Zurzeit: $name';
  String get defaultLauncherNone =>
      _en ? 'No home app set' : 'Keine Start-App festgelegt';
  String get defaultLauncherCardTitle =>
      _en ? 'Not the home app yet' : 'Noch nicht die Standard-Start-App';
  String get defaultLauncherCardText => _en
      ? 'Until it is, the home button keeps opening the old launcher.'
      : 'Bis dahin öffnet die Home-Taste weiter den alten Launcher.';
  String get setAsDefaultLauncher =>
      _en ? 'Set as default' : 'Als Standard festlegen';
  String get defaultLauncherHowTo => _en ? 'How it works' : 'Wie das geht';
  String get defaultLauncherSteps => _en
      ? '1. Tap "Set as default".\n\n'
            '2. If a dialog asks which app to use as the home app, pick '
            'hanneslauncher and confirm.\n\n'
            '3. If a settings screen opens instead, tap hanneslauncher in '
            'the list there.'
      : '1. Auf „Als Standard festlegen" tippen.\n\n'
            '2. Fragt ein Dialog, welche App die Start-App sein soll, dort '
            'hanneslauncher auswählen und bestätigen.\n\n'
            '3. Öffnet sich stattdessen ein Einstellungsbildschirm, dort '
            'hanneslauncher in der Liste antippen.';
  String get defaultLauncherManual => _en
      ? 'If nothing opens, it works by hand as well: Settings → Apps → '
            'Default apps → Home app. Depending on the phone that entry is '
            'called "Launcher", "Home screen" or "Home app".'
      : 'Öffnet sich nichts, geht es auch von Hand: Einstellungen → Apps → '
            'Standard-Apps → Start-App. Je nach Handy heißt der Eintrag '
            '„Launcher", „Startbildschirm" oder „Home-App".';
  String get later => _en ? 'Later' : 'Später';
  String get defaultLauncherFindAgain => _en
      ? 'You can do this later at any time under Settings → App → Default '
            'home app.'
      : 'Das geht später jederzeit unter Einstellungen → App → '
            'Standard-Start-App.';
  String get defaultLauncherOpenFailed => _en
      ? 'Android did not offer a screen for this - see the steps below'
      : 'Android hat dafür keinen Bildschirm angeboten - siehe die Schritte '
            'darunter';

  String get backup => _en ? 'Backup' : 'Sicherung';
  String get backupSubtitle => _en
      ? 'Export or import all settings as a file'
      : 'Alle Einstellungen als Datei exportieren oder importieren';
  // The notification block on the panel (notifications_block_view.dart).
  String get notifications => _en ? 'Notifications' : 'Benachrichtigungen';
  String get notificationsHint => _en
      ? 'What is waiting, on the panel. Tap one to go where it points, swipe '
            'to clear it. Nothing is stored and nothing leaves the phone - '
            'the list is read when the panel opens and dropped when it '
            'closes.'
      : 'Was wartet, im Panel. Antippen führt dorthin, wo sie hinzeigt, '
            'Wischen räumt sie weg. Nichts wird gespeichert und nichts '
            'verlässt das Handy - die Liste wird beim Öffnen des Panels '
            'gelesen und beim Schließen verworfen.';
  String get notificationsNoneWaiting =>
      _en ? 'Nothing waiting' : 'Nichts wartet';
  String notificationsMore(int count) =>
      _en ? '+$count more' : '+$count weitere';
  String get notificationsCount => _en ? 'How many to show' : 'Wie viele zeigen';

  // App pairs: two apps side by side, as one entry
  // (app_pairs_settings_screen.dart).
  String get appPairs => _en ? 'App pairs' : 'App-Paare';
  /// The one-liner for the settings list. [appPairsHint] is the long form,
  /// and it stays on the pairs screen itself.
  String get appPairsSubtitle => _en
      ? 'Two apps side by side, as one entry'
      : 'Zwei Apps nebeneinander, als ein Eintrag';
  String get appPairsHint => _en
      ? 'Two apps that open side by side in split screen, as one entry. It '
            'goes in the app list, into folders, onto the home screen and '
            'onto a drawn shape, like anything else.'
      : 'Zwei Apps, die nebeneinander im geteilten Bildschirm aufgehen, als '
            'ein Eintrag. Er kommt in die App-Liste, in Ordner, auf den '
            'Homescreen und auf eine gezeichnete Form, wie alles andere '
            'auch.';
  String get appPairsNone =>
      _en ? 'No pairs yet' : 'Noch keine Paare';
  String get appPairsUnsupported => _en
      ? 'This phone has no split screen, so a pair would only open the first '
            'of the two apps.'
      : 'Dieses Handy hat keinen geteilten Bildschirm - ein Paar würde nur '
            'die erste der beiden Apps öffnen.';
  String get appPairPickFirst => _en ? 'First app' : 'Erste App';
  String get appPairPickSecond => _en ? 'Second app' : 'Zweite App';
  String get appPairName => _en ? 'Name' : 'Name';

  // The magnifier at the bottom of the alphabet bar - which piles it looks
  // through besides the apps (app_list_settings_screen.dart).
  String get searchSection => _en ? 'Search' : 'Suche';
  String get searchSectionHint => _en
      ? 'What the magnifier looks through besides your apps, folders and web '
            'apps.'
      : 'Was die Lupe außer Apps, Ordnern und Web-Apps noch durchsucht.';
  String get searchExtras =>
      _en ? 'Sums and settings' : 'Rechnen und Einstellungen';
  String get searchExtrasHint => _en
      ? 'Type 35*1.19 for the answer, or part of a setting name to jump '
            'straight to it. Neither needs a permission or the internet.'
      : 'Tippe 35*1.19 für das Ergebnis, oder einen Teil eines '
            'Einstellungsnamens, um direkt dorthin zu springen. Beides '
            'braucht weder Berechtigung noch Internet.';
  String get searchContacts => _en ? 'Contacts' : 'Kontakte';
  String get searchContactsHint => _en
      ? 'Finds a person by name and taps through to the dialer. Asks for the '
            'contacts permission the first time it is used, not now.'
      : 'Findet eine Person über den Namen und geht per Tipp zum Wähler. '
            'Fragt beim ersten Benutzen nach der Kontakt-Berechtigung, nicht '
            'jetzt.';
  String get searchWebUrl => _en ? 'Web search' : 'Web-Suche';
  String get searchWebUrlHint => _en
      ? 'The last row, when nothing here matched. Put {{suche}} where the '
            'typed words belong. Empty leaves the row out.'
      : 'Die letzte Zeile, wenn hier nichts passt. {{suche}} dort '
            'hinschreiben, wo die getippten Wörter hingehören. Leer lässt die '
            'Zeile weg.';

  String get backupHint => _en
      ? 'Holds the clock, widgets, panel, pinned apps, folders, web apps, '
            'kept shortcuts, data sources, device data packages, custom '
            'colors, app renames, the design and the language. The code '
            'widgets come along with their HTML, CSS and JavaScript, and with '
            'the files uploaded into them up to 512 KB each. Your own '
            'pictures - the wallpaper, replaced icons - travel as the '
            'pictures themselves, up to 8 MB each; a wallpaper video is past '
            'that and stays behind.'
      : 'Enthält Uhr, Widgets, Panel, angepinnte Apps, Ordner, Web-Apps, '
            'behaltene Verknüpfungen, Datenquellen, Gerätedaten-Pakete, '
            'eigene Farben, App-Umbenennungen, das Design und die Sprache. '
            'Die Code-Widgets kommen mit ihrem HTML, CSS und JavaScript mit, '
            'und mit den hochgeladenen Dateien bis 512 KB pro Stück. Eigene '
            'Bilder - Hintergrund, ersetzte Icons - reisen als Bild mit, bis '
            '8 MB pro Stück; ein Hintergrund-Video liegt darüber und bleibt '
            'zurück.';
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
  String get backupImportFailed =>
      _en ? 'Not a readable backup file' : 'Keine lesbare Sicherungsdatei';
  String backupImportSuccessWithoutPictures(int count) => _en
      ? 'Settings imported - $count picture(s) were too large to travel'
      : 'Einstellungen importiert - $count Bild(er) waren zu groß zum '
            'Mitnehmen';

  // The snapshots the app writes by itself (auto_backup_service.dart).
  String get backupAutomatic => _en ? 'On this phone' : 'Auf diesem Handy';
  String get backupAutomaticHint => _en
      ? 'The app saves a copy into Download/hanneslauncher by itself: once a '
            'day, and always right before it installs an update. That folder '
            'survives uninstalling the app, which is the moment the copy is '
            'for. Tap one to put it back.'
      : 'Die App legt selbst eine Kopie in Download/hanneslauncher ab: '
            'einmal am Tag, und immer direkt vor dem Installieren eines '
            'Updates. Dieser Ordner überlebt das Deinstallieren der App - '
            'genau dafür ist die Kopie da. Zum Zurückholen antippen.';
  String get backupSaveNow => _en ? 'Save now' : 'Jetzt sichern';
  String backupSavedTo(String name) =>
      _en ? 'Saved as $name' : 'Gesichert als $name';
  String get backupNoneYet =>
      _en ? 'Nothing saved yet' : 'Noch nichts gesichert';
  String get backupRestore => _en ? 'Restore' : 'Zurückholen';
  String backupRestoreConfirm(String when) => _en
      ? 'This replaces all current settings with the ones from $when. '
            'Continue?'
      : 'Das ersetzt alle aktuellen Einstellungen durch die von $when. '
            'Fortfahren?';
  String get backupShare => _en ? 'Send a copy' : 'Kopie senden';
  String get backupToday => _en ? 'Today' : 'Heute';
  String get backupYesterday => _en ? 'Yesterday' : 'Gestern';
  String get backupReasonDaily => _en ? 'daily' : 'täglich';
  String get backupReasonUpdate => _en ? 'before update' : 'vor Update';
  String get backupReasonManual => _en ? 'by hand' : 'von Hand';
  String get backupManual => _en ? 'To another phone' : 'Auf ein anderes Handy';
  String get backupManualHint => _en
      ? 'Send the file somewhere off this phone, or read one back in from '
            'wherever it was put.'
      : 'Die Datei irgendwohin außerhalb dieses Handys schicken - oder eine '
            'von dort wieder einlesen.';

  // The update check (update_screen.dart) - this app doesn't come from a
  // store, so new versions arrive as an APK attached to a GitHub release
  // and the check is what notices one is there.
  String get update => _en ? 'Update' : 'Update';
  String get updateSubtitleUpToDate => _en ? 'Up to date' : 'Aktuell';
  String updateSubtitleInstalled(String version) =>
      _en ? 'Version $version · up to date' : 'Version $version · aktuell';
  String updateSubtitleAvailable(String version) =>
      _en ? 'Version $version available' : 'Version $version verfügbar';
  String get updateSubtitleUnknown =>
      _en ? 'Check for a new version' : 'Auf neue Version prüfen';
  String updateInstalledVersion(String version) =>
      _en ? 'Installed: $version' : 'Installiert: $version';
  String get updateVersionUnknown =>
      _en ? 'Installed version unknown' : 'Installierte Version unbekannt';
  String updateLatestVersion(String version) =>
      _en ? 'Latest release: $version' : 'Neuestes Release: $version';
  String get updateNoReleaseYet =>
      _en ? 'No release found yet' : 'Noch kein Release gefunden';
  String get updateAvailableTitle =>
      _en ? 'Update available' : 'Update verfügbar';
  String get updateUpToDate =>
      _en ? 'You have the latest version.' : 'Du hast die neueste Version.';
  String get updateNoApkInRelease => _en
      ? 'This release has no APK attached - open it on GitHub to see what\'s '
            'in it.'
      : 'An dieses Release ist keine APK angehängt - auf GitHub öffnen, um '
            'zu sehen, was drin ist.';
  String get updateInstallHint => _en
      ? 'The app fetches the file itself and hands it to Android\'s '
            'installer. It installs over the current version, so all settings '
            'stay - the app is never uninstalled in between.'
      : 'Die App lädt die Datei selbst und übergibt sie Androids Installer. '
            'Er installiert über die aktuelle Version, alle Einstellungen '
            'bleiben also erhalten - die App wird zwischendurch nie '
            'deinstalliert.';
  String get updateDownloadAndInstall =>
      _en ? 'Download & install' : 'Herunterladen & installieren';
  String updateDownloading(int percent) =>
      _en ? 'Downloading… $percent%' : 'Wird geladen… $percent%';
  String get updateStartingInstaller => _en
      ? 'Handing it to Android\'s installer…'
      : 'Wird an Androids Installer übergeben…';
  String get updateDownloadFailed => _en
      ? 'Download failed. Open the release on GitHub and try from there.'
      : 'Herunterladen fehlgeschlagen. Öffne das Release auf GitHub und '
            'versuch es von dort.';
  String get updateNeedsInstallPermission => _en
      ? 'Android has to allow this app to install apps. Turn it on, then tap '
            'the button again.'
      : 'Android muss dieser App erlauben, Apps zu installieren. Schalte es '
            'ein und tippe dann noch einmal auf den Knopf.';
  String get updateOpenInstallSettings =>
      _en ? 'Open the setting' : 'Einstellung öffnen';
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
  String get updateOpenFailed =>
      _en ? 'Couldn\'t open the link' : 'Link konnte nicht geöffnet werden';

  String get addColor => _en ? 'Add color' : 'Farbe hinzufügen';
  String get pickColor => _en ? 'Pick a color' : 'Farbe wählen';
  String colorBrightness(int percent) =>
      _en ? 'Brightness ($percent%)' : 'Helligkeit ($percent%)';
  String colorOpacity(int percent) =>
      _en ? 'Opacity ($percent%)' : 'Deckkraft ($percent%)';

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
  String get packageSunTimes =>
      _en ? 'Sunrise/sunset' : 'Sonnenauf-/-untergang';
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
  // Input element - the field itself, and how other elements reach what
  // was typed into it.
  String get inputNameLabel => _en ? 'Field name' : 'Feldname';
  String inputNameHint(String reference) => _en
      ? 'Other elements read this field as $reference - put that in a text '
            'element to display it, or in a button\'s address to send it.'
      : 'Andere Elemente lesen dieses Feld als $reference - das in ein '
            'Text-Element setzen zeigt es an, in die Adresse eines Buttons '
            'gesetzt verschickt es.';
  String get inputNameEmpty => _en
      ? 'Without a name nothing can read this field'
      : 'Ohne Namen kann nichts dieses Feld auslesen';
  String get inputNameTaken => _en
      ? 'Another field already goes by this name - both would hold the same '
            'text'
      : 'Ein anderes Feld heißt schon so - beide hätten denselben Inhalt';
  String get inputHintLabel =>
      _en ? 'Hint while empty' : 'Hinweis, solange leer';
  String get inputKeyboardLabel => _en ? 'Keyboard' : 'Tastatur';
  String get inputKeyboardText => _en ? 'Text' : 'Text';
  String get inputKeyboardNumber => _en ? 'Numbers' : 'Zahlen';
  String get inputKeyboardUrl => _en ? 'Address' : 'Adresse';
  String get inputNotStoredHint => _en
      ? 'What is typed here is not saved - it is gone once the launcher '
            'restarts'
      : 'Was hier eingetippt wird, wird nicht gespeichert - nach einem '
            'Neustart des Launchers ist es weg';
  String get inputRecipe => _en
      ? 'A search box: this field, plus an action button set to "Open" with '
            'an address like https://duckduckgo.com/?q={{input.NAME|url}}. '
            'Several buttons on one field means several places to search.'
      : 'Ein Suchfeld: dieses Feld, dazu ein Aktions-Button auf "Öffnen" mit '
            'einer Adresse wie https://duckduckgo.com/?q={{eingabe.NAME|url}}. '
            'Mehrere Buttons an einem Feld sind mehrere Ziele.';

  // Action element - whether the tap sends a request or opens something.
  String get actionKindLabel =>
      _en ? 'What the tap does' : 'Was der Tipp macht';
  String get actionKindHttp => _en ? 'Send request' : 'Anfrage senden';
  String get actionKindOpen => _en ? 'Open' : 'Öffnen';
  String get actionKindSearch => _en ? 'Search' : 'Suchen';
  String get actionKindSearchHint => _en
      ? 'Searches for whatever is typed in a field. Pick the field and the '
            'engine below - there is no address to type.'
      : 'Sucht nach dem, was in einem Feld steht. Feld und Suchmaschine '
            'unten auswählen - eine Adresse musst du nicht eintippen.';
  String get searchButtonNotSetUp => _en
      ? 'This button has no field or no search engine yet'
      : 'Diesem Button fehlt noch ein Feld oder eine Suchmaschine';
  String get searchButtonEmptyField =>
      _en ? 'Nothing typed yet' : 'Noch nichts eingetippt';
  String get actionSearchPreview =>
      _en ? 'What a tap opens right now' : 'Was ein Tipp gerade öffnet';
  String get actionKindHttpHint => _en
      ? 'Calls an address in the background and reports back - for a smart '
            'home device\'s own API'
      : 'Ruft eine Adresse im Hintergrund auf und meldet das Ergebnis - für '
            'die eigene API eines Smart-Home-Geräts';
  String get actionKindOpenHint => _en
      ? 'Hands the address to the phone: https opens the browser, tel: the '
            'dialer, geo: the map. Combined with an input field this is a '
            'search button.'
      : 'Gibt die Adresse ans Handy weiter: https öffnet den Browser, tel: '
            'die Telefon-App, geo: die Karte. Zusammen mit einem Eingabefeld '
            'ist das ein Such-Button.';
  String get actionOpenUrlLabel =>
      _en ? 'Address to open' : 'Adresse zum Öffnen';
  String get actionOpenUrlHint => _en
      ? 'Anything the phone can open. Insert an input field below - picked '
            'here it is added URL-safe, so a space in the text cannot break '
            'the address.'
      : 'Alles, was das Handy öffnen kann. Eingabefeld unten einfügen - hier '
            'wird es URL-sicher eingesetzt, damit ein Leerzeichen im Text '
            'die Adresse nicht zerlegt.';
  String get actionOpenNoApp => _en
      ? 'No app on the phone opens this address'
      : 'Keine App auf dem Handy öffnet diese Adresse';
  String get actionOpenNotValid => _en
      ? 'Needs a scheme in front, e.g. https://, tel: or geo:'
      : 'Braucht ein Schema davor, z.B. https://, tel: oder geo:';
  String get testOpenAction => _en ? 'Open now' : 'Jetzt öffnen';
  String get actionOpened => _en ? 'Opened' : 'Geöffnet';
  String get valueUrlSafe => _en ? 'URL-safe' : 'URL-sicher';

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
  String get actionPreviewLabel => _en
      ? 'This is what a tap sends right now:'
      : 'Das wird beim Antippen gerade gesendet:';
  String get actionPreviewEmpty =>
      _en ? '(no address yet)' : '(noch keine Adresse)';
  String get actionToggleUnreadable => _en
      ? 'Current value isn\'t readable as true/false yet - check "Current '
            'value" above'
      : 'Aktueller Wert ist noch nicht als wahr/falsch lesbar - "Aktueller '
            'Wert" oben prüfen';
  String get advanced => _en ? 'Advanced' : 'Erweitert';

  // Shortcuts drawn onto the home screen (gesture_*.dart). A shape, what it
  // does, and the two sentences that explain why a straight swipe down still
  // opens the panel instead of drawing a line.
  String get gestureShortcuts => 'Shortcuts';
  String gestureShortcutsSubtitle(int count) => _en
      ? 'Draw a shape on the home screen ($count)'
      : 'Formen auf den Homescreen zeichnen ($count)';
  String get gestureAdd => _en ? 'New shape' : 'Neue Form';
  String get gestureSavedShapes => _en ? 'Saved shapes' : 'Gespeicherte Formen';
  String get gestureNoShortcuts => _en
      ? 'Nothing saved yet. Draw a shape below, say what it should do, and '
            'from then on drawing it on the home screen does exactly that.'
      : 'Noch nichts gespeichert. Unten eine Form zeichnen, festlegen was '
            'passieren soll - ab dann macht genau das, wer sie auf dem '
            'Homescreen zeichnet.';
  String gestureShortcutsFull(int max) => _en
      ? 'Room for $max shapes - delete one first'
      : 'Platz für $max Formen - erst eine löschen';
  String get gestureDrawingEnabled =>
      _en ? 'Draw on the home screen' : 'Auf dem Homescreen zeichnen';
  String get gestureDrawingEnabledHint => _en
      ? 'Off keeps every shape, it just stops them being watched for'
      : 'Aus behält alle Formen, sie werden nur nicht mehr erkannt';
  String get gestureHomeHint => _en
      ? 'A shape is recognised wherever on the home screen it is drawn and '
            'at whatever size - only its outline counts, and which end it '
            'starts at. A straight pull up or down stays the settings panel, '
            'so start a shape sideways or on a curve.'
      : 'Eine Form wird überall auf dem Homescreen und in jeder Größe '
            'erkannt - es zählt nur ihr Umriss und an welchem Ende sie '
            'anfängt. Ein gerader Zug nach oben oder unten bleibt das '
            'Einstellungs-Panel, fang eine Form also seitlich oder in einer '
            'Kurve an.';
  String get gestureShowTrail =>
      _en ? 'Show the line' : 'Strich anzeigen';
  String get gestureShowTrailHint => _en
      ? 'Off still recognises the shape, it just leaves no trace on screen'
      : 'Aus erkennt die Form trotzdem, sie hinterlässt nur keine Spur auf '
            'dem Bildschirm';
  String get gestureTrailColor => _en ? 'Line colour' : 'Farbe des Strichs';
  String gestureLooksLike(String other) =>
      _en ? 'Looks like "$other"' : 'Sieht aus wie "$other"';
  String get gestureNameTitle => _en ? 'Name the shape' : 'Form benennen';
  String get gestureRedraw => _en ? 'Draw shape again' : 'Form neu zeichnen';
  String get gestureChangeAction =>
      _en ? 'Change what it does' : 'Aktion ändern';
  String get gestureDelete => _en ? 'Delete shortcut' : 'Shortcut löschen';
  String get gestureTooSimilarTitle =>
      _en ? 'Two shapes alike' : 'Zwei ähnliche Formen';
  String gestureTooSimilarBody(String other) => _en
      ? 'This is close enough to "$other" that the home screen may not be '
            'able to tell them apart - it then does nothing rather than risk '
            'the wrong one. Drawing it differently is the safer way out.'
      : 'Das kommt "$other" so nahe, dass der Homescreen die beiden '
            'vielleicht nicht auseinanderhalten kann - dann passiert lieber '
            'nichts, als die falsche auszulösen. Anders zeichnen ist der '
            'sicherere Weg.';
  String get gestureSaveAnyway => _en ? 'Save anyway' : 'Trotzdem speichern';

  // The blank sheet a shape is drawn on.
  String get gestureDrawTitle => _en ? 'Draw a shape' : 'Form zeichnen';
  String get gestureDrawHint => _en
      ? 'Draw in one go, without lifting your finger - a heart, a house, a '
            'circle, whatever you will remember.'
      : 'In einem Zug zeichnen, ohne den Finger zu heben - ein Herz, ein '
            'Haus, ein Kreis, was du dir merken kannst.';
  String get gestureOneStrokeOnly => _en
      ? 'One stroke only, so that one replaced the last'
      : 'Nur ein Zug - der hier hat den vorherigen ersetzt';
  String get gestureDrawAgain => _en ? 'Draw again' : 'Neu zeichnen';
  String get gestureUseShape => _en ? 'Use this shape' : 'Form übernehmen';
  String get gestureTooSmall => _en
      ? 'Too small or too straight to tell apart later - draw it bigger'
      : 'Zu klein oder zu gerade, um sie später zu erkennen - größer '
            'zeichnen';

  // What a shape does.
  String get gestureWhatHappens =>
      _en ? 'What should happen?' : 'Was soll passieren?';
  String get gestureActionKindEntry => _en ? 'Open app' : 'App öffnen';
  String get gestureActionKindEntryHint => _en
      ? 'An app, a web app, a folder or one of the launcher\'s own screens'
      : 'Eine App, eine Web-App, ein Ordner oder ein Screen des Launchers';
  String get gestureActionKindAddress =>
      _en ? 'Open an address' : 'Adresse öffnen';
  String get gestureActionKindAddressHint => _en
      ? 'A website, but also tel: to call someone or geo: for a place'
      : 'Eine Webseite, aber auch tel: zum Anrufen oder geo: für einen Ort';
  String get gestureActionKindTimer => _en ? 'Countdown' : 'Countdown';
  String get gestureActionKindTimerHint => _en
      ? 'Starts a timer in the phone\'s clock app, so it rings on its own'
      : 'Startet einen Timer in der Uhren-App des Handys, er klingelt also '
            'von selbst';
  String get gestureActionKindSettings =>
      _en ? 'Open settings' : 'Einstellungen öffnen';
  String get gestureActionKindSettingsHint => _en
      ? 'Pulls the settings panel down'
      : 'Zieht das Einstellungs-Panel herunter';
  String get gestureTimerLength => _en ? 'How long?' : 'Wie lange?';
  String get gestureTimerMinutes => _en ? 'Minutes' : 'Minuten';
  String get secondsShort => _en ? 'sec' : 'Sek';
  String get minutesShort => _en ? 'min' : 'Min';
  String gestureActionTimerFor(String duration) =>
      _en ? 'Countdown $duration' : 'Countdown $duration';
  String get gestureActionEntryMissing =>
      _en ? 'App no longer here' : 'App nicht mehr da';

  // What the home screen says about a drawing, and only ever briefly. A
  // stroke that was never meant as a shape is answered with silence - see
  // StrokeVerdict.notAShape.
  String get gestureNotRecognized =>
      _en ? 'Shape not recognised' : 'Form nicht erkannt';
  String get gestureAmbiguous => _en
      ? 'Fits several shapes - draw it more clearly'
      : 'Passt auf mehrere Formen - deutlicher zeichnen';
  String get gestureActionGone => _en
      ? 'What this shape opened is gone'
      : 'Was diese Form geöffnet hat, gibt es nicht mehr';
  String gestureTimerStarted(String duration) =>
      _en ? 'Countdown $duration started' : 'Countdown $duration gestartet';
  String get gestureTimerNoClockApp => _en
      ? 'No clock app that can run a timer'
      : 'Keine Uhren-App, die einen Timer stellen kann';

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
