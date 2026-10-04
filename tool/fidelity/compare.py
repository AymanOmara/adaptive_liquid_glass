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


def load_spec():
    return json.loads((ROOT / "tool/scenes/scenes.json").read_text())


def run(run_dir, no_fail=False, spec=None, prefix=""):
    """Scores every scene in `run_dir`; returns the process exit code.

    A scene missing either screenshot is reported as missing and fails the
    run, as does a run with nothing scored (unless `no_fail`). `prefix`
    limits the run to scene ids starting with it, as `capture.sh` does.
    """
    run_dir = pathlib.Path(run_dir)
    spec = spec or load_spec()
    scale = spec["device"]["scale"]
    rows, missing = [], []
    for scene in (s for s in spec["scenes"] if s["id"].startswith(prefix)):
        f = run_dir / f"{scene['id']}.flutter.png"
        s = run_dir / f"{scene['id']}.swiftui.png"
        if not (f.exists() and s.exists()):
            missing.append(scene["id"])
            continue
        a, b = load(f), load(s)
        if a.shape != b.shape:
            raise ValueError(f"{scene['id']}: flutter {a.shape} != swiftui {b.shape}")
        x0, y0, x1, y1 = region_for(scene, scale, a.shape[1], a.shape[0])
        r = score(a[y0:y1, x0:x1], b[y0:y1, x0:x1])
        diff = (np.abs(a[y0:y1, x0:x1] - b[y0:y1, x0:x1]).mean(axis=2) * 4).clip(0, 1)
        Image.fromarray((diff * 255).astype(np.uint8)).save(run_dir / f"{scene['id']}.diff.png")
        rows.append({"id": scene["id"], **r, "region": [x0, y0, x1, y1]})

    passed = sum(r["pass"] for r in rows)
    (run_dir / "report.json").write_text(json.dumps(
        {"scored": len(rows), "passed": passed, "missing": missing, "scenes": rows},
        indent=2))
    cells = "".join(
        f"<tr class={'ok' if r['pass'] else 'bad'}><td>{html.escape(r['id'])}</td>"
        f"<td>{r['ssim']:.4f}</td><td>{r['delta_e']:.2f}</td>"
        f"<td><img src='{r['id']}.flutter.png'></td><td><img src='{r['id']}.swiftui.png'></td>"
        f"<td><img src='{r['id']}.diff.png'></td></tr>" for r in rows)
    missing_html = (f"<p class=bad>{len(missing)} missing: "
                    f"{html.escape(', '.join(missing))}</p>" if missing else "")
    (run_dir / "report.html").write_text(
        "<meta charset=utf-8><style>img{width:200px}.bad{background:#fdd}"
        "td{padding:4px;font:13px system-ui}</style>"
        f"<p>{passed}/{len(rows)} pass "
        f"(SSIM ≥ {SSIM_MIN}, ΔE ≤ {DELTA_E_MAX})</p>{missing_html}"
        f"<table><tr><th>scene<th>SSIM<th>ΔE<th>Flutter<th>SwiftUI<th>diff</tr>{cells}</table>")
    failed = [r["id"] for r in rows if not r["pass"]]
    print(f"{passed}/{len(rows)} pass, {len(missing)} missing")
    for i in failed:
        print("FAIL", i)
    for i in missing:
        print("MISSING", i)
    if not rows:
        print("ERROR: no scene had both screenshots", file=sys.stderr)
    bad = bool(failed or missing or not rows)
    return 1 if bad and not no_fail else 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("run_dir", type=pathlib.Path)
    ap.add_argument("--no-fail", action="store_true")
    ap.add_argument("--prefix", default="", help="only scenes whose id starts with this")
    args = ap.parse_args()
    sys.exit(run(args.run_dir, args.no_fail, prefix=args.prefix))


if __name__ == "__main__":
    main()
