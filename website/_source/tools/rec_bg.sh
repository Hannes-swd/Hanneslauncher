#!/bin/sh
# rec_bg.sh start|stop <name> - free-form recording around manual steps
ADB="$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe"
D="$(dirname "$0")/../raw"
if [ "$1" = start ]; then
  MSYS_NO_PATHCONV=1 "$ADB" -s emulator-5554 shell "screenrecord --bit-rate 20000000 --time-limit 120 /sdcard/hl_$2.mp4" >/dev/null 2>&1 &
  sleep 1.2
else
  MSYS_NO_PATHCONV=1 "$ADB" -s emulator-5554 shell pkill -INT screenrecord; sleep 1.5
  MSYS_NO_PATHCONV=1 "$ADB" -s emulator-5554 pull "/sdcard/hl_$2.mp4" "$D/$2.mp4" >/dev/null && MSYS_NO_PATHCONV=1 "$ADB" -s emulator-5554 shell rm "/sdcard/hl_$2.mp4"
  ffprobe -v error -show_entries format=duration -of csv=p=0 "$D/$2.mp4"
fi
