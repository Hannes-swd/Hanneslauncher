// Records one clip on the emulator while a gesture plays.
//
//   node record.mjs <name> <steps.json | inline JSON> [leadMs] [tailMs]
//
// Starts `screenrecord`, waits leadMs, plays the gesture (gesture.mjs),
// waits tailMs, stops the recording with SIGINT so the mp4 is finalised,
// and pulls it to _source/raw/<name>.mp4.

import { spawn, execFileSync } from 'node:child_process';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const ADB = join(process.env.LOCALAPPDATA, 'Android/Sdk/platform-tools/adb.exe');
const SERIAL = process.env.SERIAL || 'emulator-5554';
const [name, steps, lead = '900', tail = '1200'] = process.argv.slice(2);
const remote = `/sdcard/hl_${name}.mp4`;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const adb = (...a) => execFileSync(ADB, ['-s', SERIAL, ...a], { encoding: 'utf8' });

const rec = spawn(ADB, ['-s', SERIAL, 'shell', 'screenrecord', '--bit-rate', '20000000', '--time-limit', '60', remote]);
await sleep(Number(lead) + 600); // screenrecord needs a moment before the first frame
if (steps && steps !== '-') {
  execFileSync('node', [join(here, 'gesture.mjs'), steps], { stdio: 'inherit' });
}
await sleep(Number(tail));
adb('shell', 'pkill', '-INT', 'screenrecord');
await new Promise((r) => rec.on('exit', r));
await sleep(500);
const out = join(here, '..', 'raw', `${name}.mp4`);
adb('pull', remote, out);
adb('shell', 'rm', remote);
console.log(out);
