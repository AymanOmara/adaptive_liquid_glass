#!/usr/bin/env bash
# Run native checks on an existing simulator, or create an isolated one.
set -euo pipefail
cd "$(dirname "$0")/../.."

scratch=$(mktemp -d)
created_device=""
cleanup() {
  if [[ -n "$created_device" ]]; then
    xcrun simctl shutdown "$created_device" >/dev/null 2>&1 || true
    xcrun simctl delete "$created_device" >/dev/null 2>&1 || true
  fi
  rm -rf "$scratch"
}
trap cleanup EXIT

swiftc ios/adaptive_liquid_glass/Sources/adaptive_liquid_glass/GlassPhotoCache.swift \
  tool/native/test_photo_cache.swift -o "$scratch/photo_cache_tests"
"$scratch/photo_cache_tests"

if [[ -z "${IOS_DEVICE_ID:-}" ]]; then
  xcrun simctl list runtimes available --json > "$scratch/runtimes.json"
  runtime=$(python3 - "$scratch/runtimes.json" <<'PY'
import json, sys
runtimes = [r for r in json.load(open(sys.argv[1]))['runtimes']
            if r.get('isAvailable') and r['name'].startswith('iOS ')
            and int(r['version'].split('.')[0]) >= 26]
if not runtimes:
    sys.exit('Native glass tests require an installed iOS 26+ simulator runtime.')
# Prefer the oldest supported major; use its newest installed patch.
major = min(int(r['version'].split('.')[0]) for r in runtimes)
runtimes = [r for r in runtimes if int(r['version'].split('.')[0]) == major]
print(max(runtimes, key=lambda r: tuple(map(int, r['version'].split('.'))))['identifier'])
PY
)
  created_device=$(xcrun simctl create "Glass native checks" \
    com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro "$runtime")
  IOS_DEVICE_ID="$created_device"
  xcrun simctl boot "$IOS_DEVICE_ID"
fi
xcrun simctl bootstatus "$IOS_DEVICE_ID" -b

cd example
flutter pub get
# Keep separate launches: first-frame assertions need fresh process state.
flutter test integration_test/native_swiftui_test.dart -d "$IOS_DEVICE_ID"
flutter test integration_test/native_batch_test.dart -d "$IOS_DEVICE_ID"
flutter test integration_test/native_tab_bar_test.dart -d "$IOS_DEVICE_ID"
