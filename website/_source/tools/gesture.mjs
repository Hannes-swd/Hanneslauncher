// Turns a gesture description into an Android monkey script and plays it on
// the emulator. Monkey runs in one process on the device, so the moves come
// out at a steady frame rate - `input motionevent` spawns a process per
// event and stutters, and /dev/input is closed to the shell.
//
//   node gesture.mjs <steps.json | inline JSON>
//
// A step is one of:
//   {"down":[x,y]}                      finger on the glass
//   {"to":[x,y],"ms":400,"ease":"io"}  glide there (ease: lin | io | out | in)
//   {"wait":300}                        hold still (finger stays down if it is)
//   {"up":true}                         lift
//   {"tap":[x,y]}                       down + short hold + up
//   {"path":[[x,y],...],"ms":900}       follow a polyline, evenly in time
// Coordinates are screen pixels (1080x2400 on the emulator).

import { execFileSync } from 'node:child_process';
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const ADB = join(process.env.LOCALAPPDATA, 'Android/Sdk/platform-tools/adb.exe');
const SERIAL = process.env.SERIAL || 'emulator-5554';
const FRAME = 12; // ms between moves

const arg = process.argv[2];
const steps = JSON.parse(existsSync(arg) ? readFileSync(arg, 'utf8') : arg);

const ease = {
  lin: (t) => t,
  io: (t) => (t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2),
  out: (t) => 1 - Math.pow(1 - t, 3),
  in: (t) => t * t * t,
};

const lines = [];
let pos = [0, 0];
let isDown = false;
const ptr = (action, [x, y]) =>
  lines.push(`DispatchPointer(0,0,${action},${x.toFixed(1)},${y.toFixed(1)},1,1,0,1,1,0,0)`);
const wait = (ms) => lines.push(`UserWait(${Math.max(0, Math.round(ms))})`);

function glide(from, to, ms, e = 'io') {
  const n = Math.max(1, Math.round(ms / FRAME));
  for (let i = 1; i <= n; i++) {
    const t = ease[e](i / n);
    const p = [from[0] + (to[0] - from[0]) * t, from[1] + (to[1] - from[1]) * t];
    if (isDown) ptr(2, p);
    wait(ms / n);
  }
  pos = to;
}

for (const s of steps) {
  if (s.down) { pos = s.down; isDown = true; ptr(0, pos); }
  else if (s.to) glide(pos, s.to, s.ms ?? 400, s.ease ?? 'io');
  else if (s.wait) {
    // keep the finger "alive" while holding, like a real thumb resting
    const n = Math.max(1, Math.round(s.wait / 50));
    for (let i = 0; i < n; i++) { if (isDown) ptr(2, pos); wait(s.wait / n); }
  }
  else if (s.up) { ptr(1, pos); isDown = false; }
  else if (s.tap) { pos = s.tap; ptr(0, pos); wait(70); ptr(1, pos); }
  else if (s.path) {
    const pts = s.path;
    const segs = pts.slice(1).map((p, i) => Math.hypot(p[0] - pts[i][0], p[1] - pts[i][1]));
    const total = segs.reduce((a, b) => a + b, 0) || 1;
    if (!isDown) { pos = pts[0]; isDown = true; ptr(0, pos); }
    pts.slice(1).forEach((p, i) => glide(pts[i], p, (s.ms ?? 900) * segs[i] / total, 'lin'));
  }
}

const script = [
  'type= raw events', `count= ${lines.length}`, 'speed= 1.0', 'start data >>', ...lines, '',
].join('\n');
const local = join(tmpdir(), 'hl_gesture.txt');
writeFileSync(local, script);
execFileSync(ADB, ['-s', SERIAL, 'push', local, '/data/local/tmp/hl_gesture.txt'], { stdio: 'ignore' });
execFileSync(ADB, ['-s', SERIAL, 'shell', 'monkey', '-f', '/data/local/tmp/hl_gesture.txt', '1'], { stdio: 'ignore' });
