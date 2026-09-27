import 'app_strings.dart';
import 'code_widget_store.dart';

/// What a freshly created code widget starts out as. A blank card would be
/// a white rectangle with no clue where the code goes, so the picker offers
/// a handful of starting points instead - each one short enough to read in
/// full and change a line of.
///
/// The code itself is written in English, names and comments alike: it is
/// meant to be edited next to examples found anywhere else, and half-German
/// identifiers next to a pasted snippet read worse than either on its own.
enum CodeWidgetTemplate { empty, button, data, gallery, game, media }

extension CodeWidgetTemplateInfo on CodeWidgetTemplate {
  String label(AppStrings s) => switch (this) {
    CodeWidgetTemplate.empty => s.codeTemplateEmpty,
    CodeWidgetTemplate.button => s.codeTemplateButton,
    CodeWidgetTemplate.data => s.codeTemplateData,
    CodeWidgetTemplate.gallery => s.codeTemplateGallery,
    CodeWidgetTemplate.game => s.codeTemplateGame,
    CodeWidgetTemplate.media => s.codeTemplateMedia,
  };

  String description(AppStrings s) => switch (this) {
    CodeWidgetTemplate.empty => s.codeTemplateEmptyHint,
    CodeWidgetTemplate.button => s.codeTemplateButtonHint,
    CodeWidgetTemplate.data => s.codeTemplateDataHint,
    CodeWidgetTemplate.gallery => s.codeTemplateGalleryHint,
    CodeWidgetTemplate.game => s.codeTemplateGameHint,
    CodeWidgetTemplate.media => s.codeTemplateMediaHint,
  };

  CodeWidgetSource get source => switch (this) {
    CodeWidgetTemplate.empty => _empty,
    CodeWidgetTemplate.button => _button,
    CodeWidgetTemplate.data => _data,
    CodeWidgetTemplate.gallery => _gallery,
    CodeWidgetTemplate.game => _game,
    CodeWidgetTemplate.media => _media,
  };
}

const CodeWidgetSource _empty = CodeWidgetSource(
  html: '''
<!-- Your HTML goes here. style.css and script.js are linked
     automatically, as soon as they hold anything. -->
<div id="card">
  <h1>Hello</h1>
  <p>Tap the tabs above to change this.</p>
</div>
''',
  css: '''
#card {
  padding: 14px;
}
h1 {
  margin: 0 0 4px;
  font-size: 20px;
}
p {
  margin: 0;
  color: #555;
}
''',
);

const CodeWidgetSource _button = CodeWidgetSource(
  html: '''
<div id="card">
  <div id="count">0</div>
  <div class="row">
    <button onclick="step(-1)">-</button>
    <button onclick="step(1)">+</button>
    <button onclick="reset()">reset</button>
  </div>
</div>
''',
  css: '''
#card {
  padding: 12px;
  text-align: center;
}
#count {
  font-size: 34px;
  font-weight: 600;
}
.row {
  display: flex;
  gap: 8px;
  justify-content: center;
  margin-top: 8px;
}
button {
  flex: 1;
  padding: 10px;
  border: 0;
  border-radius: 10px;
  background: rgba(0, 0, 0, 0.08);
}
button:active {
  background: rgba(0, 0, 0, 0.18);
}
''',
  js: '''
let count = 0;

// launcher.load / launcher.store survive a restart of the app.
launcher.load('count').then(function (stored) {
  count = stored || 0;
  show();
});

function show() {
  document.getElementById('count').textContent = count;
  launcher.store('count', count);
}

function step(by) {
  count += by;
  show();
}

function reset() {
  count = 0;
  show();
}
''',
);

const CodeWidgetSource _data = CodeWidgetSource(
  html: '''
<!-- data-value shows a value from your data sources and keeps it
     current - no JavaScript needed. The button "Insert value" above
     the editor finds the right name for you. -->
<div id="card">
  <div id="time" data-value="zeit"></div>
  <div id="place" data-value="ort"></div>
  <button onclick="launcher.refresh()">refresh</button>
</div>
''',
  css: '''
#card {
  padding: 14px;
}
#time {
  font-size: 28px;
  font-weight: 600;
}
#place {
  color: #555;
  margin-bottom: 8px;
}
button {
  padding: 8px 14px;
  border: 0;
  border-radius: 10px;
  background: rgba(0, 0, 0, 0.08);
}
''',
);

const CodeWidgetSource _gallery = CodeWidgetSource(
  html: '''
<!-- Upload pictures under the "Files" tab. They then sit right next to
     this file under their own name - no path, no address. -->
<div id="card">
  <img id="picture" alt="">
  <div id="caption"></div>
</div>
''',
  css: '''
#card {
  position: relative;
  height: 100%;
}
#picture {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}
#caption {
  position: absolute;
  left: 10px;
  bottom: 8px;
  color: #fff;
  text-shadow: 0 1px 3px rgba(0, 0, 0, 0.8);
}
''',
  js: '''
// Put the names of your uploaded pictures in here.
const pictures = [];

let index = 0;

function show() {
  if (pictures.length === 0) {
    document.getElementById('caption').textContent =
      'No pictures yet - see the "Files" tab';
    return;
  }
  document.getElementById('picture').src = pictures[index];
  document.getElementById('caption').textContent = pictures[index];
}

document.getElementById('card').addEventListener('click', function () {
  index = (index + 1) % Math.max(pictures.length, 1);
  show();
});

show();
''',
);

