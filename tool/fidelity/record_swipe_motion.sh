#!/usr/bin/env bash
# Records list swipe-action gestures frame by frame in SwiftUI's plain List
# with `.swipeActions` (`-controls <scene>`) and the package's
# GlassSwipeActions (`-twin <scene> -mode <mode>`), with the app's lossless
# `-dump` (see record_motion.sh / MotionScenes.swift).
#
#   tool/fidelity/record_swipe_motion.sh <run-dir> [scene:gesture ...]
#
# Scenes (ControlScenes.swift / reference_twin.dart): swipeone, swipeonedark
# (110-pt rows, one trailing Delete), swipe (54-pt rows; Pin leading,
# Delete + Share trailing), swipetall (70.67-pt rows); SwiftUI only (run with
# MODES=" "): swipeonemid (70.67-pt rows, one Delete), swipetwotall (110-pt
# rows, Delete + Share). Gestures act on row 1
# (the second row), at its vertical centre:
#   slow     drag from x 390 to 130 over 2 s, then let go (reveal against
#            offset, and the settle from a slow release);
#   open     a 120-pt swipe (380 to 260) in 0.3 s (the open spring);
#   close    a 230-pt swipe (380 to 150, 0.4 s) unrecorded so the row
#            rests open, then a recorded tap on the row
#            (the close spring);
#   full     a fast swipe from 385 to 40 in 0.2 s (full swipe and exit);
#   slowfull drag from x 395 to 60 over 2.5 s (past the full-swipe point
#            slowly: does the takeover wait for the release?);
#   leading  drag from x 30 to 150 in 0.3 s (the leading actions).
# Writes <run-dir>/<scene>.<gesture>.<take>/NNNN.png on the 60 fps grid
# (crop: full width, the row and 14 pt either side; crop.json) plus
# times.json; tool/fidelity/swipe_motion.py measures them. Takes: ref
# (SwiftUI) and MODES (default shader).
# Env: UDID (default the motion simulator; the tab-bar one is often busy),
#      SKIP_BUILD=1, APP (a built Runner.app to install instead of
#      building), PRE (0.4 s before the touch), POST (1.6 s after it),
#      WARMUP=0, REF=0 (keep the existing SwiftUI takes, record MODES only).
set -euo pipefail
cd "$(dirname "$0")/../.."
UDID="${UDID:-7E156D58-17BB-4F95-8C5D-9A4692BE2F60}"
BUNDLE="${BUNDLE:-com.aymanomara.adaptiveLiquidGlassExample}"
IDB="${IDB:-tool/fidelity/.venv/bin/idb}"
OUT="${1:?run dir}"; shift || true
PLAN="${*:-swipeonedark:slow swipeonedark:open swipeonedark:close swipeonedark:full swipeone:open swipe:slow swipe:open swipe:close swipe:full swipe:leading swipetall:slow}"
MODES="${MODES:-shader}"
PRE="${PRE:-0.4}"
POST="${POST:-1.6}"
mkdir -p "$OUT"
xcrun simctl bootstatus "$UDID" -b >/dev/null
"$IDB" connect "$UDID" >/dev/null
if [[ -n "${APP:-}" ]]; then
  xcrun simctl install "$UDID" "$APP"
elif [[ -z "${SKIP_BUILD:-}" ]]; then
  (cd example && flutter build ios --simulator --debug >/dev/null)
  xcrun simctl install "$UDID" example/build/ios/iphonesimulator/Runner.app
fi
DUMP_DIR="$(xcrun simctl get_app_container "$UDID" "$BUNDLE" data)/tmp/motion-dump"

# Row 1's top and height (pt): the plain List starts at 62.
row() { case "$1" in
  swipeone|swipeonedark|swipetwotall) echo "172 110" ;;
  swipeonemid) echo "132.67 70.67" ;;
  swipe) echo "116 54" ;;
  swipetall) echo "132.67 70.67" ;;
  *) echo "unknown scene $1" >&2; exit 1 ;;
esac; }

