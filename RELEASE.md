# Ein neues Release hochladen

Alles über die Kommandozeile, ohne die GitHub-Webseite zu öffnen.

Kurzfassung, wenn du es eilig hast:

```powershell
.\tool\release.ps1 1.1.0 -Notes "Was sich geändert hat"
```

Der Rest dieser Datei erklärt, was dabei passiert, wie du jeden Schritt
einzeln machst, und was zu tun ist, wenn etwas schiefgeht.

---

## 0. Einmalig einrichten

### GitHub CLI anmelden

`gh` ist bereits installiert (`gh --version` sagt es dir). Einmal anmelden:

```powershell
gh auth login
```

Antworten: **GitHub.com** → **HTTPS** → **Login with a web browser** → den
angezeigten Code im Browser eingeben. Danach merkt sich `gh` das dauerhaft.

Prüfen, ob es sitzt:

```powershell
gh auth status
```

### Den Signaturschlüssel sichern, wichtig

Android lässt eine APK nur dann über eine installierte App drüber
installieren, wenn **beide mit demselben Schlüssel signiert sind**. Sonst
kommt „App nicht installiert" und der einzige Ausweg wäre deinstallieren —
und damit wären **alle Einstellungen weg** (das Backup unter
Einstellungen → App → Sicherung ist dann dein einziges Netz).

Dieses Projekt signiert Release-Builds derzeit mit dem **Debug-Schlüssel**
(siehe `android/app/build.gradle.kts`). Der liegt hier:

```
C:\Users\hanne\.android\debug.keystore
```

Diese Datei ist damit so wichtig wie der Quellcode. Einmal an einen sicheren
Ort kopieren:

```powershell
Copy-Item "$env:USERPROFILE\.android\debug.keystore" "$env:USERPROFILE\OneDrive\hanneslauncher-debug.keystore"
```

Merke:

- **Nie löschen.** Android Studio legt bei Verlust wortlos einen neuen an —
  dann ist die Kette gebrochen.
- **Auf einem anderen Rechner** musst du diese Datei erst nach
  `%USERPROFILE%\.android\` kopieren, bevor du ein Release baust.
- Willst du irgendwann auf einen echten Release-Schlüssel umsteigen: das
  geht, kostet aber **einmal deinstallieren + Backup einspielen**. Solange
  du die Datei hast, gibt es keinen Grund dazu.

---

## 1. Der schnelle Weg: ein Befehl

Aus dem Projektordner:

```powershell
.\tool\release.ps1 1.1.0 -Notes "Neue Uhr-Stile, schnellerer Start"
```

Ohne `-Notes` baut das Skript die Release-Notizen aus den Commit-Titeln seit
dem letzten Release zusammen.

Erst mal nur sehen, was passieren würde, ändert und lädt nichts:

```powershell
.\tool\release.ps1 1.1.0 -DryRun
```

Falls PowerShell das Skript wegen der Ausführungsrichtlinie blockiert:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\release.ps1 1.1.0
```

Das Skript macht der Reihe nach:

1. prüft Versionsformat, `gh`-Anmeldung und dass es das Tag noch nicht gibt
2. prüft, dass die neue Version **höher** ist als die alte
3. setzt `version:` in `pubspec.yaml` und zählt die Build-Nummer hoch
4. baut die Release-APK
5. committet und pusht die Versionsänderung
6. legt das Release `v1.1.0` an und hängt die APK an

Schlägt der Build fehl, wird `pubspec.yaml` zurückgesetzt und nichts
hochgeladen.

---

## 2. Der Weg von Hand: jeder Schritt einzeln

Nützlich, wenn das Skript mittendrin abbricht und du ab da weitermachen
willst.

### Schritt 1, Version festlegen

In `pubspec.yaml` steht eine Zeile wie:

```yaml
version: 1.0.0+1
```

Beide Teile hochsetzen, z. B. auf `1.1.0+2`:

- **vorne** (`1.1.0`) ist das, was die App vergleicht und anzeigt
- **hinten** (`+2`) ist der `versionCode`. Der **muss** bei jedem Release
  steigen, sonst verweigert Android die Installation über die alte Version.

Faustregel für vorne: kleine Änderung → `1.0.1`, neue Funktion → `1.1.0`,
großer Umbau → `2.0.0`.

### Schritt 2, APK bauen

```powershell
flutter build apk --release
```

Ergebnis: `build\app\outputs\flutter-apk\app-release.apk`

Unter sprechendem Namen ablegen (steht sonst zehnmal gleich im
Download-Ordner des Handys):