const CodeWidgetSource _game = CodeWidgetSource(
  html: '''
<canvas id="board"></canvas>
<div id="score">0</div>
''',
  css: '''
#board {
  display: block;
  width: 100%;
  height: 100%;
  background: #101223;
}
#score {
  position: absolute;
  top: 8px;
  left: 10px;
  color: #fff;
  font-weight: 600;
}
''',
  js: '''
// Hit the dot before it moves away.
const board = document.getElementById('board');
const pen = board.getContext('2d');
let score = 0;
let target = {x: 0, y: 0, r: 18};

function resize() {
  board.width = board.clientWidth;
  board.height = board.clientHeight;
  moveTarget();
}

function moveTarget() {
  target.x = target.r + Math.random() * Math.max(board.width - 2 * target.r, 1);
  target.y = target.r + Math.random() * Math.max(board.height - 2 * target.r, 1);
  draw();
}

function draw() {
  pen.clearRect(0, 0, board.width, board.height);
  pen.fillStyle = '#4fd1c5';
  pen.beginPath();
  pen.arc(target.x, target.y, target.r, 0, Math.PI * 2);
  pen.fill();
}

board.addEventListener('click', function (event) {
  const box = board.getBoundingClientRect();
  const x = event.clientX - box.left;
  const y = event.clientY - box.top;
  if (Math.hypot(x - target.x, y - target.y) <= target.r) {
    score++;
    document.getElementById('score').textContent = score;
  }
  moveTarget();
});

window.addEventListener('resize', resize);
resize();
setInterval(moveTarget, 1400);
''',
);

const CodeWidgetSource _media = CodeWidgetSource(
  html: '''
<!-- Reads whatever is currently playing - Spotify, YouTube Music, any
     player - from Android's own media session, the same place the lock
     screen gets it from. Needs "Notification access" turned on for this
     app once; the hint below shows while it isn't. -->
<div id="card">
  <p id="hint">Turn on "Notification access" for this app in Settings,
    then reopen this card.</p>
  <div id="playing" hidden>
    <div id="title">-</div>
    <div id="artist"></div>
    <div class="controls">
      <button id="prev" aria-label="Previous">&#9198;</button>
      <button id="toggle" aria-label="Play or pause">&#9208;</button>
      <button id="next" aria-label="Next">&#9197;</button>
    </div>
  </div>
</div>
''',
  css: '''
#card {
  height: 100%;
  padding: 14px;
  background: #121212;
  color: #fff;
  display: flex;
  flex-direction: column;
  justify-content: center;
}
#hint {
  margin: 0;
  color: #b3b3b3;
  font-size: 13px;
}
#title {
  font-size: 17px;
  font-weight: 600;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
#artist {
  margin-top: 2px;
  color: #b3b3b3;
  font-size: 13px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.controls {
  display: flex;
  align-items: center;
  gap: 18px;
  margin-top: 12px;
}
.controls button {
  border: 0;
  background: none;
  color: #fff;
  padding: 0;
  font-size: 22px;
  line-height: 1;
}
#toggle {
  width: 40px;
  height: 40px;
  border-radius: 20px;
  background: #1db954;
  font-size: 18px;
  display: flex;
  align-items: center;
  justify-content: center;
}
''',
  js: '''
// Polling rather than a push: the media session can change from outside
// this card (someone else picks a track), and this is the only way to
// notice that. 1.5s keeps the play/pause icon close to true without
// waking the page up constantly.
async function tick() {
  const allowed = await launcher.mediaHasPermission();
  document.getElementById('hint').hidden = allowed;
  document.getElementById('playing').hidden = !allowed;
  if (!allowed) return;

  const now = await launcher.media();
  const title = document.getElementById('title');
  const artist = document.getElementById('artist');
  const toggle = document.getElementById('toggle');

  if (!now) {
    title.textContent = 'Nothing playing';
    artist.textContent = '';
    toggle.innerHTML = '&#9658;';
    return;
  }
  title.textContent = now.title;
  artist.textContent = now.artist || '';
  toggle.innerHTML = now.playing ? '&#9208;' : '&#9658;';
}

document
  .getElementById('prev')
  .addEventListener('click', function () { launcher.mediaPrevious(); });
document
  .getElementById('next')
  .addEventListener('click', function () { launcher.mediaNext(); });
document
  .getElementById('toggle')
  .addEventListener('click', function () { launcher.mediaPlayPause(); });

tick();
setInterval(tick, 1500);
''',
);
