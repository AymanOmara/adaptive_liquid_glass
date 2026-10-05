#!/usr/bin/env bash
# Captures the fidelity scenes with Flutter in native mode (SwiftUI glass
# hosted in a platform view). Reads tool/scenes/scenes.json, never edits it.
#
# Usage: tool/native/capture_native.sh <run-dir> [scene-id-prefix]
# Env:   UDID (default: the "iPhone 17 Pro (motion)" simulator)
#        LABEL=native   screenshot suffix: <id>.<LABEL>.png
#        MODE=native    -mode passed to the example (native|shader|auto)
#        EXTRA="..."    more launch arguments
#        SKIP_BUILD=1   reuse the installed app
#        SETTLE=2.5     seconds between launch and screenshot
set -euo pipefail
cd "$(dirname "$0")/../.."
UDID="${UDID:-7E156D58-17BB-4F95-8C5D-9A4692BE2F60}"
BUNDLE="${BUNDLE:-com.aymanomara.adaptiveLiquidGlassExample}"
OUT="${1:?run dir}"
PREFIX="${2:-}"
LABEL="${LABEL:-native}"
MODE="${MODE:-native}"

ids=$(python3 - "$PREFIX" <<'PY'
import json, sys
ids = [s["id"] for s in json.load(open("tool/scenes/scenes.json"))["scenes"]
       if s["id"].startswith(sys.argv[1])]
if not ids:
    sys.exit(f"capture_native.sh: no scene id starts with '{sys.argv[1]}'")
print("\n".join(ids))
PY
) || exit 1
cmp -s tool/scenes/scenes.json example/assets/scenes.json ||
  { echo "capture_native.sh: example/assets/scenes.json is stale" >&2; exit 1; }

mkdir -p "$OUT"
xcrun simctl bootstatus "$UDID" -b >/dev/null
if [[ -z "${SKIP_BUILD:-}" ]]; then
  (cd example && flutter build ios --simulator --debug >/dev/null)
  xcrun simctl install "$UDID" example/build/ios/iphonesimulator/Runner.app
fi
# shellcheck disable=SC2206
extra=(${EXTRA:-})
for id in $ids; do
  xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
  xcrun simctl launch "$UDID" "$BUNDLE" -scene "$id" -renderer flutter -mode "$MODE" \
    ${extra[@]+"${extra[@]}"} >/dev/null ||
    { echo "capture_native.sh: launch failed for '$id'" >&2; exit 1; }
  sleep "${SETTLE:-2.5}"
  xcrun simctl io "$UDID" screenshot "$OUT/$id.$LABEL.png" >/dev/null 2>&1 ||
    { echo "capture_native.sh: screenshot failed for '$id'" >&2; exit 1; }
done
echo "captured into $OUT"
