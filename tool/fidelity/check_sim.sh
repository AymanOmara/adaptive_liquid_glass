#!/usr/bin/env bash
# Determinism check for a second simulator: captures SwiftUI static scenes on
# $UDID and compares them (full-screen SSIM) with a reference run's PNGs.
# Usage: tool/fidelity/check_sim.sh <out-dir> <reference-dir> [scene-id ...]
# Env: UDID (default: the motion simulator), SKIP_INSTALL=1, PY (python with
#      numpy/Pillow/scikit-image; default tool/fidelity/.venv/bin/python)
set -euo pipefail
cd "$(dirname "$0")/../.."
UDID="${UDID:-7E156D58-17BB-4F95-8C5D-9A4692BE2F60}"
BUNDLE="${BUNDLE:-com.aymanomara.adaptiveLiquidGlassExample}"
PY="${PY:-tool/fidelity/.venv/bin/python}"
OUT="${1:?out dir}"
REF="${2:?reference dir}"
shift 2
ids=("$@")
[[ ${#ids[@]} -gt 0 ]] || ids=(regular-capsule-photo-light clear-rect16-text-dark tinted-circle-text-dark)
mkdir -p "$OUT"
[[ -n "${SKIP_INSTALL:-}" ]] || xcrun simctl install "$UDID" example/build/ios/iphonesimulator/Runner.app
for id in "${ids[@]}"; do
  xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
  xcrun simctl launch "$UDID" "$BUNDLE" -scene "$id" -renderer swiftui >/dev/null
  sleep "${SETTLE:-2.5}"
  xcrun simctl io "$UDID" screenshot "$OUT/$id.swiftui.png" >/dev/null 2>&1
done
"$PY" - "$OUT" "$REF" "${ids[@]}" <<'PY'
import sys

import numpy as np
from PIL import Image
from skimage.metrics import structural_similarity as ssim

out, ref, ids = sys.argv[1], sys.argv[2], sys.argv[3:]
bad = 0
for i in ids:
    a = np.asarray(Image.open(f"{out}/{i}.swiftui.png").convert("RGB"), dtype=np.float64) / 255
    b = np.asarray(Image.open(f"{ref}/{i}.swiftui.png").convert("RGB"), dtype=np.float64) / 255
    s = ssim(a, b, channel_axis=2, data_range=1.0)
    d = np.abs(a - b) * 255
    print(f"{i}: SSIM {s:.6f}  max|d| {d.max():.0f}  mean|d| {d.mean():.4f}")
    bad += s < 0.9999
sys.exit(1 if bad else 0)
PY
