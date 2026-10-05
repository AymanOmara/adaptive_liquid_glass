#!/usr/bin/env bash
# Records press/morph motions (tool/scenes/motion.json) in both renderers.
# Usage: tool/fidelity/record_motion.sh <run-dir> [motion-id-prefix]
# Writes <run-dir>/<id>.<renderer>.mov and frames/<id>.<renderer>/%04d.png
# (60 fps, cropped to the motion's region; crop origin in crop.json).
# Env: UDID (default: the motion simulator), CONSTANTS='{"motion":{...}}'
#      (Flutter only), RENDERERS="flutter swiftui", SKIP_BUILD=1,
#      PRE=0.8 (s recorded before the touch), POST=1.6 (s after it ends),
#      WARMUP=1 (run the motion once, unrecorded, first; 0 disables)
set -euo pipefail
cd "$(dirname "$0")/../.."
UDID="${UDID:-7E156D58-17BB-4F95-8C5D-9A4692BE2F60}"
BUNDLE="${BUNDLE:-com.aymanomara.adaptiveLiquidGlassExample}"
VENV="${VENV:-tool/fidelity/.venv}"
IDB="$VENV/bin/idb"
OUT="${1:?run dir}"
PREFIX="${2:-}"
RENDERERS="${RENDERERS:-flutter swiftui}"
SPEC=tool/scenes/motion.json
PRE="${PRE:-0.8}"
POST="${POST:-1.6}"
command -v ffmpeg >/dev/null || { echo "record_motion.sh: ffmpeg not found" >&2; exit 1; }

# Same device model and runtime as the static bars (any simulator name).
python3 - "$UDID" <<'PY' || exit 1
import json, subprocess, sys
udid = sys.argv[1]
devices = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "-j"]))["devices"]
for runtime, ds in devices.items():
    for d in ds:
        if d["udid"] == udid:
            if d["deviceTypeIdentifier"].endswith("iPhone-17-Pro") and runtime.endswith("iOS-26-4"):
                sys.exit(0)
            sys.exit(f"record_motion.sh: {udid} is {d['deviceTypeIdentifier']} on {runtime}")
sys.exit(f"record_motion.sh: simulator {udid} not found")
PY
for r in $RENDERERS; do
  [[ "$r" == flutter || "$r" == swiftui ]] || { echo "record_motion.sh: unknown renderer '$r'" >&2; exit 1; }
done
cmp -s "$SPEC" example/assets/motion.json ||
  { echo "record_motion.sh: example/assets/motion.json is stale; run tool/scenes/sync_example.sh" >&2; exit 1; }

# id kind touch-x touch-y hold-seconds crop(w:h:x:y in px), one line per motion.
plan=$(python3 - "$PREFIX" "$SPEC" <<'PY'
import json, sys
prefix, path = sys.argv[1], sys.argv[2]
spec = json.load(open(path))
scale, W, H = spec["device"]["scale"], spec["device"]["width"], spec["device"]["height"]
PAD = 40  # pt around every shape the motion shows (press growth, merge, glow)
rows = []
for m in spec["motion"]:
    if not m["id"].startswith(prefix):
        continue
    shapes = [m["shape"]] if m.get("shape") else m["before"] + m["after"]
    x0 = max(0, min(s["x"] for s in shapes) - PAD)
    y0 = max(0, min(s["y"] for s in shapes) - PAD)
    x1 = min(W, max(s["x"] + s["w"] for s in shapes) + PAD)
    y1 = min(H, max(s["y"] + s["h"] for s in shapes) + PAD)
    px = [int(round(v * scale)) for v in (x0, y0, x1, y1)]
    px = [v - v % 2 for v in px]  # even crop for yuv420 sources
    crop = f"{px[2] - px[0]}:{px[3] - px[1]}:{px[0]}:{px[1]}"
    rows.append(f"{m['id']} {m['kind']} {m['touch']['x']} {m['touch']['y']} "
                f"{m.get('hold_ms', 0) / 1000} {crop}")
if not rows:
    sys.exit(f"record_motion.sh: no motion id in {path} starts with '{prefix}'")
print("\n".join(rows))
PY
) || exit 1

