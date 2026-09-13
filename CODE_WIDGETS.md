# Code-Widgets

Ein normales Widget baust du aus Elementen zusammen - Text, Icon, Bild,
Knopf. Ein **Code-Widget** schreibst du stattdessen: HTML, CSS und
JavaScript, die als eigene kleine Seite in der Karte laufen.

Das ist für alles gedacht, was sich nicht aus fertigen Elementen
zusammensetzen lässt: eigene Knöpfe und Eingabefelder, ein kleines Spiel auf
einem Canvas, ein Bild das nur unter einer Bedingung erscheint, eine Liste
die sich aus einer API aufbaut, eigener Text in eigenem Layout.

---

## Anlegen

Zwei Wege, beide landen am selben Ort:

- Im Panel auf **+** → **Code**
- *Einstellungen → Panel & Daten → Code-Widgets → Neues Code-Widget*

Danach fragt eine kurze Liste nach einer **Vorlage**. Die sind absichtlich
kurz genug, um sie ganz zu lesen und eine Zeile davon zu ändern:

| Vorlage | Was drinsteht |
|---|---|
| **Leer** | Eine Überschrift und eine Zeile Text |
| **Knöpfe** | Ein Zähler, der den Neustart übersteht |
| **Datenquelle** | Zeigt einen Wert an und hält ihn aktuell |
| **Bilder** | Hochgeladene Bilder durchtippen |
| **Kleines Spiel** | Triff den Punkt, auf einem Canvas |

## Bearbeiten

*Einstellungen → Panel & Daten → Code-Widgets* führt auf die Liste aller
Code-Widgets; antippen öffnet den Editor. Auf dem Panel geht es auch: die
Karte **lange halten**.

Der Editor hat fünf Reiter: **HTML**, **CSS**, **JS**, **Dateien** und
**Karte**. Gespeichert wird automatisch, eine halbe Sekunde nachdem du
aufgehört hast zu tippen.

Oben rechts:

- **▶ Vorschau** - das Widget im Vollbild, mit seinen Fehlern und allem was
  `console.log` ausgibt darunter. Das ist die Stelle, an der du Tippfehler
  findest.
- **? Hilfe** - die Kurzfassung dieser Datei, in der App.
- **🗑 Löschen** - Widget und Ordner.

---

## Wie es aufgebaut ist

Jedes Code-Widget bekommt einen eigenen Ordner auf dem Gerät:

```
code_widgets/<id>/
    index.html      ← Reiter "HTML"
    style.css       ← Reiter "CSS"
    script.js       ← Reiter "JS"
    bild.png        ← alles unter "Dateien"
    daten.json
```

Beim Anzeigen werden die drei Dateien zu einem Dokument zusammengesetzt:
eine Grundformatierung, die `launcher`-Brücke, dein HTML, und dann `style.css`
und `script.js` - **aber nur, wenn da auch etwas drinsteht**.

Das heißt: du kannst die drei Dateien sauber trennen, oder einfach alles in
`index.html` schreiben und die anderen beiden leer lassen. Ein komplettes
Beispiel aus dem Netz, mit `<!DOCTYPE html>`, `<head>` und `<body>` drumherum,
kannst du unverändert in `index.html` einfügen - die äußere Hülle wird
entfernt, alles darin (auch `<style>` und `<script>`) bleibt und funktioniert.

Weil die Seite aus diesem Ordner geladen wird, sprichst du deine eigenen
Dateien einfach über ihren Namen an. Kein Pfad, keine Adresse:

```html
<img src="bild.png">
```

Umgekehrt heißt das auch: die Seite kommt an nichts heran, was nicht in
diesem Ordner liegt oder über `launcher` angeboten wird.

## Dateien

Der Reiter **Dateien** ist der Ordner.

- **Bild hochladen** holt ein Bild aus der Galerie und kopiert es hierher.
- **Textdatei anlegen** legt eine Datei an, die du direkt in der App tippen
  oder hineinkopieren kannst - JSON, eine Wortliste, ein zweites Stylesheet.

Jede Datei hat ein Menü: *Ins HTML einfügen* (schreibt dir das `<img>`-Tag
bzw. den Namen an die Cursorposition), *Bearbeiten* (bei Textdateien),
*Umbenennen* und *Löschen*.

Namen werden beim Hochladen kleingeschrieben und von Leerzeichen, Umlauten
und Sonderzeichen befreit - `Mein Bild.PNG` wird zu `mein_bild.png`. Sonst
müsstest du im Code raten, wie die Datei wirklich heißt.

