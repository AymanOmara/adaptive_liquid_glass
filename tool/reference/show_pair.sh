#!/usr/bin/env bash
# Shows one scene live on two simulators: native SwiftUI on NATIVE_UDID,
# this package on OURS_UDID.  tool/reference/show_pair.sh <scene> [mode]
set -euo pipefail
S=${1:?scene}; MODE=${2:-auto}
BID=${BUNDLE:-com.aymanomara.adaptiveLiquidGlassExample}
NATIVE=${NATIVE_UDID:-2AC3AF21-6F97-4706-AE23-3F507BE9699F}
OURS=${OURS_UDID:-E7A87B4A-3E48-44F8-A588-704D56774FF0}
xcrun simctl launch --terminate-running-process "$NATIVE" "$BID" -controls "$S" >/dev/null
xcrun simctl launch --terminate-running-process "$OURS" "$BID" -twin "$S" -mode "$MODE" >/dev/null
echo "native: $NATIVE   ours: $OURS   scene: $S"
