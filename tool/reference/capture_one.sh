#!/usr/bin/env bash
# Launches one SwiftUI reference scene and screenshots it after WAIT
# seconds into build/reference/swiftui/<scene>.png.
# Usage: tool/reference/capture_one.sh UDID SCENE [WAIT]
set -uo pipefail
UDID=$1; SCENE=$2; WAIT=${3:-8}
mkdir -p build/reference/swiftui
timeout 90 xcrun simctl launch --terminate-running-process "$UDID" \
  com.aymanomara.adaptiveLiquidGlassExample -controls "$SCENE" >/dev/null
echo "launch rc=$?"
sleep "$WAIT"
timeout 90 xcrun simctl io "$UDID" screenshot "build/reference/swiftui/$SCENE.png" >/dev/null 2>&1
echo "shot rc=$?"
