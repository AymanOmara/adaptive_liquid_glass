"""Compare measured sinusoidal detail with the current glass model.

Uses saved independent measurement captures, never the text scoring pattern.
Phase error is modulo the period; amplitude/phase summaries are diagnostics,
not certified fidelity scores. Crops and background caches are streamed.
"""
import argparse
import json
import os
import pathlib

for name in ("OPENBLAS_NUM_THREADS", "OMP_NUM_THREADS", "VECLIB_MAXIMUM_THREADS"):
    os.environ.setdefault(name, "1")

import numpy as np
from PIL import Image

import glass_model as gm
import measure_lens as ml

ROOT = pathlib.Path(__file__).resolve().parents[2]


def response(images):
    return ((images[0] - images[2]) + 1j * (images[3] - images[1])) / 2


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--native", required=True, type=pathlib.Path)
    ap.add_argument("--out", required=True, type=pathlib.Path)
    args = ap.parse_args()
    spec = json.loads((ROOT / "tool/scenes/measure.json").read_text())
    constants = gm.resolve_constants({})
    results = {"kind": "independent_detail_diagnostic", "device_certified": False,
               "native": str(args.native.resolve()), "scenes": {}}
    for base in ("clear-capsule-light", "clear-rect28-light"):
        original = next(s for s in spec["scenes"] if s["id"].startswith(base + "--"))
        for period in (32, 48, 80):
            native, model = [], []
            for phase in range(4):
                background = f"code-x-p{period}-k{phase}"
                sid = f"{base}--{background}"
                scene = dict(original, id=sid, background=background)
                bg = ml.load(ROOT / f"example/assets/backgrounds/{background}.png")
                win, box = gm.render_window(bg, scene, constants, scale=3)
                x0, y0, x1, y1 = box
                model.append(win[..., 1].copy())
                with Image.open(args.native / f"{sid}.swiftui.png") as image:
                    native.append(np.asarray(image.convert("RGB").crop(box),
                                             dtype=float)[..., 1] / 255)
                gm._BG.clear()
                gm._blurred_cached.cache_clear()
                del bg, win
            nr, mr = response(native), response(model)
            py, px = np.mgrid[y0:y1, x0:x1] + .5
            g = ml.shape_geometry(scene["shapes"][0], 3, px, py)
            depth = g["depth"] / 3
            phase_error = np.angle(nr * np.conjugate(mr)) * period / (2 * np.pi * 3)
            ratio = np.abs(nr) / np.maximum(np.abs(mr), 1e-9)
            rows = []
            for region, spatial in (("corners", g["corner"]),
                                    ("normal-x", ~g["corner"] & (abs(g["nx"]) > .9)),
                                    ("normal-y", ~g["corner"] & (abs(g["ny"]) > .9))):
                edges = (0, 1, 2, 3, 4, 6, 10, 16, 28, 40, 70)
                for lo, hi in zip(edges, edges[1:]):
                    mask = spatial & (depth >= lo) & (depth < hi) & \
                           (np.abs(nr) > 2 / 255) & (np.abs(mr) > 2 / 255)
                    if mask.sum() < 20:
                        continue
                    rows.append({"region": region, "depth_pt": [lo, hi],
                                 "n": int(mask.sum()),
                                 "amplitude_ratio": float(np.median(ratio[mask])),
                                 "phase_error_pt_mod_period": float(np.median(phase_error[mask])),
                                 "phase_abs_p90_pt": float(np.percentile(abs(phase_error[mask]), 90))})
            results["scenes"][f"{base}-p{period}"] = rows
            args.out.parent.mkdir(parents=True, exist_ok=True)
            args.out.write_text(json.dumps(results, indent=2) + "\n")
            print(f"Measured {base}, period {period} px", flush=True)


if __name__ == "__main__":
    main()
