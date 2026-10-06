/// The charging animations that ship with the launcher, and the template a
/// new one of your own starts from.
///
/// Every animation - these and the user's own - is one HTML document played
/// in a see-through WebView over the whole screen. Before the page's own
/// code, the overlay puts in:
///
/// * `window.charge.duration` - how long it is on screen, in milliseconds
/// * `window.charge.level` - the battery level, 0-100 (or -1 when unknown)
/// * the CSS variables `--duration` (e.g. `1500ms`) and `--level` (`0.42`)
///
/// Touches go through it to whatever is underneath, and it fades out on its
/// own at the end, so a page never has to clean up after itself.
library;

class ChargingAnimationPreset {
  const ChargingAnimationPreset({
    required this.id,
    required this.nameDe,
    required this.nameEn,
    required this.html,
  });

  /// Always starts with `preset:`, which is how a selection tells a shipped
  /// animation from one of the user's own.
  final String id;
  final String nameDe;
  final String nameEn;
  final String html;

  String name(bool en) => en ? nameEn : nameDe;
}

const String _base = '''
<style>
  html, body { margin: 0; height: 100%; background: transparent; overflow: hidden; }
  canvas { position: fixed; inset: 0; width: 100vw; height: 100vh; }
</style>
''';

/// A full-screen canvas sized to the device's pixels, and a loop that hands
/// `draw` the progress from 0 to 1 over the animation's duration.
const String _canvasLoop = '''
<canvas id="c"></canvas>
<script>
  const c = document.getElementById('c');
  const g = c.getContext('2d');
  const dpr = window.devicePixelRatio || 1;
  function size() { c.width = innerWidth * dpr; c.height = innerHeight * dpr; }
  size(); addEventListener('resize', size);
  const start = performance.now();
  function loop(now) {
    const t = Math.min(1, (now - start) / charge.duration);
    g.clearRect(0, 0, c.width, c.height);
    draw(t, (now - start) / 1000, c.width, c.height);
    if (t < 1) requestAnimationFrame(loop);
  }
  requestAnimationFrame(loop);
</script>
''';