> **Achtung beim Umbenennen:** das ist eine echte Umbenennung. Jedes
> `<img src="...">`, das noch auf den alten Namen zeigt, findet die Datei
> danach nicht mehr.

---

## Das `launcher`-Objekt

Alles, was das Widget außerhalb seines eigenen Ordners erreicht, geht über
dieses eine Objekt. Es steht zur Verfügung, bevor dein eigener Code läuft.

### Werte lesen

| Aufruf | Macht |
|---|---|
| `launcher.get(name)` | Ein Wert aus deinen Datenquellen oder ein eingebauter Wert. Zahlen bleiben Zahlen. `null`, wenn es ihn nicht gibt. |
| `launcher.text(name)` | Dasselbe, aber immer als Text - fehlende Werte als `-`. |
| `launcher.data(schlüssel)` | Die **ganze** Antwort einer Datenquelle als Objekt. |
| `launcher.all()` | Alles auf einmal: `{sources, builtins, inputs}`. |
| `launcher.fill(text)` | Setzt `{{...}}`-Platzhalter ein, genau wie auf einer Widget-Karte. |

Die Namen sind dieselben wie überall sonst in der App - siehe
**[PLACEHOLDERS.md](PLACEHOLDERS.md)**. Nur ohne die geschweiften Klammern:

```js
launcher.get('zeit')                            // "12:30"
launcher.get('akku')                            // "87"
launcher.get('wetter.current.temperature_2m')   // 21.5
launcher.get('wetter.daily.temperature_2m_max[0]')
launcher.get('eingabe.suche')                   // was in ein Eingabefeld
                                                //   auf einer Karte getippt ist
```

Den passenden Namen musst du nicht auswendig können: über dem Editor sitzt
**Wert einfügen**. Die Liste zeigt jeden verfügbaren Wert mit dem, was gerade
drinsteht, und fügt ihn an der Cursorposition ein - im HTML-Reiter als
`data-value`, im JS-Reiter als `launcher.get(...)`.

### Werte anzeigen, ohne JavaScript

Alles, was ein `data-value`-Attribut trägt, zeigt diesen Wert an und wird
aktuell gehalten, sobald neue Daten da sind:

```html
<span data-value="akku"></span> %
```

`data-text` macht dasselbe mit einem ganzen Satz voller Platzhalter:

```html
<p data-text="{{zeit}} in {{ort}}"></p>
```

### Auf neue Daten reagieren

```js
launcher.onUpdate(function () {
  document.getElementById('temp').textContent =
    launcher.get('wetter.current.temperature_2m');
});
```

`launcher.refresh()` holt alle veralteten Datenquellen neu,
`launcher.refresh('wetter')` genau eine. `launcher.apply()` schreibt alle
`data-value`-Elemente neu - brauchst du nur, wenn du selbst welche ins
Dokument gehängt hast. `launcher.list()` gibt die Liste aller verfügbaren
Werte zurück.

### Eigene API-Aufrufe

```js
const response = await launcher.fetch('https://api.example.com/things', {
  method: 'GET',
  useSource: 'meinedienst'
});
console.log(response.status, response.json);
```

Zurück kommt `{status, ok, text, json}` - `json` ist bereits geparst, wenn
die Antwort JSON war.

Warum nicht einfach `fetch()`? Die Seite wird aus einer Datei geladen und hat
damit keine echte Herkunft. Viele APIs weisen das per CORS ab.
`launcher.fetch` läuft stattdessen durch den Launcher. Das bringt drei Dinge
mit:

- **kein CORS**
- einfaches `http://` ist erlaubt, für lokale Geräte im eigenen Netz ohne
  Zertifikat (Shelly, Tasmota, Home Assistant)
- **`useSource`** übernimmt die Header einer vorhandenen Datenquelle. Dein
  API-Schlüssel bleibt damit dort, wo er hingehört, statt im Widget-Code zu
  stehen, der in jedes Backup wandert.

Erlaubt sind `GET`, `POST`, `PUT` und `DELETE`, Zeitlimit 15 Sekunden.

### Etwas merken

```js
await launcher.store('score', 12);
const score = await launcher.load('score');   // 12, auch nach einem Neustart
await launcher.forget('score');
```

`launcher.load()` ohne Namen gibt alles zurück, was dieses Widget gespeichert
hat. Die Daten gehören dem einzelnen Widget und wandern ins Backup mit.

### Sonstiges

| Aufruf | Macht |
|---|---|
| `launcher.open('com.beispiel.app')` | Öffnet eine App. Auch `web:<id>` und `folder:<id>`. |
| `launcher.openUrl('https://…')` | Gibt eine Adresse ans Handy weiter - Browser, Telefon-App, Karten-App. |
| `launcher.toast('fertig')` | Sagt kurz unten am Bildschirm Bescheid. |
| `launcher.log('…')` | Schreibt in die Konsole der Vorschau. |