gesture() { # gesture y
  case "$1" in
    slow) "$IDB" ui swipe --udid "$UDID" --duration 2.0 --delta 2 390 "$2" 130 "$2" </dev/null ;;
    open) "$IDB" ui swipe --udid "$UDID" --duration 0.3 --delta 4 380 "$2" 260 "$2" </dev/null ;;
    preopen) "$IDB" ui swipe --udid "$UDID" --duration 0.4 --delta 4 380 "$2" 150 "$2" </dev/null ;;
    close) "$IDB" ui tap --udid "$UDID" 120 "$2" </dev/null ;;
    slowfull) "$IDB" ui swipe --udid "$UDID" --duration 2.5 --delta 2 395 "$2" 60 "$2" </dev/null ;;
    full) "$IDB" ui swipe --udid "$UDID" --duration 0.2 --delta 12 385 "$2" 40 "$2" </dev/null ;;
    leading) "$IDB" ui swipe --udid "$UDID" --duration 0.3 --delta 4 30 "$2" 150 "$2" </dev/null ;;
    *) echo "unknown gesture $1" >&2; exit 1 ;;
  esac
}
span() { case "$1" in slowfull) echo 2.5 ;; slow) echo 2.0 ;; open|leading) echo 0.3 ;; full) echo 0.2 ;; *) echo 0.05 ;; esac; }
# Brings the row back to rest after a gesture (a tap closes an open row).
reset() { sleep 1.4; "$IDB" ui tap --udid "$UDID" 120 "$1" </dev/null; sleep 1.2; }

if [[ -f "$OUT/crop.json" ]]; then cp "$OUT/crop.json" "$OUT/crop.json.tmp"; else echo "{}" > "$OUT/crop.json.tmp"; fi
for item in $PLAN; do
  scene="${item%%:*}"; g="${item##*:}"
  read -r top h <<<"$(row "$scene")"
  y=$(python3 -c "print(int(round($top + $h / 2)))")
  crop=$(python3 -c "t=$top-14; print(f'0,{round(t*3)},1206,{round(($h+28)*3)}')")
  python3 - "$OUT/crop.json.tmp" "$scene.$g" "$crop" "$top" "$h" <<'PY'
import json, sys
p, k, c, top, h = sys.argv[1:6]
d = json.load(open(p)); x, y, w, hh = map(int, c.split(","))
d[k] = {"x": x, "y": y, "w": w, "h": hh, "row_top": float(top), "row_h": float(h)}
json.dump(d, open(p, "w"), indent=2)
PY
  frames=$(python3 -c "import math; print(math.ceil(($PRE + $(span "$g") + $POST) * 60) + 6)")
  takes="$MODES"; [[ "${REF:-1}" != 0 ]] && takes="ref $takes"
  for take in $takes; do
    if [[ "$take" == ref ]]; then args=(-controls "$scene"); else args=(-twin "$scene" -mode "$take"); fi
    rm -rf "$DUMP_DIR"
    xcrun simctl launch --terminate-running-process "$UDID" "$BUNDLE" "${args[@]}" \
      -dump "$crop,$frames" >/dev/null </dev/null
    sleep "${SETTLE:-3}"
    # Warm-up (both takes alike): a fresh debug (JIT) Flutter process
    # stalls on its first gesture; run it once unrecorded, then close.
    if [[ "${WARMUP:-1}" != 0 ]]; then
      if [[ "$g" == close ]]; then gesture preopen "$y"; sleep 1.2; fi
      gesture "$g" "$y"; reset "$y"
    fi
    if [[ "$g" == close ]]; then gesture preopen "$y"; sleep 1.4; fi
    mkdir -p "$DUMP_DIR"; touch "$DUMP_DIR/start"
    sleep "$PRE"
    gesture "$g" "$y"
    for _ in $(seq 240); do [[ -f "$DUMP_DIR/done" ]] && break; sleep 0.25; done
    [[ -f "$DUMP_DIR/done" ]] || { echo "no frame dump for $item/$take" >&2; exit 1; }
    dst="$OUT/$scene.$g.$take"; rm -rf "$dst"; mkdir -p "$dst"
    # Onto the 60 fps grid, as record_motion.sh does.
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
    echo "$scene $g $take: $(ls "$dst" | grep -c png) frames"
  done
done
mv "$OUT/crop.json.tmp" "$OUT/crop.json"
xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
