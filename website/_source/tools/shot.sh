#!/bin/sh
# shot.sh <name> - screenshot of the emulator, full size into raw/, small copy into the scratchpad
ADB="$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe"
S="C:/Users/hanne/AppData/Local/Temp/claude/c--Users-hanne-Flutter-hanneslouncher/60b59c1d-3b65-4a2b-b67a-78490f6d7660/scratchpad"
D="$(dirname "$0")/../raw"
"$ADB" -s emulator-5554 exec-out screencap -p > "$D/$1.png"
ffmpeg -v error -y -i "$D/$1.png" -vf scale=360:-1 "$S/$1.png"
echo "$S/$1.png"
