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
# Interior = deeper than this inside the shape union; band = the ring between
# the outline and it (the status notes' per-region convention).
INTERIOR_PT = 18.0


def region_for(scene, scale, width_px, height_px):
    xs0 = min(s["x"] for s in scene["shapes"]) - INFLATE_PT
    ys0 = min(s["y"] for s in scene["shapes"]) - INFLATE_PT
    xs1 = max(s["x"] + s["w"] for s in scene["shapes"]) + INFLATE_PT
    ys1 = max(s["y"] + s["h"] for s in scene["shapes"]) + INFLATE_PT
    clamp = lambda v, hi: int(max(0, min(hi, round(v * scale))))
    return clamp(xs0, width_px), clamp(ys0, height_px), clamp(xs1, width_px), clamp(ys1, height_px)


def region_masks(scene, scale, width_px, height_px):
    """Boolean (interior, band) masks over the whole frame: interior = at
    least [INTERIOR_PT] pt inside the shape union, band = inside the union
    but shallower (the outer ring the rim and mirrored lens live in)."""
    import measure_lens as ml
    x0, y0, x1, y1 = region_for(scene, scale, width_px, height_px)
    py, px = np.mgrid[y0:y1, x0:x1] + 0.5
    inside = np.zeros(py.shape, bool)
    interior = np.zeros(py.shape, bool)
    for sh in scene["shapes"]:
        # Minimal shape dicts (as in tests) default to a sharp rect.
        d = ml.shape_geometry({"shape": "rect", "radius": 0, **sh}, scale, px, py)["depth"] / scale
        inside |= d >= 0
        interior |= d >= INTERIOR_PT
    band = inside & ~interior
    out_i = np.zeros((height_px, width_px), bool)
    out_b = np.zeros((height_px, width_px), bool)
    out_i[y0:y1, x0:x1] = interior
    out_b[y0:y1, x0:x1] = band
    return out_i, out_b


def _flip(a, b):
    """(mean, p99) LDR FLIP (official NVIDIA implementation, raw map)."""
    from flip_evaluator import evaluate
    m = np.asarray(evaluate(a.astype(np.float32), b.astype(np.float32),
                            "LDR", applyMagma=False)[0], np.float64).squeeze()
    return float(m.mean()), float(np.percentile(m, 99))


def score(a, b, interior=None, band=None):
    ssim, full = structural_similarity(a, b, channel_axis=2, data_range=1.0, full=True)
    de = deltaE_ciede2000(rgb2lab(a), rgb2lab(b))
    flip, flip_p99 = _flip(a, b)
    out = {"ssim": float(ssim), "delta_e": float(de.mean()),
           "de_p99": float(np.percentile(de, 99)), "de_max": float(de.max()),
           "flip": flip, "flip_p99": flip_p99,
           "pass": bool(ssim >= SSIM_MIN and de.mean() <= DELTA_E_MAX)}
    if interior is not None and interior.any():
        out["ssim_interior"] = float(full[interior].mean())
        out["delta_e_interior"] = float(de[interior].mean())
    if band is not None and band.any():
        out["ssim_band"] = float(full[band].mean())
        out["delta_e_band"] = float(de[band].mean())
    return out


def load(path):
    return np.asarray(Image.open(path).convert("RGB"), dtype=np.float64) / 255.0


def load_spec():
    return json.loads((ROOT / "tool/scenes/scenes.json").read_text())


def run(run_dir, no_fail=False, spec=None, prefix="", floor=None):
    """Scores every scene in `run_dir`; returns the process exit code.

    A scene missing either screenshot is reported as missing and fails the
    run, as does a run with nothing scored (unless `no_fail`). `prefix`
    limits the run to scene ids starting with it, as `capture.sh` does.
    `floor` (a noise.py result) adds per-scene floor-relative verdicts
    (`within_noise`): the scene's error sits within Apple's own cross-run /
    cross-API noise. It never changes the exit code — the bars are the
    official ones until the floor-based rule is signed off.
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
        interior, band = region_masks(scene, scale, a.shape[1], a.shape[0])
        r = score(a[y0:y1, x0:x1], b[y0:y1, x0:x1],
                  interior=interior[y0:y1, x0:x1], band=band[y0:y1, x0:x1])
        diff = (np.abs(a[y0:y1, x0:x1] - b[y0:y1, x0:x1]).mean(axis=2) * 4).clip(0, 1)
        Image.fromarray((diff * 255).astype(np.uint8)).save(run_dir / f"{scene['id']}.diff.png")
        rows.append({"id": scene["id"], **r, "region": [x0, y0, x1, y1]})

    if floor:
        f = floor["floor"]
        fs, fd, ff = f["ssim"]["p90"], f["delta_e"]["p90"], f["flip"]["p90"]
        for r in rows:
            r["floor_ssim"], r["floor_de"], r["floor_flip"] = fs, fd, ff
            r["within_noise"] = bool(r["ssim"] >= fs - 0.005 and r["delta_e"] <= fd + 0.05
                                     and r["flip"] <= ff + 0.005)

    passed = sum(r["pass"] for r in rows)
    (run_dir / "report.json").write_text(json.dumps(
        {"scored": len(rows), "passed": passed, "missing": missing, "scenes": rows},
        indent=2))
    cells = "".join(
        f"<tr class={'ok' if r['pass'] else 'bad'}><td>{html.escape(r['id'])}</td>"
        f"<td>{r['ssim']:.4f}</td><td>{r['delta_e']:.2f}</td><td>{r['de_p99']:.2f}</td>"
        f"<td>{r['flip']:.4f}</td><td>{r.get('delta_e_interior', float('nan')):.2f}</td>"
        f"<td>{r.get('delta_e_band', float('nan')):.2f}</td>"
        f"<td><img src='{r['id']}.flutter.png'></td><td><img src='{r['id']}.swiftui.png'></td>"
        f"<td><img src='{r['id']}.diff.png'></td></tr>" for r in rows)
    missing_html = (f"<p class=bad>{len(missing)} missing: "
                    f"{html.escape(', '.join(missing))}</p>" if missing else "")
    (run_dir / "report.html").write_text(
        "<meta charset=utf-8><style>img{width:200px}.bad{background:#fdd}"
        "td{padding:4px;font:13px system-ui}</style>"
        f"<p>{passed}/{len(rows)} pass "
        f"(SSIM ≥ {SSIM_MIN}, ΔE ≤ {DELTA_E_MAX})</p>{missing_html}"
        f"<table><tr><th>scene<th>SSIM<th>ΔE<th>ΔE p99<th>FLIP"
        f"<th>ΔE int<th>ΔE band"
        f"<th>Flutter<th>SwiftUI<th>diff</tr>{cells}</table>")
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
    ap.add_argument("--floor", type=pathlib.Path,
                    help="noise.py result; adds report-only within-noise verdicts")
    ap.add_argument("--scenes", type=pathlib.Path,
                    help="scene list (default tool/scenes/scenes.json), e.g. measure.json "
                         "with --prefix holdout- for the held-out set")
    args = ap.parse_args()
    floor = json.loads(args.floor.read_text()) if args.floor else None
    spec = json.loads(args.scenes.read_text()) if args.scenes else None
    sys.exit(run(args.run_dir, args.no_fail, spec=spec, prefix=args.prefix, floor=floor))


if __name__ == "__main__":
    main()
