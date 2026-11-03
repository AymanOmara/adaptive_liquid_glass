"""Scores native-mode presses against SwiftUI, regular and clear alike.

Usage: python tool/native/score_press.py RUN [--prefix press-] [--out FILE]

RUN comes from `MODE=native tool/fidelity/record_motion.sh RUN press-`.
Every press scene is scored on its own crop.json region and the same
windows, so regular and clear numbers are comparable:

- `press_mae`: in-shape (8 pt inset) mean |SwiftUI - native| over the whole
  press (onset-LEAD ... onset+WINDOW), minus the same residual at rest (the
  first recorded frame), each clip aligned at its own first change. The
  lead covers the light, which comes on a frame before the growth passes
  the onset threshold. Out of 255.
- `press_mae_aligned`: the same, but the release frames are aligned at each
  clip's own release (its glass first shrinking a point below the held
  width) instead of the onset. idb's touch-up lands 0-5 frames apart
  between the two clips of a scene, varying from run to run, which
  `press_mae` scores as renderer error.
- `held_mae`: interior mean |SwiftUI - native| over the held frames
  onset+18...37 (fit_press_light.py's training and validation windows).
- `light`: fit_press_light.py's lift/glow fit of the held residual (pixel
  values the native light is still short by).
- `geometry`: each renderer's bounding box at the held plateau and its
  springs (compare_motion._analyse), and the rms bbox difference in points
  over the window.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tool/fidelity"))
sys.path.insert(0, str(ROOT / "tool/native"))
import compare_motion as cm  # noqa: E402
from fit_press_light import fit_correction  # noqa: E402

WINDOW = 90  # frames after the onset: 0.7 s held, 0.33 s light hold, settle
LEAD = 3     # frames before the onset
INSET_PT = 8


def interior(shape, scale, crop, size):
    """Mask of the shape inset by INSET_PT and the points grid of the crop."""
    h, w = size
    yy, xx = np.indices((h, w))
    x = (xx + crop["x"]) / scale
    y = (yy + crop["y"]) / scale
    cx = shape["x"] + shape["w"] / 2
    cy = shape["y"] + shape["h"] / 2
    halfw, halfh = shape["w"] / 2 - INSET_PT, shape["h"] / 2 - INSET_PT
    radius = (min(shape["w"], shape["h"]) / 2 if shape["shape"] in
              ("capsule", "circle") else shape["radius"]) - INSET_PT
    radius = max(0, min(radius, halfw, halfh))
    dx = np.maximum(np.abs(x - cx) - halfw + radius, 0)
    dy = np.maximum(np.abs(y - cy) - halfh + radius, 0)
    mask = (np.abs(x - cx) < halfw) & (np.abs(y - cy) < halfh)
    if radius > 0:
        mask &= dx * dx + dy * dy < radius * radius
    return mask, x, y


def score_scene(run, m, scale, crop):
    raw = {r: cm._load_frames(run / "frames" / f"{m['id']}.{r}")
           for r in ("flutter", "swiftui")}
    if not all(raw.values()):
        raise ValueError(f"no frames for {m['id']}")
    onset = {r: cm.first_change(f) for r, f in raw.items()}
    for r, k in onset.items():
        if k + 38 > len(raw[r]):
            raise ValueError(f"{m['id']}.{r}: no press onset with a held plateau")

    def window(r):
        s = raw[r][max(0, onset[r] - LEAD):]
        return (s + [s[-1]] * (WINDOW + LEAD - len(s)))[:WINDOW + LEAD]

    seqs = {r: window(r) for r in raw}
    mask, x, y = interior(m["shape"], scale, crop, seqs["flutter"][0].shape[:2])
    rest = (raw["swiftui"][0] - raw["flutter"][0])[mask]
    per = [float(np.abs((s - f)[mask] - rest).mean() * 255)
           for s, f in zip(seqs["swiftui"], seqs["flutter"])]
    held = {r: [np.mean(raw[r][onset[r] + lo:onset[r] + hi], axis=0)
                for lo, hi in ((18, 28), (28, 38))] for r in raw}
    residual = [(s - f) * 255 for s, f in zip(held["swiftui"], held["flutter"])]
    d2 = (x - m["touch"]["x"]) ** 2 + (y - m["touch"]["y"]) ** 2
    light, _ = fit_correction(residual[0], mask, d2)

    bg = cm._asset_background(m, crop)
    analysis = {r: cm._analyse(m, s, bg, scale, crop) for r, s in seqs.items()}
    boxes = {r: [cm.glass_bbox(f, bg) for f in s] for r, s in seqs.items()}
    diffs = [np.subtract(a, b) / scale for a, b in zip(boxes["swiftui"], boxes["flutter"])
             if a and b]
    rel = int(round(m["hold_ms"] / 1000 * cm.FPS)) + LEAD
    release = {r: _release(boxes[r], onset[r], rel - LEAD) for r in boxes}
    held_len = min(release[r] - onset[r] for r in release)

    def aligned(r):
        frames = raw[r] + [raw[r][-1]] * (WINDOW + LEAD)
        s = frames[max(0, onset[r] - LEAD):onset[r] + held_len]
        return s + frames[release[r]:release[r] + WINDOW - held_len]

    per_aligned = [float(np.abs((s - f)[mask] - rest).mean() * 255)
                   for s, f in zip(aligned("swiftui"), aligned("flutter"))]
    plateau = {r: [float(v) / scale for v in np.median(
        [b for b in boxes[r][rel - 6:rel] if b], axis=0)] for r in boxes}
    geometry = {
        "bbox_rms_pt": float(np.sqrt(np.mean(np.square(diffs)))) if diffs else None,
        "plateau_pt": plateau,
        **{r: {k: v for k, v in a.items() if k != "widths"} for r, a in analysis.items()},
    }
    return {
        "id": m["id"], "variant": m["shape"]["variant"], "brightness": m["brightness"],
        "crop": crop, "onset": onset,
        "press_mae": float(np.mean(per)),
        "press_mae_aligned": float(np.mean(per_aligned)),
        "release": release,
        "press_mae_held": float(np.mean(per[:rel])),
        "press_mae_release": float(np.mean(per[rel:])),
        "held_mae": float(np.mean([np.abs(r[mask]).mean() for r in residual])),
        "light": light,
        "geometry": geometry,
    }


def _release(boxes, onset, hold):
    """Frame (in the full clip) where the glass first shrinks a point below
    its held width, searched from 10 frames before the nominal release;
    the nominal release when it never does."""
    def width(b):
        return b[2] - b[0] if b else 0
    held = np.median([width(b) for b in boxes[LEAD + hold - 16:LEAD + hold - 10]])
    for k in range(LEAD + hold - 10, len(boxes)):
        if boxes[k] and width(boxes[k]) < held - 3:
            return onset + k - LEAD
    return onset + hold


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("run", type=Path)
    parser.add_argument("--prefix", default="press-")
    parser.add_argument("--out", type=Path)
    args = parser.parse_args()
    spec = json.loads((ROOT / "tool/scenes/motion.json").read_text())
    crops = json.loads((args.run / "crop.json").read_text())
    report = [score_scene(args.run, m, spec["device"]["scale"], crops[m["id"]])
              for m in spec["motion"]
              if m["id"].startswith(args.prefix) and m["kind"] == "press"
              and m["id"] in crops]
    if not report:
        parser.error("no recorded press scenes")
    output = json.dumps(report, indent=2) + "\n"
    if args.out:
        args.out.write_text(output)
    for r in report:
        g = r["geometry"]
        print(f"{r['id']}: press {r['press_mae']:.2f} (aligned {r['press_mae_aligned']:.2f}, held {r['press_mae_held']:.2f}, "
              f"release {r['press_mae_release']:.2f}), held-frame {r['held_mae']:.2f}, "
              f"light short {r['light']['lift_px']:+.2f} + {r['light']['peak_px']:+.2f}"
              f"·G({r['light']['sigma_pt']:.0f}), bbox rms {g['bbox_rms_pt']:.2f} pt, "
              f"scale S {g['swiftui'].get('pressScale')} F {g['flutter'].get('pressScale')}")


if __name__ == "__main__":
    main()
