#!/usr/bin/env bash
# Native SwiftUI vs this package, per component scene, as one image each:
# native | ours | diff (x4).
#
#   tool/reference/side_by_side.sh <out-dir> [scene ...]
#
# Launches `-controls <scene>` (SwiftUI) and `-twin <scene>` (Flutter) on the
# same simulator, screenshots both, and writes <out-dir>/<scene>.png plus
# index.html. Needs the example app installed (flutter build ios --simulator
# then simctl install). UDID / BUNDLE / SETTLE / MODE override defaults.
set -euo pipefail
OUT=${1:?out dir}; shift || true
UDID=${UDID:-E7A87B4A-3E48-44F8-A588-704D56774FF0}
BID=${BUNDLE:-com.aymanomara.adaptiveLiquidGlassExample}
SETTLE=${SETTLE:-2.5}
MODE=${MODE:-auto}
SCENES=${*:-controls toolbar accessory sheet menu search alert dialog popover stepper picker datepicker swipe textfield list progress pagecontrol actionsheet badge}
HERE=$(cd "$(dirname "$0")" && pwd)
PY="$HERE/../fidelity/.venv/bin/python"
mkdir -p "$OUT"

for s in $SCENES; do
  xcrun simctl launch --terminate-running-process "$UDID" "$BID" -controls "$s" >/dev/null
  sleep "$SETTLE"
  xcrun simctl io "$UDID" screenshot "$OUT/$s.native.png" >/dev/null 2>&1
  xcrun simctl launch --terminate-running-process "$UDID" "$BID" -twin "$s" -mode "$MODE" >/dev/null
  sleep "$SETTLE"
  xcrun simctl io "$UDID" screenshot "$OUT/$s.ours.png" >/dev/null 2>&1
  echo "captured $s"
done

"$PY" - "$OUT" $SCENES <<'EOF'
import sys, pathlib
import numpy as np
from PIL import Image, ImageDraw
out = pathlib.Path(sys.argv[1]); rows = []
for s in sys.argv[2:]:
    a = np.asarray(Image.open(out / f"{s}.native.png").convert("RGB")).astype(int)
    b = np.asarray(Image.open(out / f"{s}.ours.png").convert("RGB")).astype(int)
    d = np.clip(np.abs(a - b) * 4, 0, 255).astype(np.uint8)
    mean = float(np.abs(a - b).mean())
    h, w, _ = a.shape
    canvas = Image.new("RGB", (w * 3 + 40, h + 90), "white")
    for i, (img, label) in enumerate([(a, "Native SwiftUI"), (b, "adaptive_liquid_glass"), (d, f"Diff x4 (mean {mean:.2f})")]):
        canvas.paste(Image.fromarray(img.astype(np.uint8)), (i * (w + 20), 90))
        ImageDraw.Draw(canvas).text((i * (w + 20) + 20, 30), label, fill="black", font_size=48)
    small = canvas.resize((canvas.width // 3, canvas.height // 3))
    small.save(out / f"{s}.png"); rows.append((s, mean))
html = "".join(f"<h2>{s} — mean |diff| {m:.2f}</h2><img src='{s}.png' style='max-width:100%'>" for s, m in rows)
(out / "index.html").write_text(f"<html><body style='font-family:sans-serif'>{html}</body></html>")
print("wrote", out / "index.html")
EOF
