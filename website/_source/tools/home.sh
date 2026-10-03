#!/bin/sh
# home.sh - back out of any settings screen, then close the panel by tapping its header bar
ADB="$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe"
for i in 1 2 3 4 5; do "$ADB" -s emulator-5554 shell input keyevent KEYCODE_BACK; sleep 0.35; done
node "$(dirname "$0")/gesture.mjs" '[{"tap":[540,126]}]'
sleep 1
