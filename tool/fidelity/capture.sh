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
mkdir -p "$OUT"

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
if [[ -z "${SKIP_BUILD:-}" ]]; then
  (cd example && flutter build ios --simulator --debug >/dev/null)
  xcrun simctl install "$UDID" example/build/ios/iphonesimulator/Runner.app
fi

ids=$(python3 -c "import json;print('\n'.join(s['id'] for s in json.load(open('tool/scenes/scenes.json'))['scenes'] if s['id'].startswith('$PREFIX')))")
for id in $ids; do
  for r in $RENDERERS; do
    xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
    extra=()
    [[ "$r" == flutter && -n "${CONSTANTS:-}" ]] && extra=(-constants "$CONSTANTS")
    xcrun simctl launch "$UDID" "$BUNDLE" -scene "$id" -renderer "$r" ${extra[@]+"${extra[@]}"} >/dev/null
    sleep "${SETTLE:-2.5}"
    xcrun simctl io "$UDID" screenshot "$OUT/$id.$r.png" >/dev/null 2>&1
  done
done
echo "captured into $OUT"
