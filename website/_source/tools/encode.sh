#!/bin/sh
# encode.sh - turns the raw emulator recordings into web clips.
# Every clip loses 8 px all round (the emulator's key-focus border) and is
# scaled to 720x1600, 30 fps, H.264 without sound, plus a poster frame.
cd "$(dirname "$0")/.."
OUT=../public/media/clips
clip() { # name start end
  ffmpeg -v error -y -ss "$2" -to "$3" -i "raw/$1.mp4" \
    -vf "crop=1064:2364:8:18,scale=720:1600:flags=lanczos,fps=30,format=yuv420p" \
    -an -c:v libx264 -preset slow -crf 24 -profile:v high -movflags +faststart "$OUT/$1.mp4"
  ffmpeg -v error -y -ss "$2" -i "raw/$1.mp4" -frames:v 1 \
    -vf "crop=1064:2364:8:18,scale=720:1600:flags=lanczos" -q:v 80 "$OUT/$1.webp"
  printf '%-14s %6s KB\n' "$1" "$(( $(stat -c %s "$OUT/$1.mp4") / 1024 ))"
}
clip scrub 0.2 9.6
clip panel 0 8.1
clip design_themes 0 11.9
clip design_round 0 6.8
clip widget_drag 0 7.0
clip draw 0.4 4.3
clip search 0.6 7.0
for c in digital roman bars dotmatrix splitflap orbit vertical custom; do
  ffmpeg -v error -y -i "raw/clock_$c.png" -vf "crop=1064:2364:8:18,scale=720:1600:flags=lanczos" -q:v 82 "../public/media/shots/clock_$c.webp"
done
du -sh ../public/media
