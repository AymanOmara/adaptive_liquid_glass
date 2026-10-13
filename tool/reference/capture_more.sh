#!/usr/bin/env bash
# Captures the SwiftUI scenes for the remaining components into
# build/reference/swiftui/ (light appearance, restored after):
#   label link wheel datewheel search searchactive colorrow colorsheet
#   coverclose
# `refresh` needs a pull: launch `-controls refresh`, drag the list down
# about 200 pt and release, then screenshot while it refreshes
# (build/reference/swiftui/refresh.png). Measure with measure_components.py.
# Usage: tool/reference/capture_more.sh [UDID]
set -euo pipefail
UDID=${1:-2AC3AF21-6F97-4706-AE23-3F507BE9699F}
BID=com.aymanomara.adaptiveLiquidGlassExample
OUT=build/reference/swiftui
SCENES="label link wheel datewheel search searchactive colorrow colorsheet coverclose"
before=$(xcrun simctl ui "$UDID" appearance)
xcrun simctl ui "$UDID" appearance light
mkdir -p "$OUT"
for s in $SCENES; do
  xcrun simctl launch --terminate-running-process "$UDID" "$BID" -controls "$s" >/dev/null
  sleep 6; xcrun simctl io "$UDID" screenshot "$OUT/$s.png" >/dev/null 2>&1
done
xcrun simctl ui "$UDID" appearance "$before"
echo "captured into $OUT"
