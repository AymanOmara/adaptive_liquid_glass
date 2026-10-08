#!/usr/bin/env bash
# Records the README's tab bar demo: the package's tab bar (shader glass) on
# the black page of `-twin tabbardark`, three tabs, a press, a tap and drags.
#
#   tool/demo/record_tabbar_demo.sh
#
# Writes screenshots/tabbar.mp4 and screenshots/tabbar.gif (the bar's region,
# 15 fps for the GIF). Env: UDID (a booted simulator with the example app
# installed), SKIP_BUILD=1 to reuse the installed build.
set -euo pipefail
cd "$(dirname "$0")/../.."
UDID="${UDID:?booted simulator UDID}"
BUNDLE="${BUNDLE:-com.aymanomara.adaptiveLiquidGlassExample}"
IDB="${IDB:-tool/fidelity/.venv/bin/idb}"
OUT=screenshots
TMP="$(mktemp -d)"
"$IDB" connect "$UDID" >/dev/null
if [[ -z "${SKIP_BUILD:-}" ]]; then
  (cd example && flutter build ios --simulator --debug >/dev/null)
  xcrun simctl install "$UDID" example/build/ios/iphonesimulator/Runner.app
fi
xcrun simctl ui "$UDID" appearance dark
xcrun simctl launch --terminate-running-process "$UDID" "$BUNDLE" \
  -twin tabbardark -mode shader >/dev/null </dev/null
sleep 3
tap() { "$IDB" ui tap --udid "$UDID" "$@" </dev/null; }
swipe() { "$IDB" ui swipe --udid "$UDID" --duration "$1" --delta 4 "$2" 822 "$3" 822 </dev/null; }
# Warm-up, unrecorded: a debug (JIT) build stalls on its first gesture.
swipe 0.8 115 287; sleep 1.2; tap 115 822; sleep 1.2

xcrun simctl io "$UDID" recordVideo --codec=h264 --force "$TMP/raw.mp4" &
REC=$!
sleep 1.0
tap --duration 0.9 201 822; sleep 1.0   # press and hold Music
tap 287 822; sleep 1.0                  # tap Settings
swipe 1.0 287 115; sleep 1.0            # drag Settings to Home
swipe 1.4 115 287; sleep 1.0            # drag Home across to Settings
tap 115 822; sleep 1.2                  # tap Home
kill -INT "$REC"; wait "$REC" || true

# The bar and a little black above it (1206 x 2622 px screen).
CROP="crop=1206:500:0:2122"
ffmpeg -loglevel error -y -i "$TMP/raw.mp4" -vf "$CROP,scale=804:-2" \
  -c:v libx264 -pix_fmt yuv420p -movflags +faststart -an "$OUT/tabbar.mp4"
ffmpeg -loglevel error -y -i "$TMP/raw.mp4" \
  -vf "$CROP,fps=15,scale=603:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle" \
  "$OUT/tabbar.gif"
rm -rf "$TMP"
xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
ls -la "$OUT/tabbar.mp4" "$OUT/tabbar.gif"
