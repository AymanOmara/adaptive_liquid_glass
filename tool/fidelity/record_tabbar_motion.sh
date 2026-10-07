#!/usr/bin/env bash
# Records tab bar gestures frame by frame in SwiftUI's TabView
# (`-controls <scene>`) and the package (`-twin <scene> -mode <mode>`), with
# the app's lossless `-dump` (see record_motion.sh / MotionScenes.swift).
#
#   tool/fidelity/record_tabbar_motion.sh <run-dir> [gesture ...]
#
# Gestures (Home selected at launch; tab centres x 115 / 201 / 287 pt,
# y 822): press (hold Music 0.8 s), tap (quick tap on Settings), drag (Home
# to Settings over 0.8 s, then let go). Writes <run-dir>/<gesture>.<take>/
# NNNN.png on the 60 fps grid plus times.json; tool/fidelity/tabbar_motion.py
# compares them. Takes: ref (SwiftUI), native, shader (MODES overrides).
# Env: UDID (default the tab-bar simulator), SCENE (tabbardark: the lens shows clearly on black), SKIP_BUILD=1,
#      PRE (0.4 s before the touch), POST (1.6 s after it), WARMUP=0.
set -euo pipefail
cd "$(dirname "$0")/../.."
UDID="${UDID:-62E521E0-5881-4749-8CE6-D08108881B34}"
BUNDLE="${BUNDLE:-com.aymanomara.adaptiveLiquidGlassExample}"
IDB="${IDB:-tool/fidelity/.venv/bin/idb}"
OUT="${1:?run dir}"; shift || true
GESTURES="${*:-press tap drag}"
SCENE="${SCENE:-tabbardark}"
MODES="${MODES:-native shader}"
PRE="${PRE:-0.4}"
POST="${POST:-1.6}"
CROP="0,2280,1206,342"   # x,y,w,h px: the bar, its lens overhang and growth
mkdir -p "$OUT"
"$IDB" connect "$UDID" >/dev/null
if [[ -z "${SKIP_BUILD:-}" ]]; then
  (cd example && flutter build ios --simulator --debug >/dev/null)
  xcrun simctl install "$UDID" example/build/ios/iphonesimulator/Runner.app
fi
DUMP_DIR="$(xcrun simctl get_app_container "$UDID" "$BUNDLE" data)/tmp/motion-dump"

gesture() { # name
  case "$1" in
    press) "$IDB" ui tap --udid "$UDID" --duration 0.8 201 822 </dev/null ;;
    tap) "$IDB" ui tap --udid "$UDID" 287 822 </dev/null ;;
    drag) "$IDB" ui swipe --udid "$UDID" --duration 0.8 --delta 4 115 822 287 822 </dev/null ;;
    *) echo "unknown gesture $1" >&2; exit 1 ;;
  esac
}
span() { case "$1" in press|drag) echo 0.8 ;; *) echo 0.05 ;; esac; }

for g in $GESTURES; do
  frames=$(python3 -c "import math; print(math.ceil(($PRE + $(span "$g") + $POST) * 60) + 6)")
  for take in ref $MODES; do
    if [[ "$take" == ref ]]; then args=(-controls "$SCENE"); else args=(-twin "$SCENE" -mode "$take"); fi
    rm -rf "$DUMP_DIR"
    xcrun simctl launch --terminate-running-process "$UDID" "$BUNDLE" "${args[@]}" \
      -dump "$CROP,$frames" >/dev/null </dev/null
    sleep "${SETTLE:-3}"
    # Warm-up (both takes alike): the first gesture in a fresh debug (JIT)
    # Flutter process stalls and the wall-clock springs skip ahead; run it
    # once unrecorded, then tap Home to restore the selection.
    if [[ "${WARMUP:-1}" != 0 ]]; then
      gesture "$g"; sleep 1.2
      "$IDB" ui tap --udid "$UDID" 115 822 </dev/null; sleep 1.2
    fi
    mkdir -p "$DUMP_DIR"; touch "$DUMP_DIR/start"
    sleep "$PRE"
    gesture "$g"
    for _ in $(seq 240); do [[ -f "$DUMP_DIR/done" ]] && break; sleep 0.25; done
    [[ -f "$DUMP_DIR/done" ]] || { echo "no frame dump for $g/$take" >&2; exit 1; }
    dst="$OUT/$g.$take"; rm -rf "$dst"; mkdir -p "$dst"
    # Onto the 60 fps grid, as record_motion.sh does.
    python3 - "$DUMP_DIR" "$dst" <<'PY'
import json, math, os, shutil, sys
src, dst = sys.argv[1:3]
t = json.load(open(f"{src}/meta.json"))["times"]
n = int(math.floor((t[-1] - t[0]) * 60 + 0.25)) + 1
i, prev, held = 0, -1, []
for k in range(n):
    g = t[0] + k / 60
    while i + 1 < len(t) and t[i + 1] <= g + 0.004:
        i += 1
    if i == prev:
        held.append(k)
    prev = i
    shutil.copyfile(f"{src}/{i + 1:04d}.png", f"{dst}/{k + 1:04d}.png")
json.dump({"times": t, "grid": n, "held": held}, open(f"{dst}/times.json", "w"))
shutil.rmtree(src)
PY
    echo "$g $take: $(ls "$dst" | grep -c png) frames"
  done
done
xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