---

## Die Karte einstellen

Im Reiter **Karte**:

- **Name** - steht in der Liste in den Einstellungen.
- **Feste Höhe / mitwachsend.** Fest heißt: die Seite bekommt genau diese
  Höhe, `height: 100%` in deinem CSS ist also die Karte. Mitwachsend heißt:
  die Seite ist so hoch wie ihr Inhalt, zwischen einer Mindest- und einer
  Höchsthöhe.
- **Ohne Karte zeichnen** - die weiße Kachel hinter dem Widget verschwindet,
  die Seite malt die ganze Fläche selbst. Für ein Spiel oder ein Bild, das
  bis an den Rand gehen soll.

---

## Was man wissen muss

**Die Seite scrollt nicht.** Ein Wisch auf der Karte scrollt das Panel - das
ist Absicht, sonst käme man an einem Widget nicht mehr vorbei. Wenn der
Inhalt nicht passt, stell die Karte auf *mitwachsend*.

**Kein "Beim Antippen öffnen".** Bei einem normalen Widget kann die ganze
Karte eine App öffnen. Hier ist die Karte die Seite, ein Tipp gehört also
ihr. `launcher.open('com.beispiel.app')` auf einem eigenen Knopf macht
dasselbe.

**Ein Widget startet erst, wenn du das Panel einmal heruntergezogen hast**,
und läuft danach weiter. Der Launcher läuft immer; drei Webseiten, die hinter
einem nie geöffneten Panel Strom ziehen, wären es nicht wert.

**Jede sichtbare Code-Karte ist eine eigene WebView** und kostet
entsprechend Speicher. Bei drei, vier gleichzeitig wird das Panel spürbar
träger.

**Links werden nach außen gegeben.** Ein `<a href="https://…">` in deinem
Widget ersetzt nicht die Karte durch eine Webseite, sondern öffnet die
Adresse im Browser.

---

## Backup

Die drei Code-Dateien und alles, was `launcher.store` gespeichert hat, sind
im Einstellungs-Backup enthalten (*Einstellungen → App → Backup*).

Hochgeladene Dateien kommen **bis 512 KB pro Stück** mit. Der Reiter
*Dateien* schreibt bei jeder Datei dazu, ob sie im Backup landet. Größere
Bilder bleiben auf dem Gerät - ein Backup ist eine einzelne JSON-Datei, und
zwei Fotos darin würden aus der Datei, an der der ganze Rest hängt, etwas
machen, das man nicht mehr herumreichen kann.

---

## Beispiele

> Der Beispielcode ist - wie die Vorlagen in der App - englisch geschrieben,
> damit er sich neben Beispielen aus dem Netz nicht beißt. Die Namen deiner
> Datenquellen bleiben natürlich die, die du vergeben hast.

### Ein Knopf, der ein Gerät schaltet

```html
<button onclick="toggleLight()">Light</button>
<div id="status"></div>
```

```js
async function toggleLight() {
  const response = await launcher.fetch('http://192.168.1.50/relay/0?turn=toggle', {
    method: 'POST'
  });
  document.getElementById('status').textContent = response.ok ? 'ok' : 'failed';
}
```

### Die Wochenvorhersage aus einer Datenquelle

```js
function render() {
  const data = launcher.data('wetter');
  if (!data) return;
  const days = data.daily.time;
  const highs = data.daily.temperature_2m_max;
  document.getElementById('list').innerHTML = days
    .map((day, i) => '<div>' + day + ' · ' + Math.round(highs[i]) + '°</div>')
    .join('');
}

launcher.onUpdate(render);
render();
```

### Nur bei Regen ein Bild zeigen

```js
launcher.onUpdate(function () {
  const code = launcher.get('wetter.current.weather_code');
  document.getElementById('rain').hidden = !(code >= 51 && code <= 67);
});
```

---

## Fehler finden

Der **Vorschau**-Knopf im Editor zeigt das Widget im Vollbild, darunter
laufen `console.log` und jeder JavaScript-Fehler mit Zeilennummer ein. Ohne
das wäre die einzige Rückmeldung eine leere Karte im Panel.

Ein weißes oder leeres Widget heißt meistens eines von dreien: ein Tippfehler
im JavaScript (steht in der Konsole), ein Bildname, den es so nicht gibt
(Reiter *Dateien* zeigt die echten Namen), oder eine Karte mit fester Höhe,
deren Inhalt darunter nicht passt.
