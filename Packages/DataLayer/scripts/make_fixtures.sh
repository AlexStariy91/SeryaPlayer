#!/usr/bin/env bash
# Regenerates the audio fixtures in Tests/DataLayerTests/Fixtures (macOS only, no third-party tools).
# Usage: Packages/DataLayer/scripts/make_fixtures.sh
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/../Tests/DataLayerTests/Fixtures"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$OUT"

say -o "$WORK/voice.aiff" "One"
python3 "$HERE/make_fixtures.py" artwork "$WORK/cover.png"

afconvert -f WAVE -d LEI16@22050 -c 1 "$WORK/voice.aiff" "$OUT/untagged.wav"
afconvert -f flac -d flac@22050 -c 1 "$WORK/voice.aiff" "$WORK/plain.flac"
python3 "$HERE/make_fixtures.py" flac "$WORK/plain.flac" "$WORK/cover.png" "$OUT/tagged.flac"
afconvert -f m4af -d aac@22050 -b 32000 -c 1 "$WORK/voice.aiff" "$WORK/plain.m4a"
swift "$HERE/TagM4A.swift" "$WORK/plain.m4a" "$WORK/cover.png" "$OUT/tagged.m4a"
python3 "$HERE/make_fixtures.py" mp3 "$WORK/cover.png" "$OUT/tagged.mp3"
printf 'This is not audio.\n' > "$OUT/not-audio.mp3"
ls -l "$OUT"
