# Eigene Lade-Animationen programmieren

Einstellungen → Aussehen → **Lade-Animation** → **+ Neue Animation**
(oder bei einer Vorlage auf **Kopieren & bearbeiten**).

Eine Animation ist ein Stück **HTML mit `<style>` und `<script>`**. Es läuft in
einem durchsichtigen Browser-Fenster über dem ganzen Bildschirm, solange die
eingestellte Dauer läuft. Danach blendet der Launcher es selbst aus – du musst
nichts aufräumen.

Mit **▶** im Editor siehst du sofort, wie es aussieht (die Vorschau tut so,
als wäre der Akku bei 75 %).

---

## Was du zur Verfügung hast

### In JavaScript

| Befehl | Bedeutung | Beispiel |
|---|---|---|
| `charge.duration` | Wie lange die Animation sichtbar ist, in Millisekunden | `1500` |
| `charge.level` | Akkustand beim Anstecken, 0–100. `-1` wenn unbekannt | `42` |

### In CSS

| Variable | Bedeutung | Beispiel |
|---|---|---|
| `var(--duration)` | Die Dauer, direkt für `animation:` nutzbar | `1500ms` |
| `var(--level)` | Akkustand als Zahl von 0 bis 1 | `0.42` |

`var(--duration)` ist der wichtigste Befehl: Damit passt sich deine Animation
automatisch an die Dauer an, die du mit dem Schieberegler einstellst.

---

## Regeln

- **Hintergrund durchsichtig lassen.** `html, body { background: transparent; }`
  – sonst verdeckt die Animation den ganzen Bildschirm.
- **Berührungen gehen durch.** Knöpfe in der Animation kann man nicht drücken.
- **Kein Internet-Wechsel.** Links und Weiterleitungen werden blockiert.
- Bilder kannst du als SVG direkt in den Code schreiben (siehe Blitz-Beispiel).

---

## Grundgerüst

```html
<style>
  html, body { margin: 0; height: 100%; background: transparent; overflow: hidden; }

  .ding {
    position: fixed; inset: 0;
    animation: auftauchen var(--duration) ease-in-out forwards;
  }

  @keyframes auftauchen {
    0%   { opacity: 0; }
    30%  { opacity: 1; }
    70%  { opacity: 1; }
    100% { opacity: 0; }
  }
</style>

<div class="ding"></div>

<script>
  // charge.duration und charge.level kannst du hier benutzen
</script>
```

Die Prozentangaben in `@keyframes` sind Anteile der Dauer: bei 2 Sekunden
ist `30%` nach 0,6 Sekunden.

---

## Beispiele

### Leuchtender Rand

```html
<style>
  html, body { margin: 0; height: 100%; background: transparent; }
  .rand {
    position: fixed; inset: 0;
    box-shadow: inset 0 0 40px 12px #0af;
    animation: glow var(--duration) ease-in-out forwards;
  }
  @keyframes glow { 0%, 100% { opacity: 0; } 30%, 70% { opacity: 1; } }
</style>
<div class="rand"></div>
```

### Farbe nach Akkustand (rot → gelb → grün)

```html
<style>
  html, body { margin: 0; height: 100%; background: transparent; }
  .rand {
    position: fixed; inset: 0; border: 8px solid;
    animation: glow var(--duration) ease forwards;
  }
  @keyframes glow { 0%, 100% { opacity: 0; } 20%, 80% { opacity: 1; } }
</style>
<div class="rand" id="rand"></div>
<script>
  const l = charge.level < 0 ? 100 : charge.level;
  // 0 % = Farbton 0 (rot), 100 % = Farbton 120 (grün)
  document.getElementById('rand').style.borderColor = 'hsl(' + (l * 1.2) + ',90%,55%)';
</script>
```

### Prozentzahl in der Mitte

```html
<style>
  html, body { margin: 0; height: 100%; background: transparent; }
  .zahl {
    position: fixed; inset: 0;
    display: flex; align-items: center; justify-content: center;
    font: 700 20vw sans-serif; color: white;
    text-shadow: 0 0 20px black;
    animation: pop var(--duration) ease-out forwards;
  }
  @keyframes pop {
    0%   { opacity: 0; transform: scale(.5); }
    25%  { opacity: 1; transform: scale(1); }
    80%  { opacity: 1; }
    100% { opacity: 0; }
  }
</style>
<div class="zahl" id="zahl"></div>
<script>
  document.getElementById('zahl').textContent =
    charge.level >= 0 ? charge.level + ' %' : '⚡';
</script>
```

