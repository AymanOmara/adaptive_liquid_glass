"""Scores Flutter vs SwiftUI screenshots inside each scene's glass region."""
import argparse
import html
import json
import pathlib
import sys

import numpy as np
from PIL import Image
from skimage.color import deltaE_ciede2000, rgb2lab
from skimage.metrics import structural_similarity

ROOT = pathlib.Path(__file__).resolve().parents[2]
SSIM_MIN = 0.97
DELTA_E_MAX = 2.0
INFLATE_PT = 12


def region_for(scene, scale, width_px, height_px):
    xs0 = min(s["x"] for s in scene["shapes"]) - INFLATE_PT
    ys0 = min(s["y"] for s in scene["shapes"]) - INFLATE_PT
    xs1 = max(s["x"] + s["w"] for s in scene["shapes"]) + INFLATE_PT
    ys1 = max(s["y"] + s["h"] for s in scene["shapes"]) + INFLATE_PT
    clamp = lambda v, hi: int(max(0, min(hi, round(v * scale))))
    return clamp(xs0, width_px), clamp(ys0, height_px), clamp(xs1, width_px), clamp(ys1, height_px)


def score(a, b):
    ssim = structural_similarity(a, b, channel_axis=2, data_range=1.0)
    de = float(deltaE_ciede2000(rgb2lab(a), rgb2lab(b)).mean())
    return {"ssim": float(ssim), "delta_e": de,
            "pass": bool(ssim >= SSIM_MIN and de <= DELTA_E_MAX)}


def load(path):
    return np.asarray(Image.open(path).convert("RGB"), dtype=np.float64) / 255.0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("run_dir", type=pathlib.Path)
    ap.add_argument("--no-fail", action="store_true")
    args = ap.parse_args()

    spec = json.loads((ROOT / "tool/scenes/scenes.json").read_text())
    scale = spec["device"]["scale"]
    rows = []
    for scene in spec["scenes"]:
        f = args.run_dir / f"{scene['id']}.flutter.png"
        s = args.run_dir / f"{scene['id']}.swiftui.png"
        if not (f.exists() and s.exists()):
            continue
        a, b = load(f), load(s)
        x0, y0, x1, y1 = region_for(scene, scale, a.shape[1], a.shape[0])
        r = score(a[y0:y1, x0:x1], b[y0:y1, x0:x1])
        diff = (np.abs(a[y0:y1, x0:x1] - b[y0:y1, x0:x1]).mean(axis=2) * 4).clip(0, 1)
        Image.fromarray((diff * 255).astype(np.uint8)).save(args.run_dir / f"{scene['id']}.diff.png")
        rows.append({"id": scene["id"], **r, "region": [x0, y0, x1, y1]})

    (args.run_dir / "report.json").write_text(json.dumps(rows, indent=2))
    cells = "".join(
        f"<tr class={'ok' if r['pass'] else 'bad'}><td>{html.escape(r['id'])}</td>"
        f"<td>{r['ssim']:.4f}</td><td>{r['delta_e']:.2f}</td>"
        f"<td><img src='{r['id']}.flutter.png'></td><td><img src='{r['id']}.swiftui.png'></td>"
        f"<td><img src='{r['id']}.diff.png'></td></tr>" for r in rows)
    (args.run_dir / "report.html").write_text(
        "<meta charset=utf-8><style>img{width:200px}.bad{background:#fdd}"
        "td{padding:4px;font:13px system-ui}</style>"
        f"<p>{sum(r['pass'] for r in rows)}/{len(rows)} pass "
        f"(SSIM ≥ {SSIM_MIN}, ΔE ≤ {DELTA_E_MAX})</p>"
        f"<table><tr><th>scene<th>SSIM<th>ΔE<th>Flutter<th>SwiftUI<th>diff</tr>{cells}</table>")
    failed = [r["id"] for r in rows if not r["pass"]]
    print(f"{len(rows) - len(failed)}/{len(rows)} pass")
    for i in failed:
        print("FAIL", i)
    if failed and not args.no_fail:
        sys.exit(1)


if __name__ == "__main__":
    main()
