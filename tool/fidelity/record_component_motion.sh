#!/usr/bin/env bash
# Records one component gesture frame by frame in a SwiftUI reference
# (`-controls <scene>`) and its Flutter twin (`-twin <scene>`), with the
# app's lossless `-dump` (as record_tabbar_motion.sh, for any scene).
#
#   UDID=<sim> tool/fidelity/record_component_motion.sh <run-dir> <scene> <take-name>
#
# Env: GESTURE  idb ui arguments of the recorded gesture (e.g. "tap 200 150");
#      RESET    idb ui arguments that undo it after the warm-up (default GESTURE);
#      SETUP    ';'-separated idb ui steps run before (e.g. opening a sheet);
#      CROP     x,y,w,h px of the dump (default the whole screen);
#      SPAN     the gesture's length in s (0.05); PRE (0.4), POST (1.4);
#      TAKES    "ref twin" (default); SKIP_BUILD=1; WARMUP=0.
# Writes <run-dir>/<take-name>.<take>/NNNN.png on the 60 fps grid plus
# times.json; tool/fidelity/component_motion.py measures them.
set -euo pipefail
cd "$(dirname "$0")/../.."
UDID="${UDID:?simulator UDID}"
BUNDLE="${BUNDLE:-com.aymanomara.adaptiveLiquidGlassExample}"
IDB="${IDB:-tool/fidelity/.venv/bin/idb}"
OUT="${1:?run dir}"; SCENE="${2:?scene}"; NAME="${3:?take name}"
GESTURE="${GESTURE:?idb ui gesture}"
RESET="${RESET:-$GESTURE}"
CROP="${CROP:-0,0,1206,2622}"
SPAN="${SPAN:-0.05}"; PRE="${PRE:-0.4}"; POST="${POST:-1.4}"
TAKES="${TAKES:-ref twin}"
mkdir -p "$OUT"
"$IDB" connect "$UDID" >/dev/null
if [[ -z "${SKIP_BUILD:-}" ]]; then
  (cd example && flutter build ios --simulator --debug >/dev/null)
  xcrun simctl install "$UDID" example/build/ios/iphonesimulator/Runner.app
fi
DUMP_DIR="$(xcrun simctl get_app_container "$UDID" "$BUNDLE" data)/tmp/motion-dump"
ui() { # idb ui arguments
  # shellcheck disable=SC2086
  "$IDB" ui $1 --udid "$UDID" </dev/null
}
frames=$(python3 -c "import math; print(math.ceil(($PRE + $SPAN + $POST) * 60) + 6)")
for take in $TAKES; do
  if [[ "$take" == ref ]]; then args=(-controls "$SCENE"); else args=(-twin "$SCENE"); fi
  rm -rf "$DUMP_DIR"
  xcrun simctl launch --terminate-running-process "$UDID" "$BUNDLE" "${args[@]}" \
    -dump "$CROP,$frames" >/dev/null </dev/null
  sleep "${SETTLE:-3}"
  # SETUP: ';'-separated idb ui steps that bring the scene to the
  # gesture's start (e.g. open a sheet), 1.5 s apart.
  if [[ -n "${SETUP:-}" ]]; then
    IFS=';' read -ra steps <<<"$SETUP"
    for s in "${steps[@]}"; do ui "$s"; sleep 1.5; done
  fi
  # Warm-up: a fresh debug (JIT) Flutter process stalls on its first
  # gesture; run it once unrecorded and undo it, for both takes alike.
  if [[ "${WARMUP:-1}" != 0 ]]; then
    ui "$GESTURE"; sleep 1.5; ui "$RESET"; sleep 1.5
  fi
  mkdir -p "$DUMP_DIR"; touch "$DUMP_DIR/start"
  sleep "$PRE"
  ui "$GESTURE"
  for _ in $(seq 240); do [[ -f "$DUMP_DIR/done" ]] && break; sleep 0.25; done
  [[ -f "$DUMP_DIR/done" ]] || { echo "no frame dump for $NAME/$take" >&2; exit 1; }
  dst="$OUT/$NAME.$take"; rm -rf "$dst"; mkdir -p "$dst"
  python3 - "$DUMP_DIR" "$dst" <<'PY'
import json, math, shutil, sys
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
  echo "$NAME $take: $(ls "$dst" | grep -c png) frames"
done
xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