const List<ChargingAnimationPreset> chargingAnimationPresets = [
  ChargingAnimationPreset(
    id: 'preset:rainbow',
    nameDe: 'Regenbogen-Welle',
    nameEn: 'Rainbow wave',
    html: '''$_base
<script>
  // A wavy rainbow line running all the way round the edge of the screen.
  function draw(t, sec, w, h) {
    const fade = Math.sin(Math.PI * t);
    const inset = 10 * dpr, amp = 6 * dpr, perim = 2 * (w + h);
    g.lineWidth = 8 * dpr; g.lineCap = 'round';
    g.globalAlpha = fade;
    let prev = null;
    for (let s = 0; s <= perim; s += 4 * dpr) {
      let x, y, nx, ny;
      if (s < w) { x = s; y = 0; nx = 0; ny = 1; }
      else if (s < w + h) { x = w; y = s - w; nx = -1; ny = 0; }
      else if (s < 2 * w + h) { x = w - (s - w - h); y = h; nx = 0; ny = -1; }
      else { x = 0; y = h - (s - 2 * w - h); nx = 1; ny = 0; }
      const off = inset + amp * Math.sin(s / (30 * dpr) - sec * 10);
      const p = [x + nx * off, y + ny * off];
      if (prev) {
        g.strokeStyle = 'hsl(' + ((s / perim) * 360 + sec * 240) % 360 + ',100%,60%)';
        g.beginPath(); g.moveTo(prev[0], prev[1]); g.lineTo(p[0], p[1]); g.stroke();
      }
      prev = p;
    }
  }
</script>
$_canvasLoop''',
  ),
  ChargingAnimationPreset(
    id: 'preset:monochrome',
    nameDe: 'Schwarz-Weiß-Rand',
    nameEn: 'Black and white edge',
    html: '''$_base
<style>
  .edge {
    position: fixed; inset: 0; box-sizing: border-box;
    border: 10px solid transparent;
    border-image: repeating-linear-gradient(45deg, #fff 0 14px, #000 14px 28px) 10;
    animation: pulse var(--duration) ease-in-out forwards;
  }
  @keyframes pulse {
    0% { opacity: 0; transform: scale(1.04); }
    25% { opacity: 1; transform: scale(1); }
    75% { opacity: 1; }
    100% { opacity: 0; }
  }
</style>
<div class="edge"></div>''',
  ),
  ChargingAnimationPreset(
    id: 'preset:bolt',
    nameDe: 'Blitz in der Mitte',
    nameEn: 'Lightning bolt',
    html: '''$_base
<style>
  body { display: flex; align-items: center; justify-content: center; }
  .wrap { text-align: center; animation: pop var(--duration) ease-out forwards; }
  svg { width: 34vw; filter: drop-shadow(0 0 18px #ffd60a) drop-shadow(0 0 40px #ff9f0a); }
  .pct { font: 600 7vw sans-serif; color: #fff; text-shadow: 0 0 12px #000; margin-top: 2vh; }
  @keyframes pop {
    0% { opacity: 0; transform: scale(.3) rotate(-12deg); }
    20% { opacity: 1; transform: scale(1.1) rotate(0); }
    30% { transform: scale(1); }
    80% { opacity: 1; }
    100% { opacity: 0; transform: scale(.9); }
  }
</style>
<div class="wrap">
  <svg viewBox="0 0 24 24"><path fill="#ffd60a" d="M13 2 4 14h6l-1 8 9-12h-6z"/></svg>
  <div class="pct" id="pct"></div>
</div>
<script>
  if (charge.level >= 0) document.getElementById('pct').textContent = charge.level + ' %';
</script>''',
  ),
  ChargingAnimationPreset(
    id: 'preset:flow',
    nameDe: 'Strom fließt hoch',
    nameEn: 'Current flowing up',
    html: '''$_base
<script>
  // Glowing sparks rising from the charging port at the bottom, up the
  // sides of the screen.
  const sparks = [];
  function draw(t, sec, w, h) {
    const fade = t < .8 ? 1 : (1 - t) / .2;
    for (let i = 0; i < 6; i++) {
      sparks.push({
        x: w / 2 + (Math.random() - .5) * 60 * dpr, y: h,
        vx: (Math.random() - .5) * 6 * dpr, vy: -(8 + Math.random() * 10) * dpr,
        hue: 160 + Math.random() * 60,
      });
    }
    g.globalCompositeOperation = 'lighter';
    for (let i = sparks.length - 1; i >= 0; i--) {
      const p = sparks[i];
      p.x += p.vx; p.y += p.vy; p.vx *= 1.02;
      if (p.y < 0 || p.x < 0 || p.x > w) { sparks.splice(i, 1); continue; }
      const r = 4 * dpr;
      const grad = g.createRadialGradient(p.x, p.y, 0, p.x, p.y, r * 4);
      grad.addColorStop(0, 'hsla(' + p.hue + ',100%,70%,' + fade + ')');
      grad.addColorStop(1, 'hsla(' + p.hue + ',100%,50%,0)');
      g.fillStyle = grad;
      g.beginPath(); g.arc(p.x, p.y, r * 4, 0, Math.PI * 2); g.fill();
    }
    // The cable glow at the bottom edge.
    const base = g.createLinearGradient(0, h, 0, h - 80 * dpr);
    base.addColorStop(0, 'rgba(80,255,200,' + .6 * fade + ')');
    base.addColorStop(1, 'rgba(80,255,200,0)');
    g.fillStyle = base; g.fillRect(0, h - 80 * dpr, w, 80 * dpr);
  }
</script>
$_canvasLoop''',
  ),
  ChargingAnimationPreset(
    id: 'preset:level',
    nameDe: 'Akkustand füllt sich',
    nameEn: 'Battery fills up',
    html: '''$_base
<style>
  .fill {
    position: fixed; left: 0; right: 0; bottom: 0; height: 0;
    background: linear-gradient(to top, rgba(48,209,88,.55), rgba(48,209,88,.1));
    animation: rise var(--duration) cubic-bezier(.2,.8,.2,1) forwards;
  }
  .pct {
    position: fixed; inset: 0; display: flex; align-items: center; justify-content: center;
    font: 700 16vw sans-serif; color: #fff; text-shadow: 0 0 20px rgba(0,0,0,.6);
    animation: fade var(--duration) ease forwards;
  }
  @keyframes rise { 60% { height: calc(var(--level) * 100%); } 100% { height: calc(var(--level) * 100%); opacity: 0; } }
  @keyframes fade { 0%, 100% { opacity: 0; } 20%, 80% { opacity: 1; } }
</style>
<div class="fill"></div>
<div class="pct" id="pct"></div>
<script>
  document.getElementById('pct').textContent = charge.level >= 0 ? charge.level + ' %' : '⚡';
</script>''',
  ),
];

/// What "new animation" starts from: small, commented, and already doing
/// something, so the first thing that happens is a working preview.
const String chargingAnimationTemplate = '''<style>
  html, body { margin: 0; height: 100%; background: transparent; overflow: hidden; }
  /* A glowing ring round the screen. Change anything you like. */
  .ring {
    position: fixed; inset: 0;
    box-shadow: inset 0 0 40px 12px #0af;
    animation: glow var(--duration) ease-in-out forwards;
  }
  @keyframes glow { 0%, 100% { opacity: 0; } 30%, 70% { opacity: 1; } }
</style>
<div class="ring"></div>
<script>
  // charge.duration - milliseconds on screen
  // charge.level    - battery 0-100, -1 if unknown
</script>
''';