```powershell
Copy-Item build\app\outputs\flutter-apk\app-release.apk build\app\outputs\flutter-apk\hanneslauncher-1.1.0.apk
```

### Schritt 3, Änderungen committen und pushen

```powershell
git add -A
git commit -m "release: v1.1.0"
git push
```

### Schritt 4, Release anlegen und APK anhängen

```powershell
gh release create v1.1.0 build\app\outputs\flutter-apk\hanneslauncher-1.1.0.apk --title "v1.1.0" --notes "Neue Uhr-Stile, schnellerer Start"
```

Das Tag `v1.1.0` legt `gh` dabei selbst auf den aktuellen Commit, du musst
vorher **kein** `git tag` machen.

Mehrzeilige Notizen gehen am bequemsten aus einer Datei:

```powershell
gh release create v1.1.0 build\app\outputs\flutter-apk\hanneslauncher-1.1.0.apk --title "v1.1.0" --notes-file notes.md
```

Fertig. Prüfen:

```powershell
gh release view v1.1.0
```

---

## 3. Was auf dem Handy passiert

Die App fragt `https://api.github.com/repos/Hannes-swd/Hanneslauncher/releases/latest`
ab, nimmt das Tag (`v1.1.0` → `1.1.0`) und vergleicht es mit der installierten
Version. Ist das Release höher, erscheint ein **roter Punkt**:

- auf dem **Zahnrad** im heruntergezogenen Panel
- in den Einstellungen an der Gruppe **App**
- an der Zeile **Update** darin

Unter Einstellungen → App → Update stehen installierte und neueste Version,
die Release-Notizen und ein Knopf, der die APK im Browser öffnet. Der Browser
lädt sie herunter; ein Tipp auf den fertigen Download startet Androids
Installer. Beim ersten Mal fragt Android einmalig, ob der Browser Apps
installieren darf.

**Deine Einstellungen bleiben dabei erhalten**, es wird über die bestehende
App drüber installiert, nichts deinstalliert.

Zum Zeitpunkt der Prüfung:

- beim Herunterziehen des Panels, aber höchstens **alle 6 Stunden**
  (GitHub erlaubt 60 Anfragen pro Stunde ohne Anmeldung)
- **„Jetzt prüfen"** auf dem Update-Bildschirm fragt sofort, ohne Wartezeit

Das letzte Ergebnis wird gespeichert: der rote Punkt ist also direkt nach
dem Start da und verschwindet auch offline nicht.

---

## 4. Wenn etwas schiefgeht

### „App nicht installiert" auf dem Handy

Die APK ist mit einem anderen Schlüssel signiert als die installierte App —
fast immer, weil auf einem anderen Rechner gebaut wurde oder
`debug.keystore` neu angelegt wurde. Siehe Abschnitt 0. Deinstallieren wäre
die letzte Möglichkeit, und **vorher unbedingt** in der App unter
Einstellungen → App → Sicherung exportieren.

### Der rote Punkt kommt nicht

- Ist die APK wirklich am Release angehängt? `gh release view v1.1.0`
  muss sie unter „Assets" listen.
- Heißt das Tag `v1.1.0` oder `1.1.0`? Beides geht. `nightly` o. Ä. nicht —
  das Tag muss mit einer Zahl anfangen.
- Ist das Release noch ein Entwurf? Entwürfe zählen nicht:
  `gh release edit v1.1.0 --draft=false`
- Ist die Version wirklich höher als die installierte? Der Update-Bildschirm
  zeigt beide Nummern nebeneinander.
- Sonst: „Jetzt prüfen" antippen und die Meldung darunter lesen.

### Release korrigieren

Notizen ändern:

```powershell
gh release edit v1.1.0 --notes "Korrigierter Text"
```

APK nachträglich anhängen oder ersetzen:

```powershell
gh release upload v1.1.0 build\app\outputs\flutter-apk\hanneslauncher-1.1.0.apk --clobber
```

Release komplett zurückziehen (inklusive Tag):

```powershell
gh release delete v1.1.0 --cleanup-tag --yes
```

### Falsche Version im pubspec

Nur die Zeile zurücksetzen und neu anfangen:

```powershell
git checkout -- pubspec.yaml
```

### Alle Releases auflisten

```powershell
gh release list
```

---

## 5. Wenn sich das Repository ändert

Der Repo-Name steckt in **einer** Konstante:
`kUpdateRepo` in `lib/update_controller.dart`. Wird das Repository
umbenannt oder verschoben, dort anpassen, sonst sucht die App weiter am
alten Ort.
