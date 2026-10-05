"""Scores two capture runs against each other: the noise floor measurement.

The fidelity question is not "how close is Flutter to SwiftUI" alone but
"how close is Apple to itself" — a scene whose Flutter-vs-SwiftUI error is
within the cross-run (or cross-API) noise of the reference is
indistinguishable, and no reimplementation can do better. This tool scores
every scene of two run dirs against each other with compare.py's metrics
and aggregates the per-metric floor (median and p90 across scenes).

Usage:
    noise.py <dirA> <dirB> [--suffix-a .swiftui.png] [--suffix-b .swiftui.png]
             [--spec tool/scenes/scenes.json]
writes <dirA>/noise.json and noise.html.
"""
import argparse
import html
import json
import pathlib
import sys

import numpy as np

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from compare import load, load_spec, region_for, region_masks, score  # noqa: E402

FLOOR_METRICS = ("ssim", "delta_e", "de_p99", "de_max", "flip", "flip_p99")


def run(dir_a, dir_b, suffix_a=".swiftui.png", suffix_b=".swiftui.png", spec=None):
    """Scores every spec scene across the two dirs; refuses (SystemExit) any
    scene missing either capture, so a stale or partial run cannot silently
    thin out the floor."""
    dir_a, dir_b = pathlib.Path(dir_a), pathlib.Path(dir_b)
    spec = spec or load_spec()
    scale = spec["device"]["scale"]
    rows = []
    for scene in spec["scenes"]:
        fa = dir_a / f"{scene['id']}{suffix_a}"
        fb = dir_b / f"{scene['id']}{suffix_b}"
        if not (fa.exists() and fb.exists()):
            sys.exit(f"noise.py: missing capture for {scene['id']}: "
                     f"{fa if not fa.exists() else fb}")
        a, b = load(fa), load(fb)
        if a.shape != b.shape:
            sys.exit(f"noise.py: {scene['id']}: {fa.name} {a.shape} != {fb.name} {b.shape}")
        x0, y0, x1, y1 = region_for(scene, scale, a.shape[1], a.shape[0])
        interior, band = region_masks(scene, scale, a.shape[1], a.shape[0])
        rows.append({"id": scene["id"], **score(a[y0:y1, x0:x1], b[y0:y1, x0:x1],
                                                interior=interior[y0:y1, x0:x1],
                                                band=band[y0:y1, x0:x1])})
    floor = {m: {"median": float(np.median([r[m] for r in rows])),
                 "p90": float(np.percentile([r[m] for r in rows], 90))}
             for m in FLOOR_METRICS}
    out = {"dir_a": str(dir_a), "dir_b": str(dir_b), "floor": floor, "scenes": rows}
    (dir_a / "noise.json").write_text(json.dumps(out, indent=2))
    cells = "".join(
        f"<tr><td>{html.escape(r['id'])}</td><td>{r['ssim']:.4f}</td>"
        f"<td>{r['delta_e']:.2f}</td><td>{r['de_p99']:.2f}</td><td>{r['flip']:.4f}</td></tr>"
        for r in rows)
    summary = " ".join(f"{m} med {v['median']:.4f} / p90 {v['p90']:.4f},"
                       for m, v in floor.items()).rstrip(",")
    (dir_a / "noise.html").write_text(
        "<meta charset=utf-8><style>td{padding:4px;font:13px system-ui}</style>"
        f"<p>{len(rows)} scenes: {dir_a} vs {dir_b}</p><p>{html.escape(summary)}</p>"
        f"<table><tr><th>scene<th>SSIM<th>ΔE<th>ΔE p99<th>FLIP</tr>{cells}</table>")
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dir_a", type=pathlib.Path)
    ap.add_argument("dir_b", type=pathlib.Path)
    ap.add_argument("--suffix-a", default=".swiftui.png")
    ap.add_argument("--suffix-b", default=".swiftui.png")
    ap.add_argument("--spec", type=pathlib.Path, default=None)
    args = ap.parse_args()
    spec = json.loads(args.spec.read_text()) if args.spec else None
    out = run(args.dir_a, args.dir_b, args.suffix_a, args.suffix_b, spec)
    print(json.dumps(out["floor"], indent=1))


if __name__ == "__main__":
    main()
