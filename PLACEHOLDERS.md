# Platzhalter-Übersicht

Jeder Text/Icon-Wert in einem Widget-Element kann `{{...}}`-Platzhalter
enthalten. Diese Datei listet alle eingebauten - für eigene Datenquellen
(APIs) siehe unten.

Die Liste erscheint auch live in der App: Widget bearbeiten → Element
antippen → "Wert einfügen".

## Immer verfügbar

Kein Schalter nötig, funktionieren sofort.

| Platzhalter | Zeigt |
|---|---|
| `{{zeit}}` | Aktuelle Uhrzeit, im Format das im Handy eingestellt ist (12/24h) |
| `{{zeit24}}` | Aktuelle Uhrzeit, immer 24-Stunden-Format |
| `{{zeit12}}` | Aktuelle Uhrzeit, immer 12-Stunden-Format mit AM/PM |
| `{{ampm}}` | Nur "AM" oder "PM" |
| `{{datum}}` | Heutiges Datum, `TT.MM.JJJJ` |
| `{{wochentag}}` | Wochentag ausgeschrieben, in der App-Sprache |
| `{{ort}}` | Ort anhand des Standorts (fragt einmalig nach Standort-Berechtigung) |
| `{{lat}}` / `{{lon}}` | Koordinaten des Standorts |

## Gerätedaten (ein Paket)

Standardmäßig **aus** - unter *Datenquellen → +* als ein einziges Paket
"Gerätedaten" hinzufügbar, genau wie das Wetter-Paket. Ohne es liefern
diese Platzhalter nichts. Einmal hinzugefügt, erscheint es als eine Zeile
in der Datenquellen-Liste; antippen zeigt die aktuellen Werte live und den
"Zugriff erlauben"-Button für die zwei, die eine Berechtigung brauchen.

| Platzhalter | Zeigt | Berechtigung |
|---|---|---|
| `{{akku}}` | Akkustand in % | keine |
| `{{akku_laedt}}` | "Lädt" / "Lädt nicht" | keine |
| `{{speicher_frei}}` | Freier interner Speicher in GB | keine |
| `{{speicher_gesamt}}` | Gesamter interner Speicher in GB | keine |
| `{{verbindung}}` | "WLAN" / "Mobil" / "Ethernet" / "Andere" / "Kein Netz" | keine |
| `{{sonnenauf}}` | Sonnenaufgang heute, am Standort | keine (nutzt `{{ort}}`s Koordinaten) |
| `{{sonnenunter}}` | Sonnenuntergang heute | keine |
| `{{mondphase}}` | Mondphase als Emoji (🌑🌒🌓🌔🌕🌖🌗🌘) | keine |
| `{{schritte}}` | Schritte seit Mitternacht | Aktivitätserkennung (Systemdialog) |
| `{{meistgenutzt}}` | Name der App mit der meisten Nutzungszeit heute | "Nutzungszugriff" (manuell in den Android-Einstellungen) |

Sonnenauf-/-untergang und Mondphase sind reine Berechnung (keine
Internetverbindung, kein Standort-Zugriff über das ohnehin schon
vorhandene `{{ort}}` hinaus nötig).

## Eigene Datenquellen (APIs)

Unter *Datenquellen* lässt sich eine beliebige JSON-URL mit einem
Kurzschlüssel anlegen (z.B. `wetter`). Danach ist jeder Wert aus der
Antwort über seinen Pfad erreichbar:

```
{{wetter.current.temperature_2m}}
{{wetter.daily.temperature_2m_max[0]}}
```

Die verfügbaren Pfade zeigt "Wert einfügen" automatisch an, sobald die
Quelle einmal erfolgreich getestet wurde.

## Neue Platzhalter hinzufügen (für später)

Die eingebauten Werte werden an zwei Stellen definiert, beide in
`lib/data_sources_controller.dart`:

- `builtInKeys` (Getter) - welche Schlüssel überhaupt existieren, und ob sie
  hinter dem `DeviceDataController`-Schalter stehen (siehe
  `lib/data_packages_controller.dart`)
- `_builtIn(key)` - was der Schlüssel tatsächlich liefert

Reine Geräte-/Sensor-Werte (kein Netzwerk, keine fremde App) landen als
neue native Methode in `hanneslouncher/device_stats`
(`android/app/.../MainActivity.kt` + `lib/device_stats_controller.dart`).