mkdir -p "$OUT/frames"
xcrun simctl bootstatus "$UDID" -b >/dev/null
"$IDB" connect "$UDID" >/dev/null
if [[ -z "${SKIP_BUILD:-}" ]]; then
  (cd example && flutter build ios --simulator --debug >/dev/null)
  xcrun simctl install "$UDID" example/build/ios/iphonesimulator/Runner.app
fi

python3 - "$OUT" "$plan" <<'PY'
import json, sys
out, plan = sys.argv[1], sys.argv[2]
crops = {}
for line in plan.splitlines():
    f = line.split()
    w, h, x, y = map(int, f[5].split(":"))
    crops[f[0]] = {"x": x, "y": y, "w": w, "h": h}
json.dump(crops, open(f"{out}/crop.json", "w"), indent=2)
PY

touch_once() { # kind x y hold-seconds
  if [[ "$1" == press ]]; then
    "$IDB" ui tap --udid "$UDID" --duration "$4" "$2" "$3" </dev/null
  else
    "$IDB" ui tap --udid "$UDID" "$2" "$3" </dev/null
  fi
}

while read -r id kind tx ty hold crop; do
  for r in $RENDERERS; do
    xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
    extra=()
    [[ "$r" == flutter && -n "${CONSTANTS:-}" ]] && extra=(-constants "$CONSTANTS")
    xcrun simctl launch "$UDID" "$BUNDLE" -motion "$id" -renderer "$r" ${extra[@]+"${extra[@]}"} >/dev/null </dev/null ||
      { echo "record_motion.sh: launch failed for '$id' renderer '$r'" >&2; exit 1; }
    sleep "${SETTLE:-2.5}"
    # Warm-up: the first run of a motion in a fresh (debug, JIT) Flutter
    # process stalls 35–110 ms (measured), which the wall-clock spring skips
    # over. Both renderers do the motion once (a morph twice, back to its
    # start) so the recording shows the steady state.
    if [[ "${WARMUP:-1}" != 0 ]]; then
      touch_once "$kind" "$tx" "$ty" "$hold"
      sleep 1.5
      if [[ "$kind" == morph ]]; then
        touch_once "$kind" "$tx" "$ty" "$hold"
        sleep 1.5
      fi
    fi
    mov="$OUT/$id.$r.mov"
    log="$OUT/$id.$r.rec.log"
    xcrun simctl io "$UDID" recordVideo --codec h264 --force "$mov" 2>"$log" </dev/null &
    rec=$!
    for _ in $(seq 50); do grep -q "Recording started" "$log" && break; sleep 0.1; done
    sleep "$PRE"
    touch_once "$kind" "$tx" "$ty" "$hold"
    sleep "$POST"
    kill -INT "$rec"
    wait "$rec" || true
    rm -rf "$OUT/frames/$id.$r"
    mkdir -p "$OUT/frames/$id.$r"
    # The stream is BT.709 limited range (its smpte432 primaries tag is not
    # honoured: undecoded values match the sRGB screenshots, a P3→sRGB
    # conversion makes them worse); ffmpeg's default BT.601 decode adds a
    # 2/255 bias.
    ffmpeg -nostdin -loglevel error -y -i "$mov" -vf \
      "scale=in_color_matrix=bt709:in_range=tv:out_range=pc:flags=accurate_rnd+full_chroma_int,fps=60,crop=$crop" \
      -pix_fmt rgb24 "$OUT/frames/$id.$r/%04d.png"
    echo "$id $r: $(ls "$OUT/frames/$id.$r" | wc -l | tr -d ' ') frames"
  done
# Every command in the loop reads /dev/null: the plan is on stdin.
done <<<"$plan"
echo "recorded into $OUT"
