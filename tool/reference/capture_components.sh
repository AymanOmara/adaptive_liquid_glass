#!/usr/bin/env bash
# Captures the static component scenes three ways into build/reference/:
#   swiftui/  SwiftUI reference scenes (-controls <scene>)
#   native/   the Flutter twin on Apple's glass (-twin <scene> -mode native)
#   shader/   the Flutter twin on this package's shader (-mode shader)
# The simulator's appearance is set to light for the captures and restored.
# Interactive scenes (menu, swipe, swipetall) need a tap or swipe after
# launch; see README.md.
# Usage: tool/reference/capture_components.sh [UDID]
set -euo pipefail
UDID=${1:-2AC3AF21-6F97-4706-AE23-3F507BE9699F}
BID=com.aymanomara.adaptiveLiquidGlassExample
APP=example/build/ios/iphonesimulator/Runner.app
OUT=build/reference
SCENES="controls toolbar accessory tabbar sheet search"
before=$(xcrun simctl ui "$UDID" appearance)
xcrun simctl ui "$UDID" appearance light
xcrun simctl install "$UDID" "$APP"
mkdir -p "$OUT/swiftui" "$OUT/native" "$OUT/shader"
for s in $SCENES; do
  xcrun simctl launch --terminate-running-process "$UDID" "$BID" -controls "$s" >/dev/null
  sleep 4; xcrun simctl io "$UDID" screenshot "$OUT/swiftui/$s.png" >/dev/null 2>&1
  [ "$s" = tabbar ] && continue  # the twin's accessory scene covers it
  for mode in native shader; do
    xcrun simctl launch --terminate-running-process "$UDID" "$BID" -twin "$s" -mode "$mode" >/dev/null
    sleep 5; xcrun simctl io "$UDID" screenshot "$OUT/$mode/$s.png" >/dev/null 2>&1
  done
done
xcrun simctl ui "$UDID" appearance "$before"
echo "captured into $OUT/{swiftui,native,shader}"
