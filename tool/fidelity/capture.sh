#!/usr/bin/env bash
# Usage: tool/fidelity/capture.sh <run-dir> [scene-id-prefix]
# Env: CONSTANTS='{"regular":{...}}'  RENDERERS="flutter swiftui"  SKIP_BUILD=1
set -euo pipefail
cd "$(dirname "$0")/../.."
UDID="${UDID:-E7A87B4A-3E48-44F8-A588-704D56774FF0}"
BUNDLE="${BUNDLE:-com.aymanomara.adaptiveLiquidGlassExample}"
OUT="${1:?run dir}"
PREFIX="${2:-}"
RENDERERS="${RENDERERS:-flutter swiftui}"

# The fidelity bars are defined on one device and runtime only.
python3 - "$UDID" <<'PY' || exit 1
import json, subprocess, sys
udid = sys.argv[1]
devices = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "-j"]))["devices"]
for runtime, ds in devices.items():
    for d in ds:
        if d["udid"] == udid:
            if d["name"] == "iPhone 17 Pro" and runtime.endswith("iOS-26-4"):
                sys.exit(0)
            sys.exit(f"capture.sh: {udid} is {d['name']} on {runtime}; need iPhone 17 Pro on iOS 26.4")
sys.exit(f"capture.sh: simulator {udid} not found")
PY

for r in $RENDERERS; do
  [[ "$r" == flutter || "$r" == swiftui ]] || { echo "capture.sh: unknown renderer '$r'" >&2; exit 1; }
done

ids=$(python3 - "$PREFIX" <<'PY'
import json, sys
prefix = sys.argv[1]
ids = [s["id"] for s in json.load(open("tool/scenes/scenes.json"))["scenes"] if s["id"].startswith(prefix)]
if not ids:
    sys.exit(f"capture.sh: no scene id in tool/scenes/scenes.json starts with '{prefix}'")
print("\n".join(ids))
PY
) || exit 1
# The app bundles its own copy; a stale one would make ids unknown at launch.
cmp -s tool/scenes/scenes.json example/assets/scenes.json ||
  { echo "capture.sh: example/assets/scenes.json is stale; run tool/scenes/sync_example.sh" >&2; exit 1; }

mkdir -p "$OUT"
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
if [[ -z "${SKIP_BUILD:-}" ]]; then
  (cd example && flutter build ios --simulator --debug >/dev/null)
  xcrun simctl install "$UDID" example/build/ios/iphonesimulator/Runner.app
fi

for id in $ids; do
  for r in $RENDERERS; do
    xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
    extra=()
    [[ "$r" == flutter && -n "${CONSTANTS:-}" ]] && extra=(-constants "$CONSTANTS")
    xcrun simctl launch "$UDID" "$BUNDLE" -scene "$id" -renderer "$r" ${extra[@]+"${extra[@]}"} >/dev/null ||
      { echo "capture.sh: launch failed for scene '$id' renderer '$r'" >&2; exit 1; }
    sleep "${SETTLE:-2.5}"
    xcrun simctl io "$UDID" screenshot "$OUT/$id.$r.png" >/dev/null 2>&1 ||
      { echo "capture.sh: screenshot failed for scene '$id' renderer '$r'" >&2; exit 1; }
  done
done
echo "captured into $OUT"
