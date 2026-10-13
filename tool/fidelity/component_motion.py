"""Fits SwiftUI springs to a component's motion, reference against twin
(recordings from record_component_motion.sh).

Usage: component_motion.py <take-dir> [<take-dir> ...]
         --box x0,y0,x1,y1 --edge bottom|top|left|right [--dark N | --light N]

Per frame, the outermost row (top / bottom) or column (left / right) in the
box (crop px) whose grey level is below --dark (ink) or above --light
(glass on a dark page) is the tracked edge, in pt. Held (stalled) frames are
dropped. Prints its travel and the SwiftUI spring (response, dampingFraction) fitted to it, per take.
"""
import argparse
import glob
import json

import numpy as np
from PIL import Image

from compare_motion import fit_spring

SCALE = 3
MIN_PIXELS = 3      # a row / column counts once this many pixels match


def edge(frame, box, side, dark, light):
    x0, y0, x1, y1 = box
    g = frame[y0:y1, x0:x1]
    m = g < dark if dark is not None else g > light
    axis = 1 if side in ("top", "bottom") else 0
    hits = np.where(m.sum(axis=axis) >= MIN_PIXELS)[0]
    if len(hits) == 0:
        return np.nan
    off = y0 if axis == 1 else x0
    v = hits[-1] + 1 if side in ("bottom", "right") else hits[0]
    return (v + off) / SCALE


def measure(d, box, side, dark, light):
    fs = sorted(glob.glob(f"{d}/*.png"))
    x = np.array([edge(np.asarray(Image.open(f).convert("L")).astype(np.int16),
                       box, side, dark, light) for f in fs])
    t = np.arange(len(x)) / 60
    # Frames the app held over a stall repeat the last one; only fresh
    # frames sit at their own time.
    held = set(json.load(open(f"{d}/times.json")).get("held", []))
    ok = ~np.isnan(x) & ~np.isin(np.arange(len(x)), list(held))
    return t[ok], x[ok]


def main():
    p = argparse.ArgumentParser()
    p.add_argument("takes", nargs="+")
    p.add_argument("--box", required=True)
    p.add_argument("--edge", required=True, choices=["top", "bottom", "left", "right"])
    p.add_argument("--dark", type=int)
    p.add_argument("--light", type=int)
    p.add_argument("--trace", action="store_true")
    p.add_argument("--last", action="store_true",
                   help="fit only the final move (e.g. a refresh's snap-back)")
    a = p.parse_args()
    box = [int(v) for v in a.box.split(",")]
    for d in a.takes:
        t, x = measure(d, box, a.edge, a.dark, a.light)
        if a.trace:
            print(" ".join(f"{v:.1f}" for v in x))
        if a.last:
            # Only the final move: from the last still frame (within 1 pt
            # of the three before it) away from the resting value.
            still = [k for k in range(3, len(x))
                     if abs(x[k] - x[-1]) > 5 and np.ptp(x[k - 3:k + 1]) <= 1]
            if still:
                t, x = t[still[-1]:], x[still[-1]:]
        if len(x) < 4 or abs(x[-1] - x[0]) < 1:
            print(f"{d}: no travel ({x[0] if len(x) else 'none'})")
            continue
        f = fit_spring(t, x, full=True)
        r, z, rms = f["response"], f["damping"], f["rms"]
        print(f"{d}: {x[0]:.1f} -> {x[-1]:.1f} pt  response {r:.3f}  "
              f"damping {z:.2f}  rms {rms:.2f} pt")


if __name__ == "__main__":
    main()
