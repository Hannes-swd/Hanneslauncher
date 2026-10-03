// node type.mjs "text" [enter] - types one character at a time into the focused field
import { execFileSync } from 'node:child_process';
import { join } from 'node:path';
const ADB = join(process.env.LOCALAPPDATA, 'Android/Sdk/platform-tools/adb.exe');
const [text, enter] = process.argv.slice(2);
for (const c of text) {
  const arg = c === ' ' ? '%s' : `'${c.replace(/'/g, `'\''`)}'`;
  execFileSync(ADB, ['-s', 'emulator-5554', 'shell', 'input', 'text', arg]);
}
if (enter) execFileSync(ADB, ['-s', 'emulator-5554', 'shell', 'input', 'keyevent', 'KEYCODE_ENTER']);