### Blitz-Symbol (SVG)

```html
<style>
  html, body { margin: 0; height: 100%; background: transparent; }
  body { display: flex; align-items: center; justify-content: center; }
  svg {
    width: 30vw;
    filter: drop-shadow(0 0 20px gold);
    animation: pop var(--duration) ease-out forwards;
  }
  @keyframes pop {
    0% { opacity: 0; transform: scale(.3); }
    25% { opacity: 1; transform: scale(1.1); }
    80% { opacity: 1; transform: scale(1); }
    100% { opacity: 0; }
  }
</style>
<svg viewBox="0 0 24 24"><path fill="gold" d="M13 2 4 14h6l-1 8 9-12h-6z"/></svg>
```

### Mit Canvas selbst zeichnen (für Fortgeschrittene)

Für Partikel, Wellen usw. Die Funktion `draw` wird jedes Bild aufgerufen;
`t` läuft von 0 (Start) bis 1 (Ende).

```html
<style>
  html, body { margin: 0; height: 100%; background: transparent; overflow: hidden; }
  canvas { position: fixed; inset: 0; width: 100vw; height: 100vh; }
</style>
<canvas id="c"></canvas>
<script>
  const c = document.getElementById('c');
  const g = c.getContext('2d');
  const dpr = window.devicePixelRatio || 1;   // für scharfe Linien
  c.width = innerWidth * dpr;
  c.height = innerHeight * dpr;

  function draw(t, w, h) {
    // Ein Kreis, der von unten nach oben fliegt
    g.fillStyle = 'rgba(80, 255, 200, ' + (1 - t) + ')';
    g.beginPath();
    g.arc(w / 2, h - t * h, 30 * dpr, 0, Math.PI * 2);
    g.fill();
  }

  const start = performance.now();
  function loop(now) {
    const t = Math.min(1, (now - start) / charge.duration);
    g.clearRect(0, 0, c.width, c.height);
    draw(t, c.width, c.height);
    if (t < 1) requestAnimationFrame(loop);
  }
  requestAnimationFrame(loop);
</script>
```

---

## Nützliche CSS-Befehle

| Befehl | Was er macht |
|---|---|
| `position: fixed; inset: 0;` | Element füllt den ganzen Bildschirm |
| `box-shadow: inset 0 0 40px 10px #f0f;` | Leuchten am Rand nach innen |
| `border: 8px solid red;` | Fester Rand |
| `border-image: linear-gradient(...) 1;` | Rand mit Farbverlauf |
| `opacity: 0` … `1` | Unsichtbar … sichtbar |
| `transform: scale(1.2)` | Vergrößern |
| `transform: rotate(45deg)` | Drehen |
| `transform: translateY(-100vh)` | Nach oben schieben (eine Bildschirmhöhe) |
| `filter: blur(4px)` | Weichzeichnen |
| `filter: hue-rotate(180deg)` | Farben verschieben (schön mit Animation für Regenbogen) |
| `vw` / `vh` | Prozent der Bildschirmbreite / -höhe |
| `ease-in`, `ease-out`, `linear` | Wie die Bewegung beschleunigt |
| `forwards` | Am Ende im letzten Zustand bleiben |
| `infinite` | Animation wiederholen (z. B. ein Pulsieren innerhalb der Dauer) |

Farben: Namen (`red`, `gold`), Hex (`#00aaff`) oder `hsl(Farbton, Sättigung, Helligkeit)`
– Farbton 0 = rot, 120 = grün, 240 = blau.

---

## Wenn etwas nicht geht

- **Nichts zu sehen?** Fehlt `forwards` oder steht `opacity` am Anfang auf 0 und
  wird nie 1? Ist das Element `position: fixed` mit einer Größe?
- **Ganzer Bildschirm schwarz/weiß?** Hintergrund ist nicht `transparent`.
- **Zu schnell / zu langsam?** Statt fester Sekunden `var(--duration)` benutzen.
- **JavaScript-Fehler** zeigen keine Meldung an – im Zweifel Teil für Teil
  auskommentieren (`//`) und mit ▶ testen.
